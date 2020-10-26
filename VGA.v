module kbd_protocol (reset, clock, ps2clk, ps2data, scancode, f0);
  input        reset, clock, ps2clk, ps2data;
  output [7:0] scancode;
  output       f0;
  reg    [7:0] scancode;
  reg    [7:0] ps2clksamples; // Stores last 8 ps2clk samples

  always @(posedge clock or posedge reset)
    if (reset) ps2clksamples <= 8'd0;
      else ps2clksamples <= {ps2clksamples[7:0], ps2clk};

  wire fall_edge; // indicates a falling_edge at ps2clk
  assign fall_edge = (ps2clksamples[7:4] == 4'hF) & (ps2clksamples[3:0] == 4'h0);

  reg    [9:0] shift;   // Stores a serial package, excluding the stop bit;
  reg    [3:0] cnt;     // Used to count the ps2data samples stored so far
  reg          f0;      // Used to indicate that f0 was encountered earlier
  
  always @(posedge clock or posedge reset)
    if (reset) 
      begin
        cnt      <= 4'd0;
        scancode <= 8'd0;
        shift    <= 10'd0;
        f0       <= 1'b0;
      end  
     else if (fall_edge)
         begin
           if (cnt == 4'd10) // we just received what should be the stop bit
             begin
               cnt <= 0;
               if ((shift[0] == 0) && (ps2data == 1) && (^shift[9:1]==1)) // A well received serial packet
                 begin
                   if (f0) // following a scancode of f0. So a key is released ! 
                     begin
                       scancode <= shift[8:1];
                       f0 <= 0;
                     end
                    else if (shift[8:1] == 8'hF0) f0 <= 1'b1;
                 end // All other packets have to do with key presses and are ignored
             end
            else
             begin
               shift <= {ps2data, shift[9:1]}; // Shift right since LSB first is transmitted
               cnt <= cnt+1;
             end
         end
endmodule

module VGA(clk25M, clk05H, en, reset, h_sync, v_sync, r, g, b, scancode, f0);
input clk25M, clk05H, en, reset, f0;
input [7:0]scancode;
output [2:0]r;
output [2:0]g;
output [2:0]b;
output h_sync, v_sync;

reg [9:0]x;
reg [8:0]y;
wire h_sync_end;

always@(posedge clk25M or posedge reset)
begin
	if(reset)
	begin
		x <= 10'b0;
		y <= 9'b0;
	end
	else if (en)
	begin
		if (x < 10'd799)
			x <= x + 1;
		else
			x <= 10'b0;
		if (h_sync_end)
		begin
			if (y < 9'd448)
				y <= y + 1;			
			else
				y <= 9'b0;
		end
	end
end
	reg [9:0]w;
	reg [8:0]h;
	reg f;
	reg i;
	reg [7:0] btn;
	
//	reg [2:0] r;
//	reg [2:0] g;
//	reg [2:0] b;
	always@(negedge f0 or posedge reset)
	if (reset)
	begin
		h <= 9'd20;
		w <= 10'd20;
		f <= 1'b0;
		i <= 1'b0;
	end
	else if (en)
	begin
		h <= (scancode == 'h75) ? ((h < 9'd190)  ? h + 'd5 : h) :
			  (scancode == 'h72) ? ((h > 9'd10)   ? h - 'd5 : h) : h ;
		w <= (scancode == 'h6b) ? ((w < 10'd300) ? w + 'd5 : w) :
			  (scancode == 'h74) ? ((w > 10'd10)  ? w - 'd5 : w) : w ;
		f <= (scancode == 'h2B) ? ~f : f; 
		i <= (scancode == 'h2D) ? ~i : i;
	end
	
	assign {r, g, b} = ((x < 10'd160) || (y < 9'd49))? 9'b000000000 :
                      ((x > 10'd475 - w && x < 10'd480 - w) && (y > 9'd244 - h && y < 9'd249 + h)) ? 9'b100110100 ^ ({9{f & clk05H}} | {9{i}}) :
                      ((x > 10'd475 + w && x < 10'd480 + w) && (y > 9'd244 - h && y < 9'd249 + h)) ? 9'b100110100 ^ ({9{f & clk05H}} | {9{i}}) :
					  ((x > 10'd475 - w && x < 10'd480 + w) && (y > 9'd244 - h && y < 9'd249 - h)) ? 9'b100110100 ^ ({9{f & clk05H}} | {9{i}}) :
					  ((x > 10'd475 - w && x < 10'd480 + w) && (y > 9'd244 + h && y < 9'd249 + h)) ? 9'b100110100 ^ ({9{f & clk05H}} | {9{i}}) : 9'b000000000 ^ {9{i}};
							  
	assign h_sync_end = (x == 10'd799) ? 1'b1 : 1'b0;
	assign h_sync = ((x > 10'd15) && (x < 10'd112)) ? 1'b0 : 1'b1;
    assign v_sync = ((y > 9'd11)   && (y < 9'd14))  ? 1'b1 : 1'b0;						 
endmodule

module divider(clock, clk25M, reset, en);
	input clock, reset, en;
	output clk25M;
	reg [1:0]count;
	always@(posedge clock or posedge reset)
	begin
	if (reset) count <= 0;
	else if (en) count <= count + 1;
	end
	assign clk25M = count[1];
endmodule

module cnt25 (reset, clk, enable, clkdiv25); // modulo 5
input reset, clk, enable;
output clkdiv25;
reg [5:0] cnt;

assign clkdiv25 = (cnt==5'd4);
always @(posedge reset or posedge clk)
  if (reset) cnt <= 0;
   else if (enable) 
          if (clkdiv25) cnt <= 0;
            else cnt <= cnt + 1;
endmodule

module cnt9b (reset, clk, enable, clkdiv512);
input reset, clk, enable;
output clkdiv512;
reg [9:0] cnt;
assign clkdiv512 = cnt[9];
always@(posedge clk)
  if (reset) cnt <= 0;
   else if (enable) cnt <= cnt + 1;
endmodule


module half_hertz(reset, clk, clk05H);
input clk, reset;
output clk05H;
wire clk05H;
wire first, second, third, fourth, fifth, sixth, seventh;

cnt25 i0 (reset, clk, 1'b1, first);
cnt25 i1 (reset, clk, first, second);
cnt25 i2 (reset, clk, first & second, third);
cnt25 i3 (reset, clk, first & second & third, fourth);
cnt25 i4 (reset, clk, first & second & third & fourth, fifth);
cnt25 i5 (reset, clk, first & second & third & fourth & fifth, sixth );
cnt25 i6 (reset, clk, first & second & third & fourth & fifth & sixth, seventh);
cnt9b i7 (reset, clk, first & second & third & fourth & fifth & sixth & seventh, clk05H);
endmodule

module top(reset, en, clock, ps2clk, ps2data, h_sync, v_sync, r, g, b);
	input reset, en, clock, ps2clk, ps2data;
	output h_sync, v_sync;
	output [2:0]r;
	output [2:0]g;
   output [2:0]b;

	wire f0;
	wire [7:0]scancode;
	wire clk25M;
	wire clk05H;

	divider div(clock, clk25M, reset, en);
	half_hertz hhz(reset, clock, clk05H);
	kbd_protocol keyboard(reset, clk25M, ps2clk, ps2data, scancode, f0);
	VGA vga(clk25M, clk05H, en, reset, h_sync, v_sync, r, g, b, scancode, f0);
endmodule
