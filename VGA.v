//This module is the implementation of the built-in VGA interface on the board
module VGA(
	input	clk,				// Clock of VGA 50 MHz
	input[2:0] pixel_rgb,		// Pixel RGB value

	output hsync, vsync,		// Vertical and Horizontal synchronization signals
	output red, green, blue,	// RGB VGA pins
	output active,				// Active when pixel inside the 640 x 480 area
	output ptick,				// Pixel clock 
	output[9:0] xpos, ypos		// Current pixel position
);

	//Local parameters to set the VGA standard parameters
	localparam
	hnum_pixels = 640,
	h_active = hnum_pixels - 1,			// Horizontal active area (0 to 639 = 640 pixels)
	h_front_porch = h_active + 16,		// Horizontal front porch end position
	h_sync_signal = h_front_porch + 96,	// Horizontal sync end position
	h_back_porch = h_sync_signal + 48,	// Horizontal back porch end position
	
	vnum_pixels = 480,
	v_active = vnum_pixels - 1,			// Vertical active area (0 to 479 = 480 pixels)
	v_front_porch = v_active + 11,		// Vertical front porch end position
	v_sync_signal = v_front_porch + 2,	// Vertical sync end position
	v_back_porch = v_sync_signal + 31;	// Vertical back porch end position
	
	
	// Mod-2 counter
	reg		mod2_r;
	wire		mod2_next;
	wire		ptick_w;
	
	// Sync counters
	reg  [9:0]	hcount, hcount_next;
	reg  [9:0]	vcount, vcount_next;
	
	// Sync output buffers
	reg			vsync_r, hsync_r;
	wire			vsync_next, hsync_next;
	
	// RGB signal buffer
	reg			red_r, green_r, blue_r;
	
	// Status signals
	wire			h_end, v_end;

	// Registers for restart signal
	reg counter_reset = 1'b0;
	reg reset = 1'b0;
	
	// Generate a reset pulse
	always @(posedge clk) begin
		if (~counter_reset) begin
			counter_reset <= 1'b1;
			reset <= 1'b1;
		end
		else
			reset <= 0;
	end
	
	always @ (posedge clk or posedge reset) begin
		if  (reset) begin
			mod2_r <= 1'b0;
			
			vcount <= 0;
			hcount <= 0;
			
			vsync_r <= 1'b0;
			hsync_r <= 1'b0;
			
			red_r <= 1'b0;
			green_r <= 1'b0;
			blue_r <= 1'b0;
			
		end
		else begin
			mod2_r <= mod2_next;
			
			vcount <= vcount_next;
			hcount <= hcount_next;
			
			vsync_r <= vsync_next;
			hsync_r <= hsync_next;
			
			red_r <= pixel_rgb[0];
			green_r <= pixel_rgb[1];
			blue_r <= pixel_rgb[2];
			
		end
	end

	// Mod-2 circuit to generate the 25 MHz tick
	assign mod2_next = ~mod2_r;
	assign ptick_w = mod2_r;

	
	// End of horizontal line counter (799)
	assign h_end = (hcount == h_back_porch);

	// End of vertical (524)
	assign v_end = (vcount == v_back_porch);

	// Next-state logic of mod-800 horizontal sync counter
	always @(*) begin
		if  (ptick_w)  // 25 MHz pixel tick
			if (h_end)	// End of line ?
				hcount_next = 0;
			else
				hcount_next = hcount + 10'd1;
		else
			hcount_next = hcount;
	end

	// Next-state logic of mod-525 vertical sync counter
	always @(*) begin
		if (ptick_w & h_end)	// 25 MHz pixel tick and end of line
			if (v_end)	// Check if it is end of the monitor
				vcount_next = 0;
			else
				vcount_next = vcount + 10'd1;
		else
			vcount_next = vcount;
	end
	
	// hsync_next reset between 656 and 752
	assign	hsync_next = ~((hcount > h_front_porch) && (hcount <= h_sync_signal));

	// vsync_next reset between 491 and 493
	assign	vsync_next = ~((vcount > v_front_porch) && (vcount <= v_sync_signal));
	
	// active when the current position is inside the visible area
	assign	active = (hcount <= h_active) && (vcount <= v_active);

	// Outputs
	assign	hsync = hsync_r;
	assign	vsync = vsync_r;
	assign	xpos = hcount;
	assign	ypos = vcount;
	assign	ptick = ptick_w;

	assign	red = active ? red_r : 1'b0;
	assign	green = active ? green_r : 1'b0;
	assign	blue = active ? blue_r : 1'b0;
	
endmodule
