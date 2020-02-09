module pip
#(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=15)
	(
        input clk,
        input start,
        input rd,
        input wr,		
        input [(DATA_WIDTH-1):0] data,
        output reg [(DATA_WIDTH-1):0] q,
        output empty,
		  output full
	);

reg [(ADDR_WIDTH-1):0] read_addr;
reg [(ADDR_WIDTH-1):0] write_addr;
reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

wire [(ADDR_WIDTH-1):0] next_write_addr;

assign next_write_addr = ( write_addr + 1 );
assign full = ( next_write_addr == read_addr );
assign empty = ( write_addr == read_addr );

always @( posedge clk ) begin
	if ( start == 0 ) begin
		 read_addr <= 0;
		 write_addr <= 0;
	end else begin
		if ( wr && !full ) begin
			ram[write_addr] <= data;
			write_addr <= write_addr + 1'b1;
		end
		if ( empty == 0 && rd ) begin
			  q <= ram[read_addr];
			  read_addr <= read_addr+1'b1;
		end
	end
end

endmodule
