// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: store64.v
//	* Description	: 
// ==================================================

module store64
#(	
	parameter	BW_DATA			= 64
)
(	
	output 		[BW_DATA-1:0]	o_data,
	input		[BW_DATA-1:0]	i_data
);

	genvar		i;
	generate
		for (i=0; i<8; i=i+1) begin
			assign	o_data[63-i*8-:8] = (i_data >> 8*i) % 256;
		end
	endgenerate	

endmodule
