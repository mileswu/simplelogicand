--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   09:49:01 07/05/2013
-- Design Name:   
-- Module Name:   C:/Users/usr/simplelogicand/smbustest.vhd
-- Project Name:  simplelogicand
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: smbus
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY smbustest IS
END smbustest;
 
ARCHITECTURE behavior OF smbustest IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT smbus
    PORT(
			rst : IN std_logic;
         clk_p : IN  std_logic;
         clk_n : IN  std_logic;
         scl : OUT  std_logic;
         sda : INOUT  std_logic;
			led0 : OUT std_logic;
			led1 : OUT std_logic;
			led2 : OUT std_logic;
			led3 : OUT std_logic;
			led4 : OUT std_logic;
			led5 : OUT std_logic;
			led6 : OUT std_logic;
			resetL : out STD_LOGIC;
			laserEn : out STD_LOGIC;
			pgood25 : in STD_LOGIC
        );
    END COMPONENT;
    

   --Inputs
	signal rst : std_logic := '0';
   signal clk_p : std_logic := '0';
   signal clk_n : std_logic := '0';
	signal pgood25 : std_logic := '0';

	--BiDirs
   signal sda : std_logic;

 	--Outputs
   signal scl : std_logic;
	signal led0 : std_logic;
	signal led1 : std_logic;
	signal led2 : std_logic;
	signal led3 : std_logic;
	signal led4 : std_logic;
	signal led5 : std_logic;
	signal led6 : std_logic;
	signal test : std_logic;
	signal resetL : std_logic;
	signal laserEn : std_logic;
	
   -- Clock period definitions
   constant clk_p_period : time := 5 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: smbus PORT MAP (
          clk_p => clk_p,
          clk_n => clk_n,
          scl => scl,
          sda => sda,
			 rst => rst,
			 led0 => led0,
			 led1 => led1,
			 led2 => led2,
			 led3 => led3,
			 led6 => led6,
			 led4 => led4,
			 led5 => led5,
			 resetL => resetL,
			 laserEn => laserEn,
			 pgood25 => pgood25
        );

   -- Clock process definitions
   clk_p_process :process
   begin
		clk_p <= '0';
		clk_n <= '1';
		wait for clk_p_period/2;
		clk_p <= '1';
		clk_n <= '0';
		wait for clk_p_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin
		rst <= '1';
		sda <= 'Z';
		test <= '0';
      -- hold reset state for 100 ns.
      wait for 50 ns;
		rst <= '0';

      wait for 1097500 ns;
		
		sda <= '0';
		wait for 10000 ns;
		sda <= 'Z';
		wait for 80000 ns;
		sda <= '0';
		wait for 10000 ns;
		sda <= 'Z';

      wait for 1100000 ns;
		test <= '1';
		sda <= '0';
		wait for 10000 ns;
		sda <= 'Z';
		--wait for 40000 ns;
		

      -- insert stimulus here 

      wait;
   end process;

END;
