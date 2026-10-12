// =============================================================================
// Module  : async_fifo
// Author  : Gowtham Kumar Maruthi
// GitHub  : github.com/gowthamaruthi/async-fifo-formal-sv
// Desc    : Parameterized dual-clock asynchronous FIFO with Gray-coded CDC.
//           Combinational full/empty flags. Combinational read port.
//           Requests at full/empty are ignored. Coordinated reset required.
// =============================================================================

`timescale 1ns / 1ps

module async_fifo #(
  parameter int DEPTH = 16,    // Must be a power of 2, minimum 4
  parameter int WIDTH = 8      // Data width
) (
  // ──── Write clock domain ────────────────────────────────────────────────
  input  logic             wr_clk,
  input  logic             wr_rst_n,   // Active-low async reset
  input  logic             wr_en,
  input  logic [WIDTH-1:0] wr_data,
  output logic             full,

  // ──── Read clock domain ─────────────────────────────────────────────────
  input  logic             rd_clk,
  input  logic             rd_rst_n,   // Active-low async reset
  input  logic             rd_en,
  output logic [WIDTH-1:0] rd_data,
  output logic             empty
);

  localparam int ADDR_W = $clog2(DEPTH);  // address bits
  localparam int PTR_W  = ADDR_W + 1;    // pointer width (extra MSB = wrap bit)

  initial begin
    if (WIDTH < 1) $fatal(1, "async_fifo: WIDTH must be >= 1");
    if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0)
      $fatal(1, "async_fifo: DEPTH must be power-of-2 and >= 4 (got %0d)", DEPTH);
  end

  // ──── Shared memory ─────────────────────────────────────────────────────
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  // ========================================================================
  // Write clock domain
  // ========================================================================

  logic [PTR_W-1:0] wr_bin,     wr_gray;
  logic [PTR_W-1:0] wr_bin_inc;

  assign wr_bin_inc = wr_bin + 1'b1;   // next binary pointer (pre-computed)

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_bin  <= '0;
      wr_gray <= '0;
    end else if (wr_en && !full) begin
      wr_bin  <= wr_bin_inc;
      wr_gray <= wr_bin_inc ^ (wr_bin_inc >> 1);   // binary-to-gray
    end
  end

  always_ff @(posedge wr_clk)
    if (wr_rst_n && wr_en && !full)
      mem[wr_bin[ADDR_W-1:0]] <= wr_data;

  // ── Read pointer declared here so the 2-FF synchronizer below can reference it
  logic [PTR_W-1:0] rd_bin,     rd_gray;
  logic [PTR_W-1:0] rd_bin_inc;

  // 2-FF synchronizer: rd_gray ──► write domain
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] rd_gray_q1, rd_gray_sync;
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rd_gray_q1   <= '0;
      rd_gray_sync <= '0;
    end else begin
      rd_gray_q1   <= rd_gray;
      rd_gray_sync <= rd_gray_q1;
    end
  end

  // Full: wr_gray matches rd_gray_sync with top-2 bits inverted
  // (Cummings 2002 dual-MSB method — detects write pointer lapping read by DEPTH)
  assign full = (wr_gray == {~rd_gray_sync[PTR_W-1],
                             ~rd_gray_sync[PTR_W-2],
                              rd_gray_sync[PTR_W-3:0]});

  // ========================================================================
  // Read clock domain
  // ========================================================================

  assign rd_bin_inc = rd_bin + 1'b1;

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_bin  <= '0;
      rd_gray <= '0;
    end else if (rd_en && !empty) begin
      rd_bin  <= rd_bin_inc;
      rd_gray <= rd_bin_inc ^ (rd_bin_inc >> 1);
    end
  end

  // Combinational read port: data valid whenever !empty
  assign rd_data = mem[rd_bin[ADDR_W-1:0]];

  // 2-FF synchronizer: wr_gray ──► read domain
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wr_gray_q1, wr_gray_sync;
  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wr_gray_q1   <= '0;
      wr_gray_sync <= '0;
    end else begin
      wr_gray_q1   <= wr_gray;
      wr_gray_sync <= wr_gray_q1;
    end
  end

  // Empty: rd_gray equals synchronized wr_gray
  assign empty = (rd_gray == wr_gray_sync);


`ifdef FORMAL
`include "properties.svh"
`endif
endmodule
