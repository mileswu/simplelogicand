----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:42:31 07/05/2013 
-- Design Name: 
-- Module Name:    smbus - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library STD;
use STD.textio.all;
use IEEE.STD_LOGIC_TEXTIO.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity smbus is
    Port ( rst : in STD_LOGIC;
			  clk_p : in  STD_LOGIC;
           clk_n : in  STD_LOGIC;
           scl : out  STD_LOGIC;
           sda : inout  STD_LOGIC);
end smbus;

architecture Behavioral of smbus is

signal clk: std_logic;
signal slowclk_enable : std_logic;
signal clk_counter : integer range 0 to 50000;
signal scl_signal : std_logic;

begin

	IBUFDS_inst : IBUFDS
	generic map (
		DIFF_TERM => FALSE,
		IBUF_LOW_PWR => TRUE,
		IOSTANDARD => "DEFAULT")
	port map (
		O => clk,
		I => clk_p,
		IB => clk_n
	);
	
	scl <= scl_signal;
	
	process(rst, clk)
	begin
		if rst = '1' then
			clk_counter <= 0;
			slowclk_enable <= '0';
		elsif rising_edge(clk) then
			if clk_counter = 10 then --00 then --200mhz/100khz is 2000, but we run slowclk at 200khz for mid-cycle change
				slowclk_enable <= '1';
				clk_counter <= 0;
			else
				slowclk_enable <= '0';
				clk_counter <= clk_counter + 1;
			end if;
		end if;
	end process;
	
	process(rst, clk)
	begin
		if rst = '1' then
			sda <= '0';
			scl_signal <= '0';
		elsif rising_edge(clk) then
			if slowclk_enable = '1' then
				scl_signal <= not scl_signal;
			end if;
		end if;
	end process;


end Behavioral;

