#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
verilator --lint-only -Wall -Wno-SYNCASYNCNET --top-module axis_cdc rtl/*.sv 2>&1 | tee build/lint.log
yosys -Q -T -p 'read_verilog -sv rtl/async_fifo.sv rtl/axis_cdc.sv; synth -top axis_cdc; check -assert' > build/synthesis.log
for depth in 4 16; do
  iverilog -g2012 -Wall -s tb_axis_cdc -Ptb_axis_cdc.DEPTH="$depth" -o "build/d$depth.vvp" rtl/*.sv tb/tb_axis_cdc.sv
  for seed in 1 20260905; do
    if vvp "build/d$depth.vvp" +SEED="$seed" | tee "build/d${depth}_s${seed}.log"; then
      :
    else
      (cd build; vvp "d$depth.vvp" +SEED="$seed" +WAVES > "failure_d${depth}_s${seed}.log" 2>&1) || true
      exit 1
    fi
  done
done
