module AES_Core(               
    input wire clk, //crypto_clk
    input wire rstn, //Active low reset
    input wire start, //Start signal to begin computation
    input wire mode, //Mode = 1 (Encryption), Mode = 0 (Decryption)
    input wire zeroize, //Command to clear registers
    input wire [127:0] data_in, // Plaintext for Encryption and Cipher for Decryption
    input wire [127:0] key, // Input Key
    
    output reg [127:0] data_out, // Cipher for Encryption and Plaintext for Decryption
    output reg done, //High when entire process is completed and outputs loaded to registers
    output reg busy // High when computation process is ongoing
);

    reg [3:0]round_count;//counts number of rounds
    reg [2:0]fsm_state,ns; //fsm states = IDLE,INIT,KEY_EXP1,KEY_EXP2,ROUND,FINAL,DONE
    reg [127:0]aes_state; //stores internal transformated text
    reg [127:0]key_reg; //To register input key
    
    wire [127:0]round_key; //Current Round Key
    wire [127:0] sb_out; //SubBytes output
    wire [127:0] sr_out; //ShiftRows output
    wire [127:0] mc_out; //MixColumns output
    reg [127:0] ark_out; //AddRoundKey output
   
    
    wire [127:0] isb_out; //InvSubBytes output
    wire [127:0] isr_out; //InvShiftRows output
    wire [127:0] imc_out; //InvMixColumns output
    
    
    
    //fsm states
    localparam IDLE = 3'd0, KEY_EXP1 = 3'd1, KEY_EXP2 = 3'd2, INIT = 3'd3, ROUND = 3'd4, FINAL = 3'd5,DONE = 3'd6;
    
    //State transition
    always @(posedge clk or negedge rstn)begin
        if(!rstn) fsm_state <= IDLE;
        else if(zeroize) fsm_state <= IDLE;
        else fsm_state <= ns;
    end
        
    
    //Precomputed Key Expansion before Transformation starts - takes 2 cycles (KEY_EXP1, KEY_EXP2)
    //Round Count value is given as an input to get the current round key output
    Key_Exp KE (
    .clk(clk),
    .rst(!rstn || zeroize),
    .load(fsm_state == KEY_EXP2),
    .keyin(key_reg),
    .r_num(round_count),
    .round_key(round_key)
    );
    
    //Encryption Datapath 
    SubBytes SB(
    .din(aes_state),
    .subbed(sb_out)
    );
    
    ShiftRows SR(
        .din(sb_out),
        .shifted(sr_out)
    );
    
    MixColumns MC(
        .din(sr_out),
        .mixed(mc_out)
    );
    
    
    //Decryption Datapath
    InvShiftRows ISR(
        .din(aes_state),
        .shifted(isr_out)
    );
    
    InvSubBytes ISB(
        .din(isr_out),
        .subbed(isb_out)
    );
    
    InvMixColumns IMC(
        .din(ark_out),
        .mixed(imc_out)
    );
    
    //Common AddRoundKey for Final round vs normal rounds for Encrypt and Decrypt
    always @(*) begin
        if (mode) begin//Encryption
            if(fsm_state == FINAL)//Final Round skips MixColumns and takes ShiftRows Output instead
                ark_out = sr_out ^ round_key;
            else
                ark_out = mc_out ^ round_key;//Normal rounds takes MixColumns Output
                     
        end else ark_out = isb_out ^ round_key;//Decryption, MixColumns is always performed after ARK
    end
    
    
    
    //Sequential logic    
    always @(posedge clk or negedge rstn)begin
        if(!rstn) begin //Active Low reset
            data_out <= 128'b0;
            done <= 1'b0;
            busy <= 1'b0;
            round_count <= 4'b0;
            aes_state <= 128'b0;
            key_reg <=128'b0;
            
        end else if(zeroize) begin //Zeroize command clears registers
            data_out <= 128'b0;
            done <= 1'b0;
            busy <= 1'b0;
            round_count <= 4'b0;
            aes_state <= 128'b0;
            key_reg <=128'b0;          
        
        end else begin
          
            case(fsm_state) //AES_State and Status signals controlled by FSM
                IDLE:begin
                    done <= 0; //default value for one cycle done signal
                    if(start) begin //Busy is high and input key is loaded on receiving start signal
                        busy <= 1;
                        key_reg <= key; 
                        if(mode) // Counter is loaded to 0 for Encryption and 10 For Decryption
                            round_count <= 4'b0;
                        else begin
                            round_count <= 4'd10;
                        end            
                    end
                end
                   
                INIT: begin //Initial ARK Round before 9 Transformation Rounds
                    if(mode) begin // For Encryption, plaintext ^ input key
                        aes_state <= data_in ^ key_reg;
                        round_count <= round_count + 1'b1;
                    end else begin
                        aes_state <= data_in ^ round_key; //For Decryption, cipher ^ Last Round key
                        round_count <= round_count - 1'b1;
                    end
                end 
                
                ROUND: begin
                    if (mode) begin // ARK Output is loaded into AES State at the end of every Round for Encryption
                        aes_state <= ark_out;
                        round_count <= round_count + 1'b1;
                    end else begin
                        aes_state <= imc_out; // IMC Output is loaded into AES State at the end of every Round for Decryption
                        round_count <= round_count - 1'b1;  
                    end
                end
                
                FINAL: aes_state <= ark_out; // For final round, MixColumns is skipped and ARK output is loaded into AES state
                
                DONE: begin // Status signals are set/reset and state is loaded into output reg
                    data_out <= aes_state; 
                    busy <= 0;
                    done <= 1;
                    aes_state <= 128'b0;
                    round_count <= 4'b0;
                    key_reg <= 128'b0;
                    
                    
                end
                
                default: aes_state <= 128'b0;
                
            endcase
        end             
    end
    
    //Next state logic
    always @(*) begin
        case(fsm_state)
            IDLE: ns = start ? KEY_EXP1 : IDLE; // Idle moves to Key_Exp1 on receiving start signal
    
            KEY_EXP1: ns = KEY_EXP2; // Key_Exp1 moves to Key_Exp2
    
            KEY_EXP2: ns = INIT; //After Key expansion is completed, State moves to Initial Round
    
            INIT: ns = ROUND; //Initial Round moves to Round where the normal Round transformations are computed
    
            ROUND: ns = mode ? ((round_count == 4'd9) ? FINAL : ROUND) : ((round_count == 4'd1) ? FINAL : ROUND); // After 10 rounds of normal transformation, state moves to Final where MixColumns is skipped
    
            FINAL: ns = DONE; //After Final Round is completed, Outputs are loaded in DONE round
    
            DONE: ns = IDLE;//After Done, state reverts to IDLE and waits for the next start signal
    
            default: ns = IDLE;
    
        endcase
    end
             
endmodule
