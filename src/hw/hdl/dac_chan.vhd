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

entity dac_chan is
  port(
    clk                  : in std_logic; 
    reset                : in std_logic; 
    tenkhz_trig          : in std_logic;
    dcct_adcs            : in t_dcct_adcs_onech;
    pid_cntrl            : in t_pid_cntrl_onech;
	pid_stat             : out t_pid_stat_onech;
    dac_numbits_sel      : in std_logic;
    dac_cntrl            : in t_dac_cntrl_onech;
    dac_stat             : out t_dac_stat_onech;
    n_sync1234		     : out std_logic; 
	sclk1234   		     : out std_logic; 
	sdo                  : out std_logic	
    );
end entity;

architecture arch of dac_chan is


  type state_type is (IDLE, RUN_RAMP, UPDATE_DAC); 
  signal state             : state_type;
 
  signal dac_data          : std_logic_vector(19 downto 0);
  signal dac_rdaddr        : std_logic_vector(15 downto 0);
  signal dac_rddata        : std_logic_vector(19 downto 0);
  signal dac_rden          : std_logic;
  signal ramp_dac_setpt    : signed(19 downto 0);
  signal smooth_dac_setpt  : signed(19 downto 0);
  signal fofb_dac_setpt    : signed(19 downto 0);
  signal dac_setpt_raw     : signed(19 downto 0);
  signal dac_setpt         : signed(19 downto 0);
  signal ramp_active       : std_logic;
  signal smooth_active     : std_logic;
  signal dac_trig          : std_logic;
  signal gainoff_done      : std_logic;
  
  signal dac_setpt_gainoff : signed(19 downto 0); 
  signal dac_setpt_digital : signed(19 downto 0);  
  




   --debug signals (connect to ila)
   attribute mark_debug                 : string;
   attribute mark_debug of dac_data: signal is "true";
   attribute mark_debug of ramp_dac_setpt: signal is "true";
   attribute mark_debug of smooth_dac_setpt: signal is "true";
   attribute mark_debug of dac_setpt: signal is "true";
   attribute mark_debug of ramp_active: signal is "true";  
   attribute mark_debug of smooth_active: signal is "true";   
   


begin

--status readbacks
dac_stat.dac_setpt <= dac_setpt; --dac_setpt_gainoff;
dac_stat.active <= ramp_active or smooth_active;




--Source of DAC data depenods on Mode
--Because DAC sync's are tied together, must always update every DAC
--  0=smooth ramp, 1=ramp table, 2=FOFB, 3=Jump Mode
process(clk) 
begin 
    if rising_edge(clk) then 
      if (reset = '1') then
        dac_setpt_raw <= (others => '0');
      else
        if (tenkhz_trig = '1') then 
          case dac_cntrl.mode is 
            when "00" =>  
               dac_setpt_raw <= smooth_dac_setpt;
            when "01" =>
               dac_setpt_raw <= ramp_dac_setpt;
            when "10" =>
               dac_setpt_raw <= fofb_dac_setpt;
            when "11" =>
               dac_setpt_raw <= dac_cntrl.setpoint; 
          end case;   
        end if;
      end if;
    end if; 
end process; 


-- In rampmode, DAC setpoint comes from table in block ram
rampmode: entity work.ramptable_ramp
  port map (
    clk => clk,  
    reset => reset,  
    tenkhz_trig => tenkhz_trig, 
    dac_cntrl => dac_cntrl, 
    ramp_active => ramp_active,
    ramp_dac_setpt => ramp_dac_setpt
    );


-- In smoothmode, DAC setpoint comes from raised cosine calculation done in fabric
smoothmode: entity work.smooth_ramp
  port map (
    clk => clk,
    reset => reset,
    tenkhz_trig => tenkhz_trig,
    cur_setpt => dac_setpt_gainoff, --dac_cntrl.smooth_oldsetpt, --20d"0",
    new_setpt => dac_cntrl.setpoint, --dac_cntrl.smooth_newsetpt, --20d"10000",
    phase_inc => dac_cntrl.smooth_phaseinc, 
    smooth_active => smooth_active,
    rampout => smooth_dac_setpt
);
 
 
-- apply gain and offsets 
gainoff_dac : entity work.dac_gainoffset
  port map (
    clk => clk,
    reset => reset,
    tenkhz_trig => tenkhz_trig,
    numbits_sel => dac_numbits_sel,
    dac_setpt_raw => dac_setpt_raw,
    dac_cntrl => dac_cntrl,
    dac_setpt => dac_setpt_gainoff,
    done => gainoff_done
);
  
 
--Digital Control Loop
dig_loop : entity work.pid_fp_controller
port map(
    clk => clk, 
    rst => reset, 
    start => gainoff_done, 
    pid_cntrl => pid_cntrl,
	pid_stat => pid_stat,   
    setpoint => dac_setpt_gainoff,
    feedback => dcct_adcs.dcct0, 
    control_out => dac_setpt_digital,
    done => open
);  
  
  
dac_setpt <= dac_setpt_gainoff when pid_cntrl.digpid_enb = '0' else dac_setpt_digital;  
  
  
-- select 18 bit or 20 bit, put hard limits on dac
dac_data <= std_logic_vector(dac_setpt) when dac_numbits_sel = '1' else std_logic_vector((dac_setpt(17 downto 0) & "00"));


-- write the SPI DAC
spi_dac:  entity work.dac_ad5781 
  generic map
    (SPI_CLK_DIV => 5) --10MHz sclk
  port map(
    clk => clk,
    reset => dac_cntrl.reset, 
	start => gainoff_done,       
    dac_data => dac_data, 
    dac_ctrl_bits => dac_cntrl.cntrl(4 downto 0),       
    n_sync => n_sync1234, 
    sclk => sclk1234,
    sdo => sdo, 
    done => open
);




end arch;
