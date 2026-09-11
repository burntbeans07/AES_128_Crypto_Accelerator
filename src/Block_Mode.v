module Block_Mode (
    input wire crypto_clk,
    input wire rstn, //Active low reset
    input wire zeroize, //Clears internal registers and aborts process

    // Registered outputs from handshake module
    input wire [127:0] key_in,//Input Key
    input wire [127:0] iv_in,// Input IV for CBC and count value for CTR
    input wire aes_mode_in,// 1 = encrypt, 0 = decrypt
    input wire [1:0] block_mode_in,// 00=ECB, 01=CBC, 10=CTR
    input wire load, //Signal from Handshake mechanism that tells inputs are ready to be captured
    input wire start, //Begins Process

    // Data FIFO for Pclk to crypto_clk
    input wire [128:0] fifo_data_in, // Plaintext/Cipher from FIFO and last block bit
    input wire fifo_empty, //Signifies if Fifo is empty or has data to be read
    output reg fifo_rd_en, // Asserted if !fifo_empty so FIFO Allows data to be read

    // Result FIFO for crypto_clk to pclk
    output reg [127:0] fifo_wdata, //Output data to be sent back to Slave
    output reg fifo_wr_en, // Write enable for FIFO, asserted if !fifo_full
    input wire fifo_full,//checks if fifo is full or can be written into
    
    // Status signals to be sent through handshake mechanism
    output reg busy,
    output reg trans_done
);

    wire [127:0]fifo_rdata;
    wire last_block;
    
    assign {last_block, fifo_rdata} = fifo_data_in;
    //Registered Inputs from Handshake Mechanism
    reg [127:0] key_reg;
    reg [127:0] iv_reg;
    reg aes_mode_reg;
    reg [1:0] block_mode_reg;
    
    reg last_block_reg;//Registers Last block input when FSM is in Wait State

    //Registers for CBC and CTR Mode
    reg [127:0] cbc_reg;//Maintains previous Cipher to be XORed with input data
    reg [127:0] counter_reg;//Maintains counter value to be encrypted or decrypted

    //reg [127:0] data_reg;//Input registered from Data FIFO
    
    //Signals sent to AES Core
    reg [127:0] aes_input; //AES input after external mode operations are performed
    wire [127:0] aes_output; //Output from AES Core
    reg aes_start; //Start signal sent to AES
    wire aes_done; //Done signal from AES Core signifies process is over
    wire aes_busy; //Busy signal from AES Core signifies process is ongoing
    
    reg [2:0] state;
    reg [2:0] ns;
    //fsm states
    localparam IDLE = 3'd0, WAIT = 3'd1, START_AES = 3'd3, AES_BUSY = 3'd4, DONE = 3'd5;
    //localparam READ_DATA = 3'd2;

    AES_Core AES (
        .clk(crypto_clk),
        .rstn(rstn),
        .start(aes_start),
        .mode(aes_mode_reg),
        .zeroize(zeroize),
        .data_in(aes_input),
        .key(key_reg),
        .data_out(aes_output),
        .done(aes_done),
        .busy(aes_busy)
    );
    
  
    //Combinational Logic for next state
    always @(*) begin
        ns = state;

        case (state)
            IDLE: ns = start? WAIT : IDLE; //Idle moves to wait state if start signal received

            WAIT: ns = (!fifo_empty)? START_AES : WAIT;//Wait checks if fifo is empty and asserts rd_en and moves to start_aes

            START_AES: ns = (!aes_busy)? AES_BUSY : START_AES;//Block Mode specific inputs are loaded and AES computation begins

            AES_BUSY: ns = aes_done? DONE : AES_BUSY;//Stays here until AES_done is high, moves to DONE for loading outputs
            
            /*If fifo is not full - output is written to fifo
            After writing, if it is the last block, ns = IDLE and waits for next transaction
            Otherwise it moves to WAIT for the next 128 bit data block
            If fifo is full it stays in DONE*/
            DONE: ns = (!fifo_full)? (last_block_reg? IDLE : WAIT) : DONE;
            
            default:ns = IDLE;
        endcase
    end

    //Sequential Logic controlling FSM and status signals
    always @(posedge crypto_clk or negedge rstn) begin
        if (!rstn) begin //All registers cleared
            key_reg <= 128'b0;
            iv_reg <= 128'b0;
            aes_mode_reg <= 1'b0;
            block_mode_reg <= 2'b00;
            cbc_reg <= 128'b0;
            counter_reg <= 128'b0;
            //data_reg <= 128'b0;
            aes_input <= 128'b0;
            aes_start <= 1'b0;
            fifo_rd_en <= 1'b0;
            fifo_wdata <= 128'b0;
            fifo_wr_en <= 1'b0;
            busy <= 1'b0;
            state <= IDLE;
            trans_done <= 1'b0;
            cfg_ack <= 1'b0;

        end else if(zeroize) begin // All registers cleared - highest priority
            key_reg <= 128'b0;
            iv_reg <= 128'b0;
            aes_mode_reg <= 1'b0;
            block_mode_reg <= 2'b00;
            cbc_reg <= 128'b0;
            counter_reg <= 128'b0;
            //data_reg <= 128'b0;
            aes_input <= 128'b0;
            aes_start <= 1'b0;
            fifo_rd_en <= 1'b0;
            fifo_wdata <= 128'b0;
            fifo_wr_en <= 1'b0;
            busy <= 1'b0;
            state <= IDLE;
            trans_done <= 1'b0;
            cfg_ack <= 1'b0;
    
        end else begin
            state <= ns;

            //Default value for one cycle signals
            aes_start <= 1'b0;
            fifo_rd_en <= 1'b0;
            fifo_wr_en <= 1'b0;
            
            // Inputs from handshake are registered when aes core is idle and enable is given from handshake
            //Only loaded once per transaction
            if (load && !busy) begin
                key_reg <= key_in;
                iv_reg <= (block_mode_in == 2'b00) ? 128'b0 : iv_in;
                aes_mode_reg <= (block_mode_in == 2'b10) ? 1'b1 : aes_mode_in;
                block_mode_reg <= block_mode_in;
            end
            
            //Control/Status/Data signals
            case (state)
                IDLE: begin //Idle state - waiting to start
                    busy <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        //Block Specific registers loaded depending on ECB,CBC or CTR
                        case (block_mode_in)
                            //ECB
                            2'b00: begin
                                cbc_reg <= 128'b0;
                                counter_reg <= 128'b0;
                            end
                            // CBC
                            2'b01: begin
                                cbc_reg <= iv_reg;
                                counter_reg <= 128'b0;
                            end
        
                            // CTR
                            2'b10: begin
                                cbc_reg <= 128'b0;
                                counter_reg <= iv_reg;
                            end
        
                            default: begin
                                cbc_reg <= 128'b0;
                                counter_reg <= 128'b0;
                            end
                        endcase
                    end
                end
                
                //Waiting to read input data from FIFO - checks if fifo is empty
                WAIT: begin 
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1'b1;
                        last_block_reg <= last_block;
                    end
                end
                
                /*FIFO data is loaded into data_reg
                READ_DATA: begin 
                    data_reg <= fifo_rdata;
                    state <= START_AES;
                end*/

                //Block specific input modifications are loaded to aes input and aes_start signal generated
                START_AES: begin
                    if(!aes_busy) begin
                        aes_start <= 1'b1;
                        case (block_mode_reg) //Inputs loaded to AES Core depending on Block Mode
                            2'b00: aes_input <= fifo_rdata; //ECB

                            2'b01: begin
                                if (aes_mode_reg) aes_input <= fifo_rdata ^ cbc_reg; //CBC Encryption
                                else aes_input <= fifo_rdata; //CBC Decryption
                            end

                            2'b10: aes_input <= counter_reg;
                            
                            default: aes_input <= 128'b0;
                        endcase
                    end
                end

                //Wait for AES Core to finish computing and move to Done state
                AES_BUSY: begin end

                //Outputs are loaded into register
                DONE: begin
                    if (!fifo_full) begin //checks if fifo can be written into
                        fifo_wr_en <= 1'b1;
                        case (block_mode_reg)
                            2'b00: fifo_wdata <= aes_output; //ECB

                            2'b01: begin
                                if (aes_mode_reg) begin //CBC Encryption
                                    fifo_wdata <= aes_output;// Output loaded to wdata to be sent to FIFO
                                    cbc_reg <= aes_output;// Output Ciphertext becomes next chaining value

                                end else begin//CBC Decryption
                                    fifo_wdata <= aes_output ^ cbc_reg;// AES Output XORed with previous cipher to obtain original plaintext
                                    cbc_reg <= fifo_rdata;// Current ciphertext becomes next chaining value
                                end
                            end

                            //CTR
                            2'b10: begin
                                fifo_wdata <= fifo_rdata ^ aes_output;//Input Data XORed with Encrypted Counter value to get Cipher/Original Plaintext
                                counter_reg <= counter_reg + 128'd1;//Increment for next block
                            end
                            
                            default: fifo_wdata <= 128'b0;
                        endcase
                        
                        if(last_block) begin
                            busy <= 1'b0;
                            trans_done <= 1'b1;
                        end
                    end
                end

                default: begin
                    busy  <= 1'b0;
                end
            endcase

        end
    end

endmodule
