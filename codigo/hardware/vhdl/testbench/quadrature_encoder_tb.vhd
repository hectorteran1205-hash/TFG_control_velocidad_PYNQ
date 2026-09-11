library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity quadrature_encoder_tb is
end quadrature_encoder_tb;


architecture Behavioral of quadrature_encoder_tb is

    --------------------------------------------------------------------
    -- RELOJ
    --------------------------------------------------------------------

    constant CLK_PERIOD : time := 10 ns;

    --------------------------------------------------------------------
    -- ENTRADAS
    --------------------------------------------------------------------

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';

    signal encoder_a : std_logic := '0';
    signal encoder_b : std_logic := '0';

    --------------------------------------------------------------------
    -- SALIDA
    --------------------------------------------------------------------

    signal position_count :
        signed(31 downto 0);

begin


    --------------------------------------------------------------------
    -- RELOJ DE 100 MHz
    --------------------------------------------------------------------

    clk <= not clk after CLK_PERIOD/2;


    --------------------------------------------------------------------
    -- INSTANCIA DEL DECODIFICADOR
    --------------------------------------------------------------------

    uut : entity work.quadrature_encoder

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
    -- ESTÍMULOS
    --------------------------------------------------------------------

    stimulus : process
    begin


        ---------------------------------------------------------------
        -- RESET
        ---------------------------------------------------------------

        resetn <= '0';

        encoder_a <= '0';
        encoder_b <= '0';

        wait for 100 ns;


        ---------------------------------------------------------------
        -- SALIDA DEL RESET
        ---------------------------------------------------------------

        resetn <= '1';

        -- Tiempo suficiente para que el estado inicial 00
        -- atraviese las dos etapas de sincronización.
        wait for 100 ns;


        ---------------------------------------------------------------
        -- GIRO EN SENTIDO POSITIVO
        --
        -- Secuencia:
        --
        -- 00 → 01 → 11 → 10 → 00
        --
        -- Cada transición válida debe incrementar
        -- position_count en una unidad.
        --
        -- Resultado esperado al finalizar:
        --
        -- position_count = +4
        ---------------------------------------------------------------


        -- 00 -> 01
        encoder_a <= '0';
        encoder_b <= '1';

        wait for 80 ns;


        -- 01 -> 11
        encoder_a <= '1';
        encoder_b <= '1';

        wait for 80 ns;


        -- 11 -> 10
        encoder_a <= '1';
        encoder_b <= '0';

        wait for 80 ns;


        -- 10 -> 00
        encoder_a <= '0';
        encoder_b <= '0';

        wait for 120 ns;



        ---------------------------------------------------------------
        -- GIRO EN SENTIDO NEGATIVO
        --
        -- Secuencia:
        --
        -- 00 → 10 → 11 → 01 → 00
        --
        -- Cada transición válida debe decrementar
        -- position_count en una unidad.
        --
        -- Partimos de +4.
        --
        -- Resultado esperado:
        --
        -- position_count = 0
        ---------------------------------------------------------------


        -- 00 -> 10
        encoder_a <= '1';
        encoder_b <= '0';

        wait for 80 ns;


        -- 10 -> 11
        encoder_a <= '1';
        encoder_b <= '1';

        wait for 80 ns;


        -- 11 -> 01
        encoder_a <= '0';
        encoder_b <= '1';

        wait for 80 ns;


        -- 01 -> 00
        encoder_a <= '0';
        encoder_b <= '0';

        wait for 120 ns;



        ---------------------------------------------------------------
        -- TRANSICIÓN NO VÁLIDA
        --
        -- Se fuerza directamente:
        --
        -- 00 → 11
        --
        -- Ambos canales cambian simultáneamente.
        -- Esta transición no debe incrementar
        -- ni decrementar el contador.
        ---------------------------------------------------------------

        encoder_a <= '1';
        encoder_b <= '1';

        wait for 120 ns;


        ---------------------------------------------------------------
        -- Otra transición no válida para regresar a 00:
        --
        -- 11 → 00
        ---------------------------------------------------------------

        encoder_a <= '0';
        encoder_b <= '0';

        wait for 120 ns;



        ---------------------------------------------------------------
        -- FIN
        ---------------------------------------------------------------

        wait;

    end process;


end Behavioral;