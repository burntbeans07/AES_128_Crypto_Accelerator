module FF2_Synch #(
    parameter WIDTH = 1
)(
    input clk,
    input rstn,
    input [WIDTH-1:0]sync_in,
    output reg [WIDTH-1:0]sync_out
);
    reg [WIDTH-1:0] ff1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ff1      <= {WIDTH{1'b0}};
            sync_out <= {WIDTH{1'b0}};
        end else begin
            ff1      <= sync_in;
            sync_out <= ff1;
        end
    end
endmodule


