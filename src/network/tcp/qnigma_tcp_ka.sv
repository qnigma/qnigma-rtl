module qnigma_tcp_ka
  import
    qnigma_pkg::*;
(
  input  logic clk,
  input  logic tick_s,
  input  logic rst,
  input  tcb_t tcb,
  input  logic flt_src_port,
  input  logic flt_dst_port,
  input  logic rcv,
  output logic send, // Send event
  input  logic sent,
  output logic dcn  // Force disconnect
);

  logic [$clog2(TCP_KEEPALIVE_PERIOD_S+1)-1:0] timer;
  logic [$clog2(TCP_KEEPALIVE_TRIES+2)-1:0]  tries;
  
  logic int_rst;
  
  always_ff @ (posedge clk) if (rst) int_rst <= 1; else int_rst <= (tcb.status != tcp_connected);

  always_ff @ (posedge clk) begin
    if (int_rst) begin
      timer   <= 0; 
      tries   <= 0; 
      send    <= 0;
    end
    else begin
      if (rcv && flt_src_port && flt_dst_port) begin // packet received for current connection
        timer <= 0; // if any packet arrives, restart ack timeout counter 
        tries <= 0; // reset keep-alive tries (connection is definitely active)
      end
      else if (tick_s) begin // Count every second (slow process)
        if (timer == TCP_KEEPALIVE_PERIOD_S - 1) begin
          send <= 1;
          timer <= 0;
          if (tries == TCP_KEEPALIVE_TRIES) begin
            tries <= tries; // Stop counting 
          end
          else tries <= tries + 1;
        end
        else begin
          timer <= timer + 1;
        end
      end
      else if (sent) send  <= 0; 
      // If there were TCP_KEEPALIVE_TRIES to send ka but 
      // no packets were received from remote host,
      // request tcp engine to disconnect
    end
  end

  // Disconnect condition for Keep-Alive timeout
  always_ff @ (posedge clk) dcn <= (tries == TCP_KEEPALIVE_TRIES); 

endmodule : qnigma_tcp_ka
