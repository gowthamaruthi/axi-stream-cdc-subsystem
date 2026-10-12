`timescale 1ns/1ps
module axis_cdc #(parameter integer DEPTH=16)(
  input wire s_clk, m_clk, rst_n,
  input wire [31:0] s_axis_tdata,
  input wire [3:0] s_axis_tkeep,
  input wire s_axis_tlast, s_axis_tvalid,
  output wire s_axis_tready,
  output wire [31:0] m_axis_tdata,
  output wire [3:0] m_axis_tkeep,
  output wire m_axis_tlast, m_axis_tvalid,
  input wire m_axis_tready,
  input wire [7:0] s_axil_awaddr,
  input wire [2:0] s_axil_awprot,
  input wire s_axil_awvalid,
  output wire s_axil_awready,
  input wire [31:0] s_axil_wdata,
  input wire [3:0] s_axil_wstrb,
  input wire s_axil_wvalid,
  output wire s_axil_wready,
  output reg [1:0] s_axil_bresp,
  output reg s_axil_bvalid,
  input wire s_axil_bready,
  input wire [7:0] s_axil_araddr,
  input wire [2:0] s_axil_arprot,
  input wire s_axil_arvalid,
  output wire s_axil_arready,
  output reg [31:0] s_axil_rdata,
  output reg [1:0] s_axil_rresp,
  output reg s_axil_rvalid,
  input wire s_axil_rready
);
  (* ASYNC_REG="TRUE" *) reg [1:0] s_reset, m_reset;
  always @(posedge s_clk or negedge rst_n)
    if(!rst_n) s_reset<=0; else s_reset<={s_reset[0],1'b1};
  always @(posedge m_clk or negedge rst_n)
    if(!rst_n) m_reset<=0; else m_reset<={m_reset[0],1'b1};
  wire s_rst_n=s_reset[1], m_rst_n=m_reset[1];
  reg enabled;
  wire full,empty;
  wire [36:0] fifo_out;
  wire accepted=s_axis_tvalid && s_axis_tready;
  assign s_axis_tready=s_rst_n && enabled && !full;
  assign m_axis_tvalid=m_rst_n && !empty;
  assign {m_axis_tlast,m_axis_tkeep,m_axis_tdata}=fifo_out;
  async_fifo #(.DEPTH(DEPTH),.WIDTH(37)) fifo(
    .wr_clk(s_clk),.wr_rst_n(s_rst_n),.wr_en(accepted),
    .wr_data({s_axis_tlast,s_axis_tkeep,s_axis_tdata}),.full(full),
    .rd_clk(m_clk),.rd_rst_n(m_rst_n),.rd_en(m_axis_tvalid && m_axis_tready),
    .rd_data(fifo_out),.empty(empty));
  (* ASYNC_REG="TRUE" *) reg empty_meta,empty_sync;
  always @(posedge s_clk or negedge s_rst_n)
    if(!s_rst_n) begin empty_meta<=1; empty_sync<=1; end
    else begin empty_meta<=empty; empty_sync<=empty_meta; end
  reg [31:0] accepted_count,scratch;
  reg aw_pending,w_pending;
  reg [7:0] awaddr;
  reg [31:0] wdata;
  reg [3:0] wstrb;
  // Protection attributes are accepted but unused in this unprivileged register bank.
  wire unused_prot=&{1'b0,s_axil_awprot,s_axil_arprot};
  assign s_axil_awready=s_rst_n && !aw_pending && !s_axil_bvalid;
  assign s_axil_wready=s_rst_n && !w_pending && !s_axil_bvalid;
  assign s_axil_arready=s_rst_n && !s_axil_rvalid;
  integer lane;
  always @(posedge s_clk or negedge s_rst_n) begin
    if(!s_rst_n) begin
      enabled<=1; accepted_count<=0; scratch<=0;
      aw_pending<=0; w_pending<=0; awaddr<=0; wdata<=0; wstrb<=0;
      s_axil_bvalid<=0; s_axil_bresp<=0;
      s_axil_rvalid<=0; s_axil_rresp<=0; s_axil_rdata<=0;
    end else begin
      if(accepted) accepted_count<=accepted_count+1'b1;
      if(s_axil_awvalid && s_axil_awready) begin aw_pending<=1; awaddr<=s_axil_awaddr; end
      if(s_axil_wvalid && s_axil_wready) begin w_pending<=1; wdata<=s_axil_wdata; wstrb<=s_axil_wstrb; end
      if(s_axil_bvalid && s_axil_bready) s_axil_bvalid<=0;
      if(aw_pending && w_pending && !s_axil_bvalid) begin
        aw_pending<=0; w_pending<=0; s_axil_bvalid<=1; s_axil_bresp<=0;
        case(awaddr)
          8'h04: if(wstrb[0]) enabled<=wdata[0];
          8'h10: for(lane=0;lane<4;lane=lane+1)
            if(wstrb[lane]) scratch[lane*8+:8]<=wdata[lane*8+:8];
          default: s_axil_bresp<=2'b10;
        endcase
      end
      if(s_axil_rvalid && s_axil_rready) s_axil_rvalid<=0;
      if(s_axil_arvalid && s_axil_arready) begin
        s_axil_rvalid<=1; s_axil_rresp<=0;
        case(s_axil_araddr)
          8'h00: s_axil_rdata<=32'h43444301;
          8'h04: s_axil_rdata<={31'b0,enabled};
          8'h08: s_axil_rdata<={29'b0,enabled,empty_sync,full};
          8'h0c: s_axil_rdata<=accepted_count;
          8'h10: s_axil_rdata<=scratch;
          default: begin s_axil_rdata<=0; s_axil_rresp<=2'b10; end
        endcase
      end
    end
  end
endmodule
