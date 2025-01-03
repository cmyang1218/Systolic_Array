

`define CYCLE_TIME 20.0

`include "global_buffer.v"


module PATTERN(
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


output reg          clk;
output reg          rst_n;

output reg          in_valid;
output reg [7:0]    K;
output reg [7:0]    M;
output reg [7:0]    N;
input               busy;


input               A_wr_en;
input      [15:0]   A_index;
input      [31:0]   A_data_in;
output     [31:0]   A_data_out;

input               B_wr_en;
input      [15:0]   B_index;
input      [31:0]   B_data_in;
output     [31:0]   B_data_out;

input               C_wr_en;
input      [15:0]   C_index;
input      [127:0]  C_data_in;
output     [127:0]  C_data_out;


// parameter PATNUM = 1000;


integer PATNUM;

integer cycles;
integer total_cycles;
integer in_fd;
integer patcount;
integer nrow;
integer i, j, k;
integer err;
integer scanf;

real CYCLE;





reg [127:0] GOLDEN [65535:0];

reg [7:0] rbuf [3:0];
reg [31:0] goldenbuf [3:0];
reg [7:0] K_golden;
reg [7:0] M_golden;
reg [7:0] N_golden;



initial CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;



global_buffer #(
    .ADDR_BITS(16),
    .DATA_BITS(32)
) gbuff_A(
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(A_wr_en),
    .index(A_index),
    .data_in(A_data_in),
    .data_out(A_data_out)
);

global_buffer #(
    .ADDR_BITS(16),
    .DATA_BITS(32)
) gbuff_B(
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(B_wr_en),
    .index(B_index),
    .data_in(B_data_in),
    .data_out(B_data_out)
);


global_buffer #(
    .ADDR_BITS(16),
    .DATA_BITS(128)
) gbuff_C(
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(C_wr_en),
    .index(C_index),
    .data_in(C_data_in),
    .data_out(C_data_out)
);






initial begin

    rst_n = 1'b1;
    in_valid = 1'b0;
    K = 'bx;
    M = 'bx;
    N = 'bx;
    cycles = 0;
    total_cycles = 0;

    force clk = 0;


    reset_task;


    in_fd = $fopen("./TESTBENCH/input.txt", "r");

    //* PATNUM
    scanf = $fscanf(in_fd, "%d", PATNUM);

    for(patcount = 0; patcount < PATNUM; patcount = patcount + 1) begin

        //* read input
        read_KMN;
        read_A_Matrix;
        read_B_Matrix;
        read_golden;
    
        //* start to feed data
        repeat(3) @(negedge clk);

        in_valid = 1'b1;
        K = K_golden;
        M = M_golden;
        N = N_golden;
        @(negedge clk);

        in_valid = 1'b0;
        K = 'bx;
        M = 'bx;
        N = 'bx;

        wait_finished;
        
        golden_check;

        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32m Cycles: %3d\033[m", patcount ,cycles);
        total_cycles = total_cycles + cycles;
        cycles = 0;
        repeat(5) @(negedge clk);
    end

    YOU_PASS_task;
    $finish;

end


task reset_task ; begin

    #(3*`CYCLE_TIME); rst_n = 0;
    #(3*`CYCLE_TIME);

    if(busy !== 1'b0) begin
        $display("----------------------------------------------------------------");
        $display("                        Reset failed!                           ");
        $display("         Output signal should be 0 after initial RESET at %8t   ", $time);
        $display("----------------------------------------------------------------");
        #(100);
        $finish;
    end

    #(`CYCLE_TIME); rst_n = 1;
    release clk;
end endtask



task read_KMN; begin
    scanf = $fscanf(in_fd, "%h", K_golden);
    scanf = $fscanf(in_fd, "%h", M_golden);
    scanf = $fscanf(in_fd, "%h", N_golden);
end endtask


task read_A_Matrix; begin

    nrow = (M_golden[1:0] !== 2'b00) ?  K_golden * ((M_golden>>2) + 1) : K_golden * (M_golden >> 2);
    $display("Arow: %d", nrow);
    for(i=0;i<nrow;i=i+1) begin
        scanf = $fscanf(in_fd, "%h %h %h %h", rbuf[3], rbuf[2], rbuf[1], rbuf[0]);
        gbuff_A.gbuff[i] = {rbuf[3], rbuf[2], rbuf[1], rbuf[0]};
        // $display("A[%d] = %8h", i, gbuff_A.gbuff[i]);
    end

end endtask


task read_B_Matrix; begin

    nrow = (N_golden[1:0] !== 2'b00) ? K_golden * ((N_golden >> 2) + 1) : K_golden * (N_golden >> 2);
    $display("Brow: %d", nrow);
    for(i=0;i<nrow;i=i+1) begin
        scanf = $fscanf(in_fd, "%h %h %h %h", rbuf[3], rbuf[2], rbuf[1], rbuf[0]);
        gbuff_B.gbuff[i] = {rbuf[3], rbuf[2], rbuf[1], rbuf[0]};
        // $display("B[%d] = %8h", i, gbuff_B.gbuff[i]);
    end

end endtask


task read_golden; begin

    nrow = (N_golden[1:0] !== 2'b00) ? M_golden * ((N_golden>>2) + 1) : M_golden * (N_golden>>2);

    for(i=0;i<nrow;i=i+1) begin
        scanf = $fscanf(in_fd, "%h %h %h %h", goldenbuf[3], goldenbuf[2], goldenbuf[1], goldenbuf[0]);
        GOLDEN[i] = {goldenbuf[3], goldenbuf[2], goldenbuf[1], goldenbuf[0]};
        // $display("GOLDEN[%d] = %8h %8h %8h %8h", i, GOLDEN[i][127:96],  GOLDEN[i][95:64],  GOLDEN[i][63:32],  GOLDEN[i][31:0]);
    end

end endtask


task wait_finished; begin

    cycles = 0;
    while(busy === 1'b1) begin
        cycles = cycles + 1;
        if(cycles >= 1500000) begin
            exceed_1500000_cycles;
        end
        @(negedge clk);
    end

end endtask




task exceed_1500000_cycles; begin
    $display ("------------------------------------------------------------------------------------");
    $display ("                               exceed 1500000 cycles, (%d) wrong                      ", cycles);
    $display ("------------------------------------------------------------------------------------");
    repeat(10)@(negedge clk);
    $finish;
end endtask



task golden_check; begin

    err = 0;

    nrow = (N_golden[1:0] !== 2'b00) ? M_golden * ((N_golden>>2) + 1) : M_golden * (N_golden>>2);
    for(i = 0; i < nrow; i=i+1) begin
        if(GOLDEN[i][127:96] !== gbuff_C.gbuff[i][127:96]) begin
            $display("gbuff[%d][127:96] = %8h, expect = %8h", i, gbuff_C.gbuff[i][127:96], GOLDEN[i][127:96]);
            err = err + 1;
        end 

        if(GOLDEN[i][95:64] !== gbuff_C.gbuff[i][95:64]) begin
            $display("gbuff[%d][95:64] = %8h, expect = %8h", i, gbuff_C.gbuff[i][95:64], GOLDEN[i][95:64]);
            err = err + 1;
        end

        if(GOLDEN[i][63:32] !== gbuff_C.gbuff[i][63:32]) begin
            $display("gbuff[%d][63:32] = %8h, expect = %8h", i, gbuff_C.gbuff[i][63:32], GOLDEN[i][63:32]);
            err = err + 1;
        end

        if(GOLDEN[i][31:0] !== gbuff_C.gbuff[i][31:0]) begin
            $display("gbuff[%d][31:0] = %8h, expect = %8h", i, gbuff_C.gbuff[i][31:0], GOLDEN[i][31:0]);
            err = err + 1;
        end
    end


    if(err != 0) begin
        wrong_ans;
    end


end endtask


task wrong_ans; begin
    $display("                                       -----------                                      ");
    $display("                                     -=====,======--                                    ");
    $display("                                   ---------,-,,,,,,-                                   ");
    $display("                                 :-=====:=====:=======:                                 ");
    $display("                               :=----------------------::                               ");
    $display("                              :--------------------------::                             ");
    $display("                             :-----------------------------:                            ");
    $display("                            :-------------------------------:                           ");
    $display("                           :---------------------------------:                          ");
    $display("                          :--------------=:::==::::-----------:                         ");
    $display("                          :----------:====--,,,,--====:=------:                         ");
    $display("                         :-------:===,=++++...++++..--===:-----:                        ");
    $display("                         :-===--.......+    +.+    +......====-:                        ");
    $display("                         /==-.........+      +      +.........../                       ");
    $display("                         /-..........+     - / -     +........../                       ");
    $display("                         /...........+    -# . #-    +........../                       ");
    $display("                         /...........+       +       +........../                       ");
    $display("                         /...........+      +.+      +........../                       ");
    $display("                         /............+    +...+    +.........../                       ");
    $display("                         /.............++++.....++++.........../                        ");
    $display("                          /..................................-./                        ");
    $display("                          /.-...............................-./                         ");
    $display("                           /.-..........M##M$HM###M........-../                         ");
    $display("                            /.-..........# FAIL #$........-../                          ");
    $display("                             /.-....-......$$$$+-....-.....-/                           ");
    $display("                              /......--.........,,,,...--.//                            ");
    $display("                               //..----.............---.//                              ");
    $display("                                 ///-..-------------.-//                                ");
    $display("                                    //////////////////                                  ");
    $display("----------------------------------------------------------------------------------------");
    $display("                             Unfortunately, your answer is wrong                        ");
    $display("----------------------------------------------------------------------------------------");
    $finish;
end endtask




task YOU_PASS_task; begin
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8OOOOOOO8@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@O               .o8@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:.                   .o@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@o                         :O@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                           .o8@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@888888@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@88888888OOO88@@@@@@@@@@                             :@@@@@@@");
    $display("@@@@@@@@@@@@8o:.          .o8@@@@@@@@@@@@@@@@@@@88Oo:.                      .:ooo                              o@@@@@@");
    $display("@@@@@@@@@@8                  .8@@@@@@@@@@@@8O:.           ..::::::ooo:.                                        .8@@@@@");
    $display("@@@@@@@O.                      8@@@@@8O:.        .:O88@@@@@@@@@@@@@@@@@@@@@@@88Oo.                             :8@@@@@");
    $display("@@@@@@o                        :8@@8.      .:o8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@OO:                         o@@@@@@");
    $display("@@@@@8                          :o.     .O8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@88@@8o.                      8@@@@@@");
    $display("@@@@:                               o8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:          :OO.                  o@@@@@8@");
    $display("@@@o.                             :O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.              OO:              :8@@@@@@@@");
    $display("@@8.                           O8@@@@@@@@@@O:.    .oO@@@@@@@@@@@@@@@@@@@@@@@.                o88          O@@@@@@@@@@@");
    $display("@@O.                         :O@@@@@@@@@@:           o@@@@@@@@@@@@@@@@@@@@@@.                 .88o.     oO@@@@@@@@@@@@");
    $display("@@O.                       :8@@@@@@@@@@8:            .O@@@@@@@@@@@@@@@@@@@@@o                  .@@8O:   o8@@@@@8@@@@@@");
    $display("@@@:                      8@@@@@@@@@@O.               :8@@@@@@@@@@@@@@@@@@@@8o                  O@@@@.    8@@@@@@@@@8@");
    $display("@@@@o                    :@@@@@@@@@@o                 :8@@@@@@@@@@@@@@@@@@@@@@o                 O@@@@O:   .O@@@@@@@@@@");
    $display("@@@@@@.                .O@@@@@@@@@@8                  O@@@@@@@@@@@@@@@@@@@@@@@@@O             .O@@@@@@@@o   :@@@@@@@@@");
    $display("@@@@@@@O:.           .O@@@@@@@@@@@@o                 .8@@@@@@@@@@@@888O8@@@@@@@@@o.         .o8@@@@@@@@@@o   o8@@@@@@@");
    $display("@@@@@@@@@@8.         o@@@@@@@@@@@@@:                 o@@@@@@@O:.         :O@@@@@@@@Oo.   .:8@@@@@@@@@@@@@8     @@@@@@@");
    $display("@@@@@@@@@@@@@@@@:    8@@@@@@@@@@@@@8               :8@@@@8:              .O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@     @@@@@@");
    $display("@@@@@@@@@@@@@@@@    :@@@@@@@@@@@@@@@O.             8@@@@@8:              o@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8@@@    @@@@@@");
    $display("@@@@@@@@@@@@@@@O   :@@@@@@@@@@@@@@@@@@@8O:....:O8@@@@@@@@@@@o          O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8@@@@    @@@@@");
    $display("@@@@@@@@@@@@@@8:  :O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@Oo.    .o8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    @@@@");
    $display("@@@@@@@@@@@@@8:   o@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8  :@@@@@@@@@@@@@@@@@@@@@@@8Ooo\033[0;40;31m:::::\033[0;40;37moOO8@@8OOo   o@@@");
    $display("@@@@@@@@@@@@@O   O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8. .8@@8o:O@@@@@@@@@@@@@8O\033[0;40;31m:::::::::::::::\033[0;40;37mO@@@O   :@@@");
    $display("@@@@@@@@@@@@@O   O@@@@@@@@@@@@@@@@@@88888@@@@@@@@@@@@@@@@@@O:oO8@8.  .:    o@@@@@@@@@@@@O\033[0;40;31m::::::::::::::::::\033[0;40;37mo8@O   :8@@");
    $display("@@@@@@@@@@@@@O   O@@@@@@@@@@@@@\033[1;40;31mO\033[0;40;31m:::::::::::::\033[0;40;37mo8@@@@@@@@@@@@8.              :@@@@@@@@@@8o\033[0;40;31m::::::::::::::::::::\033[0;40;37mo8@:   .@@");
    $display("@@@@@@@@@@@@O.  .8@@@@@@@@@@8Oo\033[0;40;31m.:::::::::::::::\033[0;40;37moO@@@@@@@@@@8:              .@@@@@@@@@@O\033[0;40;31m::::::::::::::::::::::\033[0;40;37mo8O    @@");
    $display("@@@@@@@@@@@@o   O@@@@@@@@@@8o\033[0;40;31m::::::::::::::::::::\033[0;40;37mo8@@@@@@@@@O              .@@@@@@@@@@O\033[0;40;31m::::::::::::::::::::::\033[0;40;37mo8O    @@");
    $display("@@@@@@@@@@@@O.  :8@@@@@@@@o\033[0;40;31m::::::::::::::::::::::::\033[0;40;37m8@@@@@@@@@              :@@@@@@@@@@8o\033[0;40;31m:::::::::::::::::::::\033[0;40;37mO@o    @@");
    $display("@@@@@@@@@@@@8:  :8@@@@@@@8\033[0;40;31m:::::::::::::::::::::::::\033[0;40;37m8@@@@@@@@@              O@@@@@@@@@@@O\033[0;40;31m::::::::::::::::::::\033[0;40;37mo8@:   :@@");
    $display("@@@@@@@@@@@@@O   O@@@@@@8O\033[0;40;31m:::::::::::::::::::::::::\033[0;40;37mo8@@@@@@@@O           .8@@@@@@@@@@@@@8o\033[0;40;31m::::::::::::::::\033[0;40;37mo8@@@   .O@@");
    $display("@@@@@@@@@@@@@O   O8@@@@@8O\033[0;40;31m:::::::::::::::::::::::::\033[0;40;37mo8@@@@@@@@@8:       .O@@@@@@@@@@@@@@@@@O\033[0;40;31m::::::::::::::\033[0;40;37mo@@@@8   .8@@");
    $display("@@@@@@@@@@@@@O   O@@@@@@@O\033[0;40;31m::::::::::::::::::::::::.\033[0;40;37mO8@@@@8OOooo:.     :@@@@@@@@@@@@@@@@@@@@8OOo\033[0;40;31m::::::\033[0;40;37mooO8@@@@@o   :@@@");
    $display("@@@@@@@@@@@@@8.  o8@@@@@@@\033[0;40;31m:::::::::::::::::::::::::\033[0;40;37m8@8O.                  .:O8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8o   o@@@@");
    $display("@@@@@@@@@@@@@8:  .O@@@@@@@O\033[0;40;31m:::::::::::::::::::::::\033[0;40;37mo@O.    .:oOOOo::.           .:OO8@@@@@@@@@@@@@@@@@@@@@@@@O.  :8@@@@");
    $display("@@@@@@@@@@@@@@8.  :8@@@@@@@8o\033[0;40;31m:::::::::::::::::::\033[0;40;37mO8@O    8@@@@@@@@@@@@@@@@@8O..         :oO8@@@@@@@@@@@@@@@8o.  .8@@@@@");
    $display("@@@@@@@@@@@@@@@O   :8@@@@@@@@8O\033[0;40;31m:::::::::::::::\033[0;40;37mO8@@@:   .@@@@@@@@@@@@@@@@@@@@@@88Oo:.       .:O8@@@@@@@@@@@.    O@@@@@@");
    $display("@@@@@@@@@@@@@@@8    O@@@@@@@@@@8Oo\033[0;40;31m::::::::\033[0;40;37mooO8@@@@@O.   O@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:.      .o@@@@@@@@@o    O@@@@@@@");
    $display("@@@@@@@@@@@@@@@@o    8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:    :O8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@o.    :O@@@8o.  .o@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@:    :8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:      ...:oO8@@@@@@@@@@@@@@@@@@@@@@@@@O:   .O8.    .O@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@O:    :@@@@@@@@@@@@@@@@@@@@@@@@@@@O.   \033[0;40;33m...\033[0;40;37m          O@@@@@@@@@@@@@@@@@@@@@@@O       .O8@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@:    :O@@@@@@@@@@@@@@@@@@@@@@@@@O   \033[0;40;33m:O888Ooo:..\033[0;40;37m    :8@@@@@@@@@@@@@@@@@@@@O:     :O@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@8o     .O8@@@@@@@@@@@@@@@@@@@@@O:  \033[0;40;33m.o8888888888O.\033[0;40;37m  .O@@@@@@@@@@@OO888@8O:.    :O@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@O        o8@@@@@@@@@@@@@@@@@@@o   \033[0;40;33m:88888888888o\033[0;40;37m   o8@@@@@@@:              o8@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@:          .:88@@@@@@@@@@@@@8:   \033[0;40;33mo8888O88888O.\033[0;40;37m  .8@@@@@@@O    \033[1;40;33m..\033[0;40;37m     .::O@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@O.                  .:o          \033[0;40;33m8888\033[0;40;37m@@@@\033[0;40;33m888o.\033[0;40;37m  o8@@@@@8o   \033[0;40;33mo88o.\033[0;40;37m   @@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@o        .OOo:.                 \033[0;40;33mO88\033[0;40;37m@@@@@\033[0;40;33m888o.\033[0;40;37m  :8@@@@@o   \033[0;40;33m:O88.\033[0;40;37m   .@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@8o         :@@@@@O:             \033[0;40;33m.O8\033[0;40;37m@@@@\033[0;40;33m8888O:\033[0;40;37m   .O88O:   \033[0;40;33m.O88O\033[0;40;37m    O@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@:                             \033[0;40;33m.o8\033[0;40;37m@@@@\033[0;40;33m\033[0;40;33m888888O:\033[0;40;37m         \033[0;40;33m.888O:\033[0;40;37m   o8@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@8o                            \033[0;40;33m.O\033[0;40;37m@@@@\033[0;40;33m\888888888Oo:...ooO8888:   \033[0;40;37m:8@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8o                         \033[0;40;33mo8\033[0;40;37m@@@@\033[0;40;33m888888888888888888888O.\033[0;40;37m  :8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@o.                      \033[0;40;33m.8\033[0;40;37m@@@@\033[0;40;33m888888888888888888888O:\033[0;40;37m   o@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@O:.                 \033[0;40;33m.o8\033[0;40;37m@@@@@\033[0;40;33m88888888888888888888Oo\033[0;40;37m   :8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8OOo::::::.   \033[0;40;33mo888\033[0;40;37m@@@@@\033[0;40;33m88888888888888888888o.\033[0;40;37m   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:   \033[0;40;33mo888\033[0;40;37m@@@@@\033[0;40;33m88888888888888888888.\033[0;40;37m   .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8:   \033[0;40;33mo888\033[0;40;37m@@@@@\033[0;40;33m88888888888888888888O\033[0;40;37m   .O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@O.   \033[0;40;33mO8888\033[0;40;37m@@@\033[0;40;33m88888888888888888888O.\033[0;40;37m   O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@o    \033[0;40;33m8888888888888888888888888888o\033[0;40;37m   o8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.    \033[0;40;33m. ..:oOO8888888888888888888o.\033[0;40;37m  .8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@O.           \033[0;40;33m..:oO8888888888888O.\033[0;40;37m  .O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8OO.             \033[0;40;33m.oOO88O.\033[0;40;37m   O@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@88:..          \033[0;40;33m...\033[0;40;37m    8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@88Ooo:.          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@8OoOO@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$display ("                                                  Congratulations!                						             ");
	$display ("                                           You have passed all patterns!          						             ");
	$display ("                                           Your execution cycles = %5d cycles   						                 ", total_cycles);
	$display ("                                           Your clock period = %.1f ns        					                     ", `CYCLE_TIME);
	$display ("                                           Your total latency = %.1f ns         						                 ", total_cycles*`CYCLE_TIME);
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$finish;
end endtask












endmodule











