// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: rol64.v
//	* Description	: 
// ==================================================

module rol64
#(	
	parameter	BW_A			= 64,
	parameter	BW_N			= 9 
)
(	
	output		[BW_A-1:0]		o_rol64,
	input		[BW_A-1:0]		i_a,
	input		[BW_N-1:0]		i_n
);

	//assign	o_rol64	=  ((i_a >> (64-(i_n%64))) + (i_a << (i_n%64))) % (1 << 64);

	wire	[64:0]	mod;
	assign	mod	= 1 << 64;
	assign	o_rol64	=  ((i_a >> (64-(i_n%64))) + (i_a << (i_n%64))) % mod;

endmodule
