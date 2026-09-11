library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity speed_measurement is
    port (
        clk                 : in  std_logic;
        resetn              : in  std_logic;
        enable              : in  std_logic;

        position_count      : in  signed(31 downto 0);
        sample_period_count : in  std_logic_vector(31 downto 0);

        speed_count         : out signed(31 downto 0);
        sample_tick         : out std_logic
    );
end speed_measurement;


architecture Behavioral of speed_measurement is

-- Contador interno para generar el periodo de muestreo
signal sample_counter : unsigned(31 downto 0);

-- Pulso interno de muestreo
signal sample_tick_i : std_logic;

-- Posición almacenada en el muestreo anterior
signal position_previous : signed(31 downto 0);

-- Medida interna de velocidad en cuentas por periodo de muestreo
signal speed_count_i : signed(31 downto 0);

begin

-- Generación del periodo de muestreo
process(clk)
begin
    if rising_edge(clk) then

        if resetn = '0' then
            sample_counter <= (others => '0');
            sample_tick_i  <= '0';
            position_previous <= (others => '0');
            speed_count_i      <= (others => '0');

        elsif enable = '0' then
            sample_counter    <= (others => '0');
            sample_tick_i     <= '0';
            position_previous <= position_count;
            speed_count_i     <= (others => '0');
        elsif unsigned(sample_period_count) <= to_unsigned(1, 32) then
            sample_counter    <= (others => '0');
            sample_tick_i     <= '0';
            position_previous <= position_count;
            speed_count_i     <= (others => '0');
        elsif sample_counter >= unsigned(sample_period_count) - to_unsigned(1, 32) then
        
            -- Reinicio del contador temporal
            sample_counter <= (others => '0');
        
            -- Indicación de nueva medida disponible
            sample_tick_i <= '1';
        
            -- Cálculo de las cuentas producidas durante el intervalo
            speed_count_i <= position_count - position_previous;
        
            -- La posición actual pasa a ser la referencia
            -- para el siguiente periodo de muestreo
            position_previous <= position_count;
        else
            sample_counter <= sample_counter + 1;
            sample_tick_i  <= '0';

        end if;

    end if;
end process;

-- Salidas del bloque
sample_tick <= sample_tick_i;
speed_count <= speed_count_i;

end Behavioral;
