	sdram u0 (
		.clk_clk                   (<connected-to-clk_clk>),                   //         clk.clk
		.reset_reset_n             (<connected-to-reset_reset_n>),             //       reset.reset_n
		.sdram_slave_address       (<connected-to-sdram_slave_address>),       // sdram_slave.address
		.sdram_slave_byteenable_n  (<connected-to-sdram_slave_byteenable_n>),  //            .byteenable_n
		.sdram_slave_chipselect    (<connected-to-sdram_slave_chipselect>),    //            .chipselect
		.sdram_slave_writedata     (<connected-to-sdram_slave_writedata>),     //            .writedata
		.sdram_slave_read_n        (<connected-to-sdram_slave_read_n>),        //            .read_n
		.sdram_slave_write_n       (<connected-to-sdram_slave_write_n>),       //            .write_n
		.sdram_slave_readdata      (<connected-to-sdram_slave_readdata>),      //            .readdata
		.sdram_slave_readdatavalid (<connected-to-sdram_slave_readdatavalid>), //            .readdatavalid
		.sdram_slave_waitrequest   (<connected-to-sdram_slave_waitrequest>),   //            .waitrequest
		.sdram_wire_addr           (<connected-to-sdram_wire_addr>),           //  sdram_wire.addr
		.sdram_wire_ba             (<connected-to-sdram_wire_ba>),             //            .ba
		.sdram_wire_cas_n          (<connected-to-sdram_wire_cas_n>),          //            .cas_n
		.sdram_wire_cke            (<connected-to-sdram_wire_cke>),            //            .cke
		.sdram_wire_cs_n           (<connected-to-sdram_wire_cs_n>),           //            .cs_n
		.sdram_wire_dq             (<connected-to-sdram_wire_dq>),             //            .dq
		.sdram_wire_dqm            (<connected-to-sdram_wire_dqm>),            //            .dqm
		.sdram_wire_ras_n          (<connected-to-sdram_wire_ras_n>),          //            .ras_n
		.sdram_wire_we_n           (<connected-to-sdram_wire_we_n>)            //            .we_n
	);

