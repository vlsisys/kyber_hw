// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccakf1600.v
//	* Description	: 
// ==================================================

module keccakf1600
#(	
	parameter	BW_DATA			= 64*5*5		//1600
)
(	
	output 		[BW_DATA-1:0]	o_state,
	output reg					o_valid,
	input		[BW_DATA-1:0]	i_state,
	input						i_valid,
	input						i_clk,
	input						i_rstn
);

// --------------------------------------------------
//	Wiring for Lane
// --------------------------------------------------
	wire		[63:0]			lanes[0:4][0:4];
	genvar						x, y;
	generate
		for (x=0; x<5; x=x+1) begin
			for (y=0; y<5; y=y+1) begin
				assign	lanes[x][y]	=	i_state[BW_DATA-1-((x+5*y)*64)-:64];
			end
		end
	endgenerate


endmodule
