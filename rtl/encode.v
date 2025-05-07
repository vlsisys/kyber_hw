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
	input		[63:0]		i_coeffs,
	input					i_coeffs_valid,
	input		[3:0]		i_l,
	input					i_clk,
	input					i_rstn
);


endmodule
