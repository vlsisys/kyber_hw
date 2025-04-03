// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: cbd.v
//	* Description	: 
// ==================================================

`include	"configs.v"

module cbd
(	
	output 		[47:0]		o_coeffs,
	output 					o_coeffs_valid,
	output					o_done,
	input		[63:0]		i_ibytes,
	input					i_ibytes_valid,
	input		[1:0]		i_eta,
	input					i_clk,
	input					i_rstn
);
//	coefficients = [0 for _ in range(self.n)]
//	list_of_bits = bytes_to_bits(input_bytes) # Convert 64 bytes to 512 bits
//	for i in range(self.n):
//		a = sum(list_of_bits[2*i*eta + j]       for j in range(eta))
//		b = sum(list_of_bits[2*i*eta + eta + j] for j in range(eta))
//		coefficients[i] = a-b
// --------------------------------------------------
//		max index: 
//			eta == 2 : 4*i + 3 = 3,  7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 51, 55, 59, 63
//			eta == 3 : 6*i + 5 = 5, 11, 17, 23, 29, 35, 41, 47, 53, 59

	wire		[7:0]		ibytes_len;
	assign					ibytes_len = (i_eta == 2) ? 128 : 192;
// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE		= 2'd0  ;
	localparam	S_COMP		= 2'd1  ;
	localparam	S_DONE		= 2'd2  ;

	reg			[1:0]		p_state;
	reg			[1:0]		c_state;
	reg			[1:0]		n_state;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			p_state	<= S_IDLE;
			c_state	<= S_IDLE;
		end else begin
			p_state	<= c_state;
			c_state	<= n_state;
		end
	end

	// Next State Logic
	always @(*) begin
		case(c_state)
			S_IDLE	: n_state = (i_ibytes_valid)	? S_COMP : S_IDLE;
			S_COMP	: n_state = (cnt_out == 63)		? S_DONE : S_COMP;
			S_DONE	: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE	: o_done	= 1;
			default	: o_done	= 0;
		endcase
	end

// --------------------------------------------------
//	Input Byte With Byte-Wise Reversed Order
// --------------------------------------------------
	wire		[63:0]		ibytes_bytewise_rev;
	for (genvar i=0; i<8; i=i+1) begin
		assign	ibytes_bytewise_rev[64-1-8*i-:8] = {
					i_ibytes[64-1-8*i-7],
					i_ibytes[64-1-8*i-6],
					i_ibytes[64-1-8*i-5],
					i_ibytes[64-1-8*i-4],
					i_ibytes[64-1-8*i-3],
					i_ibytes[64-1-8*i-2],
					i_ibytes[64-1-8*i-1],
					i_ibytes[64-1-8*i-0]
		};
	end


	reg			[192*8-1:0]	ibytes;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibytes	<= 0;
		end else begin
			case (c_state)
				S_IDLE	: ibytes	<= 0;
				S_COMP	: ibytes	<= 0;
			endcase
		end
	end

	reg			[2:0]		coeffs[0:255];
	for (genvar i=0; i<256; i=i+1) begin
		always @(*) begin
			if (i_eta == 2) begin
				coeffs[i]	=	ibytes[128*8-(2*i*i_eta         + 0)-1] +
								ibytes[128*8-(2*i*i_eta         + 1)-1] -
								ibytes[128*8-(2*i*i_eta + i_eta + 0)-1] -
								ibytes[128*8-(2*i*i_eta + i_eta + 1)-1];
			end else begin
				coeffs[i]	=	ibytes[192*8-(2*i*i_eta         + 0)-1] +
								ibytes[192*8-(2*i*i_eta         + 1)-1] +
								ibytes[192*8-(2*i*i_eta         + 2)-1] -
								ibytes[192*8-(2*i*i_eta + i_eta + 0)-1] -
								ibytes[192*8-(2*i*i_eta + i_eta + 1)-1] -
								ibytes[192*8-(2*i*i_eta + i_eta + 2)-1];
			end
		end
	end
	
	assign	o_coeffs =	{	coeffs[  0],
							coeffs[  1],
							coeffs[  2],
							coeffs[  3],
							coeffs[  4],
							coeffs[  5],
							coeffs[  6],
							coeffs[  7],
							coeffs[  8],
							coeffs[  9],
							coeffs[ 10],
							coeffs[ 11],
							coeffs[ 12],
							coeffs[ 13],
							coeffs[ 14],
							coeffs[ 15],
							coeffs[ 16],
							coeffs[ 17],
							coeffs[ 18],
							coeffs[ 19],
							coeffs[ 20],
							coeffs[ 21],
							coeffs[ 22],
							coeffs[ 23],
							coeffs[ 24],
							coeffs[ 25],
							coeffs[ 26],
							coeffs[ 27],
							coeffs[ 28],
							coeffs[ 29],
							coeffs[ 30],
							coeffs[ 31],
							coeffs[ 32],
							coeffs[ 33],
							coeffs[ 34],
							coeffs[ 35],
							coeffs[ 36],
							coeffs[ 37],
							coeffs[ 38],
							coeffs[ 39],
							coeffs[ 40],
							coeffs[ 41],
							coeffs[ 42],
							coeffs[ 43],
							coeffs[ 44],
							coeffs[ 45],
							coeffs[ 46],
							coeffs[ 47],
							coeffs[ 48],
							coeffs[ 49],
							coeffs[ 50],
							coeffs[ 51],
							coeffs[ 52],
							coeffs[ 53],
							coeffs[ 54],
							coeffs[ 55],
							coeffs[ 56],
							coeffs[ 57],
							coeffs[ 58],
							coeffs[ 59],
							coeffs[ 60],
							coeffs[ 61],
							coeffs[ 62],
							coeffs[ 63],
							coeffs[ 64],
							coeffs[ 65],
							coeffs[ 66],
							coeffs[ 67],
							coeffs[ 68],
							coeffs[ 69],
							coeffs[ 70],
							coeffs[ 71],
							coeffs[ 72],
							coeffs[ 73],
							coeffs[ 74],
							coeffs[ 75],
							coeffs[ 76],
							coeffs[ 77],
							coeffs[ 78],
							coeffs[ 79],
							coeffs[ 80],
							coeffs[ 81],
							coeffs[ 82],
							coeffs[ 83],
							coeffs[ 84],
							coeffs[ 85],
							coeffs[ 86],
							coeffs[ 87],
							coeffs[ 88],
							coeffs[ 89],
							coeffs[ 90],
							coeffs[ 91],
							coeffs[ 92],
							coeffs[ 93],
							coeffs[ 94],
							coeffs[ 95],
							coeffs[ 96],
							coeffs[ 97],
							coeffs[ 98],
							coeffs[ 99],
							coeffs[100],
							coeffs[101],
							coeffs[102],
							coeffs[103],
							coeffs[104],
							coeffs[105],
							coeffs[106],
							coeffs[107],
							coeffs[108],
							coeffs[109],
							coeffs[110],
							coeffs[111],
							coeffs[112],
							coeffs[113],
							coeffs[114],
							coeffs[115],
							coeffs[116],
							coeffs[117],
							coeffs[118],
							coeffs[119],
							coeffs[120],
							coeffs[121],
							coeffs[122],
							coeffs[123],
							coeffs[124],
							coeffs[125],
							coeffs[126],
							coeffs[127],
							coeffs[128],
							coeffs[129],
							coeffs[130],
							coeffs[131],
							coeffs[132],
							coeffs[133],
							coeffs[134],
							coeffs[135],
							coeffs[136],
							coeffs[137],
							coeffs[138],
							coeffs[139],
							coeffs[140],
							coeffs[141],
							coeffs[142],
							coeffs[143],
							coeffs[144],
							coeffs[145],
							coeffs[146],
							coeffs[147],
							coeffs[148],
							coeffs[149],
							coeffs[150],
							coeffs[151],
							coeffs[152],
							coeffs[153],
							coeffs[154],
							coeffs[155],
							coeffs[156],
							coeffs[157],
							coeffs[158],
							coeffs[159],
							coeffs[160],
							coeffs[161],
							coeffs[162],
							coeffs[163],
							coeffs[164],
							coeffs[165],
							coeffs[166],
							coeffs[167],
							coeffs[168],
							coeffs[169],
							coeffs[170],
							coeffs[171],
							coeffs[172],
							coeffs[173],
							coeffs[174],
							coeffs[175],
							coeffs[176],
							coeffs[177],
							coeffs[178],
							coeffs[179],
							coeffs[180],
							coeffs[181],
							coeffs[182],
							coeffs[183],
							coeffs[184],
							coeffs[185],
							coeffs[186],
							coeffs[187],
							coeffs[188],
							coeffs[189],
							coeffs[190],
							coeffs[191],
							coeffs[192],
							coeffs[193],
							coeffs[194],
							coeffs[195],
							coeffs[196],
							coeffs[197],
							coeffs[198],
							coeffs[199],
							coeffs[200],
							coeffs[201],
							coeffs[202],
							coeffs[203],
							coeffs[204],
							coeffs[205],
							coeffs[206],
							coeffs[207],
							coeffs[208],
							coeffs[209],
							coeffs[210],
							coeffs[211],
							coeffs[212],
							coeffs[213],
							coeffs[214],
							coeffs[215],
							coeffs[216],
							coeffs[217],
							coeffs[218],
							coeffs[219],
							coeffs[220],
							coeffs[221],
							coeffs[222],
							coeffs[223],
							coeffs[224],
							coeffs[225],
							coeffs[226],
							coeffs[227],
							coeffs[228],
							coeffs[229],
							coeffs[230],
							coeffs[231],
							coeffs[232],
							coeffs[233],
							coeffs[234],
							coeffs[235],
							coeffs[236],
							coeffs[237],
							coeffs[238],
							coeffs[239],
							coeffs[240],
							coeffs[241],
							coeffs[242],
							coeffs[243],
							coeffs[244],
							coeffs[245],
							coeffs[246],
							coeffs[247],
							coeffs[248],
							coeffs[249],
							coeffs[250],
							coeffs[251],
							coeffs[252],
							coeffs[253],
							coeffs[254],
							coeffs[255]};

endmodule
