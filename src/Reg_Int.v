module Reg_Int #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input wire PCLK,
    input wire PRESETn,
    
    //APB Interface
    input wire write_en, //write data_in to tx fifo
    input wire read_en, //read result from rx fifo
    input wire [ADDR_WIDTH-1:0] reg_addr,//address from APB
    input wire [DATA_WIDTH-1:0] reg_wdata,// write data from APB
    input wire [2:0] reg_pprot,

    output reg [DATA_WIDTH-1:0] reg_rdata,
    output reg reg_pslverr,

    //AES Configurations from APB to Mode Wrapper through Handshake mechanism
    output reg  [127:0] cfg_key, 
    output reg  [127:0] cfg_iv,
    output reg cfg_aes_mode,
    output reg [1:0] cfg_block_mode,
    output reg cfg_req,
    input wire cfg_busy,

    //Start and zeroize commands to Mode wrapper through handshake
    output reg start_req,
    output reg zeroize_req,

    //TX FIFO - writes data (PCLK to Crypto)
    output reg  [128:0]data_fifo_wdata,
    output reg data_fifo_wr_en,
    input wire data_fifo_full,

    //RX FIFO - reads data (Crypto to PCLK)
    input wire [127:0]result_fifo_rdata,
    input wire result_fifo_empty,
    output reg result_fifo_rd_en,

    //Transaction signals from Mode Wrapper
    input wire busy,
    input wire trans_done,
    
    output wire security_violation
);

    //ADDRESS MAP
    localparam [7:0] ADDR_CONTROL = 8'h00;
    localparam [7:0] ADDR_STATUS  = 8'h04;

    localparam [7:0] ADDR_KEY0 = 8'h08;
    localparam [7:0] ADDR_KEY1 = 8'h0C;
    localparam [7:0] ADDR_KEY2 = 8'h10;
    localparam [7:0] ADDR_KEY3 = 8'h14;

    localparam [7:0] ADDR_IV0 = 8'h18;
    localparam [7:0] ADDR_IV1 = 8'h1C;
    localparam [7:0] ADDR_IV2 = 8'h20;
    localparam [7:0] ADDR_IV3 = 8'h24;

    localparam [7:0] ADDR_DATA0 = 8'h28;
    localparam [7:0] ADDR_DATA1 = 8'h2C;
    localparam [7:0] ADDR_DATA2 = 8'h30;
    localparam [7:0] ADDR_DATA3 = 8'h34;

    localparam [7:0] ADDR_RESULT0 = 8'h38;
    localparam [7:0] ADDR_RESULT1 = 8'h3C;
    localparam [7:0] ADDR_RESULT2 = 8'h40;
    localparam [7:0] ADDR_RESULT3 = 8'h44;

    //Control bits
    localparam START_BIT = 0;
    localparam ZEROIZE_BIT = 1;
    localparam AES_MODE_BIT = 2;
    localparam BLOCK_MODE = 3;
    localparam KEY_LOCK_BIT = 5;
    localparam LAST_BLOCK_BIT = 6;

    //PCLK Regs
    reg [31:0] key_word0;
    reg [31:0] key_word1;
    reg [31:0] key_word2;
    reg [31:0] key_word3;

    reg [31:0] iv_word0;
    reg [31:0] iv_word1;
    reg [31:0] iv_word2;
    reg [31:0] iv_word3;

    reg [31:0] data_word0;
    reg [31:0] data_word1;
    reg [31:0] data_word2;

    reg [127:0] key_reg;
    reg [127:0] iv_reg;

    reg aes_mode_reg;
    reg [1:0] block_mode_reg;
    reg key_lock_reg;
    reg last_block_reg;

    reg [127:0] result_reg;
    reg done_reg;

    reg result_read_pending;
    reg transaction_active;

    reg security_violation_reg;

    reg valid_addr;
    reg security_sensitive_access;

    always @(*) begin
        security_sensitive_access = 1'b0;
        valid_addr = 1'b0;
        case (reg_addr)
            ADDR_CONTROL,
            ADDR_KEY0, ADDR_KEY1, ADDR_KEY2, ADDR_KEY3,
            ADDR_IV0, ADDR_IV1, ADDR_IV2, ADDR_IV3,
            ADDR_DATA0, ADDR_DATA1, ADDR_DATA2, ADDR_DATA3:
                security_sensitive_access = 1'b1;

            default:security_sensitive_access = 1'b0;
        endcase
        
        case (reg_addr)
            ADDR_CONTROL,ADDR_STATUS,
            ADDR_KEY0, ADDR_KEY1, ADDR_KEY2, ADDR_KEY3,
            ADDR_IV0, ADDR_IV1, ADDR_IV2, ADDR_IV3,
            ADDR_DATA0, ADDR_DATA1, ADDR_DATA2, ADDR_DATA3,
            ADDR_RESULT0, ADDR_RESULT1, ADDR_RESULT2, ADDR_RESULT3:
                valid_addr = 1'b1;

            default:valid_addr = 1'b0;
        endcase
    end

    wire secure_write,secure_read;
    wire write_only_reg, read_only_reg;
    
    assign secure_write = write_en && !(security_sensitive_access && !reg_pprot[0]);//Not of ( Protected and Unprivileged)

    assign secure_read = read_en && !(security_sensitive_access && !reg_pprot[0]);
    
    assign write_only_reg =
       (reg_addr >= ADDR_KEY0)  && (reg_addr <= ADDR_KEY3)  ||
       (reg_addr >= ADDR_IV0)   && (reg_addr <= ADDR_IV3)   ||
       (reg_addr >= ADDR_DATA0) && (reg_addr <= ADDR_DATA3);

    assign read_only_reg =
       (reg_addr >= ADDR_RESULT0) && (reg_addr <= ADDR_RESULT3) ||
       (reg_addr >= ADDR_STATUS);

    //Configuration, Control, Data and Result registers
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            key_word0 <= 32'b0;
            key_word1 <= 32'b0;
            key_word2 <= 32'b0;
            key_word3 <= 32'b0;

            iv_word0 <= 32'b0;
            iv_word1 <= 32'b0;
            iv_word2 <= 32'b0;
            iv_word3 <= 32'b0;

            data_word0 <= 32'b0;
            data_word1 <= 32'b0;
            data_word2 <= 32'b0;

            key_reg <= 128'b0;
            iv_reg <= 128'b0;

            aes_mode_reg <= 1'b0;
            block_mode_reg <= 2'b0;
            key_lock_reg <= 1'b0;
            last_block_reg <= 1'b0;

            cfg_key <= 128'b0;
            cfg_iv <= 128'b0;
            cfg_aes_mode <= 1'b0;
            cfg_block_mode <= 2'b0;
            cfg_req <= 1'b0;

            start_req <= 1'b0;
            zeroize_req <= 1'b0;

            data_fifo_wdata <= 129'b0;
            data_fifo_wr_en <= 1'b0;

            result_fifo_rd_en <= 1'b0;
            result_read_pending <= 1'b0;
            result_reg <= 128'b0;
            done_reg <= 1'b0;

            transaction_active <= 1'b0;

        end else begin

            cfg_req <= 1'b0;
            start_req <= 1'b0;
            zeroize_req <= 1'b0;
            data_fifo_wr_en <= 1'b0;
            result_fifo_rd_en <= 1'b0;
            

            if (trans_done) transaction_active <= 1'b0;

            //ZEROIZE has highest priority
            if (secure_write && reg_addr == ADDR_CONTROL && reg_wdata[ZEROIZE_BIT]) begin

                zeroize_req <= 1'b1;

                key_word0 <= 32'b0;
                key_word1 <= 32'b0;
                key_word2 <= 32'b0;
                key_word3 <= 32'b0;

                iv_word0 <= 32'b0;
                iv_word1 <= 32'b0;
                iv_word2 <= 32'b0;
                iv_word3 <= 32'b0;

                data_word0 <= 32'b0;
                data_word1 <= 32'b0;
                data_word2 <= 32'b0;

                key_reg <= 128'b0;
                iv_reg <= 128'b0;

                aes_mode_reg <= 1'b0;
                block_mode_reg <= 2'b0;
                last_block_reg <= 1'b0;

                cfg_key <= 128'b0;
                cfg_iv <= 128'b0;
                cfg_aes_mode <= 1'b0;
                cfg_block_mode <= 2'b0;
                cfg_req <= 1'b0;

                data_fifo_wdata <= 129'b0;

                result_reg <= 128'b0;
                done_reg <= 1'b0;
                result_read_pending <= 1'b0;

                transaction_active <= 1'b0;

            end else begin

                //Key Registers
                if (secure_write && !key_lock_reg && !transaction_active) begin
                    case (reg_addr)
                        ADDR_KEY0: key_word0 <= reg_wdata;
                        ADDR_KEY1: key_word1 <= reg_wdata;
                        ADDR_KEY2: key_word2 <= reg_wdata;
                        ADDR_KEY3: key_word3 <= reg_wdata;
                        //default: ;
                    endcase
                end

                //IV Registers
                if (secure_write && !key_lock_reg && !transaction_active) begin
                    case (reg_addr)
                        ADDR_IV0: iv_word0 <= reg_wdata;
                        ADDR_IV1: iv_word1 <= reg_wdata;
                        ADDR_IV2: iv_word2 <= reg_wdata;
                        ADDR_IV3: iv_word3 <= reg_wdata;
                        //default: ;
                    endcase
                end

                key_reg <= {key_word3,key_word2,key_word1,key_word0};
                iv_reg <= {iv_word3,iv_word2,iv_word1,iv_word0};

                //Control Register
                if (secure_write && reg_addr == ADDR_CONTROL) begin

                    if (reg_wdata[START_BIT] && !cfg_busy && !transaction_active && !busy) begin
                        cfg_key <= key_reg;
                        cfg_iv <= iv_reg;
                        cfg_aes_mode <= aes_mode_reg;
                        cfg_block_mode <= block_mode_reg;

                        cfg_req <= 1'b1;
                        start_req <= 1'b1;
                        transaction_active <= 1'b1;
                        done_reg <= 1'b0;
                    end

                    if (!transaction_active && !key_lock_reg) begin
                        aes_mode_reg <= reg_wdata[AES_MODE_BIT];
                        block_mode_reg <= reg_wdata[BLOCK_MODE +: 2];

                        if (reg_wdata[KEY_LOCK_BIT])
                            key_lock_reg <= 1'b1;
                    end

                    if (!transaction_active)
                        last_block_reg <= reg_wdata[LAST_BLOCK_BIT];
                end

                //Data registering and FIFO writing
                if (secure_write && !transaction_active) begin
                    if (reg_addr == ADDR_DATA0)
                        data_word0 <= reg_wdata;
                
                    if (reg_addr == ADDR_DATA1)
                        data_word1 <= reg_wdata;
                
                    if (reg_addr == ADDR_DATA2)
                        data_word2 <= reg_wdata;
                
                    if (reg_addr == ADDR_DATA3) begin
                        data_fifo_wdata <= {last_block_reg, reg_wdata, data_word2, data_word1, data_word0};
                
                        data_fifo_wr_en <= 1'b1;
                        last_block_reg <= 1'b0;
                    end
                end 

                //RX FIFO
                if (trans_done && !result_fifo_empty) begin
                    result_fifo_rd_en <= 1'b1;
                    result_read_pending <= 1'b1;
                end

                if (result_read_pending) begin
                    result_reg <= result_fifo_rdata;
                    result_read_pending <= 1'b0;
                    done_reg <= 1'b1;
                end
            end
        end
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            security_violation_reg <= 1'b0;

        else if ((write_en || read_en) && security_sensitive_access && !reg_pprot[0])
            security_violation_reg <= 1'b1; //only for security violations not every pslverr
    end

    //APB Read MUX
    always @(*) begin
        reg_rdata = 32'b0;

        if (secure_read) begin
            case (reg_addr)

                ADDR_CONTROL: begin
                    reg_rdata[START_BIT] = 1'b0;
                    reg_rdata[ZEROIZE_BIT] = 1'b0;
                    reg_rdata[AES_MODE_BIT] = aes_mode_reg;
                    reg_rdata[BLOCK_MODE +: 2] = block_mode_reg;
                    reg_rdata[KEY_LOCK_BIT] = key_lock_reg;
                    reg_rdata[LAST_BLOCK_BIT] = last_block_reg;
                end

                ADDR_STATUS: begin
                    reg_rdata[0] = busy;
                    reg_rdata[1] = done_reg;
                    reg_rdata[2] = data_fifo_full;
                    reg_rdata[3] = result_fifo_empty;
                    reg_rdata[4] = security_violation_reg;
                end

                ADDR_RESULT0:if (done_reg) reg_rdata = result_reg[31:0];

                ADDR_RESULT1: if (done_reg) reg_rdata = result_reg[63:32];

                ADDR_RESULT2: if (done_reg) reg_rdata = result_reg[95:64];

                ADDR_RESULT3: if (done_reg) reg_rdata = result_reg[127:96];

                ADDR_KEY0, ADDR_KEY1, ADDR_KEY2, ADDR_KEY3: reg_rdata = 32'b0;

                ADDR_IV0, ADDR_IV1, ADDR_IV2, ADDR_IV3: reg_rdata = 32'b0;

                ADDR_DATA0, ADDR_DATA1, ADDR_DATA2, ADDR_DATA3: reg_rdata = 32'b0;

                default: reg_rdata = 32'b0;

            endcase
        end
    end
    
    //PSLVERR 
    always @(*) begin
        reg_pslverr = 1'b0;

        if ((write_en || read_en) && !valid_addr) reg_pslverr = 1'b1;

        if ((write_en || read_en) && security_sensitive_access && !reg_pprot[0]) reg_pslverr = 1'b1; //unprivileged access

        //Read from write-only registers
        if (read_en && write_only_reg)
            reg_pslverr = 1'b1;

        //Write to read only regs
        if (write_en && read_only_reg)
            reg_pslverr = 1'b1;

        //Start while busy or while outstanding handshake/transaction
        if (secure_write && reg_addr == ADDR_CONTROL && reg_wdata[START_BIT] && (busy || transaction_active || cfg_busy))
            reg_pslverr = 1'b1;
    end

    assign security_violation = security_violation_reg;

endmodule
