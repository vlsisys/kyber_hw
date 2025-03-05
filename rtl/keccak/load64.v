// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: load64.v
//	* Description	: 
// ==================================================

module load64
#(	
	parameter	BW_DATA			= 64
)
(	
	output 		[BW_DATA-1:0]	o_data,
	input		[BW_DATA-1:0]	i_data
);

	assign	o_data	=	({56'd0, i_data[63-0*8-:8]} << 8*0) +
						({56'd0, i_data[63-1*8-:8]} << 8*1) +
						({56'd0, i_data[63-2*8-:8]} << 8*2) +
						({56'd0, i_data[63-3*8-:8]} << 8*3) +
						({56'd0, i_data[63-4*8-:8]} << 8*4) +
						({56'd0, i_data[63-5*8-:8]} << 8*5) +
						({56'd0, i_data[63-6*8-:8]} << 8*6) +
						({56'd0, i_data[63-7*8-:8]} << 8*7);

endmodule
