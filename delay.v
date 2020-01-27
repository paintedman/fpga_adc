module delay(
	input clk,
	input start,
	output reg delay_out=0
);
 reg [23:0] count;

 always @ (posedge clk or posedge start)  //
   begin
     if(start)
      begin
       count[23:0]<=24'hffffff;
       delay_out<=1'b0;
      end
     else
      begin
       if(count!=0) count<=count-1'b1;//
       if(count==24'd2) delay_out<=1'b1;
       else if(count==24'd1) delay_out<=1'b1;
       else  delay_out<=1'b0;
      end
   end
 endmodule


