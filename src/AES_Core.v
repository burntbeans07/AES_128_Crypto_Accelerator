module AES_Core(       
    input wire clk,
    input wire rst,
    input wire start,
    input wire mode, 
    input wire zeroize,
    input wire [127:0] data_in,
    input wire [127:0] key,
    
    output reg [127:0] data_out,
    output reg done,
    output reg busy
);

    reg [3:0]round_count;//counts number of rounds
    reg [2:0]fsm_state,ns; //fsm states = IDLE,INIT,ROUND,FINAL,DONE
    reg [127:0]aes_state; //stores internal transformated text
    reg [127:0]key_reg;
    
    wire [127:0]round_key; //Current Round Key
    wire [127:0] sb_out; //SubBytes output
    wire [127:0] sr_out; //ShiftRows output
    wire [127:0] mc_out; //MixColumns output
    reg [127:0] ark_out; //AddRoundKey output
    //reg [127:0]temp; // Input to IMC module
    
    wire [127:0] isb_out; //InvSubBytes output
    wire [127:0] isr_out; //InvShiftRows output
    wire [127:0] imc_out; //InvMixColumns output
    
    
    
    //fsm states
    localparam IDLE=3'd0, INIT=3'd1, ROUND=3'd2, FINAL=3'd3, DONE=3'd4;
    
    Key_Exp KE (
    .keyin(key_reg),
    .r_num(round_count),
    .round_key(round_key)
    );
    
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
    
    //AddRoundKey for Final round vs normal rounds for Encrypt and Decrypt
    always @(*) begin
        if (mode) begin//Encrypt
            if(fsm_state == FINAL)
                ark_out = sr_out ^ round_key;
            else
                ark_out = mc_out ^ round_key;
                     
        end else ark_out = isb_out ^ round_key;
    end
    
    //State transition
    always @(posedge clk or posedge rst)begin
        if(rst) fsm_state <= IDLE;
        else if (zeroize) fsm_state <= IDLE;
        else fsm_state <= ns;
    end
    
    /*always @(*)begin
        if(fsm_state == INIT)
            temp = ark_out;
        else 
            temp = imc_out;
    end
    */
    
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
    
    
    
    //Sequential logic    
    always @(posedge clk or posedge rst)begin
        if(rst) begin
            data_out <= 128'b0;
            done <= 1'b0;
            busy <= 1'b0;
            round_count <= 4'b0;
            aes_state <= 128'b0;
            key_reg <=128'b0;
        
        end else if(zeroize) begin 
	  data_out <= 128'b0;
            done <= 1'b0;
            busy <= 1'b0;
            round_count <= 4'b0;
            aes_state <= 128'b0;
            key_reg <=128'b0;

        end else begin
          
            case(fsm_state)
                IDLE:begin
                    done <= 0;
                    if(start) begin
                        busy <= 1;
                        key_reg <= key; 
                        if(mode) 
                            round_count <= 4'b0;
                        else begin
                            round_count <= 4'd10;
                        end            
                    end
                end
                
                INIT: begin
                    if(mode) begin
                        aes_state <= data_in ^ key_reg;
                        round_count <= round_count + 1'b1;
                    end else begin
                        aes_state <= data_in ^ round_key;
                        round_count <= round_count - 1'b1;
                    end
                end 
                
                ROUND: begin
                    if (mode) begin
                        aes_state <= ark_out;
                        round_count <= round_count + 1'b1;
                    end else begin
                        aes_state <= imc_out;
                        round_count <= round_count - 1'b1;  
                    end
                end
                
                FINAL: aes_state <= ark_out;
                
                DONE: begin
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
        IDLE: ns = start ? INIT : IDLE;
    
        INIT: ns = ROUND;
    
        ROUND: ns = mode? ((round_count == 4'd9)? FINAL : ROUND):((round_count == 4'd1)? FINAL : ROUND)  ;
            
        FINAL: ns = DONE;
    
        DONE: ns = IDLE;
        
        default: ns = IDLE;
    
        endcase
    end
endmodule
