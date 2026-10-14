module APB_Slave #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 32
    )(
     
        input wire PCLK,
        input wire PRESETn,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [2:0]PPROT,
        input wire [ADDR_WIDTH-1:0]PADDR,
        input wire [DATA_WIDTH-1:0]PWDATA,
    
        output reg PREADY,
        output reg [DATA_WIDTH-1:0] PRDATA,
        output reg PSLVERR,
        
        output wire [ADDR_WIDTH-1:0]reg_addr,
        output wire [DATA_WIDTH-1:0]reg_wdata,
        output wire [2:0] reg_pprot,
    
        input wire [DATA_WIDTH-1:0] reg_rdata,
        input wire reg_pslverr,
        input wire data_fifo_full,
        
        output wire write_en,
        output wire read_en
    );
    

    
        assign write_en = PSEL && PENABLE && PWRITE;
        assign read_en  = PSEL && PENABLE && !PWRITE;
        assign reg_addr  = PADDR;
        assign reg_wdata = PWDATA;
        assign reg_pprot = PPROT;

        always @(*) begin
            PRDATA  = {DATA_WIDTH{1'b0}};
            PSLVERR = 1'b0;
            PREADY  = 1'b0;
            if (write_en) begin
                PSLVERR = reg_pslverr;
                PREADY = 1'b1;
            
            end else if (read_en) begin
                PRDATA  = reg_rdata;
                PSLVERR = reg_pslverr;
                PREADY = 1'b1;
            end
        end
    
endmodule
