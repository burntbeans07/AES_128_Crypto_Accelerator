module IMCol(input wire [31:0]col, output wire [31:0] out);
    
    wire [7:0] s0,s1,s2,s3;
    
    //Addition is done by XOR in GF Field (Polynomial Representation) 
    //function for XTimes (x2) Multiplication in GF Field
    function [7:0] mul2;//0010 = x
        input [7:0] a;
        begin
            if (a[7])
                mul2 = (a << 1) ^ 8'h1B;
            else
                mul2 = a << 1;
        end
    endfunction
    
    //function for x9 multiplication in GF Field
    function [7:0] mul9;//1001 = x^3 + 1
        input [7:0] a;
        begin
            mul9 = mul2(mul2(mul2(a))) ^ a;
        end
    endfunction 
    
    //Function for x11 multiplication in GF Field
    function [7:0] mulB;//1011 = x^3 + x + 1
        input [7:0] a;
        begin
            mulB = mul2(mul2(mul2(a))) ^ mul2(a) ^ a;
        end
    endfunction
    
    //Function for x13 multiplication in GF Field
    function [7:0] mulD;//1101 = x^3 + x^2 + 1
        input [7:0] a;
        begin
            mulD = mul2(mul2(mul2(a))) ^ mul2(mul2(a)) ^ a;
        end
    endfunction
    
    //Function for x14 multiplication in GF Field
    function [7:0] mulE;//1110 = x^3 + x^2 + x
        input [7:0] a;
        begin
            mulE = mul2(mul2(mul2(a))) ^ mul2(mul2(a)) ^ mul2(a);
        end
    endfunction
    
    //32 bit input column is split into 4 bytes
    assign s0 = col[31:24];
    assign s1 = col[23:16];
    assign s2 = col[15:8];
    assign s3 = col[7:0];
    
    //According to derived matrix from algorithm
    // 0E 0B 0D 09
    assign out[31:24] = mulE(s0) ^ mulB(s1) ^ mulD(s2) ^ mul9(s3);
    
    // 09 0E 0B 0D
    assign out[23:16] = mul9(s0) ^ mulE(s1) ^ mulB(s2) ^ mulD(s3);
    
    // 0D 09 0E 0B
    assign out[15:8] = mulD(s0) ^ mul9(s1) ^ mulE(s2) ^ mulB(s3);
    
    // 0B 0D 09 0E
    assign out[7:0] = mulB(s0) ^ mulD(s1) ^ mul9(s2) ^ mulE(s3);

        
endmodule
