#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/adc
verilator --lint-only -Wall --top-module adc_axis_ingress examples/adc/adc_axis_ingress.sv > build/adc/lint.log 2>&1
yosys -Q -T -p 'read_verilog -sv examples/adc/adc_axis_ingress.sv; synth -top adc_axis_ingress; check -assert' > build/adc/synthesis.log
iverilog -g2012 -s tb_adc -o build/adc/test.vvp rtl/async_fifo.sv rtl/axis_cdc.sv examples/adc/adc_axis_ingress.sv examples/adc/tb_adc.sv
vvp build/adc/test.vvp | tee build/adc/simulation.log
