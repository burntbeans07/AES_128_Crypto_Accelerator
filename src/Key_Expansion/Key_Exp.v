module Key_Exp(
    input wire [127:0]keyin, 
    input wire [3:0]r_num, 
    output reg [127:0]round_key);
    
    wire [127:0] rk1,rk2,rk3,rk4,rk5,rk6,rk7,rk8,rk9,rk10; //key for each round
    reg [127:0] key_ram [0:10];
   
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
    

    //Each round key assigned to mem
    always @(*) begin
        key_ram[0]=keyin;
        key_ram[1]=rk1;
        key_ram[2]=rk2;
        key_ram[3]=rk3;
        key_ram[4]=rk4;
        key_ram[5]=rk5;
        key_ram[6]=rk6;
        key_ram[7]=rk7;
        key_ram[8]=rk8;
        key_ram[9]=rk9;
        key_ram[10]=rk10;
        
    end
    
    always @(*)begin
        if(r_num>10)
            round_key = 128'b0;       
        else 
            round_key = key_ram[r_num]; 
    end
endmodule
