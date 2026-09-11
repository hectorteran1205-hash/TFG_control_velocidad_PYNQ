library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity speed_measurement_tb is
end speed_measurement_tb;


architecture Behavioral of speed_measurement_tb is


    --------------------------------------------------------------------
    -- RELOJ
    --------------------------------------------------------------------

    constant CLK_PERIOD : time := 10 ns;


    --------------------------------------------------------------------
    -- ENTRADAS
    --------------------------------------------------------------------

    signal clk    : std_logic := '0';
    signal resetn : std_logic := '0';
    signal enable : std_logic := '0';

    signal position_count :
        signed(31 downto 0) := (others => '0');

    signal sample_period_count :
        std_logic_vector(31 downto 0) := (others => '0');


    --------------------------------------------------------------------
    -- SALIDAS
    --------------------------------------------------------------------

    signal speed_count :
        signed(31 downto 0);

    signal sample_tick :
        std_logic;


begin


    --------------------------------------------------------------------
    -- RELOJ DE 100 MHz
    --------------------------------------------------------------------

    clk <= not clk after CLK_PERIOD/2;



    --------------------------------------------------------------------
    -- INSTANCIA DEL BLOQUE DE MEDIDA
    --------------------------------------------------------------------

    uut : entity work.speed_measurement

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
    -- PROCESO DE ESTÍMULOS
    --------------------------------------------------------------------

    stimulus : process
    begin


        ---------------------------------------------------------------
        -- CONFIGURACIÓN
        ---------------------------------------------------------------

        -- Periodo de muestreo:
        --
        -- 10 ciclos × 10 ns = 100 ns

        sample_period_count <=
            std_logic_vector(to_unsigned(10, 32));


        ---------------------------------------------------------------
        -- RESET
        ---------------------------------------------------------------

        resetn <= '0';
        enable <= '0';

        position_count <=
            to_signed(0, 32);

        wait for 100 ns;



        ---------------------------------------------------------------
        -- ACTIVACIÓN
        ---------------------------------------------------------------

        resetn <= '1';
        enable <= '1';


        ---------------------------------------------------------------
        -- PRIMER INTERVALO
        --
        -- Posición:
        --
        -- 0 → 5
        --
        -- Resultado esperado:
        --
        -- speed_count = 5
        ---------------------------------------------------------------

        wait for 50 ns;

        position_count <=
            to_signed(5, 32);

        wait for 100 ns;



        ---------------------------------------------------------------
        -- SEGUNDO INTERVALO
        --
        -- Posición:
        --
        -- 5 → 13
        --
        -- Resultado esperado:
        --
        -- speed_count = 8
        ---------------------------------------------------------------

        position_count <=
            to_signed(13, 32);

        wait for 100 ns;



        ---------------------------------------------------------------
        -- TERCER INTERVALO
        --
        -- Posición:
        --
        -- 13 → 9
        --
        -- Resultado esperado:
        --
        -- speed_count = -4
        ---------------------------------------------------------------

        position_count <=
            to_signed(9, 32);

        wait for 100 ns;



        ---------------------------------------------------------------
        -- DESHABILITACIÓN
        ---------------------------------------------------------------

        enable <= '0';

        wait for 50 ns;


        ---------------------------------------------------------------
        -- MOVIMIENTO CON EL CONTROL DESHABILITADO
        --
        -- Posición:
        --
        -- 9 → 100
        --
        -- Este movimiento NO debe aparecer como una
        -- medida de velocidad al volver a habilitar.
        ---------------------------------------------------------------

        position_count <=
            to_signed(100, 32);

        wait for 100 ns;



        ---------------------------------------------------------------
        -- REACTIVACIÓN
        ---------------------------------------------------------------

        enable <= '1';

        wait for 50 ns;


        ---------------------------------------------------------------
        -- NUEVO MOVIMIENTO
        --
        -- Posición:
        --
        -- 100 → 103
        --
        -- Resultado esperado:
        --
        -- speed_count = 3
        ---------------------------------------------------------------

        position_count <=
            to_signed(103, 32);

        wait for 150 ns;



        ---------------------------------------------------------------
        -- FIN
        ---------------------------------------------------------------

        wait;

    end process;


end Behavioral;