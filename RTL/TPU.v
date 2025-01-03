module TPU(
    clk,
    rst_n,

    in_valid,
    K,
    M,
    N,
    busy,

    A_wr_en,
    A_index,
    A_data_in,
    A_data_out,

    B_wr_en,
    B_index,
    B_data_in,
    B_data_out,

    C_wr_en,
    C_index,
    C_data_in,
    C_data_out
);


input clk;
input rst_n;
input            in_valid;
input  [8-1:0]   K;
input  [8-1:0]   M;
input  [8-1:0]   N;
output  reg      busy;

output             A_wr_en;
output   [16-1:0]  A_index;
output   [32-1:0]  A_data_in;
input    [32-1:0]  A_data_out;

output             B_wr_en;
output   [16-1:0]  B_index;
output   [32-1:0]  B_data_in;
input    [32-1:0]  B_data_out;

output             C_wr_en;
output   [16-1:0]  C_index;
output  [128-1:0]  C_data_in;
input   [128-1:0]  C_data_out;
 

reg [128-1:0] C_data_in;

//* Implement your design here 
localparam [1:0] S_INIT = 2'b00, 
                 S_CALC = 2'b01, 
                 S_DONE = 2'b10;

reg [1:0] curr_state, next_state;
wire done;
wire load_done, calc_done, store_done;
wire calc_part_done, calc_col_done, calc_all_done;
wire [32-1:0] A_data_out_calc, B_data_out_calc;

// finite state machine
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        curr_state <= S_INIT;
    end
    else begin 
        curr_state <= next_state;            
    end
end

always @(*) begin 
    case (curr_state)
        S_INIT: begin 
            next_state <= (in_valid) ? S_CALC : S_INIT;
        end
        S_CALC: begin 
            next_state <= (done) ? S_DONE : S_CALC;
        end
        S_DONE: begin 
            next_state <= S_INIT;
        end
        default: begin 
            next_state <= S_INIT;
        end
    endcase
end

always @(*) begin 
    if (!rst_n) begin 
        busy <= 1'b0;
    end
    else if (curr_state == S_CALC) begin 
        busy <= 1'b1;
    end
    else if (curr_state == S_INIT || curr_state == S_DONE) begin 
        busy <= 1'b0;
    end
end

reg [16-1:0] size_K, size_M, size_N;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        size_K <= 16'b0;
        size_M <= 16'b0;
        size_N <= 16'b0;
    end
    else if (in_valid) begin 
        size_K <= K;
        size_M <= M;
        size_N <= N;
    end
    else begin 
        size_K <= size_K;
        size_M <= size_M;
        size_N <= size_N;
    end
end

reg [16-1:0] counter_A, counter_B, counter_C;
reg [16-1:0] counter_A_max, counter_B_max, counter_C_max;
reg [16-1:0] counter_A_row, counter_B_col;
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        counter_A_max <= 16'b0;
        counter_B_max <= 16'b0;
        counter_C_max <= 16'b0;
    end
    else if (in_valid) begin
        if (M[1:0] !== 2'b00) begin 
            counter_A_max <= K * ((M >> 2) + 1);
        end
        else begin
            counter_A_max <= K * (M >> 2);
        end
        if (N[1:0] != 2'b00) begin 
            counter_B_max <= K * ((N >> 2) + 1);
        end
        else begin 
            counter_B_max <= K * (N >> 2);
        end
        if (N[1:0] != 2'b00) begin 
            counter_C_max <= M * ((N >> 2) + 1);
        end
        else begin 
            counter_C_max <= M * (N >> 2);
        end
    end
    else begin 
        counter_A_max <= counter_A_max;
        counter_B_max <= counter_B_max;
        counter_C_max <= counter_C_max;
    end
end

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        counter_A <= 16'b0;
    end
    else if (calc_col_done && store_done) begin 
        counter_A <= 16'b0;
    end
    else if (calc_part_done && store_done) begin
        counter_A <= counter_A_row * size_K;
    end
    else if (counter_A >= counter_A_max) begin 
        counter_A <= counter_A;
    end
    else if (!load_done && curr_state == S_CALC) begin 
        counter_A <= counter_A + 'd1;
    end
end

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        counter_B <= 16'b0;
    end
    else if (calc_col_done && store_done) begin 
        counter_B <= counter_B_col * size_K;
    end
    else if (calc_part_done && store_done) begin 
        counter_B <= (counter_B_col - 1) * size_K;
    end
    else if (counter_B >= counter_B_max) begin 
        counter_B <= counter_B;
    end
    else if (!load_done && curr_state == S_CALC) begin 
        counter_B <= counter_B + 'd1;
    end
end

assign A_index = counter_A;
assign B_index = counter_B;


always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        counter_A_row <= 'd1;
    end
    else if (calc_col_done && store_done) begin 
        counter_A_row <= 'd1;
    end
    else if (calc_part_done && store_done) begin 
        counter_A_row <= counter_A_row + 'd1;
    end
    else begin 
        counter_A_row <= counter_A_row;
    end
end

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        counter_B_col <= 'd1;
    end
    else if (calc_col_done && store_done) begin 
        counter_B_col <= counter_B_col + 'd1;
    end
    else begin 
        counter_B_col <= counter_B_col;
    end
end

assign done = (counter_A >= counter_A_max) && (counter_B >= counter_B_max) && (counter_C >= counter_C_max);
assign calc_part_done = (counter_A >= counter_A_row * size_K) && (counter_B >= counter_B_col * size_K) && calc_done;
assign calc_col_done = (counter_A >= counter_A_max) && (counter_B >= counter_B_col * size_K) && calc_done;
assign calc_all_done = (counter_A >= counter_A_max) && (counter_B >= counter_B_max) && calc_done;

reg [16-1:0] counter_load;
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid || (calc_done && !calc_part_done && !calc_col_done && !calc_all_done)) begin 
        counter_load <= 3'b0;
    end
    else if (counter_load >= size_K) begin 
        counter_load <= counter_load;
    end
    else if (!load_done && curr_state == S_CALC) begin 
        counter_load <= counter_load + 'd1;
    end
end

assign load_done = (counter_load >= size_K);

integer i, j;
reg [8-1:0] A_data_buf [0:3][0:3];
reg [8-1:0] B_data_buf [0:3][0:3];

assign A_data_out_calc = (counter_A >= counter_A_row * size_K) ? 32'b0 : A_data_out;
assign B_data_out_calc = (counter_B >= counter_B_col * size_K) ? 32'b0 : B_data_out;

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        for (i = 0; i < 4; i = i + 1) begin 
            for (j = 0; j < 4; j = j + 1) begin 
                A_data_buf[i][j] <= 8'b0;  
            end
        end
    end
    else if (!calc_done && curr_state == S_CALC) begin 
        A_data_buf[0][0] <= (A_data_out_calc[31:24] === 8'bZZ) ? 8'b0 : A_data_out_calc[31:24];
        A_data_buf[0][1] <= A_data_buf[1][1]; 
        A_data_buf[0][2] <= A_data_buf[1][2];  
        A_data_buf[0][3] <= A_data_buf[1][3];

        A_data_buf[1][1] <= (A_data_out_calc[23:16] === 8'bZZ) ? 8'b0 : A_data_out_calc[23:16];
        A_data_buf[1][2] <= A_data_buf[2][2];
        A_data_buf[1][3] <= A_data_buf[2][3];

        A_data_buf[2][2] <= (A_data_out_calc[15: 8] === 8'bZZ) ? 8'b0 : A_data_out_calc[15: 8];
        A_data_buf[2][3] <= A_data_buf[3][3];

        A_data_buf[3][3] <= (A_data_out_calc[7 : 0] === 8'bZZ) ? 8'b0 : A_data_out_calc[7 : 0];
    end
end

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        for (i = 0; i < 4; i = i + 1) begin 
            for (j = 0; j < 4; j = j + 1) begin 
                B_data_buf[i][j] <= 8'b0;
            end
        end
    end
    else if (!calc_done && curr_state == S_CALC) begin 
        B_data_buf[0][0] <= (B_data_out_calc[31:24] === 8'bZZ) ? 8'b0 : B_data_out_calc[31:24];
        B_data_buf[0][1] <= B_data_buf[1][1];
        B_data_buf[0][2] <= B_data_buf[1][2];
        B_data_buf[0][3] <= B_data_buf[1][3];

        B_data_buf[1][1] <= (B_data_out_calc[23:16] === 8'bZZ) ? 8'b0 : B_data_out_calc[23:16];
        B_data_buf[1][2] <= B_data_buf[2][2];
        B_data_buf[1][3] <= B_data_buf[2][3];

        B_data_buf[2][2] <= (B_data_out_calc[15: 8] === 8'bZZ) ? 8'b0 : B_data_out_calc[15: 8];
        B_data_buf[2][3] <= B_data_buf[3][3];

        B_data_buf[3][3] <= (B_data_out_calc[7 : 0] === 8'bZZ) ? 8'b0 : B_data_out_calc[7 : 0];
    end
end

reg [16-1:0] counter_calc;
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid || (calc_done && !calc_part_done && !calc_col_done && !calc_all_done)) begin 
        counter_calc <= 'd0;
    end
    else if (counter_calc >= (size_K + 'd6)) begin 
        counter_calc <= counter_calc;
    end
    else if ((counter_load >= 'd1) && !calc_done && curr_state == S_CALC) begin 
        counter_calc <= counter_calc + 'd1;
    end
end

assign calc_done = (counter_calc >= (size_K + 'd6)); 

wire [8-1:0] pe_right_out_1_1, pe_right_out_1_2, pe_right_out_1_3, pe_right_out_1_4;
wire [8-1:0] pe_right_out_2_1, pe_right_out_2_2, pe_right_out_2_3, pe_right_out_2_4;
wire [8-1:0] pe_right_out_3_1, pe_right_out_3_2, pe_right_out_3_3, pe_right_out_3_4;
wire [8-1:0] pe_right_out_4_1, pe_right_out_4_2, pe_right_out_4_3, pe_right_out_4_4;

wire [8-1:0] pe_bottom_out_1_1, pe_bottom_out_1_2, pe_bottom_out_1_3, pe_bottom_out_1_4;
wire [8-1:0] pe_bottom_out_2_1, pe_bottom_out_2_2, pe_bottom_out_2_3, pe_bottom_out_2_4;
wire [8-1:0] pe_bottom_out_3_1, pe_bottom_out_3_2, pe_bottom_out_3_3, pe_bottom_out_3_4;
wire [8-1:0] pe_bottom_out_4_1, pe_bottom_out_4_2, pe_bottom_out_4_3, pe_bottom_out_4_4;

wire [32-1:0] pe_mult_out_1_1, pe_mult_out_1_2, pe_mult_out_1_3, pe_mult_out_1_4;
wire [32-1:0] pe_mult_out_2_1, pe_mult_out_2_2, pe_mult_out_2_3, pe_mult_out_2_4;
wire [32-1:0] pe_mult_out_3_1, pe_mult_out_3_2, pe_mult_out_3_3, pe_mult_out_3_4;
wire [32-1:0] pe_mult_out_4_1, pe_mult_out_4_2, pe_mult_out_4_3, pe_mult_out_4_4;

// PE declaration
assign pe_in_valid = !calc_done && curr_state == S_CALC;
assign flush = calc_part_done && store_done;
PE pe_calc_1_1(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(B_data_buf[0][0]),
    .left_data_in(A_data_buf[0][0]),
    .bottom_data_out(pe_bottom_out_1_1),
    .right_data_out(pe_right_out_1_1),
    .mult_data_out(pe_mult_out_1_1)
);

PE pe_calc_1_2(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(B_data_buf[0][1]),
    .left_data_in(pe_right_out_1_1),
    .bottom_data_out(pe_bottom_out_1_2),
    .right_data_out(pe_right_out_1_2),
    .mult_data_out(pe_mult_out_1_2)
);

PE pe_calc_1_3(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(B_data_buf[0][2]),
    .left_data_in(pe_right_out_1_2),
    .bottom_data_out(pe_bottom_out_1_3),
    .right_data_out(pe_right_out_1_3),
    .mult_data_out(pe_mult_out_1_3)
);

PE pe_calc_1_4(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(B_data_buf[0][3]),
    .left_data_in(pe_right_out_1_3),
    .bottom_data_out(pe_bottom_out_1_4),
    .right_data_out(pe_right_out_1_4),
    .mult_data_out(pe_mult_out_1_4)
);

PE pe_calc_2_1(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),  
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_1_1),
    .left_data_in(A_data_buf[0][1]),
    .bottom_data_out(pe_bottom_out_2_1),
    .right_data_out(pe_right_out_2_1),
    .mult_data_out(pe_mult_out_2_1)
);

PE pe_calc_2_2(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_1_2),
    .left_data_in(pe_right_out_2_1),
    .bottom_data_out(pe_bottom_out_2_2),
    .right_data_out(pe_right_out_2_2),
    .mult_data_out(pe_mult_out_2_2)    
);

PE pe_calc_2_3(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_1_3),
    .left_data_in(pe_right_out_2_2),
    .bottom_data_out(pe_bottom_out_2_3),
    .right_data_out(pe_right_out_2_3),
    .mult_data_out(pe_mult_out_2_3)
);

PE pe_calc_2_4(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_1_4),
    .left_data_in(pe_right_out_2_3),
    .bottom_data_out(pe_bottom_out_2_4),
    .right_data_out(pe_right_out_2_4),
    .mult_data_out(pe_mult_out_2_4)
);

PE pe_calc_3_1(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_2_1),
    .left_data_in(A_data_buf[0][2]),
    .bottom_data_out(pe_bottom_out_3_1),
    .right_data_out(pe_right_out_3_1),
    .mult_data_out(pe_mult_out_3_1)
);

PE pe_calc_3_2(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_2_2),
    .left_data_in(pe_right_out_3_1),
    .bottom_data_out(pe_bottom_out_3_2),
    .right_data_out(pe_right_out_3_2),
    .mult_data_out(pe_mult_out_3_2)
);

PE pe_calc_3_3(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_2_3),
    .left_data_in(pe_right_out_3_2),
    .bottom_data_out(pe_bottom_out_3_3),
    .right_data_out(pe_right_out_3_3),
    .mult_data_out(pe_mult_out_3_3)
);

PE pe_calc_3_4(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_2_4),
    .left_data_in(pe_right_out_3_3),
    .bottom_data_out(pe_bottom_out_3_4),
    .right_data_out(pe_right_out_3_4),
    .mult_data_out(pe_mult_out_3_4)
);

PE pe_calc_4_1(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_3_1),
    .left_data_in(A_data_buf[0][3]),
    .bottom_data_out(pe_bottom_out_4_1),
    .right_data_out(pe_right_out_4_1),
    .mult_data_out(pe_mult_out_4_1)
);

PE pe_calc_4_2(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_3_2),
    .left_data_in(pe_right_out_4_1),
    .bottom_data_out(pe_bottom_out_4_2),
    .right_data_out(pe_right_out_4_2),
    .mult_data_out(pe_mult_out_4_2)
);

PE pe_calc_4_3(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_3_3),
    .left_data_in(pe_right_out_4_2),
    .bottom_data_out(pe_bottom_out_4_3),
    .right_data_out(pe_right_out_4_3),
    .mult_data_out(pe_mult_out_4_3)
);

PE pe_calc_4_4(
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .in_valid(in_valid),
    .pe_in_valid(pe_in_valid),
    .top_data_in(pe_bottom_out_3_4),
    .left_data_in(pe_right_out_4_3),
    .bottom_data_out(pe_bottom_out_4_4),
    .right_data_out(pe_right_out_4_4),
    .mult_data_out(pe_mult_out_4_4)
);

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid) begin 
        counter_C <= 'd0;
    end
    else if (counter_C >= counter_C_max || counter_C >= (counter_B_col * size_M)) begin 
        counter_C <= counter_C;
    end
    else if (calc_part_done && !store_done && curr_state == S_CALC) begin 
        counter_C <= counter_C + 'd1;
    end
end

reg [2:0] counter_store;
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n || in_valid || store_done) begin 
        counter_store <= 'd0;
    end
    else if (counter_store >= 'd4 || counter_C >= (counter_B_col * size_M)) begin 
        counter_store <= counter_store;
    end
    else if (calc_part_done && !store_done && curr_state == S_CALC) begin 
        counter_store <= counter_store + 'd1;
    end
end


assign store_done = (counter_store >= 'd4) || (counter_C >= (counter_B_col * size_M));

assign C_wr_en = calc_part_done && !store_done;
assign C_index = counter_C;

always @(*) begin 
    if (counter_store == 'd0) begin 
        C_data_in <= {pe_mult_out_1_1, pe_mult_out_1_2, pe_mult_out_1_3, pe_mult_out_1_4};    
    end
    else if (counter_store == 'd1) begin 
        C_data_in <= {pe_mult_out_2_1, pe_mult_out_2_2, pe_mult_out_2_3, pe_mult_out_2_4};
    end
    else if (counter_store == 'd2) begin 
        C_data_in <= {pe_mult_out_3_1, pe_mult_out_3_2, pe_mult_out_3_3, pe_mult_out_3_4};
    end
    else if (counter_store == 'd3) begin 
        C_data_in <= {pe_mult_out_4_1, pe_mult_out_4_2, pe_mult_out_4_3, pe_mult_out_4_4};
    end
end

endmodule

module PE(
    clk,
    rst_n,
    flush,
    in_valid,
    pe_in_valid,
    top_data_in,
    left_data_in,
    bottom_data_out,
    right_data_out,
    mult_data_out
);

input clk; 
input rst_n;
input flush;
input in_valid;
input pe_in_valid;
input [8-1:0] top_data_in;
input [8-1:0] left_data_in;
output reg [8-1:0] bottom_data_out;
output reg [8-1:0] right_data_out;
output reg [32-1:0] mult_data_out;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || in_valid || flush) begin
        bottom_data_out <= 8'b0;
        right_data_out <= 8'b0;
        mult_data_out <= 32'b0;
    end
    else if (pe_in_valid) begin
        bottom_data_out <= top_data_in;
        right_data_out <= left_data_in;
        mult_data_out <= mult_data_out + top_data_in * left_data_in;
    end
end

endmodule
