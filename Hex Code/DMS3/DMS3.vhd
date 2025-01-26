--- History
--- 3.0 - v1.0 chip code
---   Initial release
--- 3.1 - unreleased (internal testing only)
---   41/61 fix for dodgy dvd-rips
---   addr_reg(16) race condition fixed in flash statemachine
--- 3.2 - unreleased (internal testing only)
---   PSX browser boot fix and initial v8 support
--- 3.3 - v2.0 chip code
---   v8 boot from browser added
---   Rewrite of flash S/M, some register placement tweaks
---     to improve off-chip performance
---   Fallback kernel patch len is no longer hardcoded
---   Kernel patch S/M tweaked (uses a seperate pattern
---     detector - fMax improvement for -F speed grade

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity dms is
    port(
        iop_clk, reset_n : in std_logic;
        bios_d   : inout std_logic_vector(7 downto 0);
        bios_ce_n : inout std_logic;
        bios_oe_n : in std_logic;

        cdvd_d          : inout std_logic_vector(7 downto 0);
        cdvd_strobe_n   : in std_logic;

        eject   : in std_logic;
        scex    : inout std_logic;

        flash_a : out std_logic_vector(16 downto 0);
        flash_d : inout std_logic_vector(7 downto 0);
        flash_ce_n, flash_we_n, flash_oe_n : out std_logic;

        debug : out std_logic_vector(11 downto 1)
        );
end entity;

architecture rtl of dms is
signal clk : std_logic;

signal region : std_logic_vector(1 downto 0);
signal mode : std_logic_vector(1 downto 0);
signal mode_is_set : std_logic;
signal cdvd_sm_go : std_logic;

signal cold_boot : std_logic;

signal kp_len : std_logic_vector(15 downto 0);
signal eject_n_sync : std_logic;

signal bios_d_last_z2, bios_d_last_z3, bios_d_last, bios_d_sync : std_logic_vector(7 downto 0);

signal bios_oe_n_fall, bios_oe_n_rise, bios_ce_n_fall, bios_ce_n_fall_delayed, bios_ce_n_rise, bs_fall, bs_rise : std_logic;
signal bios_oe_n_last, bios_oe_n_sync, bios_ce_n_last, bios_ce_n_sync : std_logic;

type states is (sync_wait, reset_go, check_upgrade_block, snarf_kp_len_lsb, snarf_kp_len_msb, k_w8, k_w9, k_p0, k_p0_r, k_p0_end, region_sel, region_sel_r, eeload_0, mode_sel, mode_sel_r, psx_w0, psx_w1, psx_w2, psx_w3, psx_w4, psx_p0, bios_reg_init, bios_reg_idle, bios_reg_select_wait, bios_reg_select_read, bios_reg_selected, bios_reg_read_wait, bios_reg_write_wait, bios_reg_write_wait_relax, idle);
signal state : states;
signal dout : std_logic_vector(7 downto 0);
signal doe : std_logic;

signal loop_instruction_skip_counter : std_logic_vector(7 downto 0);
signal cycle_timer : std_logic_vector(7 downto 0);

signal is_read : std_logic;

signal k_flash_a : std_logic_vector(15 downto 0);
signal upgrade_valid : std_logic;

type reset_states is (rm0, rm1, rm2, rm3, rm4, rm5, rm6, rm7, rm8, rm9, rm10, rm11, rm12, rm13, rm14, rm15, rtrip);
signal sync_state, reset_state_1 : reset_states;
signal sync_trip, reset_trip_1 : std_logic;
signal reset_counter : std_logic_vector(3 downto 0);
signal reset_counter_clr : std_logic;

type psxboot_states is (ps0, ps1, ps2, ps3, ps4, ps5, ps6, ps7, pstrip);
signal psxboot_state : psxboot_states;
signal psxboot_trip : std_logic;

signal addr_reg : std_logic_vector(16 downto 0);
--signal data_reg : std_logic_vector(7 downto 0);
signal cmd_reg : std_logic_vector(7 downto 0);
signal lock_reg : std_logic_vector(15 downto 0);
signal stat_reg : std_logic_vector(7 downto 0);

signal reg_we : std_logic;
signal reg_sel, reg_din, reg_dout : std_logic_vector(7 downto 0);

constant lfsr_initv : std_logic_vector(15 downto 0) := X"d532";
signal lfsr, lfsr_next : std_logic_vector(15 downto 0);
signal cipher : std_logic_vector(7 downto 0);

signal reg_iface_owns_flash : std_logic;

signal flash_din_reg, flash_dout_reg, flash_data_reg : std_logic_vector(7 downto 0);
signal i_flash_oe_n, i_flash_ce_n, i_flash_we_n : std_logic;
signal i_flash_a : std_logic_vector(16 downto 0);
signal flash_req, flash_busy : std_logic;

type flash_states is (idle, reset, read, read_a, read_r, unlock_1, unlock_1_a, unlock_1_r, unlock_2, unlock_2_a, unlock_2_r, program_1, program_1_a, program_1_r, program_2, program_2_a, program_2_r, sector_erase_1, sector_erase_1_a, sector_erase_1_r, sector_erase_2, sector_erase_2_a, sector_erase_2_r, sector_erase_3, sector_erase_3_a, sector_erase_3_r, sector_erase_4, sector_erase_4_a, sector_erase_4_r);
signal flash_state : flash_states;

type psxauth_states is (init, pa0, pa1, pa2, pa3, pa4, idle, sleep);
signal psxauth_state : psxauth_states;

signal cdvd_reset_n : std_logic;
signal cdvd_cs, cdvd_cs_rise : std_logic;
signal cdvd_cs_z : std_logic_vector(3 downto 0);
signal cdvd_d_sync, cdvd_d_last, cdvd_d_last_1, cdvd_d_to_match : std_logic_vector(7 downto 0);
signal cdvd_matched_0a01e00c, cdvd_matched_01000c0a, cdvd_matched_034401, cdvd_matched_00c2, cdvd_matched_4100, cdvd_matched_10f7, cdvd_matched_faffff : std_logic;
signal cdvd_doe : std_logic;
signal cdvd_dout : std_logic_vector(7 downto 0);


signal scex_carrier_counter : std_logic_vector(11 downto 0);
signal scex_carrier_max : std_logic_vector(11 downto 0); -- := X"91d";
signal scex_carrier, scex_bit, scex_out : std_logic;
signal sub_bit_count : std_logic_vector(7 downto 0);
signal scex_counter : std_logic_vector(5 downto 0);

signal scex_strings_left, scex_gen_count : std_logic_vector(7 downto 0);

signal scex_running, scex_go : std_logic;

constant FPGA_REV_MAJOR : std_logic_vector(3 downto 0) := X"3";
constant FPGA_REV_MINOR : std_logic_vector(3 downto 0) := X"9";

begin

    clk <= iop_clk;
    bios_ce_n <= 'Z';

    lfsr_next(0) <= lfsr(15) xor lfsr(14) xor lfsr(12) xor lfsr(10) xor lfsr(7) xor lfsr(5) xor lfsr(2) xor lfsr(0);
    lfsr_next(15 downto 1) <= lfsr(14 downto 0);

    cipher <= lfsr(7 downto 0);

    bios_oe_n_fall <= '1' when bios_oe_n_last = '1' and bios_oe_n_sync = '0' else '0';
    bios_oe_n_rise <= '1' when bios_oe_n_last = '0' and bios_oe_n_sync = '1' else '0';

    bios_ce_n_fall <= '1' when bios_ce_n_last = '1' and bios_ce_n_sync = '0' else '0';
    bios_ce_n_rise <= '1' when bios_ce_n_last = '0' and bios_ce_n_sync = '1' else '0';

    bs_fall <= '1' when bios_oe_n_fall = '1' and bios_ce_n_sync = '0' else '0';
    bs_rise <= '1' when bios_oe_n_rise = '1' and bios_ce_n_sync = '0' else '0';

    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            doe <= '0';
            dout <= (others => '0');
            state <= idle;
            bios_oe_n_sync <= '1';
            bios_oe_n_last <= '1';
            bios_ce_n_sync <= '1';
            bios_ce_n_last <= '1';
            bios_d_last_z3 <= (others => '0');
            bios_d_last_z2 <= (others => '0');
            bios_d_last <= (others => '0');
            bios_d_sync <= (others => '0');
            reg_we <= '0';
            reg_din <= (others => '0');
            reg_sel <= (others => '0');
            bios_ce_n_fall_delayed <= '0';
            is_read <= '0';
            reg_iface_owns_flash <= '0';
			loop_instruction_skip_counter <= (others => '0');
            k_flash_a <= (others => '0');
            cycle_timer <= (others => '0');
            lfsr <= lfsr_initv;
            region <= "00";
            kp_len <= (others => '0');
            eject_n_sync <= '0';
            mode <= (others => '0');
            mode_is_set <= '0';
            cdvd_sm_go <= '0';
            upgrade_valid <= '0';
            reset_counter_clr <= '0';
		elsif rising_edge(clk) then
            bios_oe_n_sync <= bios_oe_n;
            bios_oe_n_last <= bios_oe_n_sync;
            bios_ce_n_sync <= bios_ce_n;
            bios_ce_n_last <= bios_ce_n_sync;

            bios_d_sync <= bios_d;
            bios_d_last <= bios_d_sync;
            bios_d_last_z2 <= bios_d_last;
            bios_d_last_z3 <= bios_d_last_z2;

            bios_ce_n_fall_delayed <= bios_ce_n_fall;

            eject_n_sync <= eject;

            is_read <= '0';
            doe <= '0';
            reg_we <= '0';
            cdvd_sm_go <= '0';
            reset_counter_clr <= '0';
            case state is
            when sync_wait =>
                if sync_trip = '1' then
                    state <= reset_go;
                end if;
            when reset_go =>
                k_flash_a <= X"0001";
                upgrade_valid <= '1';
				loop_instruction_skip_counter <= (others => '0');
                reg_iface_owns_flash <= '0';
                lfsr <= lfsr_initv;
                mode <= "00";
                mode_is_set <= '0';
                if bs_rise = '1' then
                    state <= check_upgrade_block;
                end if;

            when check_upgrade_block =>
                if bs_rise = '1' then
                    k_flash_a <= k_flash_a + 1;
                    if flash_d = X"FF" or reset_counter >= X"4" then
                        upgrade_valid <= '0';
                    end if;
                    if eject_n_sync = '1' then
                        state <= snarf_kp_len_lsb;
                    else
                        reset_counter_clr <= '1';
                        state <= bios_reg_idle; --idle;
                    end if;
                end if;

            when snarf_kp_len_lsb =>
                if bs_rise = '1' then
                    kp_len(7 downto 0) <= flash_d xor cipher;
                    lfsr <= lfsr_next;
                    k_flash_a <= k_flash_a + 1;
                    state <= snarf_kp_len_msb;
                end if;

            when snarf_kp_len_msb =>
                if bs_rise = '1' then
                    kp_len(15 downto 8) <= flash_d xor cipher;
                    lfsr <= lfsr_next;
                    k_flash_a <= k_flash_a + 1;
                    state <= k_p0;
                end if;

            when k_p0 =>
                doe <= '1';
                if bs_fall = '1' then
                    dout <= flash_d xor cipher;
                    lfsr <= lfsr_next;
                    k_flash_a <= k_flash_a + 1;
                    if k_flash_a(11 downto 0) = kp_len(11 downto 0) then -- we're done
                        state <= k_p0_end;
 --                   elsif k_flash_a(1 downto 0) = "11" then -- relies on the patch being aligned 4 !!!!!
 --                       state <= k_p0_r;
                    else
                        state <= k_p0;
                    end if;
                end if;

            when k_p0_end =>
                doe <= '1';
                if bs_rise = '1' then
                    state <= region_sel;
                end if;

            when region_sel =>
                if bios_ce_n_fall_delayed = '1' and bios_oe_n_sync = '1' then
                    region <= bios_d_sync(1 downto 0);
                    dout <= flash_d xor cipher;
                    lfsr <= lfsr_next;
                    k_flash_a <= k_flash_a + 1;
                    state <= region_sel_r;
                end if;

            when region_sel_r =>
                if bios_ce_n_rise = '1' then --or bs_fall = '1' then    -- workaround for read - store CE issue
                    state <= eeload_0;
                end if;

            when eeload_0 =>
                doe <= '1';
                if bs_rise = '1' then
                    dout <= flash_d xor cipher;
                    lfsr <= lfsr_next;
                    k_flash_a <= k_flash_a + 1;
                    state <= eeload_0;
                elsif bios_ce_n_fall_delayed = '1' and bios_oe_n_sync = '1' then
                    state <= mode_sel;
                end if;

            when mode_sel =>
                if bios_ce_n_fall_delayed = '1' and bios_oe_n_sync = '1' then
                    mode <= bios_d_sync(1 downto 0);
                    mode_is_set <= '1';
                    cdvd_sm_go <= '1';
                    state <= mode_sel_r;
                end if;

            when mode_sel_r =>
                if bios_ce_n_rise = '1' then --or bs_fall = '1' then
                    reset_counter_clr <= '1';
                    case mode is
                    when "01" => state <= psx_w0;
                    when others => state <= bios_reg_idle;
                    end case;
                end if;

            when psx_w0 =>
                loop_instruction_skip_counter <= X"00";
                if bs_rise = '1' then
                    if bios_d_last = X"35" then
                        state <= psx_w1;
                    else
                        state <= psx_w0;
                    end if;
                end if;
            when psx_w1 =>
                if bs_rise = '1' then
                    if bios_d_last = X"2e" then
                        state <= psx_w2;
                    else
                        state <= psx_w0;
                    end if;
                end if;
            when psx_w2 =>
                if bs_rise = '1' then
                    if bios_d_last = X"30" then
                        state <= psx_w3;
                    else
                        state <= psx_w0;
                    end if;
                end if;
            when psx_w3 =>
                if bs_rise = '1' then
                    if bios_d_last = X"20" then
                        state <= psx_w4;
                    else
                        state <= psx_w0;
                    end if;
                end if;

            when psx_w4 =>
                if bs_rise = '1' then
                    loop_instruction_skip_counter <= loop_instruction_skip_counter + 1;
                    if loop_instruction_skip_counter = X"08" then
                        state <= psx_p0;
                    else
                        state <= psx_w4;
                    end if;
                end if;

            when psx_p0 =>
                doe <= '1';
                dout <= X"41";
                if bs_rise = '1' then
                    state <= idle;
                end if;

            when bios_reg_idle =>
                reg_iface_owns_flash <= '1';
                cycle_timer <= (others => '0');
                if bios_ce_n_fall_delayed = '1' and bios_oe_n_sync = '1' then
                    cycle_timer <= cycle_timer + 1;
                    state <= bios_reg_select_wait;
                end if;

            when bios_reg_select_wait =>
                cycle_timer <= cycle_timer + 1;
                if cycle_timer = X"F" then
                    state <= bios_reg_selected;
                end if;
                if bios_d_last = bios_d_sync and bios_d_last = bios_d_last_z2 then
                    reg_sel <= bios_d_last;
                end if;

            when bios_reg_selected =>
                doe <= '1';
                dout <= reg_dout;
                cycle_timer <= (others => '0');
                if bios_ce_n_fall_delayed = '1' then
                    cycle_timer <= cycle_timer + 1;
                    if bios_oe_n_sync = '0' then
                        state <= bios_reg_read_wait;
                    else
                        state <= bios_reg_write_wait;
                    end if;
                end if;

            when bios_reg_read_wait =>
                doe <= '1';
                cycle_timer <= cycle_timer + 1;
                if cycle_timer = X"a" then
                    state <= bios_reg_idle;
                end if;

            when bios_reg_write_wait =>
                cycle_timer <= cycle_timer + 1;
                if cycle_timer = X"F" then
                    state <= bios_reg_idle;
                end if;
                if bios_d_last = bios_d_sync and bios_d_last = bios_d_last_z2 then
                    reg_we <= '1';
                    reg_din <= bios_d_last;
                    state <= bios_reg_write_wait_relax;
                end if;

            when bios_reg_write_wait_relax =>
                cycle_timer <= cycle_timer + 1;
                if cycle_timer = X"F" then
                    state <= bios_reg_idle;
                end if;

            when idle =>
--                reset_counter_clr <= '1';
                doe <= '0';
                state <= idle;

            when others =>
                doe <= '0';
                state <= idle;
            end case;

            if reset_trip_1 = '1' then
                state <= sync_wait;
            end if;

        end if;
    end process;

    bios_d <= dout when doe = '1' and bios_oe_n = '0' and bios_ce_n = '0' else "ZZZZZZZZ";

    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            addr_reg <= (others => '0');
            cmd_reg <= (others => '0');
			lock_reg <= (others => '0');
            flash_data_reg <= (others => '0');
            flash_req <= '0';
        elsif rising_edge(clk) then
            flash_req <= '0';
            if reset_trip_1 = '1' then
                addr_reg <= (others => '0');
                cmd_reg <= (others => '0');
                lock_reg <= (others => '0');
                flash_data_reg <= (others => '0');
            elsif reg_we = '1' then
                case reg_sel(3 downto 0) is
                when X"0" =>
                    addr_reg(7 downto 0) <= reg_din;
                when X"1" =>
                    addr_reg(15 downto 8) <= reg_din;
                when X"2" =>
                    addr_reg(16) <= reg_din(0);
--                when X"3" =>
--                    addr_reg(31 downto 24) <= reg_din;
                when X"4" =>
                    flash_data_reg <= reg_din;
                when X"6" =>
                    flash_req <= '1';
                    cmd_reg <= reg_din;

                when X"C" =>
                    lock_reg(7 downto 0) <= reg_din;
                when X"D" =>
                    lock_reg(15 downto 8) <= reg_din;
                when others =>
                end case;
            end if;
        end if;
    end process;

    with reg_sel(3 downto 0) select
        reg_dout <=     --addr_reg(7 downto 0) when X"0",
                        --addr_reg(15 downto 8) when X"1",
                        --addr_reg(23 downto 16) when X"2",
                        --addr_reg(31 downto 24) when X"3",
                        --flash_data_reg when X"4",
                        flash_din_reg when X"5",
                        --cmd_reg when X"6",
                        stat_reg when X"7",
--                        lock_reg(7 downto 0) when X"C",
--                        lock_reg(15 downto 8) when X"D",
                        FPGA_REV_MAJOR & FPGA_REV_MINOR when others; --X"A",

--                        reg_sel when others;

    stat_reg <= "0000000" & flash_busy;

    process(clk, reset_n) is
    variable count : std_logic_vector(2 downto 0);
    begin
        if reset_n = '0' then
            flash_busy <= '0';
            flash_state <= idle;
            count := "000";
            flash_din_reg <= (others => '0');
            flash_dout_reg <= (others => '0');
            i_flash_a <= (others => '0');
            i_flash_ce_n <= '1';
            i_flash_oe_n <= '1';
            i_flash_we_n <= '1';
        elsif rising_edge(clk) then
            i_flash_ce_n <= '1';
            i_flash_oe_n <= '1';
            i_flash_we_n <= '1';
            i_flash_a <= addr_reg(16 downto 0);
            flash_busy <= '0';
            case flash_state is
            when idle =>
                count := "000";

                if flash_req = '1' and lock_reg = X"471e" then
                    flash_busy <= '1';

                    case cmd_reg is
                    when X"00" =>
                        flash_state <= read;
                    when X"01" =>
                        if addr_reg(16) = '1' then
                            flash_state <= unlock_1;
                        else
                            flash_state <= idle;
                        end if;
                    when X"02" =>
                        if addr_reg(16) = '1' then
                            flash_state <= unlock_1;
                        else
                            flash_state <= idle;
                        end if;
                    when X"03" =>
                        flash_state <= reset;
                    when others =>
                        flash_state <= idle;
                    end case;

                end if;

            when read =>
                i_flash_a <= addr_reg(16 downto 0);
                flash_busy <= '1';
                flash_state <= read_a;

            when read_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '0';
                i_flash_we_n <= '1';
                i_flash_a <= addr_reg(16 downto 0);
                flash_busy <= '1';
                if count = "111" then
                    flash_din_reg <= flash_d;
                    flash_state <= read_r;
                end if;
                count := count + 1;

            when read_r =>
                i_flash_a <= addr_reg(16 downto 0);
                flash_busy <= '1';
                if count = "111" then
                    flash_state <= idle;
                end if;
                count := count + 1;

            when unlock_1 =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"AA";
                flash_state <= unlock_1_a;

            when unlock_1_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"AA";
                if count = "111" then
                    flash_state <= unlock_1_r;
                end if;
                count := count + 1;

            when unlock_1_r =>
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"AA";
                flash_busy <= '1';
                if count = "111" then
                    flash_state <= unlock_2;
                end if;
                count := count + 1;

            when unlock_2 =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"2AAA";
                flash_dout_reg <= X"55";
                flash_state <= unlock_2_a;

            when unlock_2_a =>

                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '0' & X"2AAA";
                flash_dout_reg <= X"55";
                if count = "111" then
                    flash_state <= unlock_2_r;
                end if;
                count := count + 1;

            when unlock_2_r =>
                i_flash_a <= '0' & X"2AAA";
                flash_dout_reg <= X"55";
                flash_busy <= '1';
                if count = "111" then
                    case cmd_reg is
                    when X"01" =>
                        flash_state <= program_1;
                    when X"02" =>
                        flash_state <= sector_erase_1;
                    when others =>
                        flash_state <= reset;
                    end case;
                end if;
                count := count + 1;

            when program_1 =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"A0";
                flash_state <= program_1_a;

            when program_1_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"A0";
                if count = "111" then
                    flash_state <= program_1_r;
                end if;
                count := count + 1;

            when program_1_r =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"A0";
                flash_busy <= '1';
                if count = "111" then
                    flash_state <= program_2;
                end if;
                count := count + 1;

            when program_2 =>
                flash_state <= program_2_a;
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= flash_data_reg;

            when program_2_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= flash_data_reg;
                if count = "111" then
                    flash_state <= program_2_r;
                end if;
                count := count + 1;

            when program_2_r =>
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= flash_data_reg;
                if count = "111" then
                    flash_state <= idle;
                end if;
                count := count + 1;

            when sector_erase_1 =>
                flash_state <= sector_erase_1_a;
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"80";

            when sector_erase_1_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"80";
                if count = "111" then
                    flash_state <= sector_erase_1_r;
                end if;
                count := count + 1;

            when sector_erase_1_r =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"80";
                if count = "111" then
                    flash_state <= sector_erase_2;
                end if;
                count := count + 1;

            when sector_erase_2 =>
                flash_state <= sector_erase_2_a;
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"AA";

            when sector_erase_2_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"AA";
                if count = "111" then
                    flash_state <= sector_erase_2_r;
                end if;
                count := count + 1;

            when sector_erase_2_r =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"5555";
                flash_dout_reg <= X"AA";
                if count = "111" then
                    flash_state <= sector_erase_3;
                end if;
                count := count + 1;

            when sector_erase_3 =>
                flash_state <= sector_erase_3_a;
                flash_busy <= '1';
                i_flash_a <= '0' & X"2AAA";
                flash_dout_reg <= X"55";

            when sector_erase_3_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '0' & X"2AAA";
                flash_dout_reg <= X"55";
                if count = "111" then
                    flash_state <= sector_erase_3_r;
                end if;
                count := count + 1;

            when sector_erase_3_r =>
                flash_busy <= '1';
                i_flash_a <= '0' & X"2AAA";
                flash_dout_reg <= X"55";
                if count = "111" then
                    flash_state <= sector_erase_4;
                end if;
                count := count + 1;

            when sector_erase_4 =>
                flash_state <= sector_erase_4_a;
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= X"30";

            when sector_erase_4_a =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= X"30";
                if count = "111" then
                    flash_state <= sector_erase_4_r;
                end if;
                count := count + 1;

            when sector_erase_4_r =>
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= X"30";
                if count = "111" then
                    flash_state <= idle;
                end if;
                count := count + 1;

            when reset =>
                i_flash_ce_n <= '0';
                i_flash_oe_n <= '1';
                i_flash_we_n <= '0';
                flash_busy <= '1';
                i_flash_a <= '1' & addr_reg(15 downto 0); --!!!
                flash_dout_reg <= X"F0";
                if count = "111" then
                    flash_state <= idle;
                end if;
                count := count + 1;

            when others =>
  			    flash_state <= idle;
            end case;

        end if;
    end process;

    process(reg_iface_owns_flash, flash_dout_reg, i_flash_oe_n, i_flash_ce_n, i_flash_we_n, i_flash_a, k_flash_a, upgrade_valid) is
    begin
        if reg_iface_owns_flash = '1' then
        	if i_flash_oe_n = '1' then
    			flash_d <= flash_dout_reg;
			else
				flash_d <= (others => 'Z');
			end if;
            flash_a <= i_flash_a;
        else
            flash_d <= (others => 'Z');
            flash_a <= upgrade_valid & k_flash_a;
        end if;
    end process;

    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            flash_oe_n <= '1';
            flash_ce_n <= '1';
            flash_we_n <= '1';
        elsif rising_edge(clk) then
            if reg_iface_owns_flash = '1' then
                flash_oe_n <= i_flash_oe_n;
                flash_ce_n <= i_flash_ce_n;
                flash_we_n <= i_flash_we_n;
            else
                flash_oe_n <= '0';
                flash_ce_n <= '0';
                flash_we_n <= '1';
            end if;
        end if;
    end process;


    cdvd_reset_n <= '1' when reset_n = '1' and eject_n_sync = '1' and mode(1) = '1' else '0';
    cdvd_d <= cdvd_dout when cdvd_doe = '1' else (others => 'Z');
    cdvd_cs <= cdvd_strobe_n;

    process(clk, cdvd_reset_n) is
    begin
        if cdvd_reset_n = '0' then
            cdvd_cs_z <= (others => '1');
        elsif rising_edge(clk) then
            cdvd_cs_z <= cdvd_cs_z(2 downto 0) & cdvd_cs;
        end if;
    end process;

--     process(cdvd_cs, cdvd_reset_n) is
--     begin
--         if cdvd_reset_n = '0' then
--             cdvd_d_sync <= (others => '0');
--         elsif rising_edge(cdvd_cs) then
--             cdvd_d_sync <= cdvd_d;
--         end if;
--     end process;

    process(clk, cdvd_reset_n) is
    begin
        if cdvd_reset_n = '0' then
            cdvd_d_last <= (others => '0');
            cdvd_d_last_1 <= (others => '0');
            cdvd_d_sync <= (others => '0');
        elsif rising_edge(clk) then
            cdvd_d_sync <= cdvd_d;
            cdvd_d_last <= cdvd_d_sync;
            cdvd_d_last_1 <= cdvd_d_last;
        end if;
    end process;

    cdvd_cs_rise <= '1' when cdvd_cs_z = "0001" else '0';
--    cdvd_cs_fall <= '1' when cdvd_cs_z4 = '1' and cdvd_cs_z3 = '0' else '0';
    cdvd_d_to_match <= cdvd_d_last;



    cdvd_patchers: block is
        signal cdvd_state, cdvd_state_plus_1 : std_logic_vector(3 downto 0);
        signal cdvd_cd_state, cdvd_cd_state_plus_1 : std_logic_vector(3 downto 0);
        signal cdvd_dvd_state, cdvd_dvd_state_plus_1 : std_logic_vector(3 downto 0);
        signal cdvd_auth_state : std_logic_vector(3 downto 0);
        signal cdvd_cd_kick, cdvd_cd_ack, cdvd_dvd_kick, cdvd_dvd_ack, cdvd_auth_kick : std_logic;
        signal cdvd_auth_active : std_logic;
        signal cdvd_cd_doe, cdvd_dvd_doe : std_logic;
        signal cdvd_bt_state : std_logic_vector(1 downto 0);
        signal cdvd_bt_active, cdvd_bt_doe : std_logic;
        signal cdvd_round : std_logic;

        signal cdvd_patch_a : std_logic_vector(6 downto 0);
        signal cdvd_patch_d : std_logic_vector(7 downto 0);

    begin

        cdvd_state_plus_1 <= cdvd_state + 1;
        cdvd_cd_state_plus_1 <= cdvd_cd_state + 1;
        cdvd_dvd_state_plus_1 <= cdvd_dvd_state + 1;

        cdvd_master_sm: process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                cdvd_state <= (others => '0');
                cdvd_cd_kick <= '0';
                cdvd_dvd_kick <= '0';
                cdvd_auth_kick <= '0';
                cdvd_bt_active <= '0';
                cdvd_round <= '0';
            elsif rising_edge(clk) then
                cdvd_cd_kick <= '0';
                cdvd_dvd_kick <= '0';
                cdvd_auth_kick <= '0';
                cdvd_bt_active <= '0';

                case cdvd_state is
                when "0000" =>
                    cdvd_bt_active <= '1';
                    if cdvd_matched_034401 = '1' then
                        cdvd_state <= cdvd_state_plus_1;
                    end if;

                when "0001" =>
                    if cdvd_matched_00c2 = '1' then
                        cdvd_state <= cdvd_state_plus_1;
                    end if;

                when "0010" =>
                    if cdvd_round = '1' then
                        cdvd_state <= "0101";
                    elsif cdvd_cs_rise = '1' then
                        if cdvd_d_sync = X"1e" then
                            cdvd_dvd_kick <= '1';
                        else
                            cdvd_cd_kick <= '1';
                        end if;
                        cdvd_state <= cdvd_state_plus_1;
                    end if;

                when "0011" =>
                    cdvd_state <= cdvd_state_plus_1;

                when "0100" =>
                    if cdvd_cd_ack = '1' or cdvd_dvd_ack = '1' then
                        cdvd_state <= cdvd_state_plus_1;
                    end if;

                when "0101" =>
                    if cdvd_matched_faffff = '1' then
                        cdvd_state <= cdvd_state_plus_1;
                    end if;
                when "0110" =>
                    if cdvd_matched_faffff = '1' then
                        cdvd_state <= cdvd_state_plus_1;
                    end if;
                when "0111" =>
                    if cdvd_matched_faffff = '1' then
                        cdvd_state <= cdvd_state_plus_1;
                    end if;
                when "1000" =>
                    cdvd_auth_kick <= '1';
                    cdvd_state <= cdvd_state_plus_1;

                when "1001" =>
                    --cdvd_state <= "1001";
                    cdvd_state <= cdvd_state_plus_1;

                when "1010" =>
                    if cdvd_auth_active = '0' then
                        cdvd_round <= '1';
                        cdvd_state <= "0000";
                    end if;

                when others =>
                    cdvd_state <= (others => '0');
                end case;
            end if;
        end process;

        cdvd_auth_sm: process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                cdvd_auth_active <= '0';
                cdvd_auth_state <= (others => '0');
            elsif rising_edge(clk) then
                if cdvd_auth_active = '0' then
                    if cdvd_auth_kick = '1' then
                        cdvd_auth_active <= '1';
                    end if;
                else
                    if cdvd_cs_rise = '1' then
                        cdvd_auth_state <= cdvd_auth_state + '1';
                        if cdvd_auth_state = "1111" then
                            cdvd_auth_active <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end process;

        cdvd_cd_sm: process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                cdvd_cd_doe <= '0';
                cdvd_cd_ack <= '0';
                cdvd_cd_state <= (others => '0');
            elsif rising_edge(clk) then
                cdvd_cd_ack <= '0';
                cdvd_cd_doe <= '0';

                case cdvd_cd_state is
                when "0000" =>
                    if cdvd_cd_kick = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "0001" =>
                    if cdvd_matched_4100 = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;

                when "0010" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "0011" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "0100" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "0101" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "0110" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "0111" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "1000" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "1001" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "1010" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "1011" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                when "1100" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;

                when "1101" =>
                    cdvd_cd_doe <= '1';
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;

                when "1110" =>
                    if cdvd_cs_rise = '1' then
                        if cdvd_d_sync = X"21" then
                            cdvd_cd_state <= "0000";
                            cdvd_cd_ack <= '1';
                        else
                            cdvd_cd_state <= "0001";
                        end if;
                    end if;

                when others =>
                    if cdvd_cs_rise = '1' then
                        cdvd_cd_state <= cdvd_cd_state_plus_1;
                    end if;
                end case;
            end if;
        end process;


        cdvd_dvd_sm: process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                cdvd_dvd_doe <= '0';
                cdvd_dvd_ack <= '0';
                cdvd_dvd_state <= (others => '0');
            elsif rising_edge(clk) then
                cdvd_dvd_ack <= '0';
                cdvd_dvd_doe <= '0';

                case cdvd_dvd_state is
                when "0000" =>
                    if cdvd_dvd_kick = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "0001" =>
                    if cdvd_matched_10f7 = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;

                when "0010" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "0011" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "0100" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "0101" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "0110" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "0111" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                when "1000" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;

                when "1001" =>
                    cdvd_dvd_doe <= '1';
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;

                when "1010" =>
                    if cdvd_cs_rise = '1' then
                        if cdvd_d_sync = X"23" then
                            cdvd_dvd_state <= "0000";
                            cdvd_dvd_ack <= '1';
                        else
                            cdvd_dvd_state <= "0001";
                        end if;
                    end if;

                when others =>
                    if cdvd_cs_rise = '1' then
                        cdvd_dvd_state <= cdvd_dvd_state_plus_1;
                    end if;
                end case;
            end if;
        end process;

        book_type: process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                cdvd_bt_doe <= '0';
                cdvd_bt_state <= (others => '0');
            elsif rising_edge(clk) then
                cdvd_bt_doe <= '0';

                case cdvd_bt_state is
                when "00" =>
                    if cdvd_bt_active = '1' then
                        if cdvd_matched_01000c0a = '1' then
                            cdvd_bt_state <= "10";
                        end if;
                        if cdvd_matched_0a01e00c = '1' then
                            cdvd_bt_state <= "01";
                        end if;
                    end if;

                when "01" =>
                    if cdvd_cs_rise = '1' then
                        cdvd_bt_state <= "10";
                    end if;

                when "10" =>
                    cdvd_bt_doe <= '1';
                    if cdvd_cs_rise = '1' then
                        cdvd_bt_state <= "00";
                    end if;

                when others =>
                    if cdvd_cs_rise = '1' then
                        cdvd_bt_state <= "00";
                    end if;

                end case;
            end if;
        end process;

        cdvd_output: process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                cdvd_doe <= '0';
                cdvd_dout <= (others => '0');
            elsif rising_edge(clk) then
                cdvd_doe <= cdvd_cd_doe or cdvd_dvd_doe or cdvd_auth_active or cdvd_bt_doe;
                cdvd_dout <= (others => '-');
                if cdvd_cd_doe = '1' then
                    cdvd_dout <= X"91";
                end if;
                if cdvd_dvd_doe = '1' then
                    cdvd_dout <= X"B3";
                end if;
                if cdvd_auth_active = '1' then
                    cdvd_dout <= cdvd_patch_d;
                end if;
                if cdvd_bt_doe = '1' then
                    cdvd_dout <= X"01";
                end if;
            end if;
        end process;



        cdvd_patch_a <= cdvd_round & region & cdvd_auth_state;

        auth_rom: process(cdvd_patch_a) is
        begin
            case cdvd_patch_a is

            -- check these please!

            -- jap round 0
            when "0000000" => cdvd_patch_d <= X"47";
            when "0000001" => cdvd_patch_d <= X"07";
            when "0000010" => cdvd_patch_d <= X"f2";
            when "0000011" => cdvd_patch_d <= X"ec";

            when "0000100" => cdvd_patch_d <= X"07";
            when "0000101" => cdvd_patch_d <= X"33";
            when "0000110" => cdvd_patch_d <= X"03";
            when "0000111" => cdvd_patch_d <= X"9e";

            when "0001000" => cdvd_patch_d <= X"59";
            when "0001001" => cdvd_patch_d <= X"0f";
            when "0001010" => cdvd_patch_d <= X"51";
            when "0001011" => cdvd_patch_d <= X"0f";

            when "0001100" => cdvd_patch_d <= X"7e";
            when "0001101" => cdvd_patch_d <= X"01";
            when "0001110" => cdvd_patch_d <= X"48";
            when "0001111" => cdvd_patch_d <= X"00";


            -- us round 0
            when "0010000" => cdvd_patch_d <= X"2f"; -- BF
            when "0010001" => cdvd_patch_d <= X"af"; -- 2F
            when "0010010" => cdvd_patch_d <= X"ba"; -- 2F
            when "0010011" => cdvd_patch_d <= X"02"; -- 34

            when "0010100" => cdvd_patch_d <= X"2f"; -- 3F
            when "0010101" => cdvd_patch_d <= X"2d"; -- 3F
            when "0010110" => cdvd_patch_d <= X"2c"; -- 2F
            when "0010111" => cdvd_patch_d <= X"94"; -- 99

            when "0011000" => cdvd_patch_d <= X"2c"; -- 60
            when "0011001" => cdvd_patch_d <= X"1e"; -- 0A
            when "0011010" => cdvd_patch_d <= X"71"; -- 64
            when "0011011" => cdvd_patch_d <= X"71"; -- 0A

            when "0011100" => cdvd_patch_d <= X"1c"; -- DB
            when "0011101" => cdvd_patch_d <= X"4a"; -- 0E
            when "0011110" => cdvd_patch_d <= X"4a";
            when "0011111" => cdvd_patch_d <= X"01";

            -- pal round 0
            when "0100000" => cdvd_patch_d <= X"54";
            when "0100001" => cdvd_patch_d <= X"54";
            when "0100010" => cdvd_patch_d <= X"f3";
            when "0100011" => cdvd_patch_d <= X"db";

            when "0100100" => cdvd_patch_d <= X"15";
            when "0100101" => cdvd_patch_d <= X"2f";
            when "0100110" => cdvd_patch_d <= X"36";
            when "0100111" => cdvd_patch_d <= X"a9";

            when "0101000" => cdvd_patch_d <= X"6c";
            when "0101001" => cdvd_patch_d <= X"0f";
            when "0101010" => cdvd_patch_d <= X"34";
            when "0101011" => cdvd_patch_d <= X"34";

            when "0101100" => cdvd_patch_d <= X"0f";
            when "0101101" => cdvd_patch_d <= X"21";
            when "0101110" => cdvd_patch_d <= X"21";
            when "0101111" => cdvd_patch_d <= X"01";


            -- jap round 1
            when "1000000" => cdvd_patch_d <= X"a8";
            when "1000001" => cdvd_patch_d <= X"e8";
            when "1000010" => cdvd_patch_d <= X"2a";
            when "1000011" => cdvd_patch_d <= X"e8";

            when "1000100" => cdvd_patch_d <= X"28";
            when "1000101" => cdvd_patch_d <= X"18";
            when "1000110" => cdvd_patch_d <= X"28";
            when "1000111" => cdvd_patch_d <= X"8d";

            when "1001000" => cdvd_patch_d <= X"32";
            when "1001001" => cdvd_patch_d <= X"11";
            when "1001010" => cdvd_patch_d <= X"9f";
            when "1001011" => cdvd_patch_d <= X"10";

            when "1001100" => cdvd_patch_d <= X"41";
            when "1001101" => cdvd_patch_d <= X"02";
            when "1001110" => cdvd_patch_d <= X"5a";
            when "1001111" => cdvd_patch_d <= X"1c";


            -- us round 1
            when "1010000" => cdvd_patch_d <= X"a7";
            when "1010001" => cdvd_patch_d <= X"27";
            when "1010010" => cdvd_patch_d <= X"30";
            when "1010011" => cdvd_patch_d <= X"27";

            when "1010100" => cdvd_patch_d <= X"27";
            when "1010101" => cdvd_patch_d <= X"2e";
            when "1010110" => cdvd_patch_d <= X"27";
            when "1010111" => cdvd_patch_d <= X"82";

            when "1011000" => cdvd_patch_d <= X"96";
            when "1011001" => cdvd_patch_d <= X"20";
            when "1011010" => cdvd_patch_d <= X"e5";
            when "1011011" => cdvd_patch_d <= X"e5";

            when "1011100" => cdvd_patch_d <= X"26";
            when "1011101" => cdvd_patch_d <= X"a6";
            when "1011110" => cdvd_patch_d <= X"a6";
            when "1011111" => cdvd_patch_d <= X"01";

            -- pal round 1
            when "1100000" => cdvd_patch_d <= X"65";
            when "1100001" => cdvd_patch_d <= X"65";
            when "1100010" => cdvd_patch_d <= X"70";
            when "1100011" => cdvd_patch_d <= X"65";

            when "1100100" => cdvd_patch_d <= X"24";
            when "1100101" => cdvd_patch_d <= X"37";
            when "1100110" => cdvd_patch_d <= X"24";
            when "1100111" => cdvd_patch_d <= X"93";

            when "1101000" => cdvd_patch_d <= X"68";
            when "1101001" => cdvd_patch_d <= X"10";
            when "1101010" => cdvd_patch_d <= X"b8";
            when "1101011" => cdvd_patch_d <= X"b8";

            when "1101100" => cdvd_patch_d <= X"0f";
            when "1101101" => cdvd_patch_d <= X"ef";
            when "1101110" => cdvd_patch_d <= X"ef";
            when "1101111" => cdvd_patch_d <= X"01";

            when others => cdvd_patch_d <= (others => '-');

            end case;

        end process;

    end block;


    cdvd_pmatch: block is
        signal top_nibble_is_0 : std_logic;

        signal d_is_01, d_is_00, d_is_0c, d_is_0a, d_is_e0, d_is_03, d_is_44, d_is_c2, d_is_41or61, d_is_21, d_is_10, d_is_f7, d_is_23, d_is_fa, d_is_ff : std_logic;
        signal match_mux_out_0a01e00c, match_mux_out_01000c0a, match_mux_out_034401, match_mux_out_00c2, match_mux_out_4100, match_mux_out_10f7, match_mux_out_faffff : std_logic;

        signal state_034401, state_034401_plus_1, state_faffff, state_faffff_plus_1, state_0a01e00c, state_0a01e00c_plus_1, state_01000c0a, state_01000c0a_plus_1 : std_logic_vector(1 downto 0);
        signal state_00c2, state_4100, state_10f7 : std_logic;

    begin

        top_nibble_is_0 <= '1' when cdvd_d_to_match(7 downto 4) = x"0" else '0';
        
        d_is_01 <= '1' when cdvd_d_to_match(3 downto 0) = X"1" and top_nibble_is_0 = '1' else '0';
        d_is_00 <= '1' when cdvd_d_to_match(3 downto 0) = X"0" and top_nibble_is_0 = '1' else '0';
        d_is_0c <= '1' when cdvd_d_to_match(3 downto 0) = X"c" and top_nibble_is_0 = '1' else '0';
        d_is_0a <= '1' when cdvd_d_to_match(3 downto 0) = X"a" and top_nibble_is_0 = '1' else '0';
        d_is_e0 <= '1' when cdvd_d_to_match = X"E0" else '0';
        d_is_03 <= '1' when cdvd_d_to_match(3 downto 0) = X"3" and top_nibble_is_0 = '1' else '0';
        d_is_44 <= '1' when cdvd_d_to_match = X"44" else '0';
        d_is_c2 <= '1' when cdvd_d_to_match = X"c2" else '0';
        d_is_41or61 <= '1' when cdvd_d_to_match(7 downto 6) = "01" and cdvd_d_to_match(4 downto 0) = "00001" else '0';
--        d_is_21 <= '1' when cdvd_d_to_match = X"21" else '0';
        d_is_10 <= '1' when cdvd_d_to_match = X"10" else '0';
        d_is_f7 <= '1' when cdvd_d_to_match = X"F7" else '0';
--        d_is_23 <= '1' when cdvd_d_to_match = X"23" else '0';
        d_is_fa <= '1' when cdvd_d_to_match = X"fa" else '0';
        d_is_ff <= '1' when cdvd_d_to_match = X"ff" else '0';


    --
    --
    --
    --
    --

        state_01000c0a_plus_1 <= state_01000c0a + 1;

        with state_01000c0a select
            match_mux_out_01000c0a <= d_is_01 when "00",
                                      d_is_00 when "01",
                                      d_is_0c when "10",
                                      d_is_0a when "11",
                                      '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_01000c0a <= (others => '0');
                cdvd_matched_01000c0a <= '0';
           elsif rising_edge(clk) then
                cdvd_matched_01000c0a <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_01000c0a = '1' then
                        if state_01000c0a = "11" then
 --                           state_0a01e00c <= (others => '0');
                            cdvd_matched_01000c0a <= '1';
                        end if;
                        state_01000c0a <= state_01000c0a_plus_1;
                    else
                        state_01000c0a <= (others => '0');
                    end if;
                end if;
            end if;
        end process;


    --
    --
    --
    --
    --


        state_0a01e00c_plus_1 <= state_0a01e00c + 1;
        with state_0a01e00c select
            match_mux_out_0a01e00c <= d_is_0a when "00",
                                      d_is_01 when "01",
                                      d_is_e0 when "10",
                                      d_is_0c when "11",
                                      '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_0a01e00c <= (others => '0');
                cdvd_matched_0a01e00c <= '0';
            elsif rising_edge(clk) then
                cdvd_matched_0a01e00c <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_0a01e00c = '1' then
                        if state_0a01e00c = "11" then
--                            state_0a01e00c <= (others => '0');
                            cdvd_matched_0a01e00c <= '1';
                        end if;
                        state_0a01e00c <= state_0a01e00c_plus_1;
                    else
                        state_0a01e00c <= (others => '0');
                    end if;
                end if;
            end if;
        end process;

    --
    --
    --
    --
    --
    --

        state_034401_plus_1 <= state_034401 + 1;

        with state_034401 select
            match_mux_out_034401 <= d_is_03 when "00",
                                    d_is_44 when "01",
                                    d_is_01 when "10",
                                    '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_034401 <= (others => '0');
                cdvd_matched_034401 <= '0';
            elsif rising_edge(clk) then
                cdvd_matched_034401 <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_034401 = '1' then
                        state_034401 <= state_034401_plus_1;
                        if state_034401 = "10" then
                            cdvd_matched_034401 <= '1';
                            state_034401 <= (others => '0');
                        end if;
                    else
                        state_034401 <= (others => '0');
                    end if;
                end if;
            end if;
        end process;


    --
    --
    --
    --
    --
    --


        with state_00c2 select
            match_mux_out_00c2 <= d_is_00 when '0',
                                  d_is_c2 when '1',
                                  '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_00c2 <= '0';
                cdvd_matched_00c2 <= '0';
            elsif rising_edge(clk) then
                cdvd_matched_00c2 <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_00c2 = '1' then
                        if state_00c2 = '1' then
                            cdvd_matched_00c2 <= '1';
                        end if;
                        state_00c2 <= not state_00c2;
                    else
                        state_00c2 <= '0';
                    end if;
                end if;
            end if;
        end process;

    --
    --
    --
    --
    --
    --

        with state_4100 select
            match_mux_out_4100 <= d_is_41or61 when '0',
                                  d_is_00 when '1',
                                  '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_4100 <= '0';
                cdvd_matched_4100 <= '0';
            elsif rising_edge(clk) then
                cdvd_matched_4100 <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_4100 = '1' then
                        if state_4100 = '1' then
                            cdvd_matched_4100 <= '1';
                        end if;
                        state_4100 <= not state_4100;
                    else
                        state_4100 <= '0';
                    end if;
                end if;
            end if;
        end process;

    --
    --
    --
    --
    --
    --


        with state_10f7 select
            match_mux_out_10f7 <= d_is_10 when '0',
                                  (d_is_f7 or d_is_03) when '1', -- 50k tweak for dvd
                                  '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_10f7 <= '0';
                cdvd_matched_10f7 <= '0';
            elsif rising_edge(clk) then
                cdvd_matched_10f7 <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_10f7 = '1' then
                        if state_10f7 = '1' then
                            cdvd_matched_10f7 <= '1';
                        end if;
                        state_10f7 <= not state_10f7;
                    else
                        state_10f7 <= '0';
                    end if;
                end if;
            end if;
        end process;

    --
    --
    --
    --
    --
    --

        state_faffff_plus_1 <= state_faffff + 1;

        with state_faffff select
            match_mux_out_faffff <= d_is_fa when "00",
                                    d_is_ff when "01",
                                    d_is_ff when "10",
                                    '-' when others;

        process(clk, cdvd_reset_n) is
        begin
            if cdvd_reset_n = '0' then
                state_faffff <= (others => '0');
                cdvd_matched_faffff <= '0';
            elsif rising_edge(clk) then
                cdvd_matched_faffff <= '0';
                if cdvd_cs_rise = '1' then
                    if match_mux_out_faffff = '1' then
                        state_faffff <= state_faffff_plus_1;
                        if state_faffff = "10" then
                            cdvd_matched_faffff <= '1';
                            state_faffff <= (others => '0');
                        end if;
                    else
                        state_faffff <= (others => '0');
                    end if;
                end if;
            end if;
        end process;
    end block;



    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            psxauth_state <= init;
            scex_go <= '0';
            scex_gen_count <= X"00";
            scex_carrier_max <= X"9a4"; -- 70 usecs at 37MHz
        elsif rising_edge(clk) then
            scex_gen_count <= (others => '0');
            scex_go <= '0';
            scex_gen_count <= X"00";
            case psxauth_state is
            when init =>
                if cdvd_sm_go = '1' then
                    case mode is
                    when "01" => psxauth_state <= pa0;
                    when "11" => psxauth_state <= pa0;
                    when others => psxauth_state <= sleep;
                    end case;
                end if;

            when pa0 =>
                scex_carrier_max <= X"9a4"; -- 70 usecs at 37MHz
                scex_gen_count <= X"FF";
                scex_go <= '1';
                psxauth_state <= pa1;

            when pa1 =>
                if psxboot_trip = '1' then
                    scex_carrier_max <= X"900"; -- 70 usecs at 32MHz
                    scex_go <= '1';
                    psxauth_state <= idle;
--                elsif eject_n_sync = '0' then
--                    psxauth_state <= pa2;
                end if;

            when pa2 =>
                if eject_n_sync = '1' then
                    psxauth_state <= pa3;
                end if;

            when pa3 =>
                if eject_n_sync = '0' then
                    psxauth_state <= pa4;
                end if;

            when pa4 =>
                if eject_n_sync = '1' then
                    scex_gen_count <= X"20";
                    scex_go <= '1';
                    psxauth_state <= idle;
                end if;

            when idle =>
                if eject_n_sync = '0' then
                    psxauth_state <= pa2;
                end if;

            when sleep =>
                psxauth_state <= sleep;

            end case;

            if reset_trip_1 = '1' then
                psxauth_state <= init;
            end if;
        end if;
    end process;

    scex <= scex_out when scex_running = '1' else 'Z';

    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            scex_carrier_counter <= (others => '0');
            scex_carrier <= '0';
			scex_bit <= '0';
			scex_counter <= (others => '0');
			sub_bit_count <= (others => '0');
			scex_out <= '0';
            scex_running <= '0';
            scex_strings_left <= X"00";
        elsif rising_edge(clk) then
            scex_out <= scex_carrier and scex_bit;

            if scex_running = '1' then
                if scex_carrier_counter >= scex_carrier_max then
                    scex_carrier_counter <= (others => '0');
                    scex_carrier <= not scex_carrier;
                    if scex_carrier = '1' then
                        if sub_bit_count = X"1c" then

                            if scex_counter = X"3d" then
                                if scex_strings_left(7) = '0' then
                                    scex_strings_left <= scex_strings_left - 1;
                                end if;
                                if scex_strings_left = X"00" then
                                    scex_running <= '0';
                                end if;
                                scex_counter <= (others => '0');
                            else
                                scex_counter <= scex_counter + 1;
                            end if;

                            sub_bit_count <= (others => '0');
                        else
                            sub_bit_count <= sub_bit_count + 1;
                        end if;
                    end if;
                else
                    scex_carrier_counter <= scex_carrier_counter + 1;
                end if;

                if scex_go = '1' then
                    scex_strings_left <= scex_gen_count;
                end if;
            else
                scex_carrier_counter <= (others => '0');
                scex_carrier <= '0';
    			scex_counter <= (others => '0');
    			sub_bit_count <= (others => '0');
                if scex_go = '1' then
                    scex_strings_left <= scex_gen_count;
                    scex_running <= '1';
                else
                    scex_running <= '0';
                    scex_strings_left <= X"00";
                end if;
            end if;

--            if eject_n_sync = '0' then
--                scex_running <= '0';
--            end if;

            if reset_trip_1 = '1' then
                scex_running <= '0';
            end if;

            case scex_counter is
            when "000000" => scex_bit <= '0';
            when "000001" => scex_bit <= '0';
            when "000010" => scex_bit <= '0';
            when "000011" => scex_bit <= '0';
            when "000100" => scex_bit <= '0';
            when "000101" => scex_bit <= '0';
            when "000110" => scex_bit <= '0';
            when "000111" => scex_bit <= '0';
            when "001000" => scex_bit <= '0';
            when "001001" => scex_bit <= '0';
            when "001010" => scex_bit <= '0';
            when "001011" => scex_bit <= '0';
            when "001100" => scex_bit <= '0';
            when "001101" => scex_bit <= '0';
            when "001110" => scex_bit <= '0';
            when "001111" => scex_bit <= '0';
            when "010000" => scex_bit <= '0';
            when "010001" => scex_bit <= '0';

            when "010010" => scex_bit <= '1';

            when "010011" => scex_bit <= '0';
            when "010100" => scex_bit <= '0';
            when "010101" => scex_bit <= '1';
            when "010110" => scex_bit <= '1';
            when "010111" => scex_bit <= '0';
            when "011000" => scex_bit <= '1';
            when "011001" => scex_bit <= '0';
            when "011010" => scex_bit <= '1';

            when "011011" => scex_bit <= '0';
            when "011100" => scex_bit <= '0';

            when "011101" => scex_bit <= '1';

            when "011110" => scex_bit <= '0';
            when "011111" => scex_bit <= '0';
            when "100000" => scex_bit <= '1';
            when "100001" => scex_bit <= '1';
            when "100010" => scex_bit <= '1';
            when "100011" => scex_bit <= '1';
            when "100100" => scex_bit <= '0';
            when "100101" => scex_bit <= '1';

            when "100110" => scex_bit <= '0';
            when "100111" => scex_bit <= '0';

            when "101000" => scex_bit <= '1';

            when "101001" => scex_bit <= '0';
            when "101010" => scex_bit <= '1';
            when "101011" => scex_bit <= '0';
            when "101100" => scex_bit <= '1';
            when "101101" => scex_bit <= '1';
            when "101110" => scex_bit <= '1';
            when "101111" => scex_bit <= '0';
            when "110000" => scex_bit <= '1';

            when "110001" => scex_bit <= '0';
            when "110010" => scex_bit <= '0';

            when "110011" => scex_bit <= '1';

            when "110100" => scex_bit <= '0';
            when "110101" => scex_bit <= '1';
            when "110110" =>
                case region is
                when "00" => scex_bit <= '1';
                when "01" => scex_bit <= '1';
                when others => scex_bit <= '0';
                end case;

            when "110111" =>
                case region is
                when "00" => scex_bit <= '0';
                when others => scex_bit <= '1';
                end case;

            when "111000" => scex_bit <= '1';
            when "111001" => scex_bit <= '1';
            when "111010" => scex_bit <= '0';
            when "111011" => scex_bit <= '1';

            when "111100" => scex_bit <= '0';
            when "111101" => scex_bit <= '0';

			when others => scex_bit <= '0';

            end case;
        end if;
    end process;


    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            sync_trip <= '0';
            sync_state <= rm0;
        elsif rising_edge(clk) then
            sync_trip <= '0';

            case sync_state is

            when rm0 =>
                if bs_rise = '1' then
                    if bios_d_last = X"fa" then
                        sync_state <= rm1;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm1 =>
                if bs_rise = '1' then
                    if bios_d_last = X"ff" then
                        sync_state <= rm2;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm2 =>
                if bs_rise = '1' then
                    if bios_d_last = X"66" then
                        sync_state <= rm3;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm3 =>
                if bs_rise = '1' then
                    if bios_d_last = X"14" then
                        sync_state <= rm4;
                    else
                        sync_state <= rm0;
                    end if;
                end if;

            when rm4 =>
                if bs_rise = '1' then
                    if bios_d_last = X"01" then
                        sync_state <= rm5;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm5 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        sync_state <= rm6;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm6 =>
                if bs_rise = '1' then
                    if bios_d_last = X"84" then
                        sync_state <= rm7;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm7 =>
                if bs_rise = '1' then
                    if bios_d_last = X"24" then
                        sync_state <= rm8;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm8 =>
                if bs_rise = '1' then
                    if bios_d_last = X"08" then
                        sync_state <= rm9;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm9 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        sync_state <= rm10;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm10 =>
                if bs_rise = '1' then
                    if bios_d_last = X"e0" then
                        sync_state <= rm11;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm11 =>
                if bs_rise = '1' then
                    if bios_d_last = X"03" then
                        sync_state <= rm12;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm12 =>
                if bs_rise = '1' then
                    if bios_d_last = X"2d" then
                        sync_state <= rm13;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm13 =>
                if bs_rise = '1' then
                    if bios_d_last = X"10" then
                        sync_state <= rm14;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm14 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        sync_state <= rm15;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rm15 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        sync_state <= rtrip;
                    else
                        sync_state <= rm0;
                    end if;
                end if;
            when rtrip =>
                sync_trip <= '1';
                sync_state <= rm0;

            when others =>
                sync_state <= rm0;
            end case;

        end if;
	end process;

    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            reset_counter <= (others => '0');
            reset_state_1 <= rm0;
            reset_trip_1 <= '0';
        elsif rising_edge(clk) then
            reset_trip_1 <= '0';

            if reset_counter_clr = '1' then
                reset_counter <= (others => '0');
            elsif reset_trip_1 = '1' then
                if reset_counter /= X"F" then
                    reset_counter <= reset_counter + 1;
                end if;
            end if;

            case reset_state_1 is
            when rm0 =>
                if bs_rise = '1' then
                    if bios_d_last = X"2b" then
                        reset_state_1 <= rm1;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rm1 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        reset_state_1 <= rm2;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rm2 =>
                if bs_rise = '1' then
                    if bios_d_last = X"40" then
                        reset_state_1 <= rm3;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rm3 =>
                if bs_rise = '1' then
                    if bios_d_last = X"04" then
                        reset_state_1 <= rm4;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;

            when rm4 =>
                if bs_rise = '1' then
                    if bios_d_last = X"a0" then
                        reset_state_1 <= rm5;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rm5 =>
                if bs_rise = '1' then
                    if bios_d_last = X"ff" then
                        reset_state_1 <= rm6;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rm6 =>
                if bs_rise = '1' then
                    if bios_d_last = X"bd" then
                        reset_state_1 <= rm7;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rm7 =>
                if bs_rise = '1' then
                    if bios_d_last = X"27" then
                        reset_state_1 <= rtrip;
                    else
                        reset_state_1 <= rm0;
                    end if;
                end if;
            when rtrip =>
                reset_trip_1 <= '1';
                reset_state_1 <= rm0;

            when others =>
                reset_state_1 <= rm0;
            end case;

        end if;
	end process;


    process(clk, reset_n) is
    begin
        if reset_n = '0' then
            psxboot_trip <= '0';
            psxboot_state <= ps0;
        elsif rising_edge(clk) then
            psxboot_trip <= '0';
            case psxboot_state is
            when ps0 =>
                if bs_rise = '1' then
                    if bios_d_last = X"38" then
                        psxboot_state <= ps1;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps1 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        psxboot_state <= ps2;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps2 =>
                if bs_rise = '1' then
                    if bios_d_last = X"90" then
                        psxboot_state <= ps3;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps3 =>
                if bs_rise = '1' then
                    if bios_d_last = X"ac" then
                        psxboot_state <= ps4;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps4 =>
                if bs_rise = '1' then
                    if bios_d_last = X"1c" then
                        psxboot_state <= ps5;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps5 =>
                if bs_rise = '1' then
                    if bios_d_last = X"00" then
                        psxboot_state <= ps6;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps6 =>
                if bs_rise = '1' then
                    if bios_d_last = X"88" then
                        psxboot_state <= ps7;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when ps7 =>
                if bs_rise = '1' then
                    if bios_d_last = X"8c" then
                        psxboot_state <= pstrip;
                    else
                        psxboot_state <= ps0;
                    end if;
                end if;
            when pstrip =>
                psxboot_trip <= '1';
                psxboot_state <= ps0;
            end case;
        end if;
    end process;

--    debug(11 downto 1) <= (others => '0');

    debug(1) <= not doe;
    debug(2) <= not cdvd_doe;
    debug(3) <= reset_trip_1;
    debug(4) <= reset_counter_clr;
    debug(8 downto 5) <= reset_counter;
    debug(11 downto 10) <= region;
    debug(9) <= sync_trip;
--    debug(11 downto 8) <= reset_counter;


--    debug(8) <= upgrade_valid;
--    debug(9) <= scex_out;
--    debug(10) <= scex_running;
--    debug(11) <= scex_go;
--    debug(5) <= cds(0);
--    debug(6) <= sfedge;
--    debug(7) <= bce_glitch;
--    debug(8) <= bces(1);
--    debug(9) <= bces(0);
--    debug(10) <= bios_ce_n_rise;
--    debug(11) <= bios_ce_n_fall;
--    debug(3) <= reg_we;
--    debug(11 downto 4) <= reg_sel;
--    debug(11 downto 5) <= (others => '0');
end architecture;

