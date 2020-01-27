module main(
	input clk,
	input cs_res,
	input cs_row,
	input cs_laddr,
	input cs_haddr,
	input [15:0]host_data,	// external interface
//----
    output [23:0]sd_addr,
    output reg hrd_req
	);

//localparam  DATA_LEN = 10'd128;

	reg [23:0]rd_addr;
    reg [7:0] count;
    reg [9:0] rd_count;
	reg next_en;
//----- Reset logic
	always @(posedge clk or negedge cs_res or negedge cs_row or negedge cs_laddr or negedge cs_haddr)
	if(cs_res==0)
		begin
        rd_addr<=24'd0;
        count<=8'd150;
        next_en<=0;
		hrd_req<=0;
		rd_count<=0;
		end
    else if(cs_laddr==0) rd_addr[15:0]<=host_data[15:0];
    else if(cs_haddr==0) rd_addr[23:16]<=host_data[7:0];
	else if(cs_row==0)
	  begin
	    next_en<=1'b1;
	    hrd_req<=1'b1;
	    rd_count<=host_data[9:0];
	  end
	else begin
		if(rd_count>0) rd_count<=rd_count-1'b1;
		else hrd_req<=1'b0;
	end

//------
	assign sd_addr=rd_addr;
endmodule

