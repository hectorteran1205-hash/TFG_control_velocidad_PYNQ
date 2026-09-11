library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity pid_controller is
    port (
        clk             : in  std_logic;
        resetn          : in  std_logic;
        enable          : in  std_logic;

        -- Pulso que indica que existe una nueva medida de velocidad
        sample_tick     : in  std_logic;

        -- Reinicio de los estados internos del PID
        reset_pid       : in  std_logic;

        -- Referencia de velocidad en cuentas por periodo de muestreo
        speed_ref       : in  std_logic_vector(31 downto 0);

        -- Velocidad medida
        speed_measured  : in  signed(31 downto 0);

        -- Ganancias en formato Q16.16
        kp              : in  std_logic_vector(31 downto 0);
        ki              : in  std_logic_vector(31 downto 0);
        kd              : in  std_logic_vector(31 downto 0);

        -- Periodo PWM = duty máximo permitido
        pwm_period      : in  std_logic_vector(31 downto 0);

        -- Salida del controlador
        duty_out        : out std_logic_vector(31 downto 0);

        -- Error utilizado por el controlador
        error_out       : out signed(31 downto 0);

        -- Pulso de un ciclo al finalizar cada cálculo
        pid_update      : out std_logic;

        -- Indicadores de saturación
        saturation_high : out std_logic;
        saturation_low  : out std_logic
    );
end pid_controller;


architecture Behavioral of pid_controller is


    --------------------------------------------------------------------
    -- MÁQUINA DE ESTADOS
    --------------------------------------------------------------------

    type state_type is (
        WAIT_SAMPLE,

        CALC_ERROR,

        MULT_P,
        SCALE_P,

        MULT_I,
        SCALE_I,
        ADD_I,
        LIMIT_I,

        CALC_D_DIFF,
        MULT_D,
        SCALE_D,

        ADD_PI,
        ADD_D,

        SATURATE_OUTPUT,

        DONE
    );

    signal state : state_type;


    --------------------------------------------------------------------
    -- REGISTROS LOCALES DE ENTRADA
    --
    -- Se capturan simultáneamente al recibir sample_tick.
    --
    -- De este modo:
    --
    -- 1. La FSM utiliza parámetros constantes durante todo el cálculo.
    --
    -- 2. Los multiplicadores dejan de depender directamente
    --    de los registros situados dentro del banco AXI.
    --
    -- 3. Vivado puede colocar estos registros cerca de la
    --    lógica aritmética del PID.
    --------------------------------------------------------------------

    signal kp_latched_i :
        signed(31 downto 0);

    signal ki_latched_i :
        signed(31 downto 0);

    signal kd_latched_i :
        signed(31 downto 0);

    signal speed_ref_latched_i :
        unsigned(31 downto 0);

    signal speed_measured_latched_i :
        signed(31 downto 0);

    signal pwm_period_latched_i :
        unsigned(31 downto 0);


    --------------------------------------------------------------------
    -- ERROR
    --------------------------------------------------------------------

    signal error_i :
        signed(31 downto 0);

    signal error_prev_i :
        signed(31 downto 0);

    signal error_diff_i :
        signed(31 downto 0);


    --------------------------------------------------------------------
    -- TÉRMINO PROPORCIONAL
    --------------------------------------------------------------------

    -- 32 bits x 32 bits = 64 bits
    signal p_product_i :
        signed(63 downto 0);

    signal p_term_i :
        signed(63 downto 0);


    --------------------------------------------------------------------
    -- TÉRMINO INTEGRAL
    --------------------------------------------------------------------

    signal i_product_i :
        signed(63 downto 0);

    signal i_increment_i :
        signed(63 downto 0);

    signal i_candidate_i :
        signed(63 downto 0);

    signal i_term_i :
        signed(63 downto 0);


    --------------------------------------------------------------------
    -- TÉRMINO DERIVATIVO
    --------------------------------------------------------------------

    signal d_product_i :
        signed(63 downto 0);

    signal d_term_i :
        signed(63 downto 0);


    --------------------------------------------------------------------
    -- SUMA DEL PID
    --------------------------------------------------------------------

    -- P + I
    signal sum_pi_i :
        signed(63 downto 0);

    -- P + I + D
    signal pid_sum_i :
        signed(63 downto 0);


    --------------------------------------------------------------------
    -- PERIODO PWM AMPLIADO A 64 BITS
    --------------------------------------------------------------------

    signal pwm_period_s :
        signed(63 downto 0);


    --------------------------------------------------------------------
    -- SALIDAS INTERNAS
    --------------------------------------------------------------------

    signal duty_i :
        unsigned(31 downto 0);

    signal error_out_i :
        signed(31 downto 0);

    signal pid_update_i :
        std_logic;

    signal saturation_high_i :
        std_logic;

    signal saturation_low_i :
        std_logic;


begin


    --------------------------------------------------------------------
    -- AMPLIACIÓN DEL PERIODO PWM CAPTURADO
    --------------------------------------------------------------------

    pwm_period_s <=
        signed(
            resize(
                pwm_period_latched_i,
                64
            )
        );


    --------------------------------------------------------------------
    -- MÁQUINA DE ESTADOS + CAMINO DE DATOS
    --------------------------------------------------------------------

    process(clk)

        ----------------------------------------------------------------
        -- Variables temporales empleadas únicamente para calcular
        -- el error.
        ----------------------------------------------------------------

        variable speed_ref_v :
            signed(63 downto 0);

        variable speed_measured_v :
            signed(63 downto 0);

        variable error_v :
            signed(63 downto 0);

    begin

        if rising_edge(clk) then


            ------------------------------------------------------------
            -- RESET GENERAL
            ------------------------------------------------------------

            if resetn = '0' then

                state <= WAIT_SAMPLE;


                --------------------------------------------------------
                -- Registros locales de entrada
                --------------------------------------------------------

                kp_latched_i <=
                    (others => '0');

                ki_latched_i <=
                    (others => '0');

                kd_latched_i <=
                    (others => '0');

                speed_ref_latched_i <=
                    (others => '0');

                speed_measured_latched_i <=
                    (others => '0');

                pwm_period_latched_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Error
                --------------------------------------------------------

                error_i <=
                    (others => '0');

                error_prev_i <=
                    (others => '0');

                error_diff_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Proporcional
                --------------------------------------------------------

                p_product_i <=
                    (others => '0');

                p_term_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Integral
                --------------------------------------------------------

                i_product_i <=
                    (others => '0');

                i_increment_i <=
                    (others => '0');

                i_candidate_i <=
                    (others => '0');

                i_term_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Derivativo
                --------------------------------------------------------

                d_product_i <=
                    (others => '0');

                d_term_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Suma
                --------------------------------------------------------

                sum_pi_i <=
                    (others => '0');

                pid_sum_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Salidas
                --------------------------------------------------------

                duty_i <=
                    (others => '0');

                error_out_i <=
                    (others => '0');

                pid_update_i <=
                    '0';

                saturation_high_i <=
                    '0';

                saturation_low_i <=
                    '0';


            ------------------------------------------------------------
            -- PID DESHABILITADO O RESET INTERNO
            ------------------------------------------------------------

            elsif enable = '0' or reset_pid = '1' then

                state <= WAIT_SAMPLE;


                --------------------------------------------------------
                -- Se borran también las entradas capturadas
                --------------------------------------------------------

                kp_latched_i <=
                    (others => '0');

                ki_latched_i <=
                    (others => '0');

                kd_latched_i <=
                    (others => '0');

                speed_ref_latched_i <=
                    (others => '0');

                speed_measured_latched_i <=
                    (others => '0');

                pwm_period_latched_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Estados internos
                --------------------------------------------------------

                error_i <=
                    (others => '0');

                error_prev_i <=
                    (others => '0');

                error_diff_i <=
                    (others => '0');

                p_product_i <=
                    (others => '0');

                p_term_i <=
                    (others => '0');

                i_product_i <=
                    (others => '0');

                i_increment_i <=
                    (others => '0');

                i_candidate_i <=
                    (others => '0');

                i_term_i <=
                    (others => '0');

                d_product_i <=
                    (others => '0');

                d_term_i <=
                    (others => '0');

                sum_pi_i <=
                    (others => '0');

                pid_sum_i <=
                    (others => '0');


                --------------------------------------------------------
                -- Salidas
                --------------------------------------------------------

                duty_i <=
                    (others => '0');

                error_out_i <=
                    (others => '0');

                pid_update_i <=
                    '0';

                saturation_high_i <=
                    '0';

                saturation_low_i <=
                    '0';


            else


                --------------------------------------------------------
                -- Por defecto pid_update permanece desactivado.
                --
                -- Solo se activa durante el estado DONE.
                --------------------------------------------------------

                pid_update_i <= '0';


                case state is


                    ----------------------------------------------------
                    -- ESPERA DE UNA NUEVA MUESTRA
                    ----------------------------------------------------

                    when WAIT_SAMPLE =>


                        ------------------------------------------------
                        -- Referencia cero
                        --
                        -- Se fuerza la parada y se elimina toda
                        -- memoria acumulada del controlador.
                        ------------------------------------------------

                        if unsigned(speed_ref) = to_unsigned(0, 32) then

                            duty_i <=
                                (others => '0');

                            error_i <=
                                (others => '0');

                            error_prev_i <=
                                (others => '0');

                            error_diff_i <=
                                (others => '0');

                            p_product_i <=
                                (others => '0');

                            p_term_i <=
                                (others => '0');

                            i_product_i <=
                                (others => '0');

                            i_increment_i <=
                                (others => '0');

                            i_candidate_i <=
                                (others => '0');

                            i_term_i <=
                                (others => '0');

                            d_product_i <=
                                (others => '0');

                            d_term_i <=
                                (others => '0');

                            sum_pi_i <=
                                (others => '0');

                            pid_sum_i <=
                                (others => '0');

                            error_out_i <=
                                (others => '0');

                            saturation_high_i <=
                                '0';

                            saturation_low_i <=
                                '0';

                            state <=
                                WAIT_SAMPLE;


                        ------------------------------------------------
                        -- NUEVA MUESTRA
                        ------------------------------------------------

                        elsif sample_tick = '1' then


                            --------------------------------------------
                            -- CAPTURA COHERENTE DE TODAS LAS ENTRADAS
                            --------------------------------------------

                            kp_latched_i <=
                                signed(kp);

                            ki_latched_i <=
                                signed(ki);

                            kd_latched_i <=
                                signed(kd);

                            speed_ref_latched_i <=
                                unsigned(speed_ref);

                            speed_measured_latched_i <=
                                speed_measured;

                            pwm_period_latched_i <=
                                unsigned(pwm_period);


                            --------------------------------------------
                            -- Una vez almacenados los parámetros,
                            -- comienza el cálculo.
                            --------------------------------------------

                            state <=
                                CALC_ERROR;


                        else

                            state <=
                                WAIT_SAMPLE;

                        end if;



                    ----------------------------------------------------
                    -- CÁLCULO DEL ERROR
                    ----------------------------------------------------

                    when CALC_ERROR =>


                        ------------------------------------------------
                        -- Referencia capturada
                        ------------------------------------------------

                        speed_ref_v :=
                            signed(
                                resize(
                                    speed_ref_latched_i,
                                    64
                                )
                            );


                        ------------------------------------------------
                        -- Módulo de la velocidad capturada
                        ------------------------------------------------

                        if speed_measured_latched_i(31) = '1' then

                            speed_measured_v :=
                                -resize(
                                    speed_measured_latched_i,
                                    64
                                );

                        else

                            speed_measured_v :=
                                resize(
                                    speed_measured_latched_i,
                                    64
                                );

                        end if;


                        ------------------------------------------------
                        -- ERROR
                        --
                        -- e(k) = referencia - velocidad
                        ------------------------------------------------

                        error_v :=
                            speed_ref_v -
                            speed_measured_v;


                        error_i <=
                            resize(
                                error_v,
                                32
                            );


                        state <=
                            MULT_P;



                    ----------------------------------------------------
                    -- MULTIPLICACIÓN PROPORCIONAL
                    ----------------------------------------------------

                    when MULT_P =>


                        ------------------------------------------------
                        -- P = Kp * error
                        --
                        -- Producto:
                        --
                        -- 32 bits × 32 bits = 64 bits
                        ------------------------------------------------

                        p_product_i <=
                            error_i *
                            kp_latched_i;


                        state <=
                            SCALE_P;



                    ----------------------------------------------------
                    -- ESCALADO PROPORCIONAL
                    ----------------------------------------------------

                    when SCALE_P =>


                        ------------------------------------------------
                        -- Eliminación del escalado Q16.16:
                        --
                        -- división por 2^16
                        ------------------------------------------------

                        p_term_i <=
                            shift_right(
                                p_product_i,
                                16
                            );


                        state <=
                            MULT_I;



                    ----------------------------------------------------
                    -- MULTIPLICACIÓN INTEGRAL
                    ----------------------------------------------------

                    when MULT_I =>


                        i_product_i <=
                            error_i *
                            ki_latched_i;


                        state <=
                            SCALE_I;



                    ----------------------------------------------------
                    -- ESCALADO INTEGRAL
                    ----------------------------------------------------

                    when SCALE_I =>


                        i_increment_i <=
                            shift_right(
                                i_product_i,
                                16
                            );


                        state <=
                            ADD_I;



                    ----------------------------------------------------
                    -- ACUMULACIÓN DE LA INTEGRAL
                    ----------------------------------------------------

                    when ADD_I =>


                        ------------------------------------------------
                        -- I(k) =
                        -- I(k-1) + Ki*e(k)
                        ------------------------------------------------

                        i_candidate_i <=
                            i_term_i +
                            i_increment_i;


                        state <=
                            LIMIT_I;



                    ----------------------------------------------------
                    -- ANTI-WINDUP
                    ----------------------------------------------------

                    when LIMIT_I =>


                        ------------------------------------------------
                        -- Se limita la integral al rango aproximado
                        -- permitido por el actuador.
                        ------------------------------------------------

                        if i_candidate_i > pwm_period_s then

                            i_term_i <=
                                pwm_period_s;


                        elsif i_candidate_i < -pwm_period_s then

                            i_term_i <=
                                -pwm_period_s;


                        else

                            i_term_i <=
                                i_candidate_i;

                        end if;


                        state <=
                            CALC_D_DIFF;



                    ----------------------------------------------------
                    -- DIFERENCIA DEL ERROR
                    ----------------------------------------------------

                    when CALC_D_DIFF =>


                        ------------------------------------------------
                        -- e(k) - e(k-1)
                        ------------------------------------------------

                        error_diff_i <=
                            error_i -
                            error_prev_i;


                        state <=
                            MULT_D;



                    ----------------------------------------------------
                    -- MULTIPLICACIÓN DERIVATIVA
                    ----------------------------------------------------

                    when MULT_D =>


                        d_product_i <=
                            error_diff_i *
                            kd_latched_i;


                        state <=
                            SCALE_D;



                    ----------------------------------------------------
                    -- ESCALADO DERIVATIVO
                    ----------------------------------------------------

                    when SCALE_D =>


                        d_term_i <=
                            shift_right(
                                d_product_i,
                                16
                            );


                        state <=
                            ADD_PI;



                    ----------------------------------------------------
                    -- SUMA P + I
                    ----------------------------------------------------

                    when ADD_PI =>


                        sum_pi_i <=
                            p_term_i +
                            i_term_i;


                        state <=
                            ADD_D;



                    ----------------------------------------------------
                    -- SUMA P + I + D
                    ----------------------------------------------------

                    when ADD_D =>


                        pid_sum_i <=
                            sum_pi_i +
                            d_term_i;


                        state <=
                            SATURATE_OUTPUT;



                    ----------------------------------------------------
                    -- SATURACIÓN DE LA SALIDA
                    ----------------------------------------------------

                    when SATURATE_OUTPUT =>


                        ------------------------------------------------
                        -- SALIDA NEGATIVA
                        ------------------------------------------------

                        if pid_sum_i < to_signed(0, 64) then

                            duty_i <=
                                (others => '0');

                            saturation_low_i <=
                                '1';

                            saturation_high_i <=
                                '0';


                        ------------------------------------------------
                        -- SATURACIÓN SUPERIOR
                        ------------------------------------------------

                        elsif pid_sum_i >= pwm_period_s then

                            duty_i <=
                                pwm_period_latched_i;

                            saturation_low_i <=
                                '0';

                            saturation_high_i <=
                                '1';


                        ------------------------------------------------
                        -- SALIDA DENTRO DEL RANGO
                        ------------------------------------------------

                        else

                            duty_i <=
                                resize(
                                    unsigned(pid_sum_i),
                                    32
                                );

                            saturation_low_i <=
                                '0';

                            saturation_high_i <=
                                '0';

                        end if;


                        ------------------------------------------------
                        -- MEMORIA DEL ERROR
                        ------------------------------------------------

                        error_out_i <=
                            error_i;

                        error_prev_i <=
                            error_i;


                        state <=
                            DONE;



                    ----------------------------------------------------
                    -- FIN DEL CÁLCULO
                    ----------------------------------------------------

                    when DONE =>


                        pid_update_i <=
                            '1';


                        state <=
                            WAIT_SAMPLE;



                    ----------------------------------------------------
                    -- ESTADO DE SEGURIDAD
                    ----------------------------------------------------

                    when others =>


                        state <=
                            WAIT_SAMPLE;


                end case;

            end if;

        end if;

    end process;



    --------------------------------------------------------------------
    -- ASIGNACIÓN DE SALIDAS
    --------------------------------------------------------------------

    duty_out <=
        std_logic_vector(
            duty_i
        );

    error_out <=
        error_out_i;

    pid_update <=
        pid_update_i;

    saturation_high <=
        saturation_high_i;

    saturation_low <=
        saturation_low_i;


end Behavioral;