module ShiftRows(input wire [127:0]din, output wire [127:0]shifted);

    wire [31:0] R0,R1,R2,R3;
    wire [31:0] shift_r1,shift_r2,shift_r3;
    
    //128 bit state is split into 4x4 matrix - 4 rows 4 bytes each
    assign R0={din[127:120],din[95:88], din[63:56], din[31:24]}; //Row 0 no shift
    assign R1={din[119:112],din[87:80], din[55:48], din[23:16]};
    assign R2={din[111:104],din[79:72], din[47:40], din[15:8]};
    assign R3={din[103:96], din[71:64], din[39:32], din[7:0]};
    
    assign shift_r1 = {R1[23:0],R1[31:24]};//Row 1 Shifted left by 1 byte
    assign shift_r2 = {R2[15:0],R2[31:16]};//Row 2 shifted left by 2 bytes
    assign shift_r3 = {R3[7:0],R3[31:8]};//Row 3 shifted left by 3 bytes
     
    //Output is built in column wise for the next stage ( first 32 bits - col 1, next 32 bits col2 etc) 
    assign shifted = { 
    R0[31:24], shift_r1[31:24], shift_r2[31:24], shift_r3[31:24],
    R0[23:16], shift_r1[23:16], shift_r2[23:16], shift_r3[23:16],
    R0[15:8],  shift_r1[15:8],  shift_r2[15:8],  shift_r3[15:8],
    R0[7:0],   shift_r1[7:0],   shift_r2[7:0],   shift_r3[7:0]
};
    
endmodule

