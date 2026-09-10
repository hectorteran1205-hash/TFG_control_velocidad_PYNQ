%% COMPARACION EXPERIMENTAL DE LOS CONTROLADORES P, PI Y PID
% Lee los tres CSV exportados por la interfaz, calcula metricas comunes y
% genera una figura preparada para incluirla en la memoria.

clear;
clc;
close all;

carpetaScript = fileparts(mfilename('fullpath'));

archivoP = localizarArchivo(carpetaScript, {
    'ensayo_P_Kp350_Ki0_Kd0.csv', ...
    'ensayo_PI_Kp350_Ki0_Kd0_2026-09-05_13-14-30.csv' ...
}, 'Selecciona el ensayo P');

archivoPI = localizarArchivo(carpetaScript, {
    'ensayo_PI_Kp350_Ki40_Kd0.csv', ...
    'ensayo_PI_Kp350_Ki40_Kd0_2026-09-05_13-16-44.csv' ...
}, 'Selecciona el ensayo PI');

archivoPID = localizarArchivo(carpetaScript, {
    'ensayo_PID_Kp350_Ki40_Kd50.csv', ...
    'ensayo_PI_Kp350_Ki40_Kd50_2026-09-05_13-19-00.csv' ...
}, 'Selecciona el ensayo PID');

datosP = cargarEnsayo(archivoP);
datosPI = cargarEnsayo(archivoPI);
datosPID = cargarEnsayo(archivoPID);

% Se toma como origen temporal la primera muestra de cada ensayo.
datosP.tiempo_s = datosP.tiempo_s - datosP.tiempo_s(1);
datosPI.tiempo_s = datosPI.tiempo_s - datosPI.tiempo_s(1);
datosPID.tiempo_s = datosPID.tiempo_s - datosPID.tiempo_s(1);

%% Calculo de las metricas
metricasP = calcularMetricas(datosP, "P");
metricasPI = calcularMetricas(datosPI, "PI");
metricasPID = calcularMetricas(datosPID, "PID");

resultados = [metricasP; metricasPI; metricasPID];

disp(' ');
disp('COMPARACION DE LOS CONTROLADORES');
disp(resultados);

salidaResultados = fullfile(carpetaScript, ...
    'resultados_comparacion_controladores.csv');
writetable(resultados, salidaResultados);

%% Representacion grafica
colorP = [0.0000, 0.4470, 0.7410];
colorPI = [0.1000, 0.6000, 0.3000];
colorPID = [0.8500, 0.2500, 0.1500];
colorReferencia = [0.1000, 0.1000, 0.1000];

figura = figure( ...
    'Color', 'w', ...
    'Position', [100, 100, 1400, 850] ...
);

distribucion = tiledlayout(2, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact' ...
);

% Comparacion de la velocidad.
ejeVelocidad = nexttile;

plot(datosP.tiempo_s, datosP.velocidad_rpm, ...
    'Color', colorP, 'LineWidth', 1.4);
hold on;

plot(datosPI.tiempo_s, datosPI.velocidad_rpm, ...
    'Color', colorPI, 'LineWidth', 1.4);

plot(datosPID.tiempo_s, datosPID.velocidad_rpm, ...
    'Color', colorPID, 'LineWidth', 1.4);

stairs(datosPI.tiempo_s, datosPI.referencia_rpm, '--', ...
    'Color', colorReferencia, 'LineWidth', 1.6);

ylabel('Velocidad (rpm)');
title('Seguimiento de la referencia', 'Color', 'k');
leyendaVelocidad = legend({'P', 'PI', 'PID', 'Referencia'}, ...
    'Location', 'northoutside', ...
    'Orientation', 'horizontal');
grid on;
xlim([0, 32]);
ylim([0, 240]);

% Comparacion de la accion de control.
ejeDuty = nexttile;

plot(datosP.tiempo_s, datosP.duty_percent, ...
    'Color', colorP, 'LineWidth', 1.3);
hold on;

plot(datosPI.tiempo_s, datosPI.duty_percent, ...
    'Color', colorPI, 'LineWidth', 1.3);

plot(datosPID.tiempo_s, datosPID.duty_percent, ...
    'Color', colorPID, 'LineWidth', 1.3);

xlabel('Tiempo (s)');
ylabel('Duty cycle (%)');
title('Accion de control', 'Color', 'k');
leyendaDuty = legend({'P', 'PI', 'PID'}, ...
    'Location', 'northoutside', ...
    'Orientation', 'horizontal');
grid on;
xlim([0, 32]);
ylim([0, 105]);

% Formato blanco para su inclusion en el documento.
ejes = [ejeVelocidad, ejeDuty];
for k = 1:numel(ejes)
    ejes(k).Color = 'w';
    ejes(k).XColor = 'k';
    ejes(k).YColor = 'k';
    ejes(k).GridColor = [0.75, 0.75, 0.75];
    ejes(k).GridAlpha = 0.45;
    ejes(k).FontSize = 11;
end

leyendas = [leyendaVelocidad, leyendaDuty];
for k = 1:numel(leyendas)
    leyendas(k).Color = 'w';
    leyendas(k).TextColor = 'k';
    leyendas(k).EdgeColor = [0.55, 0.55, 0.55];
end

title(distribucion, ...
    'Comparacion experimental de los controladores P, PI y PID', ...
    'FontWeight', 'bold', ...
    'Color', 'k');

salidaFigura = fullfile(carpetaScript, ...
    'comparacion_controladores.png');
exportgraphics(figura, salidaFigura, 'Resolution', 300);

fprintf('\nFigura guardada en:\n%s\n', salidaFigura);
fprintf('Tabla de resultados guardada en:\n%s\n', salidaResultados);


%% FUNCIONES LOCALES
function archivo = localizarArchivo(carpeta, nombres, tituloVentana)

    archivo = '';

    for k = 1:numel(nombres)
        candidato = fullfile(carpeta, nombres{k});

        if isfile(candidato)
            archivo = candidato;
            return;
        end
    end

    [nombre, ruta] = uigetfile('*.csv', tituloVentana);

    if isequal(nombre, 0)
        error('No se ha seleccionado uno de los ensayos necesarios.');
    end

    archivo = fullfile(ruta, nombre);

end


function datos = cargarEnsayo(archivo)

    datos = readtable(archivo);

    columnas = {
        'tiempo_s', ...
        'referencia_rpm', ...
        'velocidad_rpm', ...
        'duty_percent'
    };

    if ~all(ismember(columnas, datos.Properties.VariableNames))
        error('El archivo %s no contiene las columnas necesarias.', archivo);
    end

end


function resultado = calcularMetricas(datos, controlador)

    t = datos.tiempo_s(:);
    referencia = datos.referencia_rpm(:);
    velocidad = datos.velocidad_rpm(:);

    % Las dos primeras decimas se excluyen de las metricas globales porque
    % incluyen la activacion inicial de la adquisicion.
    mascaraGlobal = t >= 0.2;
    errorGlobal = referencia(mascaraGlobal) - velocidad(mascaraGlobal);

    MAE = mean(abs(errorGlobal));
    RMSE = sqrt(mean(errorGlobal.^2));

    cambios = [1; find(diff(referencia) ~= 0) + 1; numel(t) + 1];
    erroresEstacionarios = [];
    sobreimpulsos = [];
    tiemposEstablecimiento = [];

    for tramo = 1:numel(cambios)-1
        indiceInicial = cambios(tramo);
        indiceFinal = cambios(tramo+1) - 1;

        tiempoInicial = t(indiceInicial);
        tiempoFinal = t(indiceFinal);
        valorReferencia = referencia(indiceInicial);

        % Regimen permanente: ultimos tres segundos de cada escalon.
        inicioVentana = max(tiempoInicial + 1, tiempoFinal - 3);
        mascaraEstacionaria = ...
            t >= inicioVentana & ...
            t <= tiempoFinal & ...
            referencia == valorReferencia;

        velocidadMedia = mean(velocidad(mascaraEstacionaria));
        erroresEstacionarios(end+1, 1) = ...
            abs(valorReferencia - velocidadMedia);

        % Sobreimpulso solamente en los cambios ascendentes.
        esAscendente = tramo == 1 || ...
            valorReferencia > referencia(cambios(tramo-1));

        if esAscendente
            pico = max(velocidad(indiceInicial:indiceFinal));
            sobreimpulsos(end+1, 1) = max( ...
                0, ...
                100*(pico-valorReferencia)/valorReferencia ...
            );
        end

        % Tiempo de establecimiento dentro de una banda del 2 %.
        banda = 0.02 * valorReferencia;
        tiempoTramo = NaN;

        for indice = indiceInicial:indiceFinal
            errorRestante = abs( ...
                velocidad(indice:indiceFinal) - valorReferencia ...
            );

            if all(errorRestante <= banda)
                tiempoTramo = t(indice) - tiempoInicial;
                break;
            end
        end

        tiemposEstablecimiento(end+1, 1) = tiempoTramo;
    end

    errorEstacionarioMedio = mean(erroresEstacionarios);
    sobreimpulsoMaximo = max(sobreimpulsos);

    if all(isnan(tiemposEstablecimiento))
        tiempoEstablecimientoMedio = NaN;
    else
        tiempoEstablecimientoMedio = ...
            mean(tiemposEstablecimiento, 'omitnan');
    end

    resultado = table( ...
        string(controlador), ...
        MAE, ...
        RMSE, ...
        errorEstacionarioMedio, ...
        sobreimpulsoMaximo, ...
        tiempoEstablecimientoMedio, ...
        'VariableNames', { ...
            'controlador', ...
            'mae_global_rpm', ...
            'rmse_global_rpm', ...
            'error_estacionario_medio_rpm', ...
            'sobreimpulso_maximo_percent', ...
            'tiempo_establecimiento_medio_s' ...
        } ...
    );

end
