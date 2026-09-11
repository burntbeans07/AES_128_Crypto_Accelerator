module APB_Slave #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 32
    )(
     
        input wire PCLK,
        input wire PRESETn,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [2:0] PPROT,
        input wire [ADDR_WIDTH-1:0]PADDR,
        input wire [DATA_WIDTH-1:0]PWDATA,
    
        output wire PREADY,
        output reg [DATA_WIDTH-1:0] PRDATA,
        output reg PSLVERR,
        
        output wire [ADDR_WIDTH-1:0]reg_addr,
        output reg [DATA_WIDTH-1:0]reg_wdata,
        output wire [2:0] reg_pprot,
    
        input wire [DATA_WIDTH-1:0] reg_rdata,
        input wire reg_pslverr,
        input wire data_fifo_full,
        
        output wire write_en,
        output wire read_en
    );
    

    
        assign write_en = PSEL && PENABLE && PWRITE && PREADY;
        assign read_en  = PSEL && PENABLE && !PWRITE && PREADY;
        assign reg_addr  = PADDR;
        assign reg_pprot = PPROT;
        assign PREADY = !(reg_addr == 8'h34 && data_fifo_full);
    
        always @(posedge PCLK or negedge PRESETn) begin
    
            if (!PRESETn) begin
                PRDATA   <= {DATA_WIDTH{1'b0}};
                PSLVERR  <= 1'b0;
                reg_wdata <= {DATA_WIDTH{1'b0}};
            
            end else begin
                PSLVERR   <= 1'b0;
                
                if (write_en) begin
                    reg_wdata <= PWDATA;
                    PSLVERR   <= reg_pslverr;
                
                end else if (read_en) begin
                    PRDATA   <= reg_rdata;
                    PSLVERR  <= reg_pslverr;
                end
            end
        end
    
    endmodule
