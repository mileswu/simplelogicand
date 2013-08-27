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
           sda : inout  STD_LOGIC;
			  led0 : out STD_LOGIC;
			  led1 : out STD_LOGIC;
			  led2 : out STD_LOGIC;
			  led3 : out STD_LOGIC;
			  led4 : out STD_LOGIC;
			  led5 : out STD_LOGIC;
			  led6 : out STD_LOGIC;
			  led7 : out STD_LOGIC;
			  resetL : out STD_LOGIC;
			  laserEn : out STD_LOGIC;
			  pgood25 : in STD_LOGIC
			  );
end smbus;

architecture Behavioral of smbus is

signal clk: std_logic;
signal clk_scl_enable : std_logic;
signal clk_sda_enable : std_logic;
signal clk_logic_enable : std_logic;
signal clk_counter : integer range 0 to 50000 := 0;

signal scl_counter : integer range 0 to 50000 := 0;
constant CLKSLOWCLK_RATIO : integer := 500;
--constant CLKSLOWCLK_RATIO : integer := 2000;
--if we want slowclk at 400khz (allow us to do things 4x in cycle), ratio should be 500

type i2c_state_type is (i2c_state_idle, i2c_state_start, i2c_state_stop, i2c_state_send_slave_address,
   i2c_state_send_rw_read, i2c_state_send_rw_write, i2c_state_receive_ack, i2c_state_recieve_byte, i2c_state_send_byte, i2c_state_send_nack);
signal i2c_state_current : i2c_state_type;
signal i2c_state_next : i2c_state_type;

signal i2c_idle_counter : integer range 0 to 50000;

signal i2c_slaveaddress_counter : integer range 0 to 10;
signal i2c_slaveaddress_bits : std_logic_vector(6 downto 0);

signal i2c_receive_ack_counter : integer range 0 to 10;

signal i2c_write_bits : std_logic_vector(7 downto 0);
signal i2c_write_counter : integer range 0 to 10;
signal i2c_write_finished : std_logic;

signal i2c_read_bits : std_logic_vector(7 downto 0);
signal i2c_read_counter : integer range 0 to 10;
signal i2c_read_finished : std_logic;

signal i2c_stop_counter : integer range 0 to 10;

signal readout_finished : std_logic;
signal readout_led_counter : integer range 0 to 1000000 := 0;
signal readout_led_counter_blink : std_logic;
signal readout_led_counter_pos : integer range 0 to 10;

type logic_state_type is (logic_state_2,
logic_state_3a, logic_state_3b, logic_state_3c
);
signal logic_state_current : logic_state_type;

constant LOGIC_WAIT_1MS : integer := 400;
signal logic_wait_counter : integer range 0 to 1000000 := 0;

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
					
	slowclk_generation: process(rst, clk)
	begin
		if rst = '1' then
			clk_counter <= 0;
			clk_scl_enable <= '0';
			clk_sda_enable <= '0';
			clk_logic_enable <= '0';
		elsif rising_edge(clk) then
			if clk_counter = CLKSLOWCLK_RATIO-1-50 then
				clk_scl_enable <= '1';
			else
				clk_scl_enable <= '0';
			end if;
			
			if clk_counter = CLKSLOWCLK_RATIO-1-25 then
				clk_logic_enable <= '1';
			else
				clk_logic_enable <= '0';
			end if;
			
			if clk_counter >= (CLKSLOWCLK_RATIO-1) then
				clk_sda_enable <= '1';
				clk_counter <= 0;
			else
				clk_sda_enable <= '0';
				clk_counter <= clk_counter + 1;
			end if;
		end if;
	end process;
	
	scl_generation: process(rst, clk)
	begin
		if rst = '1' then
			scl <= '0';
			scl_counter <= 0;
		elsif falling_edge(clk) then
			if clk_scl_enable = '1' then
				if scl_counter = 3 then
					scl <= '1';
				elsif scl_counter = 1 then
					scl <= '0';
				end if;
					
				if scl_counter < 3 then
					scl_counter <= scl_counter+ 1;
				elsif scl_counter >= 3 then
					scl_counter <= 0;
				end if;
			end if;
		end if;
	end process;
	
	sda_generation: process(rst, clk)
	begin
		if rst = '1' then
			i2c_state_current <= i2c_state_idle;
			--i2c_state_next <= i2c_state_start;
			i2c_state_next <= i2c_state_idle;
			i2c_idle_counter <= 0;
			sda <= '1';
			led0 <= '0';
			led1 <= '0';
			led2 <= '0';
			led3 <= '0';
			led4 <= '0';
			i2c_slaveaddress_bits <= "1110100";
			i2c_read_finished <= '0';
			i2c_write_bits <= "10010101";
			i2c_write_finished <= '0';
			i2c_receive_ack_counter <= 0;
			i2c_stop_counter <= 0;
		elsif falling_edge(clk) then
			if clk_sda_enable = '1' then
			
				if i2c_state_current = i2c_state_idle then
					if scl_counter = 3 then -- middle of low scl
						sda <= '1';
						if i2c_idle_counter >= 100 then
							i2c_idle_counter <= 0;
							led4 <= '1';
							i2c_state_current <= i2c_state_next;
						else
							i2c_idle_counter <= i2c_idle_counter + 1;
						end if;
					end if;
					
				elsif i2c_state_current = i2c_state_start then
					if	scl_counter = 1 then -- middle of high scl
						sda <= '0';
						i2c_state_current <= i2c_state_send_slave_address;
						i2c_slaveaddress_counter <= 6; -- start at msb
					end if;
					
				elsif i2c_state_current = i2c_state_stop then
					if	scl_counter = 3 then
						i2c_stop_counter <= 1;
						sda <= '0';
					elsif scl_counter = 1 and i2c_stop_counter = 1 then
						sda <= '1';
						i2c_state_current <= i2c_state_idle;
						i2c_stop_counter <= 0;
						if i2c_read_finished = '0' then
							i2c_state_next <= i2c_state_start;
						else
							i2c_state_next <= i2c_state_idle;
						end if;
					end if;
					
				elsif i2c_state_current = i2c_state_send_slave_address then
					if scl_counter = 3 then -- middle of low scl
						sda <= i2c_slaveaddress_bits(i2c_slaveaddress_counter);
						if i2c_slaveaddress_counter = 0 then
							if i2c_write_finished = '0' then
								i2c_state_current <= i2c_state_send_rw_write;
							else
								i2c_state_current <= i2c_state_send_rw_read;
							end if;
						else 
							i2c_slaveaddress_counter <= i2c_slaveaddress_counter - 1;
						end if;
					end if;
					
				elsif i2c_state_current = i2c_state_send_rw_read then
					if scl_counter = 3 then
						sda <= '1';
						i2c_state_current <= i2c_state_receive_ack;
						i2c_state_next <= i2c_state_recieve_byte;
					end if;
					
				elsif i2c_state_current = i2c_state_send_rw_write then
					if scl_counter = 3 then
						sda <= '0';
						i2c_state_current <= i2c_state_receive_ack;
						i2c_state_next <= i2c_state_send_byte;
					end if;
					
				elsif i2c_state_current = i2c_state_receive_ack then
				   
					if scl_counter = 3 then
						sda <= 'Z';
						i2c_receive_ack_counter <= 1;
					elsif scl_counter = 1 and i2c_receive_ack_counter = 1 then
						if sda = '0' then
							led0 <= '1';
						else
							led1 <= '1';
						end if;
						i2c_state_current <= i2c_state_next;
						i2c_read_counter <= 7;
						i2c_write_counter <= 7;
						i2c_receive_ack_counter <= 0;
					end if;
					
				elsif i2c_state_current = i2c_state_recieve_byte then
					if scl_counter = 1 then
						led2 <= '1';
						i2c_read_bits(i2c_read_counter) <= sda;
						if i2c_read_counter = 0 then
							i2c_state_current <= i2c_state_send_nack;	
							i2c_read_finished <= '1';
						else
							i2c_read_counter <= i2c_read_counter - 1;
						end if;
					end if;
					
				elsif i2c_state_current = i2c_state_send_byte then
					if scl_counter = 3 then -- middle of low scl
						sda <= i2c_write_bits(i2c_write_counter);
						if i2c_write_counter = 0 then
							i2c_state_next <= i2c_state_stop;
							i2c_state_current <= i2c_state_receive_ack;
							i2c_write_finished <= '1';
							led3 <= '1';
						else 
							i2c_write_counter <= i2c_write_counter - 1;
						end if;
					end if;
				
				elsif i2c_state_current = i2c_state_send_nack then
					if scl_counter = 3 then
						sda <= '1';
						i2c_state_current <= i2c_state_stop;
					end if;
				
				
				end if;
			end if;
		end if;
	end process;

	readout_led: process(rst, clk)
	begin
		if rst = '1' then
			readout_finished <= '0';
			led5 <= '0';
			led6 <= '0';
			readout_led_counter <= 0;
			readout_led_counter_blink <= '0';
			readout_led_counter_pos <= 7;
		elsif falling_edge(clk) then
			if clk_sda_enable = '1' then
				if i2c_read_finished = '1' and readout_finished = '0' then
					if readout_led_counter >= 100000 then
						readout_led_counter <= 0;
						
						if readout_led_counter_blink = '0' then
							led5 <= '1';
							led6 <= i2c_read_bits(readout_led_counter_pos);
							readout_led_counter_blink <= '1';
							if readout_led_counter_pos = 0 then
								readout_finished <= '1';
							else
								readout_led_counter_pos <= readout_led_counter_pos - 1;
							end if;
						else
							led5 <= '0';
							led6 <= '0';
							readout_led_counter_blink <= '0';
						end if;
					else
						readout_led_counter <= readout_led_counter + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	
	logic_statemachine: process(rst, clk)
	begin
		if rst = '1' then
			resetL <= '0';
			laserEn <= '0';
			led7 <= '0';
			logic_state_current <= logic_state_2;

		elsif falling_edge(clk) then
			if clk_logic_enable = '1' then

				if logic_state_current = logic_state_2 then
					if pgood25 = '1' then
						resetL <= '1';
						logic_state_current <= logic_state_3a;
						logic_wait_counter <= 0;
					end if;
					
				elsif logic_state_current = logic_state_3a then
					if logic_wait_counter = LOGIC_WAIT_1MS*25 then
						logic_state_current <= logic_state_3b;
					else
						logic_wait_counter <= logic_wait_counter + 1;
					end if;
					
				elsif logic_state_current = logic_state_3b then
					led7 <= '1';

				
				end if;
			end if;
		end if;
	end process;


end Behavioral;

