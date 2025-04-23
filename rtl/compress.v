// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: compress.v
//	* Description	: 
// ==================================================

module compress
(	
	output 		[11:0]		o_coeff,
	input		[11:0]		i_coeff,
	input		[ 3:0]		i_d
);

	reg			[23:0]		float;
	always @(*) begin
		case (i_d)
			4'd 1	: float	= 24'h00275f;
			4'd 4	: float	= 24'h013afb;
			4'd 5	: float	= 24'h0275f7;
			4'd10	: float	= 24'h4ebede;
			4'd11	: float	= 24'h9d7dbb;
			default	: float	= 24'h000000;
		endcase
	end

	wire		[35:0]		mult;
	assign		mult	= float * i_coeff;


endmodule
