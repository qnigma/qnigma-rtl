// Generic simple single-clock FIFO
module qnigma_fifo_sc #(
  parameter D = 16,
  parameter W = 16
)
(
  input  logic         rst,
  input  logic         clk,
  
  input  logic         write,
  input  logic [W-1:0] data_in,
  
  input  logic         read,
  output logic [W-1:0] data_out,
  output logic         valid_out,
  
  output logic         full,
  output logic         empty
);

logic [D-1:0] wr_addr;
logic [D-1:0] rd_addr;
logic [D:0]   diff;
logic [D:0]   wr_ctr;
logic [D:0]   rd_ctr;

assign diff = wr_ctr - rd_ctr;

assign empty = (diff == 0);
assign full = (diff[D] == 1);

always @ (posedge clk) begin
  if (rst) wr_ctr <= 0;
  else if (write && !full) wr_ctr <= wr_ctr + 1;
end

assign wr_addr[D-1:0] = wr_ctr[D-1:0];
assign rd_addr[D-1:0] = rd_ctr[D-1:0];

always @ (posedge clk) begin
  if (rst) begin
    rd_ctr <= 0;
  end
  else if (!empty) begin
    if (read) rd_ctr <= rd_ctr + 1;
  end
end

reg [W-1:0] mem[(1<<D)-1:0];

int i;

initial for (i = 0; i < 2**D; i = i + 1) mem[i] = '0;

always @ (posedge clk) begin
  if (read && !empty) data_out <= mem[rd_addr];
  valid_out <= (read && !empty);
  if (write && !full) mem[wr_addr] <= data_in;
end

endmodule : qnigma_fifo_sc
