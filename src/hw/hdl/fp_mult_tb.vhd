library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;


entity tb_fp_mult is
end entity;

architecture sim of tb_fp_mult is

    -- Clock and reset
    signal clk : std_logic := '0';

    -- AXIS input A
    signal s_axis_a_tvalid : std_logic := '0';
    signal s_axis_a_tready : std_logic;
    signal s_axis_a_tdata  : std_logic_vector(31 downto 0);

    -- AXIS input B
    signal s_axis_b_tvalid : std_logic := '0';
    signal s_axis_b_tready : std_logic;
    signal s_axis_b_tdata  : std_logic_vector(31 downto 0);

    -- AXIS output
    signal m_axis_result_tvalid : std_logic;
    signal m_axis_result_tready : std_logic := '1';
    signal m_axis_result_tdata  : std_logic_vector(31 downto 0);






begin

    -- Clock process
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- DUT instantiation
    uut: entity work.fp_mult
        port map (
            aclk                => clk,
            s_axis_a_tvalid     => '1',
            s_axis_a_tready     => s_axis_a_tready,
            s_axis_a_tdata      => s_axis_a_tdata,
            s_axis_b_tvalid     => '1',
            s_axis_b_tready     => s_axis_b_tready,
            s_axis_b_tdata      => s_axis_b_tdata,
            m_axis_result_tvalid => m_axis_result_tvalid,
            m_axis_result_tready => m_axis_result_tready,
            m_axis_result_tdata  => m_axis_result_tdata
        );

    -- Stimulus process
    stimulus: process
    begin
        wait for 20 ns;

        -- Test case 1: 3.25 * -2.0 = -6.5
        s_axis_a_tdata  <= x"40490FDB";  -- 3.14159
        s_axis_b_tdata  <= x"BFC00000"; -- -1.5
        s_axis_a_tvalid <= '1';
        s_axis_b_tvalid <= '1';

        -- Wait for one clock and deassert
        --wait until rising_edge(clk);
        --s_axis_a_tvalid <= '0';
        --s_axis_b_tvalid <= '0';

        -- Wait for result
        --wait until m_axis_result_tvalid = '1';
         
        wait for 500 ns;
        
          -- Test case 1: 3.25 * -2.0 = -6.5
        s_axis_a_tdata  <= x"50490FDB";  -- 3.14159
        s_axis_b_tdata  <= x"BFC40000"; -- -1.5
        
        wait for 500 ns;
        
          -- Test case 1: 3.25 * -2.0 = -6.5
        s_axis_a_tdata  <= x"70490FDB";  -- 3.14159
        s_axis_b_tdata  <= x"BFC40000"; -- -1.5              
        
        wait for 1000 ns;

        assert false report "End of Simulation" severity failure;
    end process;

end architecture;
