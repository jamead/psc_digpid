-- Testbench for PID Controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.psc_pkg.all;

entity tb_pid_controller is
end entity;

architecture behavior of tb_pid_controller is

    constant CLK_PERIOD : time := 10 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal start       : std_logic := '0';
    signal setpoint    : signed(19 downto 0);
    signal feedback    : signed(19 downto 0);
    signal control_out : signed(19 downto 0);
    signal done        : std_logic;
    signal pid_cntrl   : t_pid_cntrl_onech;
    signal pid_stat    : t_pid_stat_onech;
    signal tenkhz_trig : std_logic;
    
    signal plant_output : signed(19 downto 0) := to_signed(10000, 20);
    signal noise : signed(19 downto 0);



begin

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- DUT Instantiation
    uut: entity work.pid_controller
        generic map (
            DATA_WIDTH => 20,
            SCALE_BITS => 0
        )
        port map (
            clk         => clk,
            rst         => rst,
            start       => tenkhz_trig,
            pid_cntrl   => pid_cntrl,
            pid_stat    => pid_stat,
            setpoint    => setpoint,
            feedback    => feedback, --plant_output,
            control_out => control_out,
            done        => done
        );

 -- Stimulus process
 stim_proc: process
    begin
        -- Initialize
        tenkhz_trig <= '0';
        rst <= '1';
        start <= '0';
        setpoint <= to_signed(integer(0.0 * real(2**20)), 20);
        pid_cntrl.kp <= to_signed(100,20); --to_signed(integer(0.00001 * real(2**19)), 20); --Q8.32      
        pid_cntrl.ki <= to_signed(10,20);  --to_signed(integer(0.000001 * real(2**19)), 20);
        pid_cntrl.kd <= to_signed(0, 20);
        pid_cntrl.park <= '0';
        pid_cntrl.digpid_enb <= '1';

        wait for 50 ns;
        rst <= '0';

        wait for 500 ns;

        -- Generate tenkhz_trig every 100 us (10 kHz)
        for i in 0 to 20 loop
           wait for 10 us;
           tenkhz_trig <= '1';
           wait for clk_period;
           tenkhz_trig <= '0';
        end loop;
 
        --change setpoint
        setpoint <= to_signed(10000, 20);       
        -- Generate tenkhz_trig every 100 us (10 kHz)
        for i in 0 to 10000000 loop
           wait for 10 us;
           tenkhz_trig <= '1';
           wait for clk_period;
           tenkhz_trig <= '0';
        end loop;
        
        
 
        wait for 100 ms;

    end process;


feedback <= plant_output; -- + noise;



 -- Simple Plant Model
--y[n+1] = y[n] + α * (u[n] - y[n])
 plant_proc : process(clk)
        constant alpha : integer := 20; -- responsiveness
        variable delta : signed(19 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                plant_output <= to_signed(0, 20);
            elsif tenkhz_trig = '1' then
                delta := resize(((control_out - plant_output) * alpha) / 1000, 20);
                plant_output <= plant_output + delta;
            end if;
        end if;
    end process;



 -- Simple pseudo-random noise generator
 noise_proc : process(clk)
        variable seed : integer := 7;
        variable nval : integer;
    begin
        if rising_edge(clk) then
            if tenkhz_trig = '1' then
                -- Very basic LFSR-like noise
                seed := (seed * 17 + 3) mod 100;
                nval := seed - 50;  -- Range: -50 to +49
                noise <= to_signed(nval, 20);
            end if;
        end if;
    end process;





end architecture;

