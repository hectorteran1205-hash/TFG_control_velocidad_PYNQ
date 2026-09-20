library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity pwm_generator_tb is
end pwm_generator_tb;


architecture Behavioral of pwm_generator_tb is

    -- RELOJ

    constant CLK_PERIOD : time := 10 ns;


    -- ENTRADAS

    signal clk :
        std_logic := '0';

    signal resetn :
        std_logic := '0';

    signal enable :
        std_logic := '0';

    signal period_count :
        std_logic_vector(31 downto 0) := (others => '0');

    signal duty_count :
        std_logic_vector(31 downto 0) := (others => '0');

    -- SALIDA

    signal pwm_out :
        std_logic;


begin


    -- RELOJ DE 100 MHz

    clk <= not clk after CLK_PERIOD/2;


    -- INSTANCIA DEL GENERADOR PWM

    uut : entity work.pwm_generator

        port map (

            clk =>
                clk,

            resetn =>
                resetn,

            enable =>
                enable,

            period_count =>
                period_count,

            duty_count =>
                duty_count,

            pwm_out =>
                pwm_out
        );


    -- ESTÍMULOS

    stimulus : process
    begin

        -- CONFIGURACIÓN DEL PERIODO

        period_count <=
            std_logic_vector(
                to_unsigned(10, 32)
            );

        -- RESET

        resetn <= '0';
        enable <= '0';

        duty_count <=
            (others => '0');

        wait for 100 ns;


        -- ACTIVACIÓN

        resetn <= '1';
        enable <= '1';


        -- PRUEBA 1

        duty_count <=
            std_logic_vector(
                to_unsigned(4, 32)
            );

        wait for 300 ns;


        -- PRUEBA 2

        duty_count <=
            std_logic_vector(
                to_unsigned(7, 32)
            );

        wait for 300 ns;


        -- PRUEBA 3

        duty_count <=
            std_logic_vector(
                to_unsigned(0, 32)
            );

        wait for 200 ns;


        -- PRUEBA 4

        duty_count <=
            std_logic_vector(
                to_unsigned(10, 32)
            );

        wait for 200 ns;

        -- PRUEBA 5

        enable <= '0';

        wait for 200 ns;


        wait;

    end process;


end Behavioral;
