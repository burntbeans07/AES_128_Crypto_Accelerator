module FIFO #(
    parameter DATA_WIDTH = 129, //128 bit input and last block signal
    parameter ADDR_WIDTH = 3 // Depth = 2^ADDR_WIDTH
)(
    // Write side - PCLK domain
    input wire wr_clk,
    input wire wr_rstn,
    input wire zeroize,
    input wire zeroize_rd,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_en,
    output wire full,

    // Read side - crypto_clk domain
    input wire rd_clk,
    input wire rd_rstn,
    output reg [DATA_WIDTH-1:0] rd_data,
    input wire rd_en,
    output wire empty
);

    localparam DEPTH = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Binary pointers
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_bin;

    // Gray pointers
    reg [ADDR_WIDTH:0] wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    // Synchronized pointers
    wire [ADDR_WIDTH:0] rd_ptr_gray_sync;
    wire [ADDR_WIDTH:0] wr_ptr_gray_sync;


    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) begin
            wr_ptr_bin <= 0;
            wr_ptr_gray <= 0;
         end else if (zeroize) begin
                wr_ptr_bin <= 0;
                wr_ptr_gray <= 0;
	  
        end
        else begin
            if (wr_en && !full) begin
                mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr_bin <= wr_ptr_bin + 1'b1;

                wr_ptr_gray <= ((wr_ptr_bin + 1'b1) >> 1)^(wr_ptr_bin + 1'b1);
            end
        end
    end

    always @(posedge rd_clk or negedge rd_rstn) begin
        if (!rd_rstn) begin
            rd_ptr_bin <= 0;
            rd_ptr_gray <= 0;
            rd_data <= 0;
        end else if(zeroize_rd) begin
            rd_ptr_bin <= 0;
            rd_ptr_gray <= 0;
            rd_data <= 0;
        end else begin
            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
                rd_ptr_bin <= rd_ptr_bin + 1'b1;

                rd_ptr_gray <= ((rd_ptr_bin + 1'b1) >> 1)^(rd_ptr_bin + 1'b1);
            end
        end
    end


    FF2_Synch #(.WIDTH(4)) rd_gray(wr_clk,wr_rstn,rd_ptr_gray,rd_ptr_gray_sync);
    FF2_Synch #(.WIDTH(4)) wr_gray(rd_clk,rd_rstn,wr_ptr_gray,wr_ptr_gray_sync);

    
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync);

    wire [ADDR_WIDTH:0] wr_ptr_bin_next;
    wire [ADDR_WIDTH:0] wr_ptr_gray_next;
    wire full_next;
    reg  full_reg;

    assign wr_ptr_bin_next  = wr_ptr_bin + (wr_en && !full);
    assign wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

    assign full_next = (wr_ptr_gray_next == {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_sync[ADDR_WIDTH-2:0]});

    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) full_reg <= 1'b0;
        else if (zeroize) full_reg <= 1'b0;
        else full_reg <= full_next;
    end

    assign full = full_reg;

endmodule

