module impulse_generator (input clk,
                          input input_signal,
                          output reg output_signal);
    
    reg prev_input = 1;
    
    always @ ( posedge clk ) begin
        if ( prev_input == 1 && input_signal == 0 )
            output_signal <= 1;
        else
            output_signal <= 0;
        
        prev_input <= input_signal;
    end
    
endmodule
