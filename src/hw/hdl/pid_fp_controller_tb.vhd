library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.psc_pkg.ALL;


entity pid_fp_controller_tb is
end pid_fp_controller_tb;

architecture sim of pid_fp_controller_tb is

-- Component under test
component pid_fp_controller
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    start         : in std_logic;
    pid_cntrl     : in t_pid_cntrl_onech;
    pid_stat      : out t_pid_stat_onech;
    setpoint      : in  signed(19 downto 0);
    feedback      : in  signed(19 downto 0);
    control_out   : out signed(19 downto 0);
    done          : out std_logic
);
end component;


    -- Testbench signals
    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal tenkhz_trig   : std_logic := '0';
    signal done          : std_logic;
    signal setpoint      : signed(19 downto 0);
    signal feedback      : signed(19 downto 0);
    
    signal pid_cntrl     : t_pid_cntrl_onech;
    signal pid_stat      : t_pid_stat_onech;
    
    signal noise         : signed(19 downto 0);
    
    signal control_out   : signed(19 downto 0);

    constant clk_period : time := 10 ns;

begin

    -- Clock generation
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

 



    -- DUT instantiation
    uut: pid_fp_controller
        port map (
            clk           => clk,
            rst           => rst,
            start         => tenkhz_trig,
            pid_cntrl     => pid_cntrl,
            pid_stat      => pid_stat,
            setpoint      => setpoint,
            feedback      => feedback,
            control_out   => control_out,
            done => done
        );

    -- Stimulus process
    stimulus: process
    begin
        -- Wait for global reset
        wait for 100 ns;
        rst <= '0';

        -- Step input: setpoint = 100, feedback = 0
        setpoint  <= to_signed(50000, 20);  -- e.g., 100
        feedback  <= to_signed(0, 20);    -- e.g., 0

        -- Set gains: Kp = 2.0, Ki = 0.5, Kd = 0.1
        pid_cntrl.kp <= x"40000000";  -- 2.0
        pid_cntrl.ki <= x"3F000000";  -- 0.5
        pid_cntrl.kd <= x"3DCCCCCD";  -- 0.1

        -- Integral clamp: ±50.0
        pid_cntrl.ilimit_pos <= x"42480000"; -- +50.0
        pid_cntrl.ilimit_neg <= x"C2480000"; -- -50.0

        -- Generate tenkhz_trig every 100 us (10 kHz)
        for i in 0 to 1000 loop
           wait for 1 us;
           tenkhz_trig <= '1';
           --feedback <= noise;
           wait for clk_period;
           tenkhz_trig <= '0';
        end loop;
 
        pid_cntrl.ireset <= '1';
        wait for 100 ns;
        pid_cntrl.ireset <= '0';
        
  
         -- Generate tenkhz_trig every 100 us (10 kHz)
        for i in 0 to 1000 loop
           wait for 1 us;
           tenkhz_trig <= '1';
           --feedback <= noise;
           wait for clk_period;
           tenkhz_trig <= '0';
        end loop;      

        -- Run simulation
        wait for 2000 ns;

        -- Step feedback to match setpoint
        --feedback <= to_signed(100, 20);
        --wait for 1000 ns;

        -- Change setpoint
        setpoint <= to_signed(50, 20);
        wait for 1000 ns;

        -- Finish
        wait;
    end process;





-- Simple pseudo-random noise generator
 noise_proc : process(rst,clk)
        variable seed : integer := 7;
        variable nval : integer;
    begin
        if (rst = '1') then
           noise <= to_signed(0,20);
        end if;
        if rising_edge(clk) then
           if tenkhz_trig = '1' then
             -- Very basic LFSR-like noise
             seed := (seed * 17 + 3) mod 100;
             nval := seed - 50;  -- Range: -50 to +49
             noise <= to_signed(nval, 20);
           end if;
        end if;
    end process;







end sim;

