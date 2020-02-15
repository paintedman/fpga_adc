
module sdram (
	clk_clk,
	reset_reset_n,
	sdram_slave_address,
	sdram_slave_byteenable_n,
	sdram_slave_chipselect,
	sdram_slave_writedata,
	sdram_slave_read_n,
	sdram_slave_write_n,
	sdram_slave_readdata,
	sdram_slave_readdatavalid,
	sdram_slave_waitrequest,
	sdram_wire_addr,
	sdram_wire_ba,
	sdram_wire_cas_n,
	sdram_wire_cke,
	sdram_wire_cs_n,
	sdram_wire_dq,
	sdram_wire_dqm,
	sdram_wire_ras_n,
	sdram_wire_we_n);	

	input		clk_clk;
	input		reset_reset_n;
	input	[23:0]	sdram_slave_address;
	input	[1:0]	sdram_slave_byteenable_n;
	input		sdram_slave_chipselect;
	input	[15:0]	sdram_slave_writedata;
	input		sdram_slave_read_n;
	input		sdram_slave_write_n;
	output	[15:0]	sdram_slave_readdata;
	output		sdram_slave_readdatavalid;
	output		sdram_slave_waitrequest;
	output	[12:0]	sdram_wire_addr;
	output	[1:0]	sdram_wire_ba;
	output		sdram_wire_cas_n;
	output		sdram_wire_cke;
	output		sdram_wire_cs_n;
	inout	[15:0]	sdram_wire_dq;
	output	[1:0]	sdram_wire_dqm;
	output		sdram_wire_ras_n;
	output		sdram_wire_we_n;
endmodule
