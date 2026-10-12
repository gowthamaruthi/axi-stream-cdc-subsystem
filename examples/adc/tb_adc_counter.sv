`timescale 1ns/1ps
module tb_adc_counter;
  reg clk=0,rst_n=0;
  always #5 clk=~clk;
  wire [31:0] data,dropped;
  wire [3:0] keep;
  wire last,valid;
  adc_axis_ingress dut(.sample_clk(clk),.rst_n(rst_n),.adc_data(12'habc),.adc_valid(1'b1),
    .axis_data(data),.axis_keep(keep),.axis_last(last),.axis_valid(valid),.axis_ready(1'b0),.dropped_samples(dropped));
  initial begin
    repeat(2)@(negedge clk);rst_n=1;
    @(negedge clk);
    if(!valid || data!==32'habc || keep!==3 || !last)$fatal(1,"sample capture");
    // White-box preload reaches the 32-bit counter boundary without 2^32 cycles.
    dut.dropped_samples=32'hfffffffe;
    @(negedge clk);if(dropped!==32'hffffffff)$fatal(1,"saturation boundary");
    repeat(3)begin @(negedge clk);if(dropped!==32'hffffffff)$fatal(1,"counter wrapped");end
    rst_n=0;@(negedge clk);if(dropped!==0 || valid)$fatal(1,"counter reset");
    $display("PASS ADC drop counter saturation and reset (white-box preload)");$finish;
  end
  initial begin #1000;$fatal(1,"timeout");end
endmodule
