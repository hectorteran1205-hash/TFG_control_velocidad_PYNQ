%% IDENTIFICACION DEL CONJUNTO MOTOR-L298N A PARTIR DEL CSV
% Este programa no se comunica con Arduino ni con la PYNQ-Z2.
% Unicamente procesa los datos ya guardados durante el ensayo dinamico.

clear;
clc;
close all;

%% Localizacion del archivo de datos
carpetaScript = fileparts(mfilename('fullpath'));

archivoCSV = fullfile(carpetaScript, 'ensayo_motor_raw.csv');

% Se admite tambien el nombre asignado al descargar una copia del archivo.
if ~isfile(archivoCSV)
    archivoCSV = fullfile(carpetaScript, 'ensayo_motor_raw(1).csv');
end

% Si el CSV no esta junto al programa, se permite seleccionarlo manualmente.
if ~isfile(archivoCSV)
    [nombreCSV, carpetaCSV] = uigetfile('*.csv', ...
        'Selecciona el archivo del ensayo dinamico');

    if isequal(nombreCSV, 0)
        error('No se ha seleccionado ningun archivo CSV.');
    end

    archivoCSV = fullfile(carpetaCSV, nombreCSV);
end

%% Lectura y comprobacion de los datos
datos = readtable(archivoCSV);

columnasNecesarias = {
    'tiempo_s', ...
    'duty', ...
    'pulsos_por_segundo'
};

if ~all(ismember(columnasNecesarias, datos.Properties.VariableNames))
    error(['El CSV debe contener las columnas tiempo_s, duty y ' ...
           'pulsos_por_segundo.']);
end

t = datos.tiempo_s(:);
u = datos.duty(:);
y = abs(datos.pulsos_por_segundo(:));

filasValidas = isfinite(t) & isfinite(u) & isfinite(y);
t = t(filasValidas);
u = u(filasValidas);
y = y(filasValidas);

if numel(t) < 3
    error('El archivo no contiene suficientes muestras validas.');
end

if any(diff(t) <= 0)
    error('La columna de tiempo debe ser estrictamente creciente.');
end

periodoMuestreoMedio = mean(diff(t));

%% Ajuste de un modelo de primer orden sin retardo puro
% Modelo: G(s) = K / (tau*s + 1)
% Entrada: duty normalizado entre 0 y 1.
% Salida: frecuencia del encoder en pulsos/s.

gananciaInicial = max(y) / max(u);
tauInicial = 0.4;

% Se optimizan los logaritmos para garantizar K > 0 y tau > 0.
parametrosIniciales = log([gananciaInicial, tauInicial]);

funcionCoste = @(p) sum((y - simularPrimerOrden( ...
    t, u, exp(p(1)), exp(p(2)))).^2);

opciones = optimset( ...
    'Display', 'off', ...
    'TolX', 1e-10, ...
    'TolFun', 1e-6, ...
    'MaxIter', 2000, ...
    'MaxFunEvals', 5000 ...
);

parametrosOptimos = fminsearch( ...
    funcionCoste, ...
    parametrosIniciales, ...
    opciones ...
);

K = exp(parametrosOptimos(1));
tau = exp(parametrosOptimos(2));
yModelo = simularPrimerOrden(t, u, K, tau);

%% Indicadores del ajuste
residuo = y - yModelo;
RMSE = sqrt(mean(residuo.^2));
R2 = 1 - sum(residuo.^2) / sum((y - mean(y)).^2);

fprintf('\nIDENTIFICACION DEL CONJUNTO MOTOR-L298N\n');
fprintf('Archivo analizado: %s\n', archivoCSV);
fprintf('Numero de muestras: %d\n', numel(t));
fprintf('Periodo medio de adquisicion: %.6f s\n', periodoMuestreoMedio);
fprintf('Ganancia K: %.3f pulsos/s por unidad de duty\n', K);
fprintf('Constante de tiempo tau: %.4f s\n', tau);
fprintf('RMSE: %.3f pulsos/s\n', RMSE);
fprintf('R^2: %.6f\n', R2);
fprintf('Modelo: G(s) = %.3f / (%.4f*s + 1)\n\n', K, tau);

%% Grafica de comparacion entre los datos y el modelo
figura = figure('Color', 'w');

yyaxis left;
curvaMedida = plot(t, y, ...
    'Color', [0.0000, 0.4470, 0.7410], ...
    'LineWidth', 1.1);
hold on;
curvaModelo = plot(t, yModelo, '--', ...
    'Color', [0.8500, 0.3250, 0.0980], ...
    'LineWidth', 1.7);
ylabel('Frecuencia del encoder (pulsos/s)');

yyaxis right;
curvaDuty = stairs(t, 100*u, ...
    'Color', [0.30, 0.30, 0.30], ...
    'LineWidth', 1.0);
ylabel('Duty cycle (\%)');

xlabel('Tiempo (s)');
title('Identificacion del modelo de primer orden');
legend( ...
    [curvaMedida, curvaModelo, curvaDuty], ...
    {'Medida', 'Modelo ajustado', 'Duty cycle'}, ...
    'Location', 'best' ...
);
grid on;

salidaFigura = fullfile(carpetaScript, ...
    'identificacion_modelo_motor.png');
ax = gca;
ax.Color = 'w';
ax.XColor = 'k';
ax.YAxis(1).Color = [0.0000, 0.4470, 0.7410];
ax.YAxis(2).Color = [0.8500, 0.3250, 0.0980];
ax.GridColor = [0.75, 0.75, 0.75];
ax.GridAlpha = 0.5;

title('Identificación del modelo de primer orden', 'Color', 'k');
xlabel('Tiempo (s)', 'Color', 'k');

set(gcf, 'Color', 'w');
exportgraphics(figura, salidaFigura, 'Resolution', 300);

%% Almacenamiento de los resultados numericos
resultados = table( ...
    periodoMuestreoMedio, ...
    K, ...
    tau, ...
    RMSE, ...
    R2, ...
    'VariableNames', { ...
        'periodo_muestreo_medio_s', ...
        'ganancia_pulsos_s_por_duty', ...
        'constante_tiempo_s', ...
        'rmse_pulsos_s', ...
        'r_cuadrado' ...
    } ...
);

salidaResultados = fullfile(carpetaScript, ...
    'parametros_modelo_motor.csv');
writetable(resultados, salidaResultados);

fprintf('Figura guardada en: %s\n', salidaFigura);
fprintf('Resultados guardados en: %s\n', salidaResultados);


%% FUNCION LOCAL: SIMULACION EXACTA ENTRE MUESTRAS
function yEstimado = simularPrimerOrden(t, u, K, tau)

    yEstimado = zeros(size(t));
    yEstimado(1) = 0;

    for k = 2:numel(t)
        dt = t(k) - t(k-1);
        a = exp(-dt / tau);

        yEstimado(k) = ...
            a*yEstimado(k-1) + (1-a)*K*u(k-1);
    end

end
