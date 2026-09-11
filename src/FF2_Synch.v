module FF2_Synch(input clk,rstn,sync_in, output reg sync_out);
reg ff1,ff2;
always @(posedge clk or negedge rstn)begin
	if(!rstn)begin
		ff1<=0;
		ff2<=0;
		sync_out<=0;
	end else begin
		ff1<= sync_in;
		ff2<=ff1;
		sync_out<=ff2;
	end
end
endmodule
