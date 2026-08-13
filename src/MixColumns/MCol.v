module MCol(input wire [31:0]col, output wire [31:0] out1);

    wire [7:0] s0,s1,s2,s3;//32 bit column split into 4 bytes

    assign s0 = col[31:24];
    assign s1 = col[23:16];
    assign s2 = col[15:8];
    assign s3 = col[7:0];
    
    wire [7:0] m2_s0,m2_s1,m2_s2,m2_s3;//each byte x2 - xtimes operation output
    wire [7:0] m3_s0,m3_s1,m3_s2,m3_s3; //each byte x3 output
    
    //x2 multiplication in GF
    assign m2_s0 = s0[7] ? ({s0[6:0],1'b0} ^ 8'h1B) : {s0[6:0],1'b0};
    assign m2_s1 = s1[7] ? ({s1[6:0],1'b0} ^ 8'h1B) : {s1[6:0],1'b0};
    assign m2_s2 = s2[7] ? ({s2[6:0],1'b0} ^ 8'h1B) : {s2[6:0],1'b0};
    assign m2_s3 = s3[7] ? ({s3[6:0],1'b0} ^ 8'h1B) : {s3[6:0],1'b0};
    
    
    //x3 mult = x2 ^ x1
    assign m3_s0 = m2_s0 ^ s0;
    assign m3_s1 = m2_s1 ^ s1;
    assign m3_s2 = m2_s2 ^ s2;
    assign m3_s3 = m2_s3 ^ s3;
    
    //according to fixed matrix 
    assign out1[31:24] = m2_s0 ^ m3_s1 ^ s2 ^ s3;
    assign out1[23:16] = s0 ^ m2_s1 ^ m3_s2 ^ s3;
    assign out1[15:8]  = s0 ^ s1 ^ m2_s2 ^ m3_s3;
    assign out1[7:0]   = m3_s0 ^ s1 ^ s2 ^ m2_s3;
    

    
endmodule

