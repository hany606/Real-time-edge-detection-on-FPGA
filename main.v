module Edge_detection_project(
	//General
	input button,									//Button input to select showing the static image or the real-time video
	//VGA I/O
	output VGA_red, VGA_green, VGA_blue,	//VGA colors' channel		
	output VGA_hsync, VGA_vsync,				//VGA vertical and horziontal synchronization signals
	//Camera I/O
	input cam_clock,								//(pixel clk pin) Camera's clock that generated from the camera to indicate that pixel is ready to be sent
	input cam_vsync, cam_href,					//Cameera vertical and horizontal synchronization signals
	input [7:0] cam_data_wires,				//Camera data wires (d0-d7)
	//Clocks
	input clk_50,									//Clock 50 MHz input from the board itself
	output clk_25									//Clock 25 MHz generated from PLL to be connected to Camera system clock pin
	);

	//-------------------------CAMERA--------------------------------
	//Interface for Camera module
	wire cam_pixel_valid;						//Pixel valid flag to indicate that the camra sent a pixel
	wire [15:0] cam_pixel_data;				//Pixel data lines' values
	wire cam_frame_done;						//frame done flage to indicate that the whole frame has finished
	//--------------------------
	reg[8:0] pixel_cam_counterv;		//y-position of the recieved pixel  
	reg[9:0] pixel_cam_counterh;		//x-position of the recieved pixel
	//-----------------------------------------------------------------------------------------------------

	//-------------------------Grayscale converter-----------------------------------
	reg[7:0] gray_value;					//Register 8-bits to store the grayscale value
	reg[4:0] red_channel_gray; 		//Temporary register to store red bits of the camera to be used in the grayscale converter
	reg[5:0] green_channel_gray; 		//Temporary register to store green bits of the camera to be used in the grayscale converter
	reg[4:0] blue_channel_gray;		//Temporary register to store blue bits of the camera to be used in the grayscale converter
	//-----------------------------------------------------------------------------------------------------
	
	//---------------------------Buffer---------------------------
	// The interface for Buffer module
	// Buffer port A 150x150x8: Used to store the grayscale frames
	reg [7:0]data_buffer_in_a = 0;		//Input data for the port A
	reg [14:0] read_addr_a = 0;			// Address of port A for reading
	reg [14:0] write_addr_a = 0;			// Address of port A for writing
	reg write_en_a = 0;						// Writing enable flag for port A
	wire [7:0]outp_a;							// Output data from the port A (8-bits)
	wire error_write_a;						// Writing error flag for port A
	
	// Buffer port B 150x150x1: Used to store the values results from Sobel operator and threshold
	// The data in port B is the final data to be displayed on the monitor
	reg data_buffer_in_b = 0;				// Input data for the port B
	reg [14:0] read_addr_b = 0;			// Address of port B for reading
	reg [14:0] write_addr_b =0 ;			// Address of port B for writing
	reg write_en_b = 0;						// Writing enable flag for port B
	wire outp_b;								// Output data from the port B (1-bit)
	wire error_write_b;						// Writing error flag for port B
	//-----------------------------------------------------------------------------------------------------
	
	
	//------------------------Sobel------------------------------------
	//Interface for core_sobel module
	reg[7:0] p_sobel [8:0];					//Pixels' values to be used in core_sobel module
	wire[7:0] out_sobel;						//Output result pixel's value
	//--------------------------
	reg[7:0] i_sobel = 0;					//Rows counter to iterate over the frame
	reg[7:0] j_sobel = 0;					//Columns counter to iterate over the frame
	reg[3:0] counter_sobel = 0;			//Counter for pixels to take 3x3 pixels kernel
	reg[14:0] target_sobel_addr = 0;		//target pixel address to store in it the sobel result which will be always in the middle
	//-----------------------------------------------------------------------------------------------------
	
	//---------------------------VGA---------------------------
	// Interface for VGA module
	wire	[9:0]	VGA_hpos, VGA_vpos;				// Current pixel position
	wire 			VGA_active;					// Active flag to indicate when the screen area is active
	wire			VGA_pixel_tick;				// Signal coming from the VGA generator when the pixel position is ready to be displayed
	reg	[3:0]	pixel_VGA_RGB;			// Current pixel's RGB value
	//-----------------------------------------------------------------------------------------------------
	
	pll(clk_50, clk_25);		// Instance of pll module
	
		
	Camera(						// Instance of Camera module
	.clock(cam_clock),
	.vsync(cam_vsync),
	.href(cam_href),
	.data_wires(cam_data_wires),
	.p_valid(cam_pixel_valid),
	.p_data(cam_pixel_data),
	.f_done(cam_frame_done)
   );
	
	Buffer(						// Instance of Buffer module
	.d_in_a(data_buffer_in_a),
	.r_addr_a(read_addr_a),
	.w_addr_a(write_addr_a),
	.d_in_b(data_buffer_in_b),
	.r_addr_b(read_addr_b),
	.w_addr_b(write_addr_b),
	.w_clk(clk_25),
	.r_clk(clk_50),
	.w_en_a(write_en_a),
	.d_out_a(outp_a),
	.err_w_a(error_write_a),
	.w_en_b(write_en_b),
	.d_out_b(outp_b),
	.err_w_b(error_write_b)
	);
	
	core_sobel(					// Instance of core_sobel module
	.p0(p_sobel[0]),
	.p1(p_sobel[3]),
	.p2(p_sobel[6]),
	.p3(p_sobel[1]),
	.p5(p_sobel[7]),
	.p6(p_sobel[2]),
	.p7(p_sobel[5]),
	.p8(p_sobel[8]),
	.out(out_sobel)
	);
	
	VGA(							// Instance of VGA module
		.clk(clk_50),
		.pixel_rgb(pixel_VGA_RGB),
		.hsync(VGA_hsync),
		.vsync(VGA_vsync),
		.red(VGA_red),
		.green(VGA_green),
		.blue(VGA_blue),
		.active(VGA_active),
		.ptick(VGA_pixel_tick),
		.xpos(VGA_hpos),
		.ypos(VGA_vpos),
	);
	
	
	// This block is activated at the positive edge of pixel_valid signal which means that pixel from the camera is ready
	// This block recieve the pixel's color values in RGB565 format and convert it to grayscale then store it in Buffer port A
	always @(posedge cam_pixel_valid) 
	begin
		// This is to check the button to stop the real-time at specific frame or to display the static image in the begining
		if(button == 1)
		begin
			red_channel_gray 	=	cam_pixel_data[4:0];			// Store the red bits (first 5-bits) in temp register
			green_channel_gray= cam_pixel_data[10:5];			// Store the green bits (second 6-bits) in temp register
			blue_channel_gray = cam_pixel_data[15:11];			// Store the blue bits (third 5-bits) in temp register
			// 8-bits gray scale converter from RGB5565 format
			gray_value = (red_channel_gray >> 2) + (red_channel_gray >> 5)+ (green_channel_gray >> 4) + (green_channel_gray >> 1) + (blue_channel_gray >> 4) + (blue_channel_gray >> 5);
			
			data_buffer_in_a = gray_value;					//Set the value of grayscale in the register of input data for buffer port A

			// Check if the current pixel in the needed portion of the image or not (150x150)
			if(pixel_cam_counterv < 'd150 && pixel_cam_counterh < 'd150 )
			begin
				// Start writing to the buffer port A
				write_en_a = 1;									// Set the Enable to write on the buffer
				write_addr_a = pixel_cam_counterv* 'd150 +pixel_cam_counterh;	// Set the address of the pixel in the buffer
			end
			// Increase the Vertical and Horizontal counter by one and check their limits
			pixel_cam_counterv= ((pixel_cam_counterh == 'd639)?((pixel_cam_counterv+'d1)%'d480):pixel_cam_counterv);		
			pixel_cam_counterh= (pixel_cam_counterh+'d1)%'d640;
		end
	end
	
	// This block is activated at the negative edge of clock of the system(50 MHz)
	// This block iterate over the frame by 3x3 square to apply the kernel of soble operator
	always @(negedge clk_50) begin
		// Check if we took 9 pixels or not yet
		if (counter_sobel <= 'd8) begin
			// Setting the address of needed pixel depending on its position in the kernel
			case (counter_sobel%'d3)
				0: read_addr_a = i_sobel + j_sobel*'d150;
				1: read_addr_a = i_sobel + j_sobel*'d150 +'d150;
				2: 
				begin
					read_addr_a = i_sobel + j_sobel*'d150 + 'd300;
					j_sobel = (i_sobel == 'd149 ? (j_sobel + 'd1) : j_sobel);	// Increase the Vertical counter by one when horizontal counter reached the maximum 149
					i_sobel = (i_sobel+'d1)%'d150;	// Increase the horizontal counter by one and restarting it again every 150
				end
			endcase
			// Check if it is the middle pixel or not
			if(counter_sobel == 'd4)
				target_sobel_addr = read_addr_a;			// Store the middle pixel address to store the output of sobel in it
			p_sobel[counter_sobel] = outp_a;				// Store the pixel that we recieved to process sobel on it
			counter_sobel = counter_sobel + 'd1;		// Increase the counter for pixels that we recieved by one
		end
		else begin
			counter_sobel = 0; // Reset the counter pixel's sobel 
			i_sobel = (i_sobel >= 'd2 ? (i_sobel - 'd2): i_sobel);	// Determine the horizontal position of the next square of the kernel
			
			data_buffer_in_b = (out_sobel < 'd70 ? 1'b1:1'b0);		//Applying the threshold value to determine if it less than 70 to store it as 1
			// Start writing to the buffer port B
			write_en_b = 1;									// Set the Enable to write on the buffer					
			write_addr_b= target_sobel_addr;			 	// Set the address of the pixel in the buffer	
			
			// Check if we reached the end of applying the soble on the image or not
			// 	as sobel take 3 lines and 3 columns
			if(j_sobel == 'd147) 
			begin
				i_sobel = 0;
				j_sobel = 0;
			end
		end
	end
	
	// This block is activated at the positive edge of pixel_tick signal from VGA module which means that a pixel is ready to be displayed
	// This block is responsible to output the pixel on the monitor
	always @(posedge VGA_pixel_tick) begin
		// Check if the monitor is active and ready to display the pixel or not
		if (! VGA_active)
			pixel_VGA_RGB <= 3'b0;
		else begin
			// Check if the pixel that is displayed in the available portion of the storage or not
			if(VGA_vpos < 'd150 && VGA_hpos < 'd150)
			begin	
				read_addr_b = (VGA_vpos[7:0])* 'd150 +(VGA_hpos[7:0]);	// Set the reading address from Buffer port B
				pixel_VGA_RGB <= (outp_b==1?3'b111:3'b000);					// Set the value of displayed pixe; if the value is one it will display white
			end
			else
				pixel_VGA_RGB <= 3'b000;				//if it is not in our portion of memory it will be black
		end
	end
	
endmodule
