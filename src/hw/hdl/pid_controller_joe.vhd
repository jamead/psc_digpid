--PID Controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.psc_pkg.ALL;


entity pid_controller is
    generic (
        DATA_WIDTH     : integer := 20;      -- input/output bit width
        SCALE_BITS     : integer := 0 --15       -- Q-format fractional bits (Q5.15)
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic; --Starts a PID calculation
        pid_cntrl   : in t_pid_cntrl_onech;
 	    pid_stat    : out t_pid_stat_onech;        
        setpoint    : in  signed(DATA_WIDTH-1 downto 0);
        feedback    : in  signed(DATA_WIDTH-1 downto 0) := (others => '0');
        control_out : out signed(DATA_WIDTH-1 downto 0) := (others => '0'); 
        done        : out std_logic
    );
end entity;

architecture behv of pid_controller is

    constant ACC_WIDTH  : integer := 32;
    constant PROD_WIDTH : integer := 32;

    constant MAX_INPUT  : integer := 2**(DATA_WIDTH - 1) - 1;
    constant MIN_INPUT  : integer := -2**(DATA_WIDTH - 1);

    -- Limits for error and integral (tunable)
    constant ERROR_MAX    : signed(ACC_WIDTH-1 downto 0) := to_signed(2**24 - 1, ACC_WIDTH);
    constant ERROR_MIN    : signed(ACC_WIDTH-1 downto 0) := to_signed(-2**24, ACC_WIDTH);
    constant INTEGRAL_MAX : signed(ACC_WIDTH-1 downto 0) := to_signed(2**25 - 1, ACC_WIDTH);
    constant INTEGRAL_MIN : signed(ACC_WIDTH-1 downto 0) := to_signed(-2**25, ACC_WIDTH);

    -- Limits for derivative term (example ± 2^23)
    constant DERIV_MAX   : signed((2*PROD_WIDTH)-1 downto 0) := to_signed(2**23 - 1, (2*PROD_WIDTH));
    constant DERIV_MIN   : signed((2*PROD_WIDTH)-1 downto 0) := to_signed(-2**23, (2*PROD_WIDTH));

    -- Internal state signals
    signal error         : signed(19 downto 0) := (others => '0');
    signal integral      : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal prev_error    : signed(ACC_WIDTH-1 downto 0) := (others => '0');

    -- PID term signals
    signal p_term_full   : signed((2*PROD_WIDTH)-1 downto 0) := (others => '0');
    signal p_term        : signed(31 downto 0) := (others => '0'); 
    signal i_term        : signed(31 downto 0) := (others => '0');
    
    signal d_term        : signed((2*PROD_WIDTH)-1 downto 0) := (others => '0');
    signal control_sum   : signed(31 downto 0) := (others => '0');
    signal control_scaled: signed(31 downto 0) := (others => '0');
    signal control_sat   : signed(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Signals replacing variables from original code
    signal setp_int      : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal fb_int        : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal raw_error     : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal clamped_error : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal next_integral : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal d_error       : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal Kp, Ki, Kd    : signed(31 downto 0) := (others => '0');
    signal multicycle_cntr : integer range 0 to 100 := 0; 
    
    type state_type is (IDLE, RUN_PID, COMPLETE); 
    signal state : state_type;     



-- Multiplies two signed vectors and returns result shifted down by 'fraction_bits'
function fixed_mul(
    signal a           : signed;
    signal b           : signed;
    constant fraction_bits : natural
) return signed is
    variable product : signed(a'length + b'length - 1 downto 0);
    variable shifted : signed(a'length - 1 downto 0);
begin
    -- This multiplication works because VHDL automatically infers result size
    product := a * b;

    -- Extract most significant bits after shifting right by fraction_bits
    shifted := product(product'high - fraction_bits downto product'high - fraction_bits - (a'length - 1));

    return shifted;
end function;



begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                error       <= (others => '0');
                integral    <= (others => '0');
                prev_error  <= (others => '0');
                control_sat <= (others => '0');

                setp_int      <= (others => '0');
                fb_int        <= (others => '0');
                raw_error     <= (others => '0');
                clamped_error <= (others => '0');
                next_integral <= (others => '0');
                d_error       <= (others => '0');
                Kp            <= (others => '0');
                Ki            <= (others => '0');
                Kd            <= (others => '0');

                p_term       <= (others => '0');
                i_term       <= (others => '0');
                d_term       <= (others => '0');
                control_sum  <= (others => '0');
                control_scaled <= (others => '0');
                done        <= '0'; 
                state       <= IDLE; 

            else
                
                case state is 
                    --IDLE: Waits for start strobe to start running the PID calculation
                    when IDLE => 
                        if start = '1' then 
                            state <= RUN_PID; 
                        end if; 
                        done <= '0'; 
                        
                        
                        
                    --RUN_PID: This state runs the PID calculation    
                    when RUN_PID => 
                
                    if multicycle_cntr = 10 then 
                        multicycle_cntr <= 0; 
                        state <= COMPLETE; 
                    else 
					-- Convert inputs and gains to signed types and shift left by SCALE_BITS
					setp_int <= resize(setpoint, ACC_WIDTH) sll SCALE_BITS;
					fb_int   <= resize(feedback, ACC_WIDTH) sll SCALE_BITS;
	
					Kp <= pid_cntrl.kp; 
					Ki <= pid_cntrl.ki; 
					Kd <= pid_cntrl.kd; 
	
					-- Calculate raw error
					--raw_error <= setp_int - fb_int;
	                error <= setpoint - feedback;
	
					-- Clamp error
					--if raw_error > ERROR_MAX then
					--	clamped_error <= ERROR_MAX;
					--elsif raw_error < ERROR_MIN then
					--	clamped_error <= ERROR_MIN;
					--else
					--	clamped_error <= raw_error;
					--end if;
	
					--error <= clamped_error;
	
					-- Integral update with clamp
					next_integral <= integral + error;
					if next_integral > INTEGRAL_MAX then
						integral <= INTEGRAL_MAX;
					elsif next_integral < INTEGRAL_MIN then
						integral <= INTEGRAL_MIN;
					else
						integral <= next_integral;
					end if;
	
					-- Derivative error = current - previous
					d_error <= clamped_error - prev_error;
					prev_error <= clamped_error;
	
					-- Calculate P, I, D terms
					if pid_cntrl.park = '1' then 
					   p_term_full <= (resize(clamped_error, PROD_WIDTH) * resize(Kp, PROD_WIDTH)) sll 2; 
					else 
                       --error is format is Q0.19 format (1sign, 0 integer, 19 fractional bits) range -1 to 0.99999
                       --kp is Q8.32 format (1sign, 7 integer, 24 fractional bits) range -128 to 127.99999
                       --shift by 
                       
                       --Q8.32
                       p_term <= fixed_mul(kp, error, 1);

					
					   p_term_full <= resize(clamped_error, PROD_WIDTH) * resize(Kp, PROD_WIDTH);
					end if; 
					
					--i_term <= resize(integral, PROD_WIDTH) * resize(Ki, PROD_WIDTH);
					i_term <= fixed_mul(ki,integral,1);
					
					
					d_term <= resize(d_error, PROD_WIDTH) * resize(Kd, PROD_WIDTH);
	
					-- Clamp derivative term
					if d_term > DERIV_MAX then
						d_term <= DERIV_MAX;
					elsif d_term < DERIV_MIN then
						d_term <= DERIV_MIN;
					end if;
	
					-- Sum all terms
					control_sum <= p_term + i_term; -- + d_term;
	
					-- Scale output down by shifting right by SCALE_BITS
					control_scaled <= control_sum; --resize(control_sum(PROD_WIDTH-1 downto SCALE_BITS), ACC_WIDTH);
	
					-- Clamp output to DATA_WIDTH range
					--if control_scaled > to_signed(MAX_INPUT, ACC_WIDTH) then
					--	control_sat <= to_signed(MAX_INPUT, DATA_WIDTH);
					--elsif control_scaled < to_signed(MIN_INPUT, ACC_WIDTH) then
					--	control_sat <= to_signed(MIN_INPUT, DATA_WIDTH);
					--else
					--	control_sat <= resize(control_scaled, DATA_WIDTH);
				    --end if; 
				    
				    --Increment multicycle counter 
				    multicycle_cntr <= multicycle_cntr + 1; 
                end if;
                
                --COMPLETE: PID calculation has completed, latch the control output
                when COMPLETE => 
                    done <= '1'; 
                    control_out <= control_sum(31 downto 12); --control_scaled; --control_sat; 
                    state <= IDLE; 
         
                when others => 
                    state <= IDLE; 
            end case; 
            end if;
        end if;
    end process;
    
end architecture;