library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity control_chain_tb is
end control_chain_tb;


architecture Behavioral of control_chain_tb is


    --------------------------------------------------------------------
    -- RELOJ
    --------------------------------------------------------------------

    constant CLK_PERIOD : time := 10 ns;


    --------------------------------------------------------------------
    -- SEÑALES GENERALES
    --------------------------------------------------------------------

    signal clk     : std_logic := '0';
    signal resetn  : std_logic := '0';
    signal enable  : std_logic := '0';


    --------------------------------------------------------------------
    -- ENCODER
    --------------------------------------------------------------------

    signal encoder_a :
        std_logic := '0';

    signal encoder_b :
        std_logic := '0';

    signal position_count :
        signed(31 downto 0);


    --------------------------------------------------------------------
    -- MEDIDA DE VELOCIDAD
    --------------------------------------------------------------------

    signal sample_period_count :
        std_logic_vector(31 downto 0);

    signal speed_count :
        signed(31 downto 0);

    signal sample_tick :
        std_logic;


    --------------------------------------------------------------------
    -- PID
    --------------------------------------------------------------------

    signal speed_ref :
        std_logic_vector(31 downto 0);

    signal kp :
        std_logic_vector(31 downto 0);

    signal ki :
        std_logic_vector(31 downto 0);

    signal kd :
        std_logic_vector(31 downto 0);

    signal reset_pid :
        std_logic := '0';

    signal pid_duty :
        std_logic_vector(31 downto 0);

    signal pid_error :
        signed(31 downto 0);

    signal pid_update :
        std_logic;

    signal saturation_high :
        std_logic;

    signal saturation_low :
        std_logic;


    --------------------------------------------------------------------
    -- PWM
    --------------------------------------------------------------------

    signal pwm_period :
        std_logic_vector(31 downto 0);

    signal pwm_out :
        std_logic;


begin


    --------------------------------------------------------------------
    -- GENERACIÓN DEL RELOJ DE 100 MHz
    --------------------------------------------------------------------

    clk <= not clk after CLK_PERIOD/2;



    --------------------------------------------------------------------
    -- DECODIFICADOR DEL ENCODER
    --------------------------------------------------------------------

    encoder_inst :
        entity work.quadrature_encoder

        port map (

            clk =>
                clk,

            resetn =>
                resetn,

            encoder_a =>
                encoder_a,

            encoder_b =>
                encoder_b,

            position_count =>
                position_count
        );



    --------------------------------------------------------------------
    -- BLOQUE DE MEDIDA DE VELOCIDAD
    --------------------------------------------------------------------

    speed_inst :
        entity work.speed_measurement

        port map (

            clk =>
                clk,

            resetn =>
                resetn,

            enable =>
                enable,

            position_count =>
                position_count,

            sample_period_count =>
                sample_period_count,

            speed_count =>
                speed_count,

            sample_tick =>
                sample_tick
        );



    --------------------------------------------------------------------
    -- CONTROLADOR PID
    --------------------------------------------------------------------

    pid_inst :
        entity work.pid_controller

        port map (

            clk =>
                clk,

            resetn =>
                resetn,

            enable =>
                enable,

            sample_tick =>
                sample_tick,

            reset_pid =>
                reset_pid,

            speed_ref =>
                speed_ref,

            speed_measured =>
                speed_count,

            kp =>
                kp,

            ki =>
                ki,

            kd =>
                kd,

            pwm_period =>
                pwm_period,

            duty_out =>
                pid_duty,

            error_out =>
                pid_error,

            pid_update =>
                pid_update,

            saturation_high =>
                saturation_high,

            saturation_low =>
                saturation_low
        );



    --------------------------------------------------------------------
    -- GENERADOR PWM
    --------------------------------------------------------------------

    pwm_inst :
        entity work.pwm_generator

        port map (

            clk =>
                clk,

            resetn =>
                resetn,

            enable =>
                enable,

            period_count =>
                pwm_period,

            duty_count =>
                pid_duty,

            pwm_out =>
                pwm_out
        );



    --------------------------------------------------------------------
    -- ESTÍMULOS
    --------------------------------------------------------------------

    stimulus : process


        ----------------------------------------------------------------
        -- PROCEDIMIENTO AUXILIAR
        --
        -- Genera un ciclo completo del encoder en sentido positivo.
        --
        -- Secuencia:
        --
        -- 00 → 01 → 11 → 10 → 00
        --
        -- Un ciclo produce cuatro cuentas.
        ----------------------------------------------------------------

        procedure positive_encoder_cycle is
        begin

            -- 00 -> 01
            encoder_a <= '0';
            encoder_b <= '1';

            wait for 30 ns;


            -- 01 -> 11
            encoder_a <= '1';
            encoder_b <= '1';

            wait for 30 ns;


            -- 11 -> 10
            encoder_a <= '1';
            encoder_b <= '0';

            wait for 30 ns;


            -- 10 -> 00
            encoder_a <= '0';
            encoder_b <= '0';

            wait for 30 ns;

        end procedure;


    begin


        ---------------------------------------------------------------
        -- CONFIGURACIÓN
        ---------------------------------------------------------------

        -- Periodo de medida:
        --
        -- 50 ciclos × 10 ns = 500 ns

        sample_period_count <=
            std_logic_vector(
                to_unsigned(50, 32)
            );


        -- Referencia:
        --
        -- 12 cuentas por periodo de muestreo

        speed_ref <=
            std_logic_vector(
                to_unsigned(12, 32)
            );


        ---------------------------------------------------------------
        -- PID
        --
        -- Kp = 2.0
        -- Ki = 0
        -- Kd = 0
        --
        -- Kp Q16.16:
        --
        -- 2 × 65536 = 131072
        ---------------------------------------------------------------

        kp <=
            std_logic_vector(
                to_signed(131072, 32)
            );

        ki <=
            (others => '0');

        kd <=
            (others => '0');


        ---------------------------------------------------------------
        -- PWM
        --
        -- Periodo = 20 ciclos
        --
        -- 20 × 10 ns = 200 ns
        ---------------------------------------------------------------

        pwm_period <=
            std_logic_vector(
                to_unsigned(20, 32)
            );


        ---------------------------------------------------------------
        -- RESET
        ---------------------------------------------------------------

        resetn <= '0';
        enable <= '0';

        encoder_a <= '0';
        encoder_b <= '0';

        wait for 100 ns;


        ---------------------------------------------------------------
        -- SALIDA DEL RESET
        ---------------------------------------------------------------

        resetn <= '1';

        -- Se deja tiempo para que el estado inicial del encoder
        -- atraviese los sincronizadores.
        wait for 100 ns;


        ---------------------------------------------------------------
        -- ACTIVACIÓN DEL SISTEMA
        ---------------------------------------------------------------

        enable <= '1';



        ---------------------------------------------------------------
        -- PRIMER PERIODO DE MEDIDA
        --
        -- Se generan 4 cuentas.
        --
        -- Velocidad esperada = 4
        --
        -- Error = 12 - 4 = 8
        --
        -- Duty PID:
        --
        -- 2 × 8 = 16
        --
        -- Duty PWM:
        --
        -- 16 / 20 = 80 %
        ---------------------------------------------------------------

        wait for 50 ns;

        positive_encoder_cycle;



        ---------------------------------------------------------------
        -- ESPERA HASTA EL SEGUNDO INTERVALO
        ---------------------------------------------------------------

        wait for 380 ns;



        ---------------------------------------------------------------
        -- SEGUNDO PERIODO
        --
        -- Dos ciclos completos de cuadratura:
        --
        -- 2 × 4 = 8 cuentas
        --
        -- Velocidad esperada = 8
        --
        -- Error = 12 - 8 = 4
        --
        -- Duty:
        --
        -- 2 × 4 = 8
        --
        -- PWM = 40 %
        ---------------------------------------------------------------

        positive_encoder_cycle;
        positive_encoder_cycle;



        ---------------------------------------------------------------
        -- ESPERA HASTA EL TERCER INTERVALO
        ---------------------------------------------------------------

        wait for 260 ns;



        ---------------------------------------------------------------
        -- TERCER PERIODO
        --
        -- Tres ciclos completos:
        --
        -- 3 × 4 = 12 cuentas
        --
        -- Velocidad esperada = 12
        --
        -- Error = 0
        --
        -- Duty = 0
        ---------------------------------------------------------------

        positive_encoder_cycle;
        positive_encoder_cycle;
        positive_encoder_cycle;



        ---------------------------------------------------------------
        -- CUARTO PERIODO
        --
        -- No se generan nuevas cuentas.
        --
        -- Velocidad = 0
        --
        -- Error = 12
        --
        -- PID solicita:
        --
        -- 2 × 12 = 24
        --
        -- Pero el PWM solo admite 20.
        --
        -- Resultado esperado:
        --
        -- duty = 20
        -- saturation_high = 1
        ---------------------------------------------------------------

        wait for 800 ns;



        ---------------------------------------------------------------
        -- DESHABILITACIÓN
        ---------------------------------------------------------------

        enable <= '0';

        wait for 100 ns;



        ---------------------------------------------------------------
        -- FIN
        ---------------------------------------------------------------

        wait;

    end process;


end Behavioral;