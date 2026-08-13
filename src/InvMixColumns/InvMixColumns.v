module InvMixColumns(input [127:0]din, output wire [127:0]mixed);

    wire [31:0] C0,C1,C2,C3;//128 bit state split into 4 columns
    wire [31:0] out0, out1, out2, out3; //4 output columns

    assign C0 = din[127:96];
    assign C1 = din[95:64];
    assign C2 = din[63:32];
    assign C3 = din[31:0];
    
    //Mixcolumn operation on each column
    IMCol MC0(C0, out0);
    IMCol MC1(C1, out1);
    IMCol MC2(C2, out2);
    IMCol MC3(C3, out3);
    
    //Columns joined to form 128 bit output
    assign mixed[127:96] = out0;
    assign mixed[95:64]  = out1;
    assign mixed[63:32]  = out2;
    assign mixed[31:0]   = out3;


endmodule
