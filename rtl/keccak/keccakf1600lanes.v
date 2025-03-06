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
	output reg	[BW_DATA-1:0]	o_lanes,
	output reg					o_valid,
	input		[BW_DATA-1:0]	i_lanes,
	input						i_valid,
	input						i_clk,
	input						i_rstn
);
// --------------------------------------------------
//	Initial Variables
// --------------------------------------------------
	wire		[64:0]			mod = 1 << 64;

// --------------------------------------------------
//	Input Rearrange
// --------------------------------------------------
	wire		[63:0]			lanes[0:4][0:4];
	genvar						x, y;

	generate
		for (x=0; x<5; x=x+1) begin
			for (y=0; y<5; y=y+1) begin
				assign	lanes[x][y]	= i_lanes[BW_DATA-1-(5*x+y)*64-:63];
			end
		end
	endgenerate

// --------------------------------------------------
//	Counter for Round (0~23)
// --------------------------------------------------
	reg			[4:0]			round;

	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			round	<= 0;
		end else begin
			if(round < 24) begin
				round	<= round + 1;
			end else begin
				round	<= 0;
			end
		end
	end

// --------------------------------------------------
//	Theta
// --------------------------------------------------
	wire		[63:0]			c[0:4];
	wire		[63:0]			d[0:4];
	wire		[63:0]			lanes_theta[0:4][0:4];

//	assign	o_rol64	=  ((i_a >> (64-(i_n%64))) + (i_a << (i_n%64))) % mod;
	generate
		for (x=0; x<5; x=x+1) begin
			assign	c[x] = lanes[x][0] ^ lanes[x][1] ^ lanes[x][2] ^ lanes[x][3] ^ lanes[x][4];
			assign	d[x] = c[(x+4)%5] ^ (((c[(x+1)%5] >> (64-(1))) + (c[(x+1)%5] << (1))) % mod);
		end
	endgenerate

	generate
		for (x=0; x<5; x=x+1) begin
			for (y=0; y<5; y=y+1) begin
				assign	lanes_theta[x][y]	= lanes[x][y] ^ d[x];
			end
		end
	endgenerate

// --------------------------------------------------
//	Rho & Pi
// --------------------------------------------------
	wire		[63:0]			lanes_pi[0:4][0:4];
	wire		[63:0]			current[0:23];

	assign	current[ 0]	= lanes_theta[1][0];
	assign	current[ 1]	= lanes_theta[0][2];
	assign	current[ 2]	= lanes_theta[2][1];
	assign	current[ 3]	= lanes_theta[1][2];
	assign	current[ 4]	= lanes_theta[2][3];
	assign	current[ 5]	= lanes_theta[3][3];
	assign	current[ 6]	= lanes_theta[3][0];
	assign	current[ 7]	= lanes_theta[0][1];
	assign	current[ 8]	= lanes_theta[1][3];
	assign	current[ 9]	= lanes_theta[3][1];
	assign	current[10]	= lanes_theta[1][4];
	assign	current[11]	= lanes_theta[4][4];
	assign	current[12]	= lanes_theta[4][0];
	assign	current[13]	= lanes_theta[0][3];
	assign	current[14]	= lanes_theta[3][4];
	assign	current[15]	= lanes_theta[4][3];
	assign	current[16]	= lanes_theta[3][2];
	assign	current[17]	= lanes_theta[2][2];
	assign	current[18]	= lanes_theta[2][0];
	assign	current[19]	= lanes_theta[0][4];
	assign	current[20]	= lanes_theta[4][2];
	assign	current[21]	= lanes_theta[2][4];
	assign	current[22]	= lanes_theta[4][1];
	assign	current[23]	= lanes_theta[1][1];

//	assign	o_rol64	=  ((i_a >> (64-(i_n%64))) + (i_a << (i_n%64))) % mod;
	assign	lanes_pi[0][2]	= ((current[ 0] >> (64-( 1))) + (current[ 0] << ( 1))) % mod;
	assign	lanes_pi[2][1]	= ((current[ 1] >> (64-( 3))) + (current[ 1] << ( 3))) % mod;
	assign	lanes_pi[1][2]	= ((current[ 2] >> (64-( 6))) + (current[ 2] << ( 6))) % mod;
	assign	lanes_pi[2][3]	= ((current[ 3] >> (64-(10))) + (current[ 3] << (10))) % mod;
	assign	lanes_pi[3][3]	= ((current[ 4] >> (64-(15))) + (current[ 4] << (15))) % mod;
	assign	lanes_pi[3][0]	= ((current[ 5] >> (64-(21))) + (current[ 5] << (21))) % mod;
	assign	lanes_pi[0][1]	= ((current[ 6] >> (64-(28))) + (current[ 6] << (28))) % mod;
	assign	lanes_pi[1][3]	= ((current[ 7] >> (64-(36))) + (current[ 7] << (36))) % mod;
	assign	lanes_pi[3][1]	= ((current[ 8] >> (64-(45))) + (current[ 8] << (45))) % mod;
	assign	lanes_pi[1][4]	= ((current[ 9] >> (64-(55))) + (current[ 9] << (55))) % mod;
	assign	lanes_pi[4][4]	= ((current[10] >> (64-( 2))) + (current[10] << ( 2))) % mod;
	assign	lanes_pi[4][0]	= ((current[11] >> (64-(14))) + (current[11] << (14))) % mod;
	assign	lanes_pi[0][3]	= ((current[12] >> (64-(27))) + (current[12] << (27))) % mod;
	assign	lanes_pi[3][4]	= ((current[13] >> (64-(41))) + (current[13] << (41))) % mod;
	assign	lanes_pi[4][3]	= ((current[14] >> (64-(56))) + (current[14] << (56))) % mod;
	assign	lanes_pi[3][2]	= ((current[15] >> (64-( 8))) + (current[15] << ( 8))) % mod;
	assign	lanes_pi[2][2]	= ((current[16] >> (64-(25))) + (current[16] << (25))) % mod;
	assign	lanes_pi[2][0]	= ((current[17] >> (64-(43))) + (current[17] << (43))) % mod;
	assign	lanes_pi[0][4]	= ((current[18] >> (64-(62))) + (current[18] << (62))) % mod;
	assign	lanes_pi[4][2]	= ((current[19] >> (64-(18))) + (current[19] << (18))) % mod;
	assign	lanes_pi[2][4]	= ((current[20] >> (64-(39))) + (current[20] << (39))) % mod;
	assign	lanes_pi[4][1]	= ((current[21] >> (64-(61))) + (current[21] << (61))) % mod;
	assign	lanes_pi[1][1]	= ((current[22] >> (64-(20))) + (current[22] << (20))) % mod;
	assign	lanes_pi[1][0]	= ((current[23] >> (64-(44))) + (current[23] << (44))) % mod;

// --------------------------------------------------
//	Chi
// --------------------------------------------------

// --------------------------------------------------
//	Iota
// --------------------------------------------------

endmodule
