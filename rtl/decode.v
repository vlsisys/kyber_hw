// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: decode.v
//	* Description	: 
// ==================================================

module decode
(	
	output reg	[63:0]		o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_ibytes_ready,
	output reg				o_done,
	input		[63:0]		i_ibytes,
	input					i_ibytes_valid,
	input		[3:0]		i_l,
	input					i_clk,
	input					i_rstn
);

//	       i_l = 1, 4, 5, 10, 11, 12
//	64 mod i_l = 0, 0, 4, 4, 9, 4

//	always @(*) begin
//		case (i_l)
//
//		endcase
//	end

// --------------------------------------------------
//	FSM (Control)
// --------------------------------------------------
	localparam	S_IDLE		= 2'd0  ;
	localparam	S_COMP_0	= 2'd1  ;
	localparam	S_COMP_1	= 2'd2  ;
	localparam	S_DONE		= 2'd3  ;

	reg			[1:0]		c_state;
	reg			[1:0]		n_state;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			c_state	<= S_IDLE;
		end else begin
			c_state	<= n_state;
		end
	end

	// Next State Logic
	always @(*) begin
		case(c_state)
			S_IDLE	: n_state = (i_ibytes_valid  ) ? S_COMP_1 : S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE	: o_done			= 1;
			default	: o_done			= 0;
		endcase
	end

	always @(*) begin
		case(n_state)
			default	: o_ibytes_ready	= 0;
		endcase
	end
	
// --------------------------------------------------
//	Input Byte With Byte-Wise Reversed Order
// --------------------------------------------------
	wire		[63:0]		ibytes_bwr;	
	genvar					i;
	generate
		for (i=0; i<8; i=i+1) begin
			assign	ibytes_bwr[64-1-8*i-:8] = {
						i_ibytes[64-1-8*i-7],
						i_ibytes[64-1-8*i-6],
						i_ibytes[64-1-8*i-5],
						i_ibytes[64-1-8*i-4],
						i_ibytes[64-1-8*i-3],
						i_ibytes[64-1-8*i-2],
						i_ibytes[64-1-8*i-1],
						i_ibytes[64-1-8*i-0]
			};
		end
	endgenerate

// --------------------------------------------------
//	Output Coeff
// --------------------------------------------------
	reg		[6:0]			cnt_coeffs;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_coeffs	<= 0;
		end else begin
			case (c_state)
				S_DONE	: cnt_coeffs <= 0;
				default	: cnt_coeffs <= o_coeffs_valid ? cnt_coeffs + 1 : cnt_coeffs;
			endcase
		end
	end

endmodule
