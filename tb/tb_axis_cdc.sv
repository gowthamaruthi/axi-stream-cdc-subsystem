`timescale 1ns/1ps
module tb_axis_cdc;
  parameter integer DEPTH=16;
  reg s_clk=0,m_clk=0,rst_n=0;
  integer sh=3,mh=7;
  reg pause_s=0,pause_m=0;
  always begin #(sh); if(!pause_s) s_clk=~s_clk; end
  always begin #(mh); if(!pause_m) m_clk=~m_clk; end
  reg [31:0] s_axis_tdata=0;
  reg [3:0] s_axis_tkeep=0;
  reg s_axis_tlast=0,s_axis_tvalid=0;
  wire s_axis_tready;
  wire [31:0] m_axis_tdata;
  wire [3:0] m_axis_tkeep;
  wire m_axis_tlast,m_axis_tvalid;
  reg m_axis_tready=0;
  reg [7:0] s_axil_awaddr=0,s_axil_araddr=0;
  reg [2:0] s_axil_awprot=0,s_axil_arprot=0;
  reg s_axil_awvalid=0,s_axil_wvalid=0,s_axil_bready=0,s_axil_arvalid=0,s_axil_rready=0;
  wire s_axil_awready,s_axil_wready,s_axil_bvalid,s_axil_arready,s_axil_rvalid;
  reg [31:0] s_axil_wdata=0;
  reg [3:0] s_axil_wstrb=0;
  wire [1:0] s_axil_bresp,s_axil_rresp;
  wire [31:0] s_axil_rdata;
  axis_cdc #(.DEPTH(DEPTH)) dut(.*);
  integer source_mode=0,sink_mode=0,seed=1,ws,rs,dummy;
  integer nw=0,nr=0,discarded=0,epoch=0,axi_checks=0,stalls=0;
  integer run_length=0,max_run=0;
  reg took_s=0;
  reg [36:0] expected[0:65535];
  time sent_at[0:65535];
  time min_latency=64'hffffffffffffffff,max_latency=0;
  time latency;
  function automatic integer rng(input integer x);
    integer y;
    begin y=x^(x<<13); y=y^(y>>17); rng=y^(y<<5); end
  endfunction
  always @(negedge s_clk) begin
    ws=rng(ws);
    if(!rst_n) s_axis_tvalid=0;
    else if(!s_axis_tvalid || took_s) begin
      s_axis_tvalid=(source_mode==1)||(source_mode==2 && (ws&7)<5);
      s_axis_tdata=32'(ws); s_axis_tkeep=4'(ws>>8); s_axis_tlast=(ws&15)==0;
    end
  end
  always @(negedge m_clk) begin
    rs=rng(rs); m_axis_tready=rst_n && ((sink_mode==1)||(sink_mode==2 && (rs&7)<5));
  end
  always @(posedge s_clk) begin
    took_s=rst_n && s_axis_tvalid && s_axis_tready;
    if(took_s) begin
      if(nw==65536) $fatal(1,"scoreboard capacity");
      expected[nw]={s_axis_tlast,s_axis_tkeep,s_axis_tdata}; sent_at[nw]=$time; nw=nw+1;
    end
  end
  always @(posedge m_clk) begin
    if(rst_n && m_axis_tvalid && m_axis_tready) begin
      if(nr>=nw) $fatal(1,"unexpected output");
      if({m_axis_tlast,m_axis_tkeep,m_axis_tdata} !== expected[nr]) $fatal(1,"stream data/sideband order mismatch at %0d",nr);
      latency=$time-sent_at[nr];
      if(latency<min_latency) min_latency=latency;
      if(latency>max_latency) max_latency=latency;
      nr=nr+1; run_length=run_length+1;
      if(run_length>max_run) max_run=run_length;
    end else run_length=0;
    if(rst_n && m_axis_tvalid && !m_axis_tready) stalls=stalls+1;
  end
  // Clocked protocol assertions use pre-edge payloads and reset their history on flush.
  reg ms=0,ss=0,bs=0,rrs=0;
  reg [36:0] mp,sp;
  reg [1:0] bp,rp;
  reg [31:0] rdp;
  always @(posedge m_clk or negedge rst_n) begin
    if(!rst_n) ms<=0;
    else begin
      if(ms && (!m_axis_tvalid || {m_axis_tlast,m_axis_tkeep,m_axis_tdata}!==mp)) $fatal(1,"AXIS output unstable under backpressure");
      ms<=m_axis_tvalid && !m_axis_tready; mp<={m_axis_tlast,m_axis_tkeep,m_axis_tdata};
    end
  end
  always @(posedge s_clk or negedge rst_n) begin
    if(!rst_n) begin ss<=0;bs<=0;rrs<=0; end
    else begin
      if(ss && (!s_axis_tvalid || {s_axis_tlast,s_axis_tkeep,s_axis_tdata}!==sp)) $fatal(1,"source violated AXIS hold");
      if(bs && (!s_axil_bvalid || s_axil_bresp!==bp)) $fatal(1,"AXIL B unstable");
      if(rrs && (!s_axil_rvalid || {s_axil_rresp,s_axil_rdata}!=={rp,rdp})) $fatal(1,"AXIL R unstable");
      ss<=s_axis_tvalid && !s_axis_tready; sp<={s_axis_tlast,s_axis_tkeep,s_axis_tdata};
      bs<=s_axil_bvalid && !s_axil_bready; bp<=s_axil_bresp;
      rrs<=s_axil_rvalid && !s_axil_rready; rp<=s_axil_rresp; rdp<=s_axil_rdata;
    end
  end
  integer aw_count=0,w_count=0,b_count=0,ar_count=0,r_count=0;
  always @(posedge s_clk or negedge rst_n) begin
    if(!rst_n) begin aw_count=0;w_count=0;b_count=0;ar_count=0;r_count=0;end
    else begin
      if(s_axil_awvalid && s_axil_awready)aw_count=aw_count+1;
      if(s_axil_wvalid && s_axil_wready)w_count=w_count+1;
      if(s_axil_arvalid && s_axil_arready)ar_count=ar_count+1;
      if(s_axil_bvalid && (b_count>=aw_count || b_count>=w_count))$fatal(1,"unmatched write response");
      if(s_axil_rvalid && r_count>=ar_count)$fatal(1,"unmatched read response");
      if(s_axil_bvalid && s_axil_bready)b_count=b_count+1;
      if(s_axil_rvalid && s_axil_rready)r_count=r_count+1;
    end
  end
  task automatic aw(input [7:0] address,input integer delay_cycles);
    begin
      repeat(delay_cycles) @(negedge s_clk);
      @(negedge s_clk); s_axil_awaddr=address; s_axil_awvalid=1;
      do @(posedge s_clk); while(!s_axil_awready);
      @(negedge s_clk); s_axil_awvalid=0;
    end
  endtask
  task automatic wd(input [31:0] data,input [3:0] strobe,input integer delay_cycles);
    begin
      repeat(delay_cycles) @(negedge s_clk);
      @(negedge s_clk); s_axil_wdata=data; s_axil_wstrb=strobe; s_axil_wvalid=1;
      do @(posedge s_clk); while(!s_axil_wready);
      @(negedge s_clk); s_axil_wvalid=0;
    end
  endtask
  task automatic wr(input [7:0] address,input [31:0] data,input [3:0] strobe,
                     input integer ad,dd,stall,input [1:0] response);
    begin
      fork aw(address,ad); wd(data,strobe,dd); join
      wait(s_axil_bvalid); repeat(stall) @(negedge s_clk); #1;
      if(s_axil_bresp!==response) $fatal(1,"write response %h",address);
      @(negedge s_clk); s_axil_bready=1;
      @(posedge s_clk); @(negedge s_clk); s_axil_bready=0; axi_checks=axi_checks+1;
    end
  endtask
  task automatic rd(input [7:0] address,input integer stall,input [1:0] response,output reg [31:0] data);
    begin
      @(negedge s_clk); s_axil_araddr=address; s_axil_arvalid=1;
      do @(posedge s_clk); while(!s_axil_arready);
      @(negedge s_clk); s_axil_arvalid=0;
      wait(s_axil_rvalid); repeat(stall) @(negedge s_clk); #1;
      if(s_axil_rresp!==response) $fatal(1,"read response %h",address);
      data=s_axil_rdata;
      @(negedge s_clk); s_axil_rready=1;
      @(posedge s_clk); @(negedge s_clk); s_axil_rready=0; axi_checks=axi_checks+1;
    end
  endtask
  task automatic expect_reg(input [7:0] address,input [31:0] value);
    reg [31:0] got;
    begin rd(address,4,0,got); if(got!==value) $fatal(1,"register %h got=%h expected=%h",address,got,value); end
  endtask
  task automatic reset_all;
    begin
      @(negedge s_clk); #1; rst_n=0; source_mode=0;sink_mode=0;
      discarded=discarded+nw-nr; nr=nw; epoch=nw;
      s_axil_awvalid=0;s_axil_wvalid=0;s_axil_arvalid=0;s_axil_rready=0;s_axil_bready=0;
      repeat(4) @(negedge s_clk);repeat(4) @(negedge m_clk); #1;rst_n=1;
      repeat(4) @(negedge s_clk);repeat(4) @(negedge m_clk);#1;
      if(s_axil_bvalid || s_axil_rvalid || m_axis_tvalid) $fatal(1,"reset did not flush");
    end
  endtask
  task automatic drain;
    begin
      source_mode=0;sink_mode=1;
      // A producer with a stalled beat must complete it before stopping.
      wait(!s_axis_tvalid);wait(nr==nw);
      repeat(6) @(negedge m_clk); #1;
      if(nr!=nw || m_axis_tvalid) $fatal(1,"drain/accounting");
    end
  endtask
  reg [31:0] value,shadow;
  integer start_nr,end_nr,measured,strobe;
  time window_start,window_end;
  initial begin
    dummy=$value$plusargs("SEED=%d",seed);ws=seed|1;rs=seed^32'h13579bdf;
    $display("DEPTH=%0d SEED=%0d",DEPTH,seed);
    if($test$plusargs("WAVES"))begin $dumpfile("failure.vcd");$dumpvars(0,tb_axis_cdc);end
    reset_all();expect_reg(0,32'h43444301);expect_reg(4,1);expect_reg(16,0);
    source_mode=1;sink_mode=1;wait(nw==1);source_mode=0;wait(nr==1);#1;
    $display("MEASURE cold first accepted beat latency_ns=%0d",latency);drain();
    shadow=0;
    for(strobe=0;strobe<16;strobe=strobe+1)begin
      value=32'h89abcdef ^ (32'(strobe)*32'h10204081);
      wr(16,value,4'(strobe),strobe%3,(strobe+1)%4,4,0);
      for(integer k=0;k<4;k=k+1)if((strobe>>k)&1)shadow[k*8+:8]=value[k*8+:8];
      expect_reg(16,shadow);
    end
    wr(0,0,15,0,3,2,2);wr(8,0,15,3,0,2,2);wr(12,0,15,0,0,2,2);
    wr(17,0,15,0,0,2,2);wr(252,0,15,0,0,2,2);expect_reg(16,shadow);
    rd(1,3,2,value);rd(252,3,2,value);
    for(integer address=0;address<256;address=address+1)begin
      if(address!=4 && address!=16)wr(8'(address),32'hffffffff,15,address%3,(address+1)%3,0,2);
      if(address!=0 && address!=4 && address!=8 && address!=12 && address!=16)rd(8'(address),0,2,value);
    end
    expect_reg(16,shadow);expect_reg(4,1);
    wr(4,32'hffffffff,15,0,0,1,0);expect_reg(4,1); // reserved bits read zero
    wr(4,0,0,0,0,1,0);expect_reg(4,1); // zero strobe has no effect
    // Concurrent read and write operate through independent response channels.
    fork wr(16,32'h12345678,15,0,5,8,0); expect_reg(0,32'h43444301); join
    expect_reg(16,32'h12345678);
    // AW/W were captured on the previous edge; this AR shares the commit edge.
    fork aw(16,0);wd(32'hcafebabe,15,0);join
    s_axil_araddr=16;s_axil_arvalid=1;
    @(posedge s_clk);if(!s_axil_arready)$fatal(1,"same-address AR not ready");
    @(negedge s_clk);s_axil_arvalid=0;
    if(!s_axil_rvalid || !s_axil_bvalid || s_axil_rdata!==32'h12345678 || s_axil_rresp!=0 || s_axil_bresp!=0)
      $fatal(1,"same-address read/write must return prior value");
    repeat(4)@(negedge s_clk);s_axil_bready=1;s_axil_rready=1;
    @(posedge s_clk);@(negedge s_clk);s_axil_bready=0;s_axil_rready=0;axi_checks=axi_checks+2;
    expect_reg(16,32'hcafebabe);
    wr(4,0,2,0,0,1,0);expect_reg(4,1); // wrong lane cannot disable
    source_mode=1;sink_mode=0;repeat(DEPTH+20)@(negedge s_clk);
    if(!m_axis_tvalid)$fatal(1,"buffered output must assert valid while stalled");
    rd(8,3,0,value);if(!value[0])$fatal(1,"full status not set");
    wr(4,0,1,0,4,5,0);expect_reg(4,0);
    repeat(5)@(negedge s_clk);if(s_axis_tready)$fatal(1,"disable admission");
    sink_mode=1;wait(nr==nw); // buffered output drains even when disabled
    wr(4,1,1,5,0,2,0);source_mode=2;sink_mode=2;
    repeat(1000)@(negedge s_clk);drain();expect_reg(12,32'(nw-epoch));
    source_mode=1;sink_mode=1;repeat(100)@(negedge m_clk);
    start_nr=nr;window_start=$time;repeat(200)@(negedge m_clk);end_nr=nr;window_end=$time;
    measured=end_nr-start_nr;
    $display("MEASURE saturated window: beats=%0d m_cycles=200 elapsed_ns=%0d beats_per_m_cycle=%f",measured,window_end-window_start,real'(measured)/200.0);
    @(negedge m_clk);#1;pause_m=1;repeat(DEPTH+15)@(negedge s_clk);pause_m=0;
    repeat(100)@(negedge m_clk);
    @(negedge s_clk);#1;pause_s=1;repeat(DEPTH+15)@(negedge m_clk);pause_s=0;
    drain(); sh=7;mh=3;source_mode=2;sink_mode=2;repeat(700)@(negedge s_clk);drain();
    sh=5;mh=5;source_mode=2;sink_mode=2;repeat(700)@(negedge s_clk);drain();
    source_mode=1;sink_mode=0;repeat(DEPTH+15)@(negedge s_clk);
    aw(16,0);reset_all(); // pending AW and pending stream payload discarded
    wd(32'hfeedbeef,15,0);reset_all(); // pending W discarded
    fork aw(16,0);wd(32'hffffffff,15,0);join
    wait(s_axil_bvalid);reset_all(); // unconsumed response flushed
    @(negedge s_clk);s_axil_arvalid=1;s_axil_araddr=0;
    do @(posedge s_clk);while(!s_axil_arready);
    @(negedge s_clk);s_axil_arvalid=0;wait(s_axil_rvalid);reset_all();
    expect_reg(16,0);expect_reg(12,0);expect_reg(4,1);
    source_mode=2;sink_mode=2;repeat(300)@(negedge s_clk);drain();expect_reg(12,32'(nw-epoch));
    if(aw_count!=b_count || w_count!=b_count || ar_count!=r_count)$fatal(1,"register transaction accounting");
    if(nw<100 || stalls==0 || max_run<2) $fatal(1,"insufficient activity");
    $display("PASS writes=%0d consumed=%0d discarded=%0d axil_checks=%0d stalled_output_cycles=%0d max_consecutive_reads=%0d min_latency_ns=%0d max_latency_ns=%0d",nw,nr-discarded,discarded,axi_checks,stalls,max_run,min_latency,max_latency);
    $finish;
  end
  initial begin #1000000;$fatal(1,"watchdog timeout");end
endmodule
