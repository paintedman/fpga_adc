// 27.01.2020 Dmitriev Dmitry

module adc_sdram_master #( parameter ADC_DATA_COUNT = 128 )
	(
		input	clk,
		input reset_n,
		
		input start,
		output fifo_init,
		output fifo_write,
		output fifo_read,
		output sdram_op_rw,
		output [1:0] sdram_byte_sel,
		output [31:0] sdram_addr,
		output [15:0] sdram_data
	);
	
	localparam STATE_IDLE = 0;
	localparam STATE_WRITE = 1;
	localparam STATE_READ = 2;
	
	reg start_request_r = 1;
	reg start_prev_r = 1;
	
	reg fifo_init_r;
	reg fifo_write_r;
	reg fifo_read_r;
	reg [31:0] sdram_addr_r;
	reg [15:0] sdram_data_r;
	reg sdram_op_rw_r;
	
	reg [1:0] state;
	reg [20:0] adc_data_count_r;
	
	assign fifo_init = fifo_init_r;
	assign fifo_write = fifo_write_r;
	assign fifo_read = fifo_read_r;
	assign sdram_addr = sdram_addr_r;
	assign sdram_data = sdram_data_r;
	assign sdram_op_rw = sdram_op_rw_r;
	assign sdram_byte_sel = 2'b11;
	
	
	always @ ( posedge clk ) begin
		if ( start_prev_r == 1 && start == 0 ) 
			start_request_r <= 0;
		else 
			start_request_r <= 1;
		
		start_prev_r <= start;
	end
	
	always @ ( posedge clk ) begin
		if ( reset_n == 0 ) begin
			fifo_init_r <= 0;
			fifo_write_r <= 0;
			fifo_read_r <= 0;
			sdram_addr_r <= 0;
			sdram_data_r <= 0;
			sdram_op_rw_r <= 0;
		end 
		
		case ( state ) 
			STATE_IDLE: begin
				fifo_write_r <= 0;
				fifo_read_r <= 0;
				sdram_addr_r <= 0;
				sdram_data_r <= 0;
				sdram_op_rw_r <= 0;
				adc_data_count_r <= ADC_DATA_COUNT;
				
				if ( start_request_r == 0 ) begin
					fifo_init_r <= 1;
					state <= STATE_WRITE;
				end else begin
					fifo_init_r <= 0;
					state <= STATE_IDLE;
				end
			end
			
			STATE_WRITE: begin
				fifo_write_r <= 1;
				fifo_read_r <= 0;
				
				if ( adc_data_count_r == 0 ) begin
					state <= STATE_READ;
					adc_data_count_r <= ADC_DATA_COUNT;
				end else begin
					state <= STATE_WRITE;
					adc_data_count_r <= adc_data_count_r - 1;
				end		
			end
			
			STATE_READ: begin
				fifo_write_r <= 0;
				fifo_read_r <= 1;
				
				if ( adc_data_count_r == 0 ) begin
					state <= STATE_IDLE;
					adc_data_count_r <= ADC_DATA_COUNT;
				end else begin
					state <= STATE_READ;
					adc_data_count_r <= adc_data_count_r - 1;
				end
			end
		
		endcase
	end
	
endmodule