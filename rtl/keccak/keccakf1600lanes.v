// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccakf1600lanes.v
//	* Description	: 
// ==================================================
module keccakf1600lanes
#(	
	parameter	BW_DATA			= 64*5*5		//1600
)
(	
	output reg	[BW_DATA-1:0]	o_lane,
	output reg					o_valid,
	input		[BW_DATA-1:0]	i_lane,
	input						i_clk,
	input						i_rstn
);

	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			
		end else begin
			
		end
	end


endmodule
