# Parallel ADC samples into the stream bridge

I use this example to connect a non-backpressurable sample source to the AXI4-Stream CDC subsystem. It models the digital output of an ADC; no analog converter, manufacturer-specific protocol or hardware measurement is included.

## Interface contract

- `adc_data[11:0]` and `adc_valid` meet setup/hold timing to `sample_clk`. They are not independent asynchronous inputs. A real source-synchronous ADC needs board/FPGA input timing constraints.
- One sample is captured on each valid edge if the holding register is empty or its previous sample transfers on that edge.
- A sample arriving while the register is stalled is dropped. `dropped_samples` increments and saturates at `0xffffffff`.
- Each accepted sample becomes one beat: 12 data bits zero-extended to 32, `TKEEP=0011`, `TLAST=1`. Each sample is a separate packet.
- Data and sidebands remain stable under backpressure. The existing FIFO transfers accepted beats to the consumer clock domain.
- Common reset flushes ingress and FIFO state and clears the drop count. Pending samples are discarded; the test checks normal drains before clearing accounting and explicitly separates the reset-abort scenario.

```sh
bash examples/adc/check.sh
python3 examples/adc/negative.py
```

The deterministic test drives 400 samples through stalled, faster-consumer and equal-period clock scenarios. It checks accepted-sample order, sidebands, stable held data and `sent = consumed + dropped` after draining. A second phase resets with pending data and checks clean restart. With the checked-in stimulus, the first phase consumes 240 and drops 160; restart consumes 14 and drops 6 from 20 samples. These counts describe the test, not a hardware throughput measurement.

Verilator lint, Yosys generic synthesis and the Icarus integration test pass locally. A temporary mutation that overwrites a stalled sample is rejected. This example demonstrates digital mixed-signal interfacing concepts; it does not establish DRAM design, analog performance or dedicated CDC-tool signoff.

A separate counter test preloads `dropped_samples` to `0xfffffffe`, verifies saturation across further dropped samples, and checks reset. This is a white-box boundary test, not a simulation of 2^32 samples.
