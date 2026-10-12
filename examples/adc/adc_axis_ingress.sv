`timescale 1ns/1ps
// Parallel ADC sample interface: data and valid are synchronous to sample_clk.
module adc_axis_ingress (
  input wire sample_clk, rst_n,
  input wire [11:0] adc_data,
  input wire adc_valid,
  output wire [31:0] axis_data,
  output wire [3:0] axis_keep,
  output wire axis_last,
  output reg axis_valid,
  input wire axis_ready,
  output reg [31:0] dropped_samples
);
  reg [11:0] held_sample;
  assign axis_data={20'b0,held_sample};
  assign axis_keep=4'b0011;
  assign axis_last=1'b1;
  always @(posedge sample_clk or negedge rst_n) begin
    if(!rst_n)begin held_sample<=0;axis_valid<=0;dropped_samples<=0;end
    else begin
      if(axis_valid && axis_ready)axis_valid<=0;
      if(adc_valid)begin
        if(!axis_valid || axis_ready)begin held_sample<=adc_data;axis_valid<=1;end
        else if(dropped_samples!=32'hffffffff)dropped_samples<=dropped_samples+1'b1;
      end
    end
  end
endmodule
