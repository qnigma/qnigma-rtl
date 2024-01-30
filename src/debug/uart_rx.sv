module uart_rx #(
  parameter int   DATA_BITS = 8,
  parameter int   STOP_BITS = 1,
  parameter [1:0] PARITY_MODE  = 0, // 0: None, 1: Even, 2: Odd
  parameter int   BAUD_RATE = 115200,
  parameter int   CLK_FREQ  = 50000000
) (
  input  logic       clk,
  input  logic       rst,
  input  logic       rx,
  output logic [7:0] dat,
  output logic       val
);

  // Calculate the number of clock cycles per bit based on the baud rate and clock frequency
  localparam int BAUD_TICKS = CLK_FREQ / BAUD_RATE;
  localparam int SAMPLE_POINT = BAUD_TICKS / 2; // Mid-point for sampling

  // State Machine States
  typedef enum {
    IDLE,
    START,
    DATA,
    PARITY,
    STOP
  } state_t;

  state_t state;

  // Internal Variables
  logic [31:0] ctr; // Counts the cycles to determine when to sample
  logic [5:0] bit_ctr; // Counts the received bits
  logic [DATA_BITS-1:0] shift_reg; // Temporary storage for received bits
  logic par; // Calculated parity bit

  // State Machine for Receiving Data
  always_ff @(posedge clk) begin
    if (rst) begin
      state   <= IDLE;
      val     <= 0;
      ctr     <= 0;
      bit_ctr <= 0;
      dat     <= 0;
    end
	else begin
      case (state)
        IDLE: begin
          bit_ctr <= 0;
          ctr     <= 0;
		      val     <= 0;
          if (rx == 0) state <= START;
        end
        START: begin
          if (ctr == SAMPLE_POINT) state <= (rx) ? IDLE : DATA;
        end
        DATA: begin
          if (ctr == SAMPLE_POINT) shift_reg <= {shift_reg[DATA_BITS-2:0], rx};
          if (ctr == BAUD_TICKS-1) begin
            bit_ctr <= bit_ctr + 1;
            if (bit_ctr == DATA_BITS) state <= (PARITY_MODE != 0) ? PARITY : STOP;
          end
        end
        PARITY: begin
          if (ctr == BAUD_TICKS-1) begin
            // Calculate expected parity based on received data bits
            par   <= (PARITY_MODE == 1) ? ~^shift_reg : ^shift_reg;
            state <= (PARITY_MODE != 0 && par != rx) ? IDLE : STOP;
          end
        end
        STOP: begin
          if (ctr == SAMPLE_POINT) begin
            state <= IDLE;
            if (rx) begin
              dat <= shift_reg;
              val <= 1;
			      end
          end
        end
        default: state <= IDLE;
      endcase
      if (state != IDLE) begin
        ctr <= (state == IDLE || ctr == BAUD_TICKS-1) ? 0 : ctr + 1;
      end
    end
  end

endmodule