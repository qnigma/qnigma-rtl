module qnigma_alu_core 
#(
  parameter int N  = 16,               // number of multipliers
  parameter int K  = 16,               // multipleir width
  parameter int WA = N*K,              // adder operand width. Default is same as multiplier. can be larger
  parameter int A  = 2*K+$clog2(K),    // accumulator width. each full addition may generate carry
  parameter int L  = 32                // load interface width

  // parameter int A = 2*K+$clog2(W/K) // accumulator width
)
( 
  input  logic                  clk,
  input  logic                  rst,
  input  logic [WA-1:0]         opa, // operand A
  input  logic [WA-1:0]         opb, // operand B
  input  logic                  mul, // operation is multiply
  input  logic                  add, // operation is add
  input  logic                  sub, // operation is subtract
  input  logic                  cal, // calculate A + B
  output logic [2*N-1:0][K-1:0] res, // result
  output logic                  ovf, // result is ovfative. valid when rdy
  output logic                  eql, // a equal b. vaiud when rdy
  output logic                  don  // ready
);
  parameter int AN = (WA / (2*K)) + 1; // Number of adders for add/sub operation

  parameter int CARRY_LAST = AN-2; // Last carry index for subtract operation

  logic cur_mul; // current operation is multiplication
  logic cur_add; // current operation is addition
  logic cur_sub; // current operation is subtraction

  logic [N-1 :0][  K-1:0] mul_a;
  logic [N-1 :0][  K-1:0] mul_b;
  logic [N-1 :0][2*K-1:0] mul_q;

  // Adder inputs
  logic [N-1:0][  A-1:0] add_a;
  logic [N-1:0][  A-1:0] add_b;

  logic [N-2:0][  A  :0] add_q;
  logic [N-1:0]          car;

  logic         [  A+1:0] add0_q; // first adder output
  logic         [A-K-1:0] car0;   // first carry

  logic [  N-1:0][A-1:0] acc;
  logic [3*N:0][A-1:0] acc_r; // cccumulator register. todo size

  logic [$clog2(2*N+1)-1:0] ctr;

  logic add_sel;

  logic [WA-1:0] opa_reg;
  logic [WA-1:0] opb_reg;
  
  always_ff @ (posedge clk) don <= !don && run && ((cur_mul) ? ctr == 2*N : ctr == 2); // todo check constants
  assign mul_a = opa_reg[N*K-1:0];
  assign mul_b = opb_reg[N*K-1:0];

  // always_ff @ (posedge clk) cal <= cal;
  logic run;

  always_ff @ (posedge clk) if (cal) run <= 1; else if (don) run <= 0;
  logic [1:0] upd_ctr;
  always_ff @ (posedge clk) if (cal) upd_ctr <= 0; else if (run) upd_ctr <= upd_ctr[1] ? 0 : upd_ctr + 1;

  // always_ff @ (posedge clk) if (cal) acc_r <= 0; else 

  always_ff @ (posedge clk) begin
    if (cal) begin // received add request
      add_sel <= 0;
      acc_r   <= 0;
      ctr     <= 0;
      cur_mul <= mul;
      cur_add <= add;
      cur_sub <= sub;
      opa_reg <= opa;
      opb_reg <= opb;
    end
    else if (run) begin // calculating...
      if (upd_ctr[1]) ctr <= ctr + 1;
      if (upd_ctr == 2) acc_r <= {acc, acc_r[N*2-1:0]} >> A;
      if (upd_ctr == 2 && cur_mul) opb_reg <= opb_reg >> K; // shift only if multiplying
    end
    else if (!run) begin
      ctr <= 0;
    end
  end

  // Select result output
  // Result is taken from different  	parts of 
  always_ff @ (posedge clk) begin
    if (cur_mul)
       for (int i = 0; i < 2*N; i = i + 1) res[i] <= acc_r[i][K-1:0];
    else begin
       for (int i = 0; i < (N/2)+1; i = i + 1) res[1+2*i-:2] <= add_q[i][2*K-1:0];
       for (int j = N + 1; j < 2*N; j = j + 1) res[j]        <= 0;
    end
  end

  genvar gv;

  generate
    for (gv = 0; gv < N; gv = gv + 1) begin : gen_mul
      qnigma_mul #(
        .W (K),
        .R (0)
      ) mul_inst (
        .clk (clk      ),
        .a   (mul_a[gv]),
        .b   (mul_b[0 ]),
        .q   (mul_q[gv])
      );
    end
  endgenerate

  logic [N-1:0] gen;
  logic [N-1:0] pro;

  generate
    for (gv = 1; gv < N; gv = gv + 1) begin : gen_add
      qnigma_add_cla #(
        .WA (A),
        .WL (2*K),
        .R (1)
      ) add_inst (
        .clk (clk        ),
        .a   (add_a[gv  ]),
        .b   (add_b[gv  ]),
        .q   (add_q[gv-1]),
        .g   (gen  [gv-1]),
        .p   (pro  [gv-1]),
        .c   (car  [gv-1]) // carry[0] goes into cur_add[1]
      );
    end
  endgenerate

  // adder for the first limb
  // has wide carry 
  qnigma_add #(
    .W (A),
    .C (A-K),
    .R (1)
  ) add0_inst (
    .clk (clk      ),
    .a   (add_a [0]),
    .b   (add_b [0]),
    .c   (car0  ),
    .q   (add0_q)
  );

  qnigma_cla #(
    .N (N)
  ) cla_inst (
    .clk (clk),
    .e   (~cur_mul), //
    .g   (gen),
    .p   (pro),
    .c   (car[N-1:0]),
    .ci  (cur_sub)
  );

  always_comb begin
    car0 = acc_r[2*N-1][A-1:K]; // First adder carry is current acc_r carry output
  end

  // multiplex carries
  always_ff @ (posedge clk) begin
    if      (cur_mul) ovf <= 0;
    else if (cur_add) ovf <=  add_q[CARRY_LAST][2*K];
    else              ovf <= ~add_q[CARRY_LAST][2*K];
  end

  always_comb begin
    acc[0] = add0_q[A-1:0];
    for (int i = 1; i < N; i = i + 1)
      acc[i] = add_q[i-1][A-1:0]; // Adder output
  end

  // always_comb begin
  //   add_a[0] = acc_r[2*N];
  //   add_b[0] = mul_q[0];
  //   if      (cur_mul) begin
  //     for (int i = 1; i < N; i = i + 1) begin
  //       add_a[i] = acc_r[i+2*N]; // accumulator register
  //       add_b[i] = mul_q[i];     // multiplier output
  //     end
  //   end
  //   else if (cur_add) begin
  //     for (int i = 0; i < AN-1; i = i + 1) begin
  //       add_a[i+1] = opa_reg[2*K*i+:2*K];
  //       add_b[i+1] = opb_reg[2*K*i+:2*K];
  //     end
  //     for (int i = AN; i < N; i = i + 1) begin
  //      add_a[i] = 0;
  //      add_b[i] = 0;
  //     end
  //   end
  //   else begin // cur_sub
  //     for (int i = 0; i < AN-1; i = i + 1) begin
  //       add_a[i+1] = {{(A-2*K){1'b0}},  opa_reg[2*K*i+:2*K]};
  //       add_b[i+1] = {{(A-2*K){1'b0}}, ~opb_reg[2*K*i+:2*K]};
  //     end
  //     for (int i = AN; i < N; i = i + 1) begin
  //       add_a[i] = 0;
  //       add_b[i] = 0;
  //     end
  //   end
  // end


  always_ff @ (posedge clk) begin
    if      (cur_mul) begin
      if (upd_ctr == 0) add_a[0] <= acc_r[2*N];
      if (upd_ctr == 0) add_b[0] <= mul_q[0];
      for (int i = 1; i < N; i = i + 1) begin
        if (upd_ctr == 0) add_a[i] <= acc_r[i+2*N]; // accumulator register
        if (upd_ctr == 0) add_b[i] <= mul_q[i];     // multiplier output
      end
    end
    else if (cur_add) begin
      add_a[0] <= acc_r[2*N];
      add_b[0] <= mul_q[0];
      for (int i = 0; i < AN-1; i = i + 1) begin
        add_a[i+1] <= opa_reg[2*K*i+:2*K];
        add_b[i+1] <= opb_reg[2*K*i+:2*K];
      end
      for (int i = AN; i < N; i = i + 1) begin
       add_a[i] <= 0;
       add_b[i] <= 0;
      end
    end
    else begin // cur_sub
      add_a[0] <= acc_r[2*N];
      add_b[0] <= mul_q[0];
      for (int i = 0; i < AN-1; i = i + 1) begin
        add_a[i+1] <= {{(A-2*K){1'b0}},  opa_reg[2*K*i+:2*K]};
        add_b[i+1] <= {{(A-2*K){1'b0}}, ~opb_reg[2*K*i+:2*K]};
      end
      for (int i = AN; i < N; i = i + 1) begin
        add_a[i] <= 0;
        add_b[i] <= 0;
      end
    end
  end

endmodule
