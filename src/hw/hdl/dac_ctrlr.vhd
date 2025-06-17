-------------------------------------------------------------------------------
-- Title         : DAC Controller
-------------------------------------------------------------------------------
-- File          : DAC_ctrlr.vhd
-- Author        : Thomas Chiesa tchiesa@bnl.gov
-- Created       : 07/19/2020
-------------------------------------------------------------------------------
-- Description:
-- This program is the DAC controller for the PSC.  It controls all
-- four DACs on the PSC. 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Modification history:
-- 07/19/2020: created.
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.psc_pkg.all;



entity dac_ctrlr is
  port(
    clk                  : in std_logic; 
    reset                : in std_logic; 
    tenkhz_trig          : in std_logic;
    dcct_adcs            : in t_dcct_adcs;  
	pid_cntrl            : in t_pid_cntrl;
	pid_stat             : out t_pid_stat;      
    dac_cntrl            : in t_dac_cntrl;
    dac_stat             : out t_dac_stat;
    sync    		     : out std_logic_vector(1 downto 0); 
    sclk     		     : out std_logic; 
    sdo                  : out std_logic_vector(3 downto 0)	
    );
end entity;

architecture arch of dac_ctrlr is

   signal rampout       : signed(19 downto 0);

   --debug signals (connect to ila)
   attribute mark_debug: string;   
   attribute mark_debug of tenkhz_trig: signal is "true";
   attribute mark_debug of rampout: signal is "true";



begin


dac1: entity work.dac_chan
  port map (
    clk  => clk,
    reset => reset,
    tenkhz_trig => tenkhz_trig,
    dcct_adcs => dcct_adcs.ps1, 
    pid_cntrl => pid_cntrl.ps1,
    pid_stat => pid_stat.ps1,        
    dac_numbits_sel => dac_cntrl.numbits_sel,
    dac_cntrl => dac_cntrl.ps1,
    dac_stat => dac_stat.ps1,
    n_sync1234 => sync(0),
    sclk1234 => sclk,
    sdo => sdo(0)
  );


dac2: entity work.dac_chan
  port map (
    clk => clk,
    reset => reset,
    tenkhz_trig => tenkhz_trig,
    dcct_adcs => dcct_adcs.ps2,
    pid_cntrl => pid_cntrl.ps2,
    pid_stat => pid_stat.ps2,          
    dac_numbits_sel => dac_cntrl.numbits_sel,    
    dac_cntrl => dac_cntrl.ps2,
    dac_stat => dac_stat.ps2,
    n_sync1234 => sync(1), 
    sclk1234 => open, 
    sdo => sdo(1)
  );

dac3: entity work.dac_chan
  port map (
    clk => clk,
    reset => reset,
    tenkhz_trig => tenkhz_trig,
    dcct_adcs => dcct_adcs.ps3, 
    pid_cntrl => pid_cntrl.ps3,
    pid_stat => pid_stat.ps3,        
    dac_numbits_sel => dac_cntrl.numbits_sel,   
    dac_cntrl => dac_cntrl.ps3,
    dac_stat => dac_stat.ps3,
    n_sync1234 => open, 
    sclk1234 => open, 
    sdo => sdo(2)
  );

dac4: entity work.dac_chan
  port map (
    clk => clk,
    reset => reset,
    tenkhz_trig => tenkhz_trig,
    dcct_adcs => dcct_adcs.ps4,  
    pid_cntrl => pid_cntrl.ps4,
    pid_stat => pid_stat.ps4,      
    dac_numbits_sel => dac_cntrl.numbits_sel,
    dac_cntrl => dac_cntrl.ps4,
    dac_stat => dac_stat.ps4,
    n_sync1234 => open,
    sclk1234 => open,
    sdo => sdo(3)
  );



    




end arch;
