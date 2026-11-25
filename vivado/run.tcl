# Out-of-context implementation and reports for async_fifo on the ZedBoard part.
# No pin assignments and no bitstream: this checks the FIFO itself, not a board demo.
#
# From the repository root:
#   vivado -mode batch -nojournal -source vivado/run.tcl
# Optional: -tclargs <part> <wclk_period_ns> <rclk_period_ns>
#
# The default clock periods (100 MHz write, about 71 MHz read) are example values.

set part    xc7z020clg484-1
set wperiod 10.000
set rperiod 14.000
if {[llength $argv] >= 1} { set part    [lindex $argv 0] }
if {[llength $argv] >= 2} { set wperiod [lindex $argv 1] }
if {[llength $argv] >= 3} { set rperiod [lindex $argv 2] }

set root [file normalize [file join [file dirname [info script]] ..]]
set out  [file join $root build vivado]
file mkdir $out

set clocks [file join $out clocks.xdc]
set fh [open $clocks w]
puts $fh "create_clock -name wclk -period $wperiod \[get_ports wclk\]"
puts $fh "create_clock -name rclk -period $rperiod \[get_ports rclk\]"
close $fh

set list [open [file join $root rtl files.f] r]
foreach f [split [string trim [read $list]] "\n"] {
    read_verilog -sv [file join $root $f]
}
close $list

# Clocks are read first: the FIFO constraints look up their periods.
read_xdc -mode out_of_context $clocks
read_xdc [file join $root constraints async_fifo.xdc]

synth_design -top async_fifo -part $part -mode out_of_context

# Every object the constraints refer to must exist. A pattern that matches
# nothing would leave a crossing unconstrained.
set missing 0
proc require {label objects} {
    global missing
    set n [llength $objects]
    puts [format "CHECK %-32s %d objects" $label $n]
    if {$n == 0} { incr missing }
}
require "write Gray pointer registers" [get_cells -quiet {u_wptr/wgray_reg[*]}]
require "read Gray pointer registers"  [get_cells -quiet {u_rptr/rgray_reg[*]}]
require "write-to-read synchronizer"   [get_cells -quiet {u_sync_w2r/chain_reg[*]}]
require "read-to-write synchronizer"   [get_cells -quiet {u_sync_r2w/chain_reg[*]}]
require "reset synchronizer clear pins" \
    [get_pins -quiet -hierarchical -filter {NAME =~ *u_?rst/chain_reg[*]/CLR}]
require "LUT RAM read outputs" \
    [get_pins -quiet -hierarchical -filter {NAME =~ *u_mem/*/O}]

opt_design
place_design
route_design

report_utilization                      -file [file join $out utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
                                        -file [file join $out timing_summary.rpt]
report_cdc -details                     -file [file join $out cdc.rpt]
report_bus_skew                         -file [file join $out bus_skew.rpt]
report_exceptions                       -file [file join $out exceptions.rpt]
report_exceptions -ignored              -file [file join $out exceptions_ignored.rpt]
report_methodology                      -file [file join $out methodology.rpt]
write_checkpoint -force                       [file join $out async_fifo_routed.dcp]

puts "PART $part  WCLK ${wperiod} ns  RCLK ${rperiod} ns"
puts "Reports written to $out"
if {$missing > 0} {
    puts "RESULT: $missing constraint target check(s) matched nothing. Send back the log."
    exit 1
}
puts "RESULT: script finished. This is not a pass: the reports still need review."
