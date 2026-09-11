library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity pid_controller_pid_tb is
end pid_controller_pid_tb;


architecture Behavioral of pid_controller_pid_tb is


    --------------------------------------------------------------------
    -- RELOJ
    --------------------------------------------------------------------

    constant CLK_PERIOD : time := 10 ns;


    --------------------------------------------------------------------
    -- ENTRADAS DEL PID
    --------------------------------------------------------------------

    signal clk         : std_logic := '0';
    signal resetn      : std_logic := '0';
    signal enable      : std_logic := '0';
    signal sample_tick : std_logic := '0';
    signal reset_pid   : std_logic := '0';

    signal speed_ref :
        std_logic_vector(31 downto 0) := (others => '0');

    signal speed_measured :
        signed(31 downto 0) := (others => '0');

    signal kp :
        std_logic_vector(31 downto 0) := (others => '0');

    signal ki :
        std_logic_vector(31 downto 0) := (others => '0');

    signal kd :
        std_logic_vector(31 downto 0) := (others => '0');

    signal pwm_period :
        std_logic_vector(31 downto 0) := (others => '0');


    --------------------------------------------------------------------
    -- SALIDAS DEL PID
    --------------------------------------------------------------------

    signal duty_out :
        std_logic_vector(31 downto 0);

    signal error_out :
        signed(31 downto 0);

    signal pid_update :
        std_logic;

    signal saturation_high :
        std_logic;

    signal saturation_low :
        std_logic;


begin


    --------------------------------------------------------------------
    -- GENERACIÓN DEL RELOJ DE 100 MHz
    --------------------------------------------------------------------

    clk <= not clk after CLK_PERIOD/2;



    --------------------------------------------------------------------
    -- INSTANCIA DEL CONTROLADOR PID
    --------------------------------------------------------------------

    uut : entity work.pid_controller

        port map (

            clk             => clk,
            resetn          => resetn,
            enable          => enable,

            sample_tick     => sample_tick,
            reset_pid       => reset_pid,

            speed_ref       => speed_ref,
            speed_measured  => speed_measured,

            kp              => kp,
            ki              => ki,
            kd              => kd,

            pwm_period      => pwm_period,

            duty_out        => duty_out,
            error_out       => error_out,

            pid_update      => pid_update,

            saturation_high => saturation_high,
            saturation_low  => saturation_low
        );



    --------------------------------------------------------------------
    -- PROCESO DE ESTÍMULOS
    --------------------------------------------------------------------

    stimulus : process
    begin


        ---------------------------------------------------------------
        -- ESTADO INICIAL Y RESET
        ---------------------------------------------------------------

        resetn <= '0';
        enable <= '0';

        speed_ref      <= (others => '0');
        speed_measured <= (others => '0');


        ---------------------------------------------------------------
        -- GANANCIAS EN FORMATO Q16.16
        --
        -- Kp = 1.00
        -- Ki = 0.50
        -- Kd = 0.25
        ---------------------------------------------------------------

        kp <= std_logic_vector(
            to_signed(65536, 32)
        );

        ki <= std_logic_vector(
            to_signed(32768, 32)
        );

        kd <= std_logic_vector(
            to_signed(16384, 32)
        );


        ---------------------------------------------------------------
        -- PERIODO PWM
        ---------------------------------------------------------------

        pwm_period <=
            std_logic_vector(
                to_unsigned(100000, 32)
            );


        wait for 100 ns;



        ---------------------------------------------------------------
        -- ACTIVACIÓN DEL CONTROLADOR
        ---------------------------------------------------------------

        resetn <= '1';
        enable <= '1';

        wait for 100 ns;



        ---------------------------------------------------------------
        -- MUESTRA 1
        --
        -- Referencia = 1000
        -- Velocidad  = 800
        --
        -- Error = 200
        --
        -- P = 1.00 * 200        = 200
        -- I = 0 + 0.50 * 200    = 100
        -- D = 0.25 * (200 - 0)  = 50
        --
        -- Duty esperado = 350
        ---------------------------------------------------------------

        speed_ref <=
            std_logic_vector(
                to_unsigned(1000, 32)
            );

        speed_measured <=
            to_signed(800, 32);

        sample_tick <= '1';

        wait for CLK_PERIOD;

        sample_tick <= '0';

        wait for 200 ns;



        ---------------------------------------------------------------
        -- MUESTRA 2
        --
        -- Se mantiene el mismo error.
        --
        -- Error = 200
        --
        -- P = 200
        -- I = 100 + 100 = 200
        -- D = 0.25 * (200 - 200) = 0
        --
        -- Duty esperado = 400
        ---------------------------------------------------------------

        speed_measured <=
            to_signed(800, 32);

        sample_tick <= '1';

        wait for CLK_PERIOD;

        sample_tick <= '0';

        wait for 200 ns;



        ---------------------------------------------------------------
        -- MUESTRA 3
        --
        -- Referencia = 1000
        -- Velocidad  = 900
        --
        -- Error = 100
        --
        -- P = 100
        -- I = 200 + 0.5*100 = 250
        -- D = 0.25*(100 - 200) = -25
        --
        -- Duty esperado = 325
        ---------------------------------------------------------------

        speed_measured <=
            to_signed(900, 32);

        sample_tick <= '1';

        wait for CLK_PERIOD;

        sample_tick <= '0';

        wait for 200 ns;



        ---------------------------------------------------------------
        -- RESET DE LOS ESTADOS INTERNOS DEL PID
        ---------------------------------------------------------------

        reset_pid <= '1';

        wait for 2 * CLK_PERIOD;

        reset_pid <= '0';

        wait for 100 ns;



        ---------------------------------------------------------------
        -- MUESTRA 4 DESPUÉS DEL RESET
        --
        -- Se vuelve a las condiciones de la primera muestra.
        --
        -- Error = 200
        --
        -- P = 200
        -- I = 100
        -- D = 50
        --
        -- Duty esperado = 350
        ---------------------------------------------------------------

        speed_measured <=
            to_signed(800, 32);

        sample_tick <= '1';

        wait for CLK_PERIOD;

        sample_tick <= '0';

        wait for 200 ns;



        ---------------------------------------------------------------
        -- FIN DE LA SIMULACIÓN
        ---------------------------------------------------------------

        wait;

    end process;


end Behavioral;