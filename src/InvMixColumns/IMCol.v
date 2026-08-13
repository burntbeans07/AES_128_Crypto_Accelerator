module IMCol(input wire [31:0]col, output wire [31:0] out1);
    
    wire [7:0] s0,s1,s2,s3;

    function automatic [7:0] mul2;
        input [7:0] a;
        begin
            if (a[7])
                mul2 = {a[6:0],1'b0} ^ 8'h1B;
            else
                mul2 = {a[6:0],1'b0};
        end
    endfunction
    
    function  automatic [7:0] mul9;
        input [7:0] a;
        begin
            mul9 = mul2(mul2(mul2(a))) ^ a;
        end
    endfunction 
    
    function automatic [7:0] mulB;
        input [7:0] a;
        begin
            mulB = mul2(mul2(mul2(a))) ^ mul2(a) ^ a;
        end
    endfunction
    
    function automatic [7:0] mulD;
        input [7:0] a;
        begin
            mulD = mul2(mul2(mul2(a))) ^ mul2(mul2(a)) ^ a;
        end
    endfunction
    
    function automatic [7:0] mulE;
        input [7:0] a;
        begin
            mulE = mul2(mul2(mul2(a))) ^ mul2(mul2(a)) ^ mul2(a);
        end
    endfunction
    
    assign s0 = col[31:24];
    assign s1 = col[23:16];
    assign s2 = col[15:8];
    assign s3 = col[7:0];

    // 0E 0B 0D 09
    assign out1[31:24] = mulE(s0) ^ mulB(s1) ^ mulD(s2) ^ mul9(s3);
    
    // 09 0E 0B 0D
    assign out1[23:16] = mul9(s0) ^ mulE(s1) ^ mulB(s2) ^ mulD(s3);
    
    // 0D 09 0E 0B
    assign out1[15:8] = mulD(s0) ^ mul9(s1) ^ mulE(s2) ^ mulB(s3);
    
    // 0B 0D 09 0E
    assign out1[7:0] = mulB(s0) ^ mulD(s1) ^ mul9(s2) ^ mulE(s3);

        
endmodule
