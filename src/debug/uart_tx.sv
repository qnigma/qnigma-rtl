module uart_tx #(
  parameter int   DATA_BITS   = 8,
  parameter int   STOP_BITS   = 1,
  parameter [1:0] PARITY_MODE = 0, // 0: None, 1: Even, 2: Odd
  parameter int   BAUD_RATE   = 115200,
  parameter int   CLK_FREQ    = 100000000
) (
  input  logic       clk,
  input  logic       rst,
  output logic       tx,
  input  logic [7:0] dat,
  input  logic       val,
  output logic       cts
);

  // Calculate the number of clock cycles per bit
  localparam integer BAUD_TICKS = CLK_FREQ / BAUD_RATE;

  // State Machine States
  typedef enum {
    IDLE,
    START,
    DATA,
    PARITY_BIT,
    STOP
  } state_t;

  state_t state;

  // Internal Variables
  logic [31:0] ctr;
  logic [5:0] bit_ctr;
  logic [DATA_BITS-1:0] shift_reg;
  logic par;

  // Busy signal logic
  assign cts = (state == IDLE);

  // State Machine for Transmitting Data
  always_ff @(posedge clk) begin
    if (rst) begin
      state   <= IDLE;
      tx      <= 1;
      ctr     <= 0;
      bit_ctr <= 0;
    end
	else begin
      case (state)
        IDLE: begin
          if (val) begin
            state <= START;
            shift_reg <= dat;
            // Calculate parity bit if needed
            if (PARITY_MODE == 1) begin // Even parity
              par <= ~^dat;
            end else if (PARITY_MODE == 2) begin // Odd parity
              par <= ^dat;
            end
            ctr <= 0;
          end
        end
        START: begin
          tx <= 0; // Start bit is low
          if (ctr == BAUD_TICKS - 1) begin
            state <= DATA;
            ctr <= 0;
            bit_ctr <= 0;
          end
        end
        DATA: begin
          tx <= shift_reg[DATA_BITS-1];
          if (ctr == BAUD_TICKS - 1) begin
            shift_reg <= shift_reg << 1;
            ctr <= 0;
            bit_ctr <= bit_ctr + 1;
            if (bit_ctr == DATA_BITS - 1) begin
              state <= (PARITY_MODE != 0) ? PARITY_BIT : STOP;
            end
          end
        end
        PARITY_BIT: begin
          tx <= par;
          if (ctr == BAUD_TICKS - 1) begin
            state <= STOP;
            ctr <= 0;
          end
        end
        STOP: begin
          tx <= 1; // Stop bit(s) are high
          if (ctr == BAUD_TICKS-1) begin
            state <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
      if (state != IDLE) begin
        ctr <= (ctr == BAUD_TICKS-1) ? 0 : ctr + 1;
      end
    end
  end

endmodule
