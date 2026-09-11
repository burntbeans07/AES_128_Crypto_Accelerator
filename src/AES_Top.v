module AES_Top (
    // APB clock domain
    input wire PCLK,
    input wire PRESETn,

    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [2:0] PPROT,
    input wire [7:0] PADDR,
    input wire [31:0] PWDATA,

    output wire PREADY,
    output wire [31:0] PRDATA,
    output wire PSLVERR,

    // Crypto clock domain
    input wire crypto_clk,
    input wire crypto_rstn
);
  
    // APB - Register Interface
    wire [7:0]  reg_addr;
    wire [31:0] reg_wdata;
    wire [2:0]  reg_pprot;

    wire [31:0] reg_rdata;
    wire reg_pslverr;

    wire write_en;
    wire read_en;

    wire data_fifo_full;

    APB_Slave #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32)
    ) APB (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PPROT(PPROT),
        .PADDR(PADDR),
        .PWDATA(PWDATA),

        .PREADY(PREADY),
        .PRDATA(PRDATA),
        .PSLVERR(PSLVERR),

        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_pprot(reg_pprot),

        .reg_rdata(reg_rdata),
        .reg_pslverr(reg_pslverr),

        .data_fifo_full(data_fifo_full),

        .write_en(write_en),
        .read_en(read_en)
    );

    // Register Interface
    wire [127:0] cfg_key;
    wire [127:0] cfg_iv;
    wire cfg_aes_mode;
    wire [1:0] cfg_block_mode;
    wire cfg_req;
    wire cfg_busy;

    wire start_req;
    wire zeroize_req;

    wire [128:0] data_fifo_wdata;
    wire data_fifo_wr_en;

    wire [127:0] result_fifo_rdata;
    wire result_fifo_empty;
    wire result_fifo_rd_en;

    wire busy;
    wire busy_sync;
    wire trans_done;
    wire security_violation;

    Reg_Int #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32)
    ) REG_INT (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .write_en(write_en),
        .read_en(read_en),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_pprot(reg_pprot),

        .reg_rdata(reg_rdata),
        .reg_pslverr(reg_pslverr),

        .cfg_key(cfg_key),
        .cfg_iv(cfg_iv),
        .cfg_aes_mode(cfg_aes_mode),
        .cfg_block_mode(cfg_block_mode),
        .cfg_req(cfg_req),
        .cfg_busy(cfg_busy),

        .start_req(start_req),
        .zeroize_req(zeroize_req),

        .data_fifo_wdata(data_fifo_wdata),
        .data_fifo_wr_en(data_fifo_wr_en),
        .data_fifo_full(data_fifo_full),

        .result_fifo_rdata(result_fifo_rdata),
        .result_fifo_empty(result_fifo_empty),
        .result_fifo_rd_en(result_fifo_rd_en),

        .busy(busy_sync),
        .trans_done(trans_done),

        .security_violation(security_violation)
    );

    // Configuration Handshake
    // PCLK -> crypto_clk
    wire cfg_load;

    Handshake CFG_HANDSHAKE (
        .src_clk(PCLK),
        .src_rstn(PRESETn),
        .src_req(cfg_req),
        .src_busy(cfg_busy),

        .dst_clk(crypto_clk),
        .dst_rstn(crypto_rstn),
        .dst_pulse(cfg_load)
    );

    // Start Handshake  PCLK -> crypto_clk
    wire start;

    Handshake START_HANDSHAKE (
        .src_clk(PCLK),
        .src_rstn(PRESETn),
        .src_req(start_req),
        .src_busy(),
        
        .dst_clk(crypto_clk),
        .dst_rstn(crypto_rstn),
        .dst_pulse(start)
    );
  
    // Zeroize Handshake PCLK -> crypto_clk
    wire zeroize;

    Handshake ZEROIZE_HANDSHAKE (
        .src_clk(PCLK),
        .src_rstn(PRESETn),
        .src_req(zeroize_req),
        .src_busy(),

        .dst_clk(crypto_clk),
        .dst_rstn(crypto_rstn),
        .dst_pulse(zeroize)
    );

    // TX FIFO PCLK -> crypto_clk 
    //128-bit data + last_block
    wire [128:0] tx_fifo_rdata;
    wire tx_fifo_empty;
    wire tx_fifo_rd_en;

    FIFO #(
        .DATA_WIDTH(129),
        .ADDR_WIDTH(3)
    ) TX_FIFO (
        .wr_clk(PCLK),
        .wr_rstn(PRESETn),
        .zeroize(zeroize),

        .wr_data(data_fifo_wdata),
        .wr_en(data_fifo_wr_en),
        .full(data_fifo_full),

        .rd_clk(crypto_clk),
        .rd_rstn(crypto_rstn),

        .rd_data(tx_fifo_rdata),
        .rd_en(tx_fifo_rd_en),
        .empty(tx_fifo_empty)
    );



    // RX FIFO crypto_clk -> PCLK
    wire [127:0] rx_fifo_wdata;
    wire rx_fifo_wr_en;
    wire rx_fifo_full;

    FIFO #(
        .DATA_WIDTH(128),
        .ADDR_WIDTH(3)
    ) RX_FIFO (
        .wr_clk(crypto_clk),
        .wr_rstn(crypto_rstn),
        .zeroize(zeroize),

        .wr_data(rx_fifo_wdata),
        .wr_en(rx_fifo_wr_en),
        .full(rx_fifo_full),

        .rd_clk(PCLK),
        .rd_rstn(PRESETn),

        .rd_data(result_fifo_rdata),
        .rd_en(result_fifo_rd_en),
        .empty(result_fifo_empty)
    );

    // Busy Synchronizer crypto_clk -> PCLK
    FF2_Synch BUSY_SYNC (
        .clk(PCLK),
        .rstn(PRESETn),
        .sync_in(busy),
        .sync_out(busy_sync)
    );

    // Transaction Done Handshake crypto_clk -> PCLK
    wire trans_done_src;

    Handshake DONE_HANDSHAKE (
        .src_clk(crypto_clk),
        .src_rstn(crypto_rstn),
        .src_req(trans_done_src),
        .src_busy(),

        .dst_clk(PCLK),
        .dst_rstn(PRESETn),
        .dst_pulse(trans_done)
    );


    //Mode Wrapper
    Block_Mode MODE_WRAPPER (
        .crypto_clk(crypto_clk),
        .rstn(crypto_rstn),
        .zeroize(zeroize),

        .key_in(cfg_key),
        .iv_in(cfg_iv),
        .aes_mode_in(cfg_aes_mode),
        .block_mode_in(cfg_block_mode),

        .load(cfg_load),
        .start(start),

        .fifo_data_in(tx_fifo_rdata),
        .fifo_empty(tx_fifo_empty),
        .fifo_rd_en(tx_fifo_rd_en),

        .fifo_wdata(rx_fifo_wdata),
        .fifo_wr_en(rx_fifo_wr_en),
        .fifo_full(rx_fifo_full),

        .busy(busy),
        .trans_done(trans_done_src)
    );

endmodule
