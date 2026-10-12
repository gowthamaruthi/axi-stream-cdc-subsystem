`timescale 1ns/1ps
module tb_adc;
  reg s_clk=0,m_clk=0,rst_n=0;
  always #3 s_clk=~s_clk;
  integer read_half=5;
  always begin #(read_half);m_clk=~m_clk;end
  reg [11:0] adc_data=0;
  reg adc_valid=0,m_axis_tready=0;
  wire [31:0] s_axis_tdata,m_axis_tdata,dropped_samples;
  wire [3:0] s_axis_tkeep,m_axis_tkeep;
  wire s_axis_tlast,s_axis_tvalid,s_axis_tready,m_axis_tlast,m_axis_tvalid;
  adc_axis_ingress ingress(.sample_clk(s_clk),.rst_n(rst_n),.adc_data(adc_data),.adc_valid(adc_valid),
    .axis_data(s_axis_tdata),.axis_keep(s_axis_tkeep),.axis_last(s_axis_tlast),.axis_valid(s_axis_tvalid),.axis_ready(s_axis_tready),.dropped_samples(dropped_samples));
  axis_cdc #(.DEPTH(4)) bridge(.s_clk(s_clk),.m_clk(m_clk),.rst_n(rst_n),
    .s_axis_tdata(s_axis_tdata),.s_axis_tkeep(s_axis_tkeep),.s_axis_tlast(s_axis_tlast),.s_axis_tvalid(s_axis_tvalid),.s_axis_tready(s_axis_tready),
    .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),.m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready),
    .s_axil_awaddr(8'b0),.s_axil_awprot(3'b0),.s_axil_awvalid(1'b0),.s_axil_awready(),
    .s_axil_wdata(32'b0),.s_axil_wstrb(4'b0),.s_axil_wvalid(1'b0),.s_axil_wready(),.s_axil_bresp(),.s_axil_bvalid(),.s_axil_bready(1'b1),
    .s_axil_araddr(8'b0),.s_axil_arprot(3'b0),.s_axil_arvalid(1'b0),.s_axil_arready(),.s_axil_rdata(),.s_axil_rresp(),.s_axil_rvalid(),.s_axil_rready(1'b1));
  reg [11:0] expected[0:2047];
  integer writes=0,reads=0,drops=0,sent=0;
  reg stalled=0;
  reg [31:0] held;
  always @(posedge s_clk)if(rst_n)begin
    if(stalled && (!s_axis_tvalid || s_axis_tdata!==held))$fatal(1,"input changed under stall");
    stalled=s_axis_tvalid && !s_axis_tready;held=s_axis_tdata;
    if(adc_valid)begin
      sent=sent+1;
      if(!s_axis_tvalid || s_axis_tready)begin expected[writes]=adc_data;writes=writes+1;end
      else drops=drops+1;
    end
  end else stalled=0;
  always @(posedge m_clk)if(rst_n && m_axis_tvalid && m_axis_tready)begin
    if(reads>=writes || m_axis_tdata!=={20'b0,expected[reads]} || m_axis_tkeep!==3 || !m_axis_tlast)$fatal(1,"sample order/sideband mismatch");
    reads=reads+1;
  end
  task send(input integer count);
    for(integer i=0;i<count;i=i+1)begin @(negedge s_clk);adc_valid=1;adc_data=12'(i*37+sent);end
    @(negedge s_clk);adc_valid=0;
  endtask
  task drain;
    m_axis_tready=1;
    wait(reads==writes);repeat(8)@(negedge m_clk);
    if(dropped_samples!==drops || sent!=reads+drops)$fatal(1,"accounting mismatch");
  endtask
  initial begin
    repeat(4)@(negedge s_clk);rst_n=1;
    repeat(4)@(negedge s_clk);
    send(100); // ADC cannot stop: overflow is expected while consumer is stalled.
    drain();
    if(drops==0)$fatal(1,"overflow not exercised");
    read_half=2;send(200);drain();
    read_half=3;send(100);drain();
    $display("PASS ADC integration sent=%0d consumed=%0d dropped=%0d",sent,reads,drops);
    // Coordinated reset aborts a pending ingress sample and queued FIFO data.
    m_axis_tready=0;send(10);rst_n=0;
    repeat(4)@(negedge s_clk);
    if(s_axis_tvalid || dropped_samples!=0)$fatal(1,"reset failed");
    writes=0;reads=0;drops=0;sent=0;rst_n=1;
    repeat(4)@(negedge s_clk);m_axis_tready=1;
    send(20);drain();
    $display("PASS reset flush and restart sent=%0d consumed=%0d dropped=%0d",sent,reads,drops);$finish;
  end
  initial begin #100000;$fatal(1,"watchdog");end
endmodule
