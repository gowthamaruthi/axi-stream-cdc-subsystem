#!/usr/bin/env python3
import pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[2]
out=root/'build/adc/negative';out.mkdir(parents=True,exist_ok=True)
s=(root/'examples/adc/adc_axis_ingress.sv').read_text();old='if(!axis_valid || axis_ready)begin';assert old in s
(out/'mutant.sv').write_text(s.replace(old,"if(1'b1)begin"))
subprocess.run(['iverilog','-g2012','-s','tb_adc','-o',str(out/'test.vvp'),str(root/'rtl/async_fifo.sv'),str(root/'rtl/axis_cdc.sv'),str(out/'mutant.sv'),str(root/'examples/adc/tb_adc.sv')],check=True)
r=subprocess.run(['vvp',str(out/'test.vvp')],capture_output=True,text=True,timeout=10)
(out/'failure.log').write_text(r.stdout+r.stderr)
assert r.returncode and 'input changed under stall' in r.stdout,r.stdout
print('PASS rejected stalled-sample overwrite')
