module pip
#(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=13)
	(
        input clk,
        input start,
        input rd,
        input wr,		
        input [(DATA_WIDTH-1):0] data,
        output reg [(DATA_WIDTH-1):0] q,
        output [(ADDR_WIDTH-1):0] wr_addr,		
        output [(ADDR_WIDTH-1):0] rd_addr,
        output empty
	);

reg [(ADDR_WIDTH-1):0] read_addr;
reg [(ADDR_WIDTH-1):0] write_addr;
reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

always @ (posedge clk)
if(start==0) begin
    read_addr<=0;
    write_addr<=0;
    end
else begin
	if(wr) begin
		ram[write_addr] <= data;
		write_addr<=write_addr+1'b1;
	end
    if(empty==0 && rd)
    begin
        q <= ram[read_addr];
        read_addr<=read_addr+1'b1;
    end
end

assign rd_addr=read_addr;
assign wr_addr=write_addr;
assign empty=(write_addr==read_addr);
endmodule
