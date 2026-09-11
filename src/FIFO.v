module FIFO #(
    parameter DATA_WIDTH = 129, //128 bit input and last block signal
    parameter ADDR_WIDTH = 3 // Depth = 2^ADDR_WIDTH
)(
    // Write side - PCLK domain
    input wire wr_clk,
    input wire wr_rstn,
    input zeroize,
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
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync;
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync;

    integer i;
    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) begin
            wr_ptr_bin <= 0;
            wr_ptr_gray <= 0;
            for (i=0;i< DEPTH;i=i+1) begin
                mem[i] <= 129'b0;
            end
         end else if (zeroize) begin
                wr_ptr_bin <= 0;
                wr_ptr_gray <= 0;
                for (i=0;i< DEPTH;i=i+1) begin
                    mem[i] <= 129'b0;
                end
	  
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
        end
        else begin
            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
                rd_ptr_bin <= rd_ptr_bin + 1'b1;

                rd_ptr_gray <= ((rd_ptr_bin + 1'b1) >> 1)^(rd_ptr_bin + 1'b1);
            end
        end
    end

/*
    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end
        else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end
    
    always @(posedge rd_clk or negedge rd_rstn) begin
        if (!rd_rstn) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end
        else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end */

    FF2_Synch rd_gray(wr_clk,wr_rstn,rd_ptr_gray,rd_ptr_gray_sync);
    FF2_Synch wr_gray(rd_clk,rd_rstn,wr_ptr_gray,wr_ptr_gray_sync);
    
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync);

    wire [ADDR_WIDTH:0] wr_ptr_gray_next;

    assign wr_ptr_gray_next = ((wr_ptr_bin + 1'b1) >> 1) ^ (wr_ptr_bin + 1'b1);

    assign full = (wr_ptr_gray_next == {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_sync[ADDR_WIDTH-2:0]});

endmodule
