library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity quadrature_encoder is
    port (
        clk            : in  std_logic;
        resetn         : in  std_logic;
        encoder_a      : in  std_logic;
        encoder_b      : in  std_logic;
        position_count : out signed(31 downto 0)
    );
end quadrature_encoder;


architecture Behavioral of quadrature_encoder is

    --------------------------------------------------------------------
    -- Sincronización de las señales externas del encoder
    --------------------------------------------------------------------

    -- Primera y segunda etapa de sincronización del canal A
    signal encoder_a_meta : std_logic;
    signal encoder_a_sync : std_logic;

    -- Primera y segunda etapa de sincronización del canal B
    signal encoder_b_meta : std_logic;
    signal encoder_b_sync : std_logic;


    --------------------------------------------------------------------
    -- Señales utilizadas para la decodificación en cuadratura
    --------------------------------------------------------------------

    -- Estado anterior de los canales A y B
    signal encoder_a_prev : std_logic;
    signal encoder_b_prev : std_logic;

    -- Contador interno de posición
    signal position_count_i : signed(31 downto 0);

    -- Estado anterior + estado actual:
    -- A_prev B_prev A_sync B_sync
    signal transition : std_logic_vector(3 downto 0);

    -- Indica que ya se ha capturado un estado inicial válido
    signal decoder_initialized : std_logic;


begin


    --------------------------------------------------------------------
    -- SINCRONIZACIÓN DE LAS ENTRADAS DEL ENCODER
    --------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then

            if resetn = '0' then

                encoder_a_meta <= '0';
                encoder_a_sync <= '0';

                encoder_b_meta <= '0';
                encoder_b_sync <= '0';

            else

                -- Primera etapa
                encoder_a_meta <= encoder_a;
                encoder_b_meta <= encoder_b;

                -- Segunda etapa
                encoder_a_sync <= encoder_a_meta;
                encoder_b_sync <= encoder_b_meta;

            end if;

        end if;
    end process;



    --------------------------------------------------------------------
    -- FORMACIÓN DE LA PALABRA DE TRANSICIÓN
    --------------------------------------------------------------------

    -- bits 3..2 = estado anterior AB
    -- bits 1..0 = estado actual AB

    transition <= encoder_a_prev &
                  encoder_b_prev &
                  encoder_a_sync &
                  encoder_b_sync;



    --------------------------------------------------------------------
    -- DECODIFICACIÓN DEL ENCODER EN CUADRATURA x4
    --------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then

            if resetn = '0' then

                encoder_a_prev    <= '0';
                encoder_b_prev    <= '0';

                position_count_i  <= (others => '0');

                decoder_initialized <= '0';


            else

                --------------------------------------------------------
                -- Inicialización
                --------------------------------------------------------

                if decoder_initialized = '0' then

                    -- Se toma el estado actual como estado inicial.
                    -- De esta forma no se cuenta una transición falsa
                    -- inmediatamente después del reset.

                    encoder_a_prev <= encoder_a_sync;
                    encoder_b_prev <= encoder_b_sync;

                    decoder_initialized <= '1';


                else

                    ----------------------------------------------------
                    -- Decodificación de las transiciones
                    ----------------------------------------------------

                    case transition is

                        ------------------------------------------------
                        -- Sentido positivo
                        ------------------------------------------------

                        when "0001" |
                             "0111" |
                             "1110" |
                             "1000" =>

                            position_count_i <=
                                position_count_i + to_signed(1, 32);


                        ------------------------------------------------
                        -- Sentido negativo
                        ------------------------------------------------

                        when "0010" |
                             "1011" |
                             "1101" |
                             "0100" =>

                            position_count_i <=
                                position_count_i - to_signed(1, 32);


                        ------------------------------------------------
                        -- Sin movimiento o transición no válida
                        ------------------------------------------------

                        when others =>

                            position_count_i <= position_count_i;

                    end case;


                    ----------------------------------------------------
                    -- Actualización del estado anterior
                    ----------------------------------------------------

                    encoder_a_prev <= encoder_a_sync;
                    encoder_b_prev <= encoder_b_sync;

                end if;

            end if;

        end if;
    end process;



    --------------------------------------------------------------------
    -- SALIDA DEL CONTADOR
    --------------------------------------------------------------------

    position_count <= position_count_i;


end Behavioral;