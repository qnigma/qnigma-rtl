// Generic Gray code dual-clock FIFO
module qnigma_fifo_dc #(
  parameter ADDR_WIDTH = 3,
  parameter DATA_WIDTH = 32
)
(
  input  logic clk_w,
  input  logic rst_w,
  input  logic clk_r,
  input  logic rst_r,
  input  logic write,
  input  logic [DATA_WIDTH-1:0] data_in,
  input  logic read,
  output logic [DATA_WIDTH-1:0] data_out,
  output logic valid_out,
  output logic full,
  output logic empty
);

reg [ADDR_WIDTH-1:0] wr_addr;
reg [ADDR_WIDTH-1:0] wr_addr_gray;
reg [ADDR_WIDTH-1:0] wr_addr_gray_rd;
reg [ADDR_WIDTH-1:0] wr_addr_gray_rd_r;
reg [ADDR_WIDTH-1:0] rd_addr;
reg [ADDR_WIDTH-1:0] rd_addr_gray;
reg [ADDR_WIDTH-1:0] rd_addr_gray_wr;
reg [ADDR_WIDTH-1:0] rd_addr_gray_wr_r;

function [ADDR_WIDTH-1:0] gray_conv;
  input [ADDR_WIDTH-1:0] in;
  begin
    gray_conv = {in[ADDR_WIDTH-1], in[ADDR_WIDTH-2:0] ^ in[ADDR_WIDTH-1:1]};
  end
endfunction

always @ (posedge clk_w or posedge rst_w) begin
  if (rst_w) begin
    wr_addr <= 0;
    wr_addr_gray <= 0;
  end else if (write) begin
    wr_addr <= wr_addr + 1'b1;
    wr_addr_gray <= gray_conv(wr_addr + 1'b1);
  end
end

// synchronize read address to write clock domain
always @ (posedge clk_w) begin
  rd_addr_gray_wr   <= rd_addr_gray;
  rd_addr_gray_wr_r <= rd_addr_gray_wr;
end

always @ (posedge clk_w or posedge rst_w)
  if (rst_w)
    full <= 0;
  else if (write && !full)
    full <= gray_conv (wr_addr + 2) == rd_addr_gray_wr_r;
  else
    full <= full & (gray_conv (wr_addr + 1'b1) == rd_addr_gray_wr_r);

always @ (posedge clk_r or posedge rst_r) begin
  if (rst_r) begin
    rd_addr      <= 0;
    rd_addr_gray <= 0;
  end else if (read && !empty) begin
    rd_addr      <= rd_addr + 1'b1;
    rd_addr_gray <= gray_conv(rd_addr + 1'b1);
  end
end

// synchronize write address to read clock domain
always @ (posedge clk_r) begin
  wr_addr_gray_rd   <= wr_addr_gray;
  wr_addr_gray_rd_r <= wr_addr_gray_rd;
end

always @ (posedge clk_r or posedge rst_r)
  if (rst_r)
    empty <= 1'b1;
  else if (read && !empty)
    empty <= gray_conv (rd_addr + 1) == wr_addr_gray_rd_r;
  else
    empty <= empty & (gray_conv (rd_addr) == wr_addr_gray_rd_r);

// generate dual clocked memory
reg [DATA_WIDTH-1:0] mem[(1<<ADDR_WIDTH)-1:0];

always @(posedge clk_r) begin
  if (read && !empty) data_out <= mem[rd_addr];
  valid_out <= (read && !empty);
end
always @(posedge clk_w) if (write && !full) mem[wr_addr] <= data_in;

endmodule : qnigma_fifo_dc
