// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: decode.v
//	* Description	: 
// ==================================================

module decode
(	
	output reg	[47:0]		o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_ibytes_ready,
	output reg				o_done,
	input		[63:0]		i_ibytes,
	input					i_ibytes_valid,
	input		[1:0]		i_l,
	input					i_clk,
	input					i_rstn
);



endmodule
