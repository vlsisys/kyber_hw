// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: encode.v
//	* Date			: 2025-05-08 00:35:45
//	* Description	: 
// ==================================================

module encode
(	
	output reg	[63:0]		o_obytes,
	output reg				o_obytes_valid,
	output reg				o_coeffs_ready,
	output reg				o_done,
	input		[23:0]		i_coeffs,
	input					i_coeffs_valid,
	input		[3:0]		i_l,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM (Control)
// --------------------------------------------------
	localparam	S_IDLE		= 2'd0  ;
	localparam	S_COMP		= 2'd1  ;
	localparam	S_DONE		= 2'd2  ;

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
			S_IDLE	: n_state = (i_ibytes_valid)				? S_COMP : S_IDLE;
			S_COMP	: n_state = cnt_obytes == cnt_obytes_max	? S_DONE : S_COMP;
			S_DONE	: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE		: o_done			= 1;
			default		: o_done			= 0;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_obytes_valid	<= 0;
		end else begin
			case(c_state)
				S_COMP	: o_obytes_valid	<= 1;
				default	: o_obytes_valid	<= 0;
			endcase
		end
	end

// --------------------------------------------------
//	Flow Control
// --------------------------------------------------
//	coeff			rem
//	 1	-->  2		: 0 byte & 2-bit
//	 4	-->  8		: 1 byte & 0-bit
//	 5	--> 10		: 1 byte & 2-bit
//	10	--> 20		: 2 byte & 4-bit
//	11	--> 22		: 2 byte & 6-bit
//	12	--> 24		: 3 byte & 0-bit

	reg			[5:0]		cnt_obytes;
	reg			[5:0]		cnt_coeffs;
	reg			[5:0]		cnt_coeffs_max;
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

	always @(*) begin
		case (i_l)
			4'd1	:	cnt_obytes_max	= 256* 1/64;
			4'd4	:	cnt_obytes_max	= 256* 4/64;
			4'd5	:	cnt_obytes_max	= 256* 5/64;
			4'd10	:	cnt_obytes_max	= 256*10/64;
			4'd11	:	cnt_obytes_max	= 256*11/64;
			4'd12	:	cnt_obytes_max	= 256*12/64;
			default	:	cnt_obytes_max	= 256*12/64;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			offset	<= 0;
		end else begin
			case (c_state)
				S_IDLE		: offset	<= 0;
				S_COMP_0	,
				S_COMP_1	: offset	<= offset + offset_base > 64 ? offset - (64 - offset_base) : offset + offset_base;
				default		: offset	<= offset;
			endcase
		end
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

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_coeffs	<= 0;
		end else begin
			case (c_state)
				S_COMP_0	, 
				S_COMP_1	: cnt_coeffs	<= cnt_coeffs < cnt_coeffs_max ? cnt_coeffs + 1 : cnt_coeffs;
				default		: cnt_coeffs	<= 0;
			endcase
		end
	end

	wire	[11:0]		coeff_rev[0:1];

	assign	coeff_rev[0] = {i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15],
							i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19],
							i_coeffs[20], i_coeffs[21], i_coeffs[22], i_coeffs[23]};

	assign	coeff_rev[1] = {i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3],
							i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7],
							i_coeffs[ 8], i_coeffs[ 9], i_coeffs[10], i_coeffs[11]};

	always @(*) begin
		case (i_l)
			4'd1	:  = ;
			4'd4	:  = ;
			4'd10	:  = ;
			4'd11	:  = ;
			4'd12	:  = ;
			default	:  = ;
		endcase
	end


endmodule
