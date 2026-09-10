%% CAPTURA DEL ENSAYO DINÁMICO DEL MOTOR
clear;
clc;
close all;

%% Configuración del puerto serie
puerto = "COM3";
baudrate = 115200;

%% Comprobar que el puerto está disponible
puertosDisponibles = serialportlist("available");

if ~ismember(puerto, puertosDisponibles)
    error( ...
        "El puerto %s no está disponible. Puertos detectados: %s", ...
        puerto, ...
        strjoin(puertosDisponibles, ", ") ...
    );
end

%% Abrir comunicación con Arduino
arduinoSerial = serialport(puerto, baudrate);

configureTerminator(arduinoSerial, "LF");
arduinoSerial.Timeout = 4;

% Elimina datos antiguos que pudieran quedar en el buffer.
% Al abrir el puerto, el Arduino normalmente se reinicia
% y comienza el ensayo automáticamente.
flush(arduinoSerial);

disp("Puerto COM3 abierto.");
disp("Esperando el inicio del ensayo...");
disp("No desconectes el Arduino ni abras el monitor serie.");

%% Vectores donde se almacenarán los datos
tiempo = [];
duty = [];
pulsosPorSegundo = [];

numeroMuestras = 0;

%% Lectura hasta recibir la palabra END
while true

    try
        linea = strip(readline(arduinoSerial));
    catch errorLectura
        warning( ...
            "No se ha recibido una línea válida: %s", ...
            errorLectura.message ...
        );
        continue;
    end

    % Ignorar líneas vacías
    if strlength(linea) == 0
        continue;
    end

    % Final del ensayo
    if linea == "END"
        disp("Arduino ha indicado el final del ensayo.");
        break;
    end

    % Intentar interpretar:
    % tiempo_s,duty,pulsos_por_segundo
    valores = sscanf(linea, "%f,%f,%f");

    % La cabecera de texto se ignora automáticamente
    if numel(valores) ~= 3
        continue;
    end

    numeroMuestras = numeroMuestras + 1;

    tiempo(numeroMuestras, 1) = valores(1);
    duty(numeroMuestras, 1) = valores(2);
    pulsosPorSegundo(numeroMuestras, 1) = valores(3);

    % Mostrar progreso aproximadamente cada 100 muestras
    if mod(numeroMuestras, 100) == 0
        fprintf( ...
            "Tiempo: %.2f s | Duty: %.0f %% | Encoder: %.1f pulsos/s\n", ...
            tiempo(end), ...
            duty(end) * 100, ...
            pulsosPorSegundo(end) ...
        );
    end
end

%% Cerrar el puerto
clear arduinoSerial;

%% Comprobar que se recibieron datos
if isempty(tiempo)
    error("No se ha recibido ninguna muestra válida del Arduino.");
end

%% Crear tabla
datosRaw = table( ...
    tiempo(:), ...
    duty(:), ...
    pulsosPorSegundo(:), ...
    'VariableNames', ...
    {'tiempo_s', 'duty', 'pulsos_por_segundo'} ...
);

%% Guardar CSV
nombreArchivo = "ensayo_motor_raw.csv";
writetable(datosRaw, nombreArchivo);

fprintf("\nEnsayo terminado correctamente.\n");
fprintf("Muestras registradas: %d\n", height(datosRaw));
fprintf("Archivo guardado: %s\n", nombreArchivo);

%% Representación gráfica inicial
figure;

yyaxis left;
plot( ...
    datosRaw.tiempo_s, ...
    abs(datosRaw.pulsos_por_segundo), ...
    "LineWidth", 1.2 ...
);
ylabel("Frecuencia del encoder (pulsos/s)");

yyaxis right;
stairs( ...
    datosRaw.tiempo_s, ...
    datosRaw.duty * 100, ...
    "LineWidth", 1.2 ...
);
ylabel("Duty cycle (%)");

xlabel("Tiempo (s)");
title("Respuesta dinámica del conjunto motor-L298N");
grid on;