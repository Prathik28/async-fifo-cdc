# Vivado timing constraints for async_fifo. Scope to the module instance, e.g.
#   read_xdc -ref async_fifo constraints/async_fifo.xdc
# and keep the create_clock definitions for both clocks in your top-level XDC.
#
# NOTE: these constraints have not been validated in a Vivado run. Check them with
# report_cdc, report_bus_skew and report_timing before relying on them.
#
# A blanket set_false_path or set_clock_groups between the two clocks is not
# enough: it lets routing skew the Gray bits by more than a source period, which
# breaks the one-bit-changes-at-a-time guarantee. It also overrides the limits here.

set wclk_period [get_property -min PERIOD [get_clocks -of_objects [get_ports wclk]]]
set rclk_period [get_property -min PERIOD [get_clocks -of_objects [get_ports rclk]]]

# Write pointer into the read domain.
set_max_delay -datapath_only -from [get_cells u_wptr/wgray_reg[*]] \
    -to [get_cells u_sync_w2r/chain_reg[*]] $rclk_period
set_bus_skew -from [get_cells u_wptr/wgray_reg[*]] \
    -to [get_cells u_sync_w2r/chain_reg[*]] $wclk_period

# Read pointer into the write domain.
set_max_delay -datapath_only -from [get_cells u_rptr/rgray_reg[*]] \
    -to [get_cells u_sync_r2w/chain_reg[*]] $wclk_period
set_bus_skew -from [get_cells u_rptr/rgray_reg[*]] \
    -to [get_cells u_sync_r2w/chain_reg[*]] $rclk_period

# The asynchronous reset input only reaches the reset synchronizers' clear pins.
set_false_path -to [get_pins -hierarchical -filter {NAME =~ *u_?rst/chain_reg[*]/CLR}]

# The LUT RAM read path crosses from wclk to rclk. A word is only read after the
# synchronized write pointer has passed it, so bound the delay to one read period.
set_max_delay -datapath_only -from [get_clocks -of_objects [get_ports wclk]] \
    -through [get_pins -hierarchical -filter {NAME =~ *u_mem/*/O}] $rclk_period
