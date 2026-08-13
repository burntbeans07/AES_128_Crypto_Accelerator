module InvSubBytes(input wire [127:0] din, output wire [127:0]subbed);
    
    wire [7:0]b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15;
    wire [7:0]s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15;
    
    assign b0 = din[127:120];
    assign b1 = din[119:112];
    assign b2 = din[111:104];
    assign b3 = din[103:96];
    assign b4 = din[95:88];
    assign b5 = din[87:80];
    assign b6 = din[79:72];
    assign b7 = din[71:64];
    assign b8 = din[63:56];
    assign b9 = din[55:48];
    assign b10 = din[47:40];
    assign b11 = din[39:32];
    assign b12 = din[31:24];
    assign b13 = din[23:16];
    assign b14 = din[15:8];
    assign b15 = din[7:0];
    
    ISbox_LUT x0(b0,s0);
    ISbox_LUT x1(b1,s1);
    ISbox_LUT x2(b2,s2);
    ISbox_LUT x3(b3,s3);
    ISbox_LUT x4(b4,s4);
    ISbox_LUT x5(b5,s5);
    ISbox_LUT x6(b6,s6);
    ISbox_LUT x7(b7,s7);
    ISbox_LUT x8(b8,s8);
    ISbox_LUT x9(b9,s9);
    ISbox_LUT x10(b10,s10);
    ISbox_LUT x11(b11,s11);
    ISbox_LUT x12(b12,s12);
    ISbox_LUT x13(b13,s13);
    ISbox_LUT x14(b14,s14);
    ISbox_LUT x15(b15,s15);
    
    assign subbed = { s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15 };
 
endmodule
