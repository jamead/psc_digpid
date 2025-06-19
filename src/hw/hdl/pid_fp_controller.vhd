--PID Controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.psc_pkg.ALL;

entity pid_fp_controller is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    start       : in  std_logic; 
    pid_cntrl   : in t_pid_cntrl_onech;
 	pid_stat    : out t_pid_stat_onech;          
    setpoint    : in  signed(19 downto 0);
    feedback    : in  signed(19 downto 0); 
    control_out : out signed(19 downto 0); 
    done        : out std_logic
);
end entity;


architecture behv of pid_fp_controller is



  signal setpt_f         : std_logic_vector(31 downto 0);
  signal fdbk_f          : std_logic_vector(31 downto 0);
  signal err_f           : std_logic_vector(31 downto 0);
  signal err_int_f       : std_logic_vector(31 downto 0);
  signal err_int_prev_f  : std_logic_vector(31 downto 0) := (others => '0');
  signal pterm_f         : std_logic_vector(31 downto 0); 
  signal iterm_f         : std_logic_vector(31 downto 0);
  signal pid_sum_f       : std_logic_vector(31 downto 0);
  signal setptout_fp     : std_logic_vector(31 downto 0);   
  signal setptout        : std_logic_vector(19 downto 0); 
  
  signal err_valid       : std_logic;
  signal err_int_valid   : std_logic;
  signal iterm_valid     : std_logic;
  
  
  attribute mark_debug     : string; 
  attribute mark_debug of setpoint: signal is "true";
  attribute mark_debug of feedback: signal is "true";
  attribute mark_debug of start: signal is "true";
  attribute mark_debug of pid_cntrl: signal is "true";
  attribute mark_debug of setpt_f: signal is "true";
  attribute mark_debug of fdbk_f: signal is "true";
  attribute mark_debug of pterm_f: signal is "true";  
  attribute mark_debug of err_f: signal is "true";   
  attribute mark_debug of setptout_fp: signal is "true";
  attribute mark_debug of control_out: signal is "true";



begin

pid_stat.setptin_f <= setpt_f;
pid_stat.fdbk_f <= fdbk_f;
pid_stat.error_f <= err_f;
pid_stat.pterm_f <= pterm_f;
pid_stat.iterm_f <= iterm_f;
pid_stat.dterm_f <= err_int_f;
pid_stat.sumterm_f <= pid_sum_f;

pid_stat.setptout <= control_out;

control_out <= signed(setptout_fp(31 downto 12));



--fixed to float conversion for set point
setpt_conv : entity work.fix20_to_float
  PORT MAP (
    aclk => clk,
    s_axis_a_tvalid => start, --'1',
    s_axis_a_tdata => std_logic_vector(resize(setpoint,24)),
    m_axis_result_tvalid => open,
    m_axis_result_tdata => setpt_f
  );


--fixed to float conversion for feedback
fdbk_conv : entity work.fix20_to_float
  PORT MAP (
    aclk => clk,
    s_axis_a_tvalid => start, --'1',
    s_axis_a_tdata => std_logic_vector(resize(feedback,24)),
    m_axis_result_tvalid => open,
    m_axis_result_tdata => fdbk_f
  );
  

--Error = setpoint + feedback (dcct is negative)
error_term : entity work.fp_add
  PORT MAP (
    aclk => clk,
    s_axis_a_tvalid => start, --'1',
    s_axis_a_tdata => setpt_f,
    s_axis_b_tvalid => '1',
    s_axis_b_tdata => fdbk_f,
    m_axis_result_tvalid => err_valid, 
    m_axis_result_tdata => err_f
  );



-- P = Kp * error
p_term: entity work.fp_mult
  port map (
    aclk  => clk,
    s_axis_a_tvalid => err_valid, 
    s_axis_a_tdata => pid_cntrl.kp,
    s_axis_b_tvalid => '1',
    s_axis_b_tdata => err_f,
    m_axis_result_tvalid => open,
    m_axis_result_tdata => pterm_f
 );


-- Integral = integral + error
integral_term : entity work.fp_add
  port map (
    aclk => clk,
    s_axis_a_tvalid => err_valid, 
    s_axis_a_tdata => err_f,
    s_axis_b_tvalid => '1', 
    s_axis_b_tdata => err_int_prev_f,
    m_axis_result_tvalid => err_int_valid, 
    m_axis_result_tdata => err_int_f
  );


-- latch the integral for the next update
process(clk)
begin
  if (rising_edge(clk)) then
    if (start = '1') then
       err_int_prev_f <= err_int_f;
    end if;
    if (pid_cntrl.ireset = '1') then
       err_int_prev_f <= (others => '0');
    end if;
  end if;
end process;



-- I = Ki * integral
i_term: entity work.fp_mult
  port map (
    aclk                => clk,
    s_axis_a_tvalid     => err_int_valid, 
    s_axis_a_tdata      => pid_cntrl.ki,
    s_axis_b_tvalid     => err_int_valid, 
    s_axis_b_tdata      => err_int_f,
    m_axis_result_tvalid => iterm_valid, 
    m_axis_result_tdata  => iterm_f
 );


-- PID = P + I + D  (forget D for now)
sum_term : entity work.fp_add
  PORT MAP (
    aclk => clk,
    s_axis_a_tvalid => iterm_valid, 
    s_axis_a_tdata => pterm_f,
    s_axis_b_tvalid => iterm_valid, 
    s_axis_b_tdata => iterm_f,
    m_axis_result_tvalid => open,
    m_axis_result_tdata => pid_sum_f
  );




-- Convert to Fixed20 and Output to DAC
setpt_out : entity work.float_to_fix20
  PORT MAP (
    aclk => clk,
    s_axis_a_tvalid => '1',
    s_axis_a_tdata => pid_sum_f,
    m_axis_result_tvalid => open,
    m_axis_result_tdata => setptout_fp
  );


    
end architecture;