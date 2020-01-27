module test(
	input clk,
	input res,
	input stall,
	input clk_o1,
	input hrd_req,
	input [23:0] hrd_addr,
	input [15:0] host_data,
//----
	output reg res_o=0,
	output reg re_we,
	output reg cyc_o,     // start
	output [23:0] addr,
	output [15:0] data,
	output rd_rec,
	output reg start=0
	);

//parameter  DATA_LEN = 128;

    reg wr_data_en=0;
    reg rd_data_en=0;
    reg [3:0]state;
    reg [1:0] operation=0;
    reg [9:0] data_count=0;
    reg [9:0] data_len=0;
    reg [15:0]res_count=0;//4'd10;
	reg [15:0]wr_data=0;
	reg [15:0]wr_circle_count=0;
	reg [15:0]rd_circle_count=0;
	reg [23:0]addr_count;
//----- Reset logic
	always @(posedge clk)
		if(res==0)
            begin
                res_o <= 1'b1; // short reset sdram
                res_count<=16'd20000; // 200 mks
                start<=0;
                data_len<=host_data[9:0];
            end
		else if(res_count>0)
		    begin
		        res_count<=res_count-1'b1;
                if(res_count<16'd19995) res_o <= 1'b0;
                if(res_count==16'd1) start<=1'b1;  // Start (sdram ready for test)
		    end

//------
	always @(posedge clk)
	begin
	if(start==0)
		begin
        re_we<=0;
        cyc_o<=0;
        state<=0;
		operation<=0;
		wr_data<=16'h0;
		wr_circle_count<=16'd0;
		rd_circle_count<=16'd0;
		addr_count<=24'd0;
		end
	else
        begin
//----------------- WRITE -------
         if(operation==2'd0) // write operation
            case (state)
            0:  // load data
            begin
                re_we<=1'b1;		// write
                cyc_o<=1'b1;		// start op
                state<=state+1'b1;
            end

            1: // wait for stall
            if(stall==0)
            begin
                state<=state+1'b1;
                data_count<=0;
                wr_data<=wr_data+1'b1;
            end

            2: // data send
            if(data_count<data_len)
                begin
                    data_count<=data_count+1'b1;
                    wr_data<=wr_data+1'b1;
                end
            else
            begin
                state<=state+1'b1;
                cyc_o<=1'b0;		// stop
                re_we<=1'b0;
                wr_data<=0;
                operation<=2'd1; // next operation Read
            end

            default:;
            endcase
//----------------- READ -------
			else if(hrd_req)
				begin
					re_we<=1'b0;		// read
					cyc_o<=1'b1;		// start op
				end
			else cyc_o<=1'b0;		// start op
        end
	end
 	assign addr=(hrd_req)? hrd_addr : addr_count;
	assign data=wr_data;
	assign rd_rec=rd_data_en;
endmodule

