module adr_selector(
	input [4:0]addr,
	input csel,
	input rd,
	input wr,  	
	output cs_res,
	output cs_row,
	output cs_laddr,	
	output cs_haddr,
	output cs_read	
);

assign cs_read=(addr==5'd20 && csel==0 && rd==0)?1'b0:1'b1;  	// Read data
assign cs_res=(addr==5'd20 && csel==0 && wr==0)?1'b0:1'b1;  	// Reset all
assign cs_laddr=(addr==5'd21 && csel==0 && wr==0)?1'b0:1'b1;    // 
assign cs_haddr=(addr==5'd22 && csel==0 && wr==0)?1'b0:1'b1;    //
assign cs_row=(addr==5'd23 && csel==0 && wr==0)?1'b0:1'b1;      // Load row
endmodule