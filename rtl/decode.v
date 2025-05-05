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

	wire		[63:0]		ibytes_concat;	
	assign		ibytes_concat	= {ibytes_bwr_reg[offset-1:0], i_ibytes[63:offset]};	
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
					case (i_l)
						12		: o_coeffs	<= {ibytes_bwr[52], ibytes_bwr[53], ibytes_bwr[54], ibytes_bwr[55], ibytes_bwr[56], ibytes_bwr[57], ibytes_bwr[58], ibytes_bwr[59], ibytes_bwr[60], ibytes_bwr[61], ibytes_bwr[62], ibytes_bwr[63], 
												ibytes_bwr[40], ibytes_bwr[41], ibytes_bwr[42], ibytes_bwr[43], ibytes_bwr[44], ibytes_bwr[45], ibytes_bwr[46], ibytes_bwr[47], ibytes_bwr[48], ibytes_bwr[49], ibytes_bwr[50], ibytes_bwr[51],
												ibytes_bwr[28], ibytes_bwr[29], ibytes_bwr[30], ibytes_bwr[31], ibytes_bwr[32], ibytes_bwr[33], ibytes_bwr[34], ibytes_bwr[35], ibytes_bwr[36], ibytes_bwr[37], ibytes_bwr[38], ibytes_bwr[39],
												ibytes_bwr[16], ibytes_bwr[17], ibytes_bwr[18], ibytes_bwr[19], ibytes_bwr[20], ibytes_bwr[21], ibytes_bwr[22], ibytes_bwr[23], ibytes_bwr[24], ibytes_bwr[25], ibytes_bwr[26], ibytes_bwr[27],
												ibytes_bwr[ 4], ibytes_bwr[ 5], ibytes_bwr[ 6], ibytes_bwr[ 7], ibytes_bwr[ 8], ibytes_bwr[ 9], ibytes_bwr[10], ibytes_bwr[11], ibytes_bwr[12], ibytes_bwr[13], ibytes_bwr[14], ibytes_bwr[15]};
						default	: o_coeffs	<=	ibytes_bwr;
					endcase
				end
				default		: o_coeffs	<= o_coeffs;
			endcase
		end
	end

	`ifdef	DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE	: ASCII_C_STATE = "S_IDLE  ";
			S_COMP_0: ASCII_C_STATE = "S_COMP_0";
			S_COMP_1: ASCII_C_STATE = "S_COMP_1";
			S_DONE	: ASCII_C_STATE = "S_DONE  ";
		endcase
	end
	wire	[11:0]	o_coeffs_debug[0:255];

	`endif

endmodule
