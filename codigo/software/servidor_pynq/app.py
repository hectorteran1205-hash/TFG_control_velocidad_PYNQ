from flask import Flask, jsonify, request
from pynq import Overlay
import threading
import math


# CONFIGURACIÓN GENERAL

BITSTREAM = (
    "/home/xilinx/jupyter_notebooks/"
    "overlays/motor_control/motor_control.bit"
)

app = Flask(__name__)


# Evita que dos peticiones HTTP accedan al periférico
# AXI simultáneamente
axi_lock = threading.Lock()


# PARÁMETROS FÍSICOS DEL SISTEMA

# Frecuencia del reloj AXI / lógica de control de la FPGA
FPGA_CLOCK_HZ = 100_000_000

ENCODER_COUNTS_PER_OUTPUT_REV = 1320.0


# CARGA DEL OVERLAY

overlay = Overlay(BITSTREAM)

motor = overlay.motor_control_axi_0


# MAPA DE REGISTROS AXI

CONTROL       = 0x00
PWM_PERIOD    = 0x04
DUTY_MANUAL   = 0x08
SPEED_REF     = 0x0C

KP            = 0x10
KI            = 0x14
KD            = 0x18
SAMPLE_TIME   = 0x1C

SPEED         = 0x20
ERROR         = 0x24
DUTY_ACTUAL   = 0x28
ENCODER_COUNT = 0x2C
STATUS        = 0x30


# FUNCIONES AUXILIARES BÁSICAS

def signed32(value):
    """
    Convierte un entero unsigned de 32 bits procedente
    de un registro AXI en su equivalente signed
    """

    if value & 0x80000000:
        return value - 0x100000000

    return value


def q16_16(value):
    """
    Convierte un número real al formato fijo Q16.16
    utilizado internamente por el controlador PID
    """

    return int(
        round(
            float(value) * 65536
        )
    )

# CONVERSIÓN ENTRE CUENTAS Y RPM

def sample_time_seconds(sample_time_count):
    """
    Convierte el número de ciclos de reloj configurado
    en SAMPLE_TIME al período de muestreo real en segundos

    Ts = N_ciclos / f_clk
    """

    sample_time_count = int(sample_time_count)

    if sample_time_count <= 0:
        raise ValueError(
            "SAMPLE_TIME debe ser mayor que cero"
        )

    return (
        sample_time_count /
        FPGA_CLOCK_HZ
    )


def counts_to_rpm(
    counts,
    sample_time_count
):
    """
    Convierte las cuentas de encoder acumuladas durante
    un período de muestreo a revoluciones por minuto

        rpm =
            counts * 60
            -----------------------
            CPR * Ts

    donde:

        CPR = cuentas por vuelta del eje de salida
        Ts  = período de muestreo en segundos
    """

    ts = sample_time_seconds(
        sample_time_count
    )

    return (
        float(counts) *
        60.0
        /
        (
            ENCODER_COUNTS_PER_OUTPUT_REV *
            ts
        )
    )


def rpm_to_counts(
    rpm,
    sample_time_count
):
    """
    Convierte una referencia expresada en rpm al número
    de cuentas por período de muestreo que espera la FPGA

        counts =
            rpm * CPR * Ts
            ----------------
                  60
    """

    rpm = float(rpm)

    if not math.isfinite(rpm):
        raise ValueError(
            "La referencia de velocidad no es válida"
        )

    if rpm < 0:
        raise ValueError(
            "La referencia debe ser mayor o igual que cero"
            "El sentido de giro se selecciona por separado"
        )

    ts = sample_time_seconds(
        sample_time_count
    )

    counts = (
        rpm *
        ENCODER_COUNTS_PER_OUTPUT_REV *
        ts
        /
        60.0
    )

    return int(
        round(counts)
    )

# LECTURA DEL ESTADO

def read_status():
    """
    Lee  los registros de monitorización
    del periférico AXI y genera tanto las magnitudes internas
    de la FPGA como las magnitudes físicas en rpm
    """

    with axi_lock:

        speed_counts = signed32(
            motor.read(SPEED)
        )

        error_counts = signed32(
            motor.read(ERROR)
        )

        duty = motor.read(
            DUTY_ACTUAL
        )

        encoder = signed32(
            motor.read(ENCODER_COUNT)
        )

        status = motor.read(
            STATUS
        )

        reference_counts = motor.read(
            SPEED_REF
        )

        pwm_period = motor.read(
            PWM_PERIOD
        )

        sample_count = motor.read(
            SAMPLE_TIME
        )

    # DUTY CYCLE

    duty_percent = 0.0

    if pwm_period > 0:

        duty_percent = (
            100.0 *
            duty /
            pwm_period
        )


    # CONVERSIÓN A RPM

    try:

        speed_rpm_signed = counts_to_rpm(
            speed_counts,
            sample_count
        )

        reference_rpm = counts_to_rpm(
            reference_counts,
            sample_count
        )

        error_rpm = counts_to_rpm(
            error_counts,
            sample_count
        )

        ts_seconds = sample_time_seconds(
            sample_count
        )

    except ValueError:

        speed_rpm_signed = 0.0
        reference_rpm = 0.0
        error_rpm = 0.0
        ts_seconds = 0.0

    speed_rpm = abs(
        speed_rpm_signed
    )


    # RESPUESTA

    return {

        # MAGNITUDES FÍSICAS

        "speed_rpm":
            speed_rpm,

        "speed_rpm_signed":
            speed_rpm_signed,

        "reference_rpm":
            reference_rpm,

        "error_rpm":
            error_rpm,

        # MAGNITUDES INTERNAS DE LA FPGA

        "speed_counts":
            speed_counts,

        "reference_counts":
            reference_counts,

        "error_counts":
            error_counts,

        # PWM

        "duty":
            duty,

        "duty_percent":
            duty_percent,

        "pwm_period":
            pwm_period,

        # ENCODER

        "encoder_count":
            encoder,

        "encoder_counts_per_output_rev":
            ENCODER_COUNTS_PER_OUTPUT_REV,


        # TEMPORIZACIÓN

        "sample_time_count":
            sample_count,

        "sample_time_seconds":
            ts_seconds,


        # ESTADO DEL CONTROL

        "enable":
            bool(
                status & 0x01
            ),

        "direction":
            bool(
                status & 0x02
            ),

        "automatic":
            bool(
                status & 0x04
            ),

        "saturation_high":
            bool(
                status & 0x10
            ),

        "saturation_low":
            bool(
                status & 0x20
            ),

        "status_raw":
            status,

        # Campos expresados en cuentas, mantenidos por compatibilidad

        "speed":
            speed_counts,

        "reference":
            reference_counts,

        "error":
            error_counts
    }


# CORS

@app.after_request
def add_cors_headers(response):

    # Durante el desarrollo React se ejecuta en el PC,
    # mientras Flask se ejecuta en Linux sobre la PYNQ
    # Se permiten peticiones desde otro origen para facilitar
    # la comunicación durante el desarrollo

    response.headers[
        "Access-Control-Allow-Origin"
    ] = "*"

    response.headers[
        "Access-Control-Allow-Headers"
    ] = "Content-Type"

    response.headers[
        "Access-Control-Allow-Methods"
    ] = "GET, POST, OPTIONS"

    return response

# API - ESTADO

@app.route(
    "/api/status",
    methods=["GET"]
)
def api_status():

    return jsonify(
        read_status()
    )

# API - CONFIGURACIÓN

@app.route(
    "/api/config",
    methods=["POST", "OPTIONS"]
)
def api_config():

    if request.method == "OPTIONS":
        return "", 204


    data = request.get_json(
        force=True
    )


    try:

        with axi_lock:

            # REFERENCIA EN RPM
            # Esta será la forma normal de trabajar desde React

            if "reference_rpm" in data:

                sample_count = motor.read(
                    SAMPLE_TIME
                )

                reference_counts = rpm_to_counts(
                    data["reference_rpm"],
                    sample_count
                )

                motor.write(
                    SPEED_REF,
                    reference_counts
                )

            # REFERENCIA EXPLÍCITA EN CUENTAS

            elif "reference_counts" in data:

                reference_counts = int(
                    data["reference_counts"]
                )

                if reference_counts < 0:

                    raise ValueError(
                        "reference_counts no puede ser negativo"
                    )

                motor.write(
                    SPEED_REF,
                    reference_counts
                )


            elif "reference" in data:

                reference_counts = int(
                    data["reference"]
                )

                if reference_counts < 0:

                    raise ValueError(
                        "La referencia no puede ser negativa"
                    )

                motor.write(
                    SPEED_REF,
                    reference_counts
                )

            # PID

            if "kp" in data:

                motor.write(
                    KP,
                    q16_16(
                        data["kp"]
                    )
                )


            if "ki" in data:

                motor.write(
                    KI,
                    q16_16(
                        data["ki"]
                    )
                )


            if "kd" in data:

                motor.write(
                    KD,
                    q16_16(
                        data["kd"]
                    )
                )

            # PERÍODO DE MUESTREO

            if "sample_time_count" in data:

                new_sample_count = int(
                    data[
                        "sample_time_count"
                    ]
                )

                if new_sample_count <= 0:

                    raise ValueError(
                        "sample_time_count debe ser mayor que cero"
                    )

                motor.write(
                    SAMPLE_TIME,
                    new_sample_count
                )

            # PERÍODO PWM

            if "pwm_period" in data:

                new_pwm_period = int(
                    data[
                        "pwm_period"
                    ]
                )

                if new_pwm_period <= 0:

                    raise ValueError(
                        "pwm_period debe ser mayor que cero"
                    )

                motor.write(
                    PWM_PERIOD,
                    new_pwm_period
                )


    except (
        ValueError,
        TypeError
    ) as error:

        return jsonify({

            "ok":
                False,

            "error":
                str(error)

        }), 400


    return jsonify({

        "ok":
            True,

        "status":
            read_status()
    })

# API - ARRANQUE

@app.route(
    "/api/start",
    methods=["POST", "OPTIONS"]
)
def api_start():

    if request.method == "OPTIONS":
        return "", 204


    data = request.get_json(
        silent=True
    ) or {}


    direction = int(
        data.get(
            "direction",
            0
        )
    )


    automatic = bool(
        data.get(
            "automatic",
            True
        )
    )

    control = 0

    # bit 0: enable

    control |= 0x01

    # bit 1: direction

    if direction:

        control |= 0x02

    # bit 2: automatic mode

    if automatic:

        control |= 0x04

    with axi_lock:

        motor.write(
            CONTROL,
            control
        )


    return jsonify({

        "ok":
            True,

        "status":
            read_status()
    })

# API - PARADA

@app.route(
    "/api/stop",
    methods=["POST", "OPTIONS"]
)
def api_stop():

    if request.method == "OPTIONS":
        return "", 204


    with axi_lock:

        motor.write(
            CONTROL,
            0
        )


    return jsonify({

        "ok":
            True,

        "status":
            read_status()
    })

# API - RESET PID

@app.route(
    "/api/reset_pid",
    methods=["POST", "OPTIONS"]
)
def api_reset_pid():

    if request.method == "OPTIONS":
        return "", 204


    with axi_lock:

        # Reset del PID con motor deshabilitado
        # bit 3 = reset PID

        motor.write(
            CONTROL,
            0x08
        )

        motor.write(
            CONTROL,
            0x00
        )


    return jsonify({

        "ok":
            True
    })

# CONFIGURACIÓN INICIAL SEGURA

with axi_lock:

    # MOTOR PARADO AL ARRANCAR FLASK

    motor.write(
        CONTROL,
        0
    )


    # PWM
    # FPGA = 100 MHz
    # 100 000 ciclos:
    # 100 MHz / 100 000 = 1 kHz

    motor.write(
        PWM_PERIOD,
        100_000
    )

    # MUESTREO
    # FPGA = 100 MHz
    # 10 000 000 ciclos:
    # 10 000 000 / 100 000 000 = 0.1 s
    # Ts = 100 ms

    motor.write(
        SAMPLE_TIME,
        10_000_000
    )

    # VALORES CONTROLADOR

    motor.write(
        KP,
        q16_16(350)
    )

    motor.write(
        KI,
        q16_16(40)
    )

    motor.write(
        KD,
        q16_16(0)
    )

    # REFERENCIA INICIAL
    # 100 cuentas por periodo equivalen a 45,45 rpm para Ts = 0,1 s

    motor.write(
        SPEED_REF,
        100
    )

    # DUTY MANUAL INICIALMENTE CERO

    motor.write(
        DUTY_MANUAL,
        0
    )

# INFORMACIÓN DE ARRANQUE

initial_sample_time = 0.1

initial_reference_rpm = counts_to_rpm(
    100,
    10_000_000
)

# SERVIDOR

if __name__ == "__main__":

    print(
        " Motor Control - PYNQ"
    )


    print(
        "API disponible en puerto 5000"
    )

    print()

    print(
        "Calibración encoder:"
    )

    print(
        f"  {ENCODER_COUNTS_PER_OUTPUT_REV:.0f} "
        "cuentas/vuelta"
    )

    print(
        "Período de muestreo:"
    )

    print(
        f"  {initial_sample_time * 1000:.0f} ms"
    )

    print(
        "Referencia inicial:"
    )

    print(
        f"  {initial_reference_rpm:.2f} rpm"
    )

    print()


    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False
    )