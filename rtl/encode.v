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
			S_IDLE	: n_state = (i_coeffs_valid)				? S_COMP : S_IDLE;
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

// --------------------------------------------------
//	Flow Control
// --------------------------------------------------
	reg			[6:0]		cnt_coeffs;
	reg			[5:0]		cnt_obytes;
	reg			[5:0]		cnt_obytes_max;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_coeffs <= 0;
		end else begin
			case (c_state)
				S_COMP		: begin
					case (i_l)
						4'd1	:	cnt_coeffs <= cnt_coeffs +  2 >= 64 ? cnt_coeffs +  2 - 64 : cnt_coeffs +  2;
						4'd4	:	cnt_coeffs <= cnt_coeffs +  8 >= 64 ? cnt_coeffs +  8 - 64 : cnt_coeffs +  8;
						4'd5	:	cnt_coeffs <= cnt_coeffs + 10 >= 64 ? cnt_coeffs + 10 - 64 : cnt_coeffs + 10;
						4'd10	:	cnt_coeffs <= cnt_coeffs + 20 >= 64 ? cnt_coeffs + 20 - 64 : cnt_coeffs + 20;
						4'd11	:	cnt_coeffs <= cnt_coeffs + 22 >= 64 ? cnt_coeffs + 22 - 64 : cnt_coeffs + 22;
						4'd12	:	cnt_coeffs <= cnt_coeffs + 24 >= 64 ? cnt_coeffs + 24 - 64 : cnt_coeffs + 24;
						default	:	cnt_coeffs <= 0;
					endcase
				end
				default		: cnt_coeffs	<= 0;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_obytes_valid <= 0;
		end else begin
			case (c_state)
				S_COMP		: begin
					case (i_l)
						4'd1	:	o_obytes_valid <= cnt_coeffs +  2 >= 64 ? 1 : 0;
						4'd4	:	o_obytes_valid <= cnt_coeffs +  8 >= 64 ? 1 : 0;
						4'd5	:	o_obytes_valid <= cnt_coeffs + 10 >= 64 ? 1 : 0;
						4'd10	:	o_obytes_valid <= cnt_coeffs + 20 >= 64 ? 1 : 0;
						4'd11	:	o_obytes_valid <= cnt_coeffs + 22 >= 64 ? 1 : 0;
						4'd12	:	o_obytes_valid <= cnt_coeffs + 24 >= 64 ? 1 : 0;
						default	:	o_obytes_valid <= 0;
					endcase
				end
				default		: o_obytes_valid <= 0;
			endcase
		end
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
			cnt_obytes	<= 0;
		end else begin
			case (c_state)
				S_IDLE	: cnt_obytes <= 0;
				S_COMP	: cnt_obytes <= o_obytes_valid ? cnt_obytes + 1 : cnt_obytes;
				default	: cnt_coeffs <= cnt_obytes;
			endcase
		end
	end

	reg		[23:0]		coeff_rev;
	reg		[23:0]		coeff_concat;

	always @(*) begin
		case (i_l)
			4'd1	:  coeff_rev = {22'd0,	i_coeffs[12], i_coeffs[ 0]};
			4'd4	:  coeff_rev = {16'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3]};
			4'd5	:  coeff_rev = {14'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4]};
			4'd10	:  coeff_rev = {4'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19], i_coeffs[20], i_coeffs[21], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7], i_coeffs[ 8], i_coeffs[ 9]};
			4'd11	:  coeff_rev = {2'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19], i_coeffs[20], i_coeffs[21], i_coeffs[22], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7], i_coeffs[ 8], i_coeffs[ 9], i_coeffs[10]};
			4'd12	:  coeff_rev = {		i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19], i_coeffs[20], i_coeffs[21], i_coeffs[22], i_coeffs[23], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7], i_coeffs[ 8], i_coeffs[ 9], i_coeffs[10], i_coeffs[11]};
			default	:  coeff_rev = 24'd0;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			coeff_concat	<= 0;
		end else begin
			case(cnt_coeffs)
				7'd 0 : coeff_concat	<= coeff_concat;
			endcase
		end
	end

				

	reg		[63:0]	obytes;
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			obytes	<= 0;
		end else begin
			case (i_l)
				4'd1	: obytes <= {obytes[63-2:0], coeff_rev[1:0]};
				4'd4	: obytes <= {obytes[63-8:0], coeff_rev[7:0]};
				4'd5	: obytes <= o_obytes_valid ? {obytes[63-10:0], coeff_rev[ 9:0]} : {obytes[63-10:0], coeff_rev[ 9:0]};
				4'd10	: obytes <= o_obytes_valid ? {obytes[63-20:0], coeff_rev[19:0]} : {obytes[63-20:0], coeff_rev[19:0]};
				4'd11	: obytes <= o_obytes_valid ? {obytes[63-22:0], coeff_rev[21:0]} : {obytes[63-22:0], coeff_rev[21:0]};
				4'd12	: obytes <= o_obytes_valid ? {obytes[63-24:0], coeff_rev[23:0]} : {obytes[63-24:0], coeff_rev[23:0]};
				default	: obytes <= 0;
			endcase
		end
	end

endmodule
