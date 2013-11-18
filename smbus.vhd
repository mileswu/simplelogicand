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



entity smbus is
    Port ( rst : in STD_LOGIC;
			  clk : in  STD_LOGIC;
           scl : out  STD_LOGIC;
           sda : inout  STD_LOGIC;
			  resetL : out STD_LOGIC;
			  laserEn : out STD_LOGIC;
			  pgood25 : in STD_LOGIC
			  );
end smbus;

architecture Behavioral of smbus is

signal slowclk: std_logic;
signal clk_counter : integer range 0 to 50000 := 0;

signal scl_counter : integer range 0 to 50000 := 0;
constant CLKSLOWCLK_RATIO : integer := 250;
--constant CLKSLOWCLK_RATIO : integer := 63;

type i2c_state_type is (i2c_state_idle, i2c_state_start, i2c_state_stop, i2c_state_send_slave_address,
   i2c_state_send_rw_read, i2c_state_send_rw_write, i2c_state_receive_ack, i2c_state_recieve_byte, i2c_state_send_byte, i2c_state_send_nack);
signal i2c_state_current : i2c_state_type;
signal i2c_state_next : i2c_state_type;

signal i2c_idle_counter : integer range 0 to 50000;

signal i2c_slaveaddress_counter : integer range 0 to 10;
signal i2c_slaveaddress_bits : std_logic_vector(6 downto 0);

signal i2c_receive_ack_counter : integer range 0 to 10;

constant i2c_write_bits_maxsize : integer := 120;
signal i2c_write_bits_size : integer range 0 to i2c_write_bits_maxsize;
signal i2c_write_bits : std_logic_vector(i2c_write_bits_maxsize downto 0);
signal i2c_write_counter : integer range 0 to i2c_write_bits_maxsize;
signal i2c_write_finished : std_logic;

signal i2c_read_bits : std_logic_vector(7 downto 0);
signal i2c_read_counter : integer range 0 to 10;
signal i2c_read_finished : std_logic;

signal i2c_stop_counter : integer range 0 to 10;

signal readout_finished : std_logic;

type logic_state_type is (logic_state_2,
logic_state_4,logic_state_5,
logic_state_6a,logic_state_6b,
logic_state_7a, logic_state_7b, logic_state_7c, logic_state_7d, logic_state_7e,
logic_state_8a, logic_state_8b,
logic_state_9a, logic_state_9b,
logic_state_10,
logic_state_11a, logic_state_11b, logic_state_11c, logic_state_11d, logic_state_11e, logic_state_11f,
logic_state_11g, logic_state_11h, logic_state_11i, logic_state_11j, logic_state_11k, logic_state_11l, 
logic_state_11m, logic_state_11n, logic_state_11o, logic_state_11p, logic_state_11q, logic_state_11r, 
logic_state_11s, logic_state_11t, logic_state_11u,
logic_state_12a, logic_state_12b,
logic_state_13a, logic_state_13b, logic_state_13c, logic_state_13d, logic_state_13e, logic_state_13f,
logic_state_00, logic_state_wait,
logic_state_readout, logic_state_deadend
);
signal logic_state_current : logic_state_type;
signal logic_state_next : logic_state_type;
signal logic_wait_ms : integer range 0 to 1000;

signal logic_i2c_start : std_logic;
type logic_i2c_rw_type is (logic_i2c_read, logic_i2c_write);
signal logic_i2c_rw : logic_i2c_rw_type;

constant LOGIC_WAIT_1MS : integer := 400;
--constant LOGIC_WAIT_1MS : integer := 400*4;
--constant LOGIC_WAIT_1MS : integer := 2;
signal logic_wait_counter : integer range 0 to 1000000 := 0;

begin
					
	slowclk_generation: process(rst, clk)
	begin
		if rst = '1' then
			clk_counter <= 0;
			slowclk <= '0';
		elsif rising_edge(clk) then
			if clk_counter < CLKSLOWCLK_RATIO then
				slowclk <= '0';
			else
				slowclk <= '1';
			end if;
			
			if clk_counter >= (CLKSLOWCLK_RATIO*2) then
				clk_counter <= 0;
			else
				clk_counter <= clk_counter + 1;
			end if;
		end if;
	end process;
	
	i2c_generation: process(rst, slowclk)
	begin
	if falling_edge(slowclk) then
		if rst = '1' then
			resetL <= '0';
			laserEn <= '0';
			logic_state_current <= logic_state_2;
			logic_i2c_start <= '0';
			logic_wait_counter <= 0;
		else
		--elsif falling_edge(slowclk) then
			if logic_state_current = logic_state_2 then
				if pgood25 = '1' then
					resetL <= '1';
					logic_state_current <= logic_state_wait;
					logic_wait_ms <= 25;
					logic_state_next <= logic_state_4;
				end if;
						
			-- step 4
			elsif logic_state_current = logic_state_4 then
				logic_i2c_start <= '1';
				logic_i2c_rw <= logic_i2c_write;
				i2c_write_bits_size <= 4*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 4*8 => '0') & x"0d393333";
				logic_state_next <= logic_state_5;
				logic_state_current <= logic_state_00;
				logic_wait_ms <= 5;

			-- step 5
			elsif logic_state_current = logic_state_5 then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 5*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 5*8 => '0') & x"10fbfbfbfb";
				logic_state_next <= logic_state_6a;
				logic_state_current <= logic_state_00;
			
			-- step 6
			elsif logic_state_current = logic_state_6a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 2*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"06f0";
				logic_state_current <= logic_state_6b;
			
			elsif logic_state_current = logic_state_6b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"3535";
					logic_state_next <= logic_state_7a;
					logic_state_current <= logic_state_00;
				end if;
			
			-- step 7
			elsif logic_state_current = logic_state_7a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 2*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"2f0f";
				logic_state_current <= logic_state_7b;
			
			elsif logic_state_current = logic_state_7b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"1a74";
					logic_state_current <= logic_state_7c;
				end if;
			
			elsif logic_state_current = logic_state_7c then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"1c74";
					logic_state_current <= logic_state_7d;
				end if;
			
			elsif logic_state_current = logic_state_7d then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"1e74";
					logic_state_current <= logic_state_7e;
				end if;
			
			elsif logic_state_current = logic_state_7e then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"2074";
					logic_state_next <= logic_state_8a;
					logic_state_current <= logic_state_00;
				end if;
				
			-- step 8
			elsif logic_state_current = logic_state_8a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 1*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 1*8 => '0') & x"0a";
				logic_state_current <= logic_state_8b;
			
			elsif logic_state_current = logic_state_8b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					logic_i2c_rw <= logic_i2c_read;
					logic_state_next <= logic_state_9a;
					logic_state_current <= logic_state_00;
				end if;

			-- step 9
			elsif logic_state_current = logic_state_9a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 13*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 13*8 => '0') & x"22bf02" & (i2c_read_bits and x"03")
					& x"bf02" & (i2c_read_bits and x"03") & x"bf02" & (i2c_read_bits and x"03") & x"bf02" & (i2c_read_bits and x"03");
				logic_state_current <= logic_state_9b;
			
			elsif logic_state_current = logic_state_9b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 2*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"34" &
						i2c_read_bits(1 downto 0) & i2c_read_bits(1 downto 0) & i2c_read_bits(1 downto 0) & i2c_read_bits(1 downto 0);
					logic_state_next <= logic_state_10;
					logic_state_current <= logic_state_00;
				end if;
			
			-- step 10
			elsif logic_state_current = logic_state_10 then
				laserEn <= '1';
				logic_state_current <= logic_state_wait;
				logic_wait_ms <= 200;
				logic_state_next <= logic_state_11a;
			
			-- step 11
			elsif logic_state_current = logic_state_11a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 2*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"8af2";
				logic_state_current <= logic_state_11b;
			
			elsif logic_state_current = logic_state_11b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"8c80";
					logic_state_current <= logic_state_11c;
				end if;
			
			elsif logic_state_current = logic_state_11c then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 3*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 3*8 => '0') & x"b2ff03";
					logic_state_current <= logic_state_11d;
				end if;
			
			elsif logic_state_current = logic_state_11d then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 2*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"8d80";
					logic_state_current <= logic_state_11e;
				end if;
			
			elsif logic_state_current = logic_state_11e then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"9c00";
					logic_state_current <= logic_state_11f;
				end if;

			elsif logic_state_current = logic_state_11f then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"8f0c";
					logic_state_current <= logic_state_11g;
				end if;

			elsif logic_state_current = logic_state_11g then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 5*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 5*8 => '0') & x"b47e7e7e7e";
					logic_state_current <= logic_state_11h;
				end if;
				
			elsif logic_state_current = logic_state_11h then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 4*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 4*8 => '0') & x"730609c0";
					logic_state_current <= logic_state_11i;
				end if;
			
			elsif logic_state_current = logic_state_11i then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 2*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"760f";
					logic_state_current <= logic_state_11j;
				end if;

			elsif logic_state_current = logic_state_11j then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"7f00";
					logic_state_current <= logic_state_11k;
				end if;

			elsif logic_state_current = logic_state_11k then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"8900";
					logic_state_current <= logic_state_11l;
				end if;
			
			elsif logic_state_current = logic_state_11l then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"91da";
					logic_state_current <= logic_state_11m;
				end if;

			elsif logic_state_current = logic_state_11m then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b2fe";
					logic_state_current <= logic_state_11n;
				end if;
			
			elsif logic_state_current = logic_state_11n then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b2fc";
					logic_state_current <= logic_state_11o;
				end if;

			elsif logic_state_current = logic_state_11o then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b2f8";
					logic_state_current <= logic_state_11p;
				end if;
			
			elsif logic_state_current = logic_state_11p then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b2f0";
					logic_state_current <= logic_state_11q;
				end if;

			elsif logic_state_current = logic_state_11q then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b2e0";
					logic_state_current <= logic_state_11r;
				end if;
			
			elsif logic_state_current = logic_state_11r then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b2c0";
					logic_state_current <= logic_state_11s;
				end if;

			elsif logic_state_current = logic_state_11s then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b280";
					logic_state_current <= logic_state_11t;
				end if;
			
			elsif logic_state_current = logic_state_11t then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b200";
					logic_state_current <= logic_state_11u;
				end if;

			elsif logic_state_current = logic_state_11u then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b301";
					logic_state_current <= logic_state_00;
					logic_state_next <= logic_state_12a;
					logic_wait_ms <= 10;
				end if;
			
			-- step 12
			elsif logic_state_current = logic_state_12a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 2*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"2f00";
				logic_state_current <= logic_state_12b;
			
			elsif logic_state_current = logic_state_12b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"b300";
					logic_state_current <= logic_state_00;
					logic_state_next <= logic_state_13a;
					logic_wait_ms <= 5;
				end if;
				
			-- step 13
			elsif logic_state_current = logic_state_13a then
				logic_i2c_start <= '1';
				i2c_write_bits_size <= 2*8 -1;
				i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"8d85";
				logic_state_current <= logic_state_13b;
			
			elsif logic_state_current = logic_state_13b then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"9c03";
					logic_state_current <= logic_state_13c;
				end if;		
				
			elsif logic_state_current = logic_state_13c then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 5*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 5*8 => '0') & x"10ffffffff";
					logic_state_current <= logic_state_13d;
				end if;
				
			elsif logic_state_current = logic_state_13d then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 2*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"3380";
					logic_state_current <= logic_state_13e;
				end if;	
				
			elsif logic_state_current = logic_state_13e then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 5*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 5*8 => '0') & x"8593818e89";
					logic_state_current <= logic_state_13f;
				end if;
				
			elsif logic_state_current = logic_state_13f then
				if logic_i2c_start = '0' and i2c_write_finished = '1' then
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 2*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"91d3";
					logic_state_current <= logic_state_00;
					logic_state_next <= logic_state_deadend;
					logic_wait_ms <= 600;
				end if;	
				
			-- waiter
			elsif logic_state_current = logic_state_wait then
				if logic_wait_counter = LOGIC_WAIT_1MS*logic_wait_ms then
					logic_state_current <= logic_state_next;
					logic_wait_counter <= 0;
				else
					logic_wait_counter <= logic_wait_counter + 1;
				end if;
			
			-- reset write pointer to 00
			elsif logic_state_current = logic_state_00 then
				if logic_i2c_start = '0' and (i2c_write_finished = '1' or i2c_read_finished = '1') then
				-- logic_i2c_start check to ensure that the logic_i2c_start code has run and reset write_finished
					logic_i2c_rw <= logic_i2c_write;
					logic_i2c_start <= '1';
					i2c_write_bits_size <= 2*8 -1;
					i2c_write_bits <= (i2c_write_bits_maxsize downto 2*8 => '0') & x"0000";
					logic_state_current <= logic_state_wait;
				end if;
			end if;
		end if;
	
	
	
		-- SCL
		if rst = '1' then
			scl <= '0';
			scl_counter <= 0;
		else
		--elsif falling_edge(slowclk) then
			if scl_counter = 0 then
				scl <= '1';
			elsif scl_counter = 2 then
				scl <= '0';
			end if;
				
			if scl_counter < 3 then
				scl_counter <= scl_counter+ 1;
			elsif scl_counter >= 3 then
				scl_counter <= 0;
			end if;
		end if;
		
		-- SDA
		if rst = '1' then
			i2c_state_current <= i2c_state_idle;
			i2c_state_next <= i2c_state_idle;
			i2c_idle_counter <= 0;
			sda <= '1';
			i2c_slaveaddress_bits <= "1010100";
			i2c_read_finished <= '0';
			i2c_write_finished <= '0';
			i2c_receive_ack_counter <= 0;
			i2c_stop_counter <= 0;
		
		else
		--elsif falling_edge(slowclk) then
			if logic_i2c_start = '1' then
				i2c_state_next <= i2c_state_start;
				i2c_read_finished <= '0';
				i2c_write_finished <= '0';
				logic_i2c_start <= '0'; -- turn itself off
			end if;
		
			if i2c_state_current = i2c_state_idle then
				if scl_counter = 3 then -- middle of low scl
					sda <= '1';
					if i2c_idle_counter >= 5 then --idle for 5 cycles
						i2c_idle_counter <= 0;
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
					i2c_state_next <= i2c_state_idle;
					
					if logic_i2c_rw = logic_i2c_write then
						i2c_write_finished <= '1';
					else
						i2c_read_finished <= '1';
					end if;
				end if;
				
			elsif i2c_state_current = i2c_state_send_slave_address then
				if scl_counter = 3 then -- middle of low scl
					sda <= i2c_slaveaddress_bits(i2c_slaveaddress_counter);
					if i2c_slaveaddress_counter = 0 then
						if logic_i2c_rw = logic_i2c_write then
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
					i2c_read_counter <= 7;
				end if;
				
			elsif i2c_state_current = i2c_state_send_rw_write then
				if scl_counter = 3 then
					sda <= '0';
					i2c_state_current <= i2c_state_receive_ack;
					i2c_state_next <= i2c_state_send_byte;
					i2c_write_counter <= i2c_write_bits_size;
				end if;
				
			elsif i2c_state_current = i2c_state_receive_ack then
				
				if scl_counter = 3 then
					sda <= 'Z';
					i2c_receive_ack_counter <= 1;
				elsif scl_counter = 1 and i2c_receive_ack_counter = 1 then
					i2c_state_current <= i2c_state_next;
					i2c_receive_ack_counter <= 0;
				end if;
				
			elsif i2c_state_current = i2c_state_recieve_byte then
				if scl_counter = 1 then
					i2c_read_bits(i2c_read_counter) <= sda;
					if i2c_read_counter = 0 then
						i2c_state_current <= i2c_state_send_nack;	
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
					elsif i2c_write_counter mod 8 = 0 then
						i2c_state_next <= i2c_state_send_byte;
						i2c_state_current <= i2c_state_receive_ack;
						i2c_write_counter <= i2c_write_counter - 1;
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


end Behavioral;

