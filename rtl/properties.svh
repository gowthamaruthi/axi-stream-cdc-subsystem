  reg [1:0] f_history=0;
  always @($global_clock) begin
    if(f_history<2) f_history <= f_history+1;
    if(f_history==2 && wr_rst_n && $past(wr_rst_n)) begin
      assert(wr_gray == (wr_bin ^ (wr_bin >> 1)));
      assert(rd_gray == (rd_bin ^ (rd_bin >> 1)));
      if($rose(wr_clk)) begin
        assert(wr_bin == $past(wr_bin) + PTR_W'($past(wr_en && !full)));
        assert($onehot0(wr_gray ^ $past(wr_gray)));
      end else assert(wr_bin == $past(wr_bin));
      if($rose(rd_clk)) begin
        assert(rd_bin == $past(rd_bin) + PTR_W'($past(rd_en && !empty)));
        assert($onehot0(rd_gray ^ $past(rd_gray)));
      end else assert(rd_bin == $past(rd_bin));
    end
  end
`ifndef LOCAL_ONLY
  // A symbolic memory address tracks data without constraining input data.
  (* anyconst *) reg [ADDR_W-1:0] watched;
  reg [WIDTH-1:0] expected_word;
  reg word_valid=0;
  always @(posedge wr_clk) begin
    if(!wr_rst_n) word_valid <= 0;
    else if(wr_en && !full && wr_bin[ADDR_W-1:0]==watched) begin
      expected_word <= wr_data;
      word_valid <= 1;
    end
  end
  wire [PTR_W-1:0] occupancy = wr_bin-rd_bin;
  reg seen_full=0, seen_write=0;
  always @($global_clock) begin
    if(wr_rst_n && rd_rst_n) begin
      assert(occupancy <= DEPTH);
      if(!empty) begin
        assert(occupancy != 0);
        if(rd_bin[ADDR_W-1:0]==watched) begin
          assert(word_valid);
          assert(rd_data == expected_word);
        end
      end
      if(!full) assert(occupancy < DEPTH);
      if(full) seen_full <= 1;
      if(wr_bin!=0) seen_write <= 1;
      cover(full);
      cover(seen_full && empty && rd_bin!=0);
      cover(seen_write && wr_bin==0 && rd_bin!=0);
      cover(wr_bin!=0 && rd_bin!=0);
    end
  end
`endif
