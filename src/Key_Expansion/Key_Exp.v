module Key_Exp(
    input wire clk, //crypto_clk
    input wire rst, //Active high rst 
    input wire load, //Loads the computed keys into the register
    input wire [127:0] keyin, //Input Key 
    input wire [3:0] r_num, //Round count to get current round key output
    output reg [127:0] round_key //Current round key output
);

    wire [127:0] rk1,rk2,rk3,rk4,rk5,rk6,rk7,rk8,rk9,rk10; //Outputs for each round key generation

    reg [127:0] key_ram [0:10]; // Register to store all Keys
    
    //All 10 keys are generated 
    Round_key_gen x1(keyin,4'd1,rk1);
    Round_key_gen x2(rk1,4'd2,rk2);
    Round_key_gen x3(rk2,4'd3,rk3);
    Round_key_gen x4(rk3,4'd4,rk4);
    Round_key_gen x5(rk4,4'd5,rk5);
    Round_key_gen x6(rk5,4'd6,rk6);
    Round_key_gen x7(rk6,4'd7,rk7);
    Round_key_gen x8(rk7,4'd8,rk8);
    Round_key_gen x9(rk8,4'd9,rk9);
    Round_key_gen x10(rk9,4'd10,rk10);

    // Capture keys 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_ram[0] <= 128'b0;
            key_ram[1] <= 128'b0;
            key_ram[2] <= 128'b0;
            key_ram[3] <= 128'b0;
            key_ram[4] <= 128'b0;
            key_ram[5] <= 128'b0;
            key_ram[6] <= 128'b0;
            key_ram[7] <= 128'b0;
            key_ram[8] <= 128'b0;
            key_ram[9] <= 128'b0;
            key_ram[10] <= 128'b0;
        end
        else if (load) begin //When FSM State is Key_Exp2, keys are loaded into the register
            key_ram[0] <= keyin;
            key_ram[1] <= rk1;
            key_ram[2] <= rk2;
            key_ram[3] <= rk3;
            key_ram[4] <= rk4;
            key_ram[5] <= rk5;
            key_ram[6] <= rk6;
            key_ram[7] <= rk7;
            key_ram[8] <= rk8;
            key_ram[9] <= rk9;
            key_ram[10] <= rk10;
        end
    end

    always @(*) begin
         //Round key output is loaded based in current round count
         round_key = key_ram[r_num];
    end

endmodule
