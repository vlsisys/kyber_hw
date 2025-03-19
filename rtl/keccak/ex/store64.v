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

	//genvar		i;
	//generate
	//	for (i=0; i<8; i=i+1) begin
	//		assign	o_data[63-i*8-:8] = (i_data >> 8*i) % 256;
	//	end
	//endgenerate	

	assign	o_data	= {	i_data[63-7*8-:8],
						i_data[63-6*8-:8],
						i_data[63-5*8-:8],
						i_data[63-4*8-:8],
						i_data[63-3*8-:8],
						i_data[63-2*8-:8],
						i_data[63-1*8-:8],
						i_data[63-0*8-:8]};

endmodule
