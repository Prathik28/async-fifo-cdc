.PHONY: all lint synth sim sim-icarus mutation formal clean

all: lint synth sim sim-icarus mutation formal

lint:       ; ./scripts/lint.sh
synth:      ; ./scripts/synth.sh
sim:        ; ./scripts/sim.sh verilator
sim-icarus: ; ./scripts/sim.sh icarus
mutation:   ; ./scripts/mutation.sh
formal:     ; ./scripts/formal.sh
clean:      ; rm -rf build
