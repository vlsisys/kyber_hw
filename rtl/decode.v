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
// --------------------------------------------------
//	Flow Control
// --------------------------------------------------
	reg			[5:0]		cnt_ibytes;
	reg			[6:0]		offset_base;
	reg			[6:0]		offset;

	always @(*) begin
		case (i_l)
			4'd1	,
			4'd4	:	offset_base	= 0;
			4'd11	:	offset_base	= 9;
			default	:	offset_base	= 4;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			offset	<= 0;
		end else begin
			case (c_state)
				S_IDLE		: offset	<= 0;
				S_COMP_0	,
				S_COMP_1	: offset	<= offset > 63 ? offset - (64 - offset_base) : offset + offset_base;
				default		: offset	<= offset;
			endcase
		end
	end
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
			S_IDLE		: n_state = (i_ibytes_valid)			? S_COMP_1	: S_IDLE;
			S_COMP_0	,
			S_COMP_1	: n_state = cnt_ibytes == (i_l << 5)-1	? S_DONE	: 
									offset >= 64				? S_COMP_0	: S_COMP_1;
			S_DONE		: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE		: o_done			= 1;
			default		: o_done			= 0;
		endcase
	end

	always @(*) begin
		case(c_state)
			S_IDLE		,
			S_COMP_1	: o_ibytes_ready	= 1;
			default		: o_ibytes_ready	= 0;
		endcase
	end

	always @(*) begin
		case(c_state)
			S_COMP_0	, 
			S_COMP_1	: o_coeffs_valid	= 1;
			default		: o_coeffs_valid	= 0;
		endcase
	end
	
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_ibytes	<= 0;
		end else begin
			case (c_state)
				S_IDLE		, 
				S_DONE		: cnt_ibytes	<= 0;
				S_COMP_1	: cnt_ibytes	<= cnt_ibytes + 1;
				default		: cnt_ibytes	<= cnt_ibytes;
			endcase
		end
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

	reg			[63:0]		ibytes_bwr_reg;	
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibytes_bwr_reg <= 0;	
		end else begin
			ibytes_bwr_reg <= ibytes_bwr;	
		end
	end

// --------------------------------------------------
//	Output Coeff
// --------------------------------------------------
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs	<= 0;
		end else begin
			case (c_state)
				S_COMP_0	,
				S_COMP_1	: begin
					o_coeffs	<= ibytes_bwr;
				end
				default		: o_coeffs	<= o_coeffs;
			endcase
		end
	end

endmodule
