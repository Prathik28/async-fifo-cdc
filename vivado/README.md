# Vivado run (ZedBoard, xc7z020clg484-1)

**Status: not yet run in Vivado.**

From the repository root, with Vivado on the path (on Windows, use the Vivado
Tcl Shell):

    vivado -mode batch -nojournal -source vivado/run.tcl

The device support for Zynq-7000 must be installed. Reports go to
`build/vivado/`. To get them reviewed, send that folder and `vivado.log` from the
repository root, including when the script stops with an error.

The run is out of context: there are no pin assignments and no bitstream, so it
does not test anything on the board. The clock periods are example values.
