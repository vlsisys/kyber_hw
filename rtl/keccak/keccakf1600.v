// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccakf1600.v
//	* Description	: 
// ==================================================

`include	"keccakf1600lanes.v"

module keccakf1600
#(	
	parameter	BW_DATA			= 64*5*5		//1600
)
(	
	output 		[BW_DATA-1:0]	o_state,
	output 						o_valid,
	input		[BW_DATA-1:0]	i_state,
	input						i_valid,
	input						i_clk,
	input						i_rstn
);

// --------------------------------------------------
//	Wiring for Lane
// --------------------------------------------------
	wire		[BW_DATA-1:0]	lanes_i;
	wire		[BW_DATA-1:0]	lanes_o;
	wire		[63:0]			state_pre [0:4][0:4];
	wire		[63:0]			state_post[0:4][0:4];

	genvar						x, y;
	generate
		for (x=0; x<5; x=x+1) begin
			for (y=0; y<5; y=y+1) begin
				assign	state_pre[x][y]						= i_state[BW_DATA-1-((x+5*y)*64)-:64]; 
				assign	lanes_i[BW_DATA-1-((5*x+y)*64)-:64]	= {	state_pre[x][y][63-7*8-:8],
																state_pre[x][y][63-6*8-:8],
																state_pre[x][y][63-5*8-:8],
																state_pre[x][y][63-4*8-:8],
																state_pre[x][y][63-3*8-:8],
																state_pre[x][y][63-2*8-:8],
																state_pre[x][y][63-1*8-:8],
																state_pre[x][y][63-0*8-:8]};
			end
		end
	endgenerate

	keccakf1600lanes
	#(
		.BW_DATA			(BW_DATA			)
	)
	u_keccakf1600lanes(
		.o_lanes			(lanes_o			),
		.o_valid			(o_valid			),
		.i_lanes			(lanes_i			),
		.i_valid			(i_valid			),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);


	generate
		for (x=0; x<5; x=x+1) begin
			for (y=0; y<5; y=y+1) begin
				assign	state_post[x][y]					= lanes_o[BW_DATA-1-((5*x+y)*64)-:64]; 
				assign	o_state[BW_DATA-1-((x+5*y)*64)-:64]	= o_valid ?	
															{	state_post[x][y][63-7*8-:8],
																state_post[x][y][63-6*8-:8],
																state_post[x][y][63-5*8-:8],
																state_post[x][y][63-4*8-:8],
																state_post[x][y][63-3*8-:8],
																state_post[x][y][63-2*8-:8],
																state_post[x][y][63-1*8-:8],
																state_post[x][y][63-0*8-:8]} : 0;
			end
		end
	endgenerate

endmodule
