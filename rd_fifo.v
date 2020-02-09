module rd_fifo
#(parameter ADDR_WIDTH=9)
	(
        input clk,
        input reset,
        input rd,
        input d_valid,
        input [15:0] data_i,
        output [15:0] data_o,
        output [(ADDR_WIDTH-1):0] wr_faddr,
        output [(ADDR_WIDTH-1):0] rd_faddr,
        output empty
	);

reg [(ADDR_WIDTH-1):0] read_addr;
reg [(ADDR_WIDTH-1):0] write_addr;
reg [15:0] ram[2**ADDR_WIDTH-1:0];
reg [15:0] q;

always @ (posedge rd or negedge reset)
	if(reset==0) read_addr<=0;
	else if(rd)
		if(empty==0)
		begin
			q <= ram[read_addr];
			read_addr<=read_addr+1'b1;
		end

always @ (posedge clk)
	if(reset==0) write_addr<=0;
	else begin
		if(d_valid) begin
			ram[write_addr] <= data_i;
			write_addr<=write_addr+1'b1;
			end
	end
assign wr_faddr=write_addr;
assign rd_faddr=read_addr;
assign empty=(write_addr==read_addr);
assign data_o=(rd)? q:16'bZ;
endmodule
