module Handshake (
    // Source clock domain
    input  wire src_clk,
    input  wire src_rstn,
    input  wire src_req,
    output wire src_busy,

    // Destination clock domain
    input  wire dst_clk,
    input  wire dst_rstn,
    output reg  dst_pulse
);

    reg req_toggle;

    // Synchronize acknowledgement back to source
    reg ack_sync;
    // Synchronize request to destination
    reg req_sync;
    reg req_sync_d;

    // Source is busy until destination acknowledges
    assign src_busy = (req_toggle != ack_sync);

    always @(posedge src_clk or negedge src_rstn) begin
        if (!src_rstn) begin
            req_toggle <= 1'b0;
        end
        else if (src_req && !src_busy) begin
            req_toggle <= ~req_toggle;
        end
    end

    // ACK back to source    
    FF2_Synch ack(src_clk,src_rstn,req_sync,ack_sync);
    FF2_Synch req(dst_clk,dst_rstn, req_toggle, req_sync);

    always @(posedge dst_clk or negedge dst_rstn) begin
        if (!dst_rstn) begin
            req_sync_d <= 1'b0;
            dst_pulse  <= 1'b0;
        end
        else begin
            req_sync_d <= req_sync;
            // Detect new request
            dst_pulse <= req_sync ^ req_sync_d;
        end
    end

endmodule


