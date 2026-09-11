library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_generator is
    port (
        clk          : in  std_logic;
        resetn       : in  std_logic;
        enable       : in  std_logic;
        period_count : in  std_logic_vector(31 downto 0);
        duty_count   : in  std_logic_vector(31 downto 0);
        pwm_out      : out std_logic
    );
end pwm_generator;

architecture Behavioral of pwm_generator is

-- Contador interno del PWM
signal counter : unsigned(31 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if resetn = '0' then
                counter <= (others => '0');

            elsif enable = '0' then
                counter <= (others => '0');

            elsif unsigned(period_count) <= to_unsigned(1, 32) then
                counter <= (others => '0');

            elsif counter >= unsigned(period_count) - to_unsigned(1, 32) then
                counter <= (others => '0');

            else
                counter <= counter + 1;

            end if;

        end if;
    end process;
    
    -- Generación de la señal PWM
    pwm_out <= '1' when (enable = '1' and
                         resetn = '1' and
                         unsigned(period_count) > to_unsigned(1, 32) and
                         counter < unsigned(duty_count))
               else '0';

end Behavioral;