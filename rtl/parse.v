// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: parse.v
//	* Description	: 
// ==================================================

`include	"configs.v"

module parse
(	
	output reg	[4*12-1:0]	o_coeffs,			// 3329 (12bit) x 256
	output reg				o_coeffs_valid,
	input		[    63:0]	i_ibytes,			// Total 768 Bytes
	input					i_ibytes_valid,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE		= 2'd0  ;
	localparam	S_COMP		= 2'd1  ;
	localparam	S_DONE		= 2'd2  ;

	reg			[1:0]		c_state;
	reg			[1:0]		n_state;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			c_state	<= S_IDLE;
		end else begin
			c_state	<= n_state;
		end
	end

	// Next State Logic
	always @(*) begin
		case(c_state)
			S_IDLE	: n_state = (i_ibytes_valid)  ? S_COMP : S_IDLE;
			S_COMP	: n_state = (cnt_loop == 255) ? S_DONE : S_COMP;
			S_DONE	: n_state = S_IDLE;
		endcase
	end

	reg			[7:0]		cnt_loop;	// 0 ~ 255
	reg			[9:0]		cnt_i;		// 0 ~ 768
	reg			[6:0]		cnt_in;		// 768 / 8 = 96

// --------------------------------------------------
//	Counters for Control
// --------------------------------------------------
	// Counter for Input Bytes
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_in	<= 0;
		end else begin
			if (i_ibytes_valid && cnt_in < 96) begin
				cnt_in	<= cnt_in + 1 ;
			end else begin
				cnt_in	<= (c_state == S_DONE)? 0 : cnt_in;
			end
		end
	end

	//	Input Register
	reg			[768*8-1:0]		ibytes;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibytes							<= 0;
		end else begin
			ibytes[768*8-1-8*cnt_in-:64]	<= i_ibytes;
			
		end
	end

	//	D1, D2 Computation & Related If Statement
	reg			[11:0]		d1[0:1];
	reg			[11:0]		d2[0:1];
	wire					d1_cond[0:1];
	wire					d2_cond[0:1];

	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			d1[0] <= 0                                                         ;
			d2[0] <= 0                                                         ;
			d1[1] <= 0                                                         ;
			d2[1] <= 0                                                         ;
		end else begin
			d1[0] <= ibytes[768*8-8*((cnt_i+0)  )-1-:8]			+ 256*(ibytes[768*8-8*((cnt_i+0)+1)-1-:8]%16);
			d2[0] <= ibytes[768*8-8*((cnt_i+0)+1)-1-:8] >> 4	+  16*(ibytes[768*8-8*((cnt_i+0)+2)-1-:8]   );
			d1[0] <= ibytes[768*8-8*((cnt_i+3)  )-1-:8]			+ 256*(ibytes[768*8-8*((cnt_i+3)+1)-1-:8]%16);
			d2[0] <= ibytes[768*8-8*((cnt_i+3)+1)-1-:8] >> 4	+  16*(ibytes[768*8-8*((cnt_i+3)+2)-1-:8]   );
		end
	end

	assign	d1_cond[0] = (d1[0] < `KYBER_CONFIG_Q)														? 1:0;
	assign	d2_cond[0] = (d2[0] < `KYBER_CONFIG_Q) && (cnt_loop + d1_cond[0])							? 1:0;
	assign	d1_cond[1] = (d1[1] < `KYBER_CONFIG_Q)														? 1:0;
	assign	d2_cond[1] = (d2[1] < `KYBER_CONFIG_Q) && (cnt_loop + d1_cond[0] + d2_cond[0] + d1_cond[1])	? 1:0;

	//	Counter for While Loop
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_loop	<= 0;
		end else begin
			if (cnt_loop < `KYBER_CONFIG_N && c_state == S_COMP) begin
				case (d1_cond[0] + d2_cond[0] + d1_cond[1] + d2_cond[1])
					3'd0	: cnt_loop	<= cnt_loop + 0 ;
					3'd1	: cnt_loop	<= cnt_loop + 1 ;
					3'd2	: cnt_loop	<= cnt_loop + 2 ;
					3'd3	: cnt_loop	<= cnt_loop + 3 ;
					3'd4	: cnt_loop	<= cnt_loop + 4 ;
					default	: cnt_loop	<= 0            ;
				endcase
			end else begin
				cnt_loop	<= 0;
			end
		end
	end

	// Coefficients
	reg			[11:0]		coeffs[0:255];
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			coeffs[  0]	<= 0;
			coeffs[  1]	<= 0;
			coeffs[  2]	<= 0;
			coeffs[  3]	<= 0;
			coeffs[  4]	<= 0;
			coeffs[  5]	<= 0;
			coeffs[  6]	<= 0;
			coeffs[  7]	<= 0;
			coeffs[  8]	<= 0;
			coeffs[  9]	<= 0;
			coeffs[ 10]	<= 0;
			coeffs[ 11]	<= 0;
			coeffs[ 12]	<= 0;
			coeffs[ 13]	<= 0;
			coeffs[ 14]	<= 0;
			coeffs[ 15]	<= 0;
			coeffs[ 16]	<= 0;
			coeffs[ 17]	<= 0;
			coeffs[ 18]	<= 0;
			coeffs[ 19]	<= 0;
			coeffs[ 20]	<= 0;
			coeffs[ 21]	<= 0;
			coeffs[ 22]	<= 0;
			coeffs[ 23]	<= 0;
			coeffs[ 24]	<= 0;
			coeffs[ 25]	<= 0;
			coeffs[ 26]	<= 0;
			coeffs[ 27]	<= 0;
			coeffs[ 28]	<= 0;
			coeffs[ 29]	<= 0;
			coeffs[ 30]	<= 0;
			coeffs[ 31]	<= 0;
			coeffs[ 32]	<= 0;
			coeffs[ 33]	<= 0;
			coeffs[ 34]	<= 0;
			coeffs[ 35]	<= 0;
			coeffs[ 36]	<= 0;
			coeffs[ 37]	<= 0;
			coeffs[ 38]	<= 0;
			coeffs[ 39]	<= 0;
			coeffs[ 40]	<= 0;
			coeffs[ 41]	<= 0;
			coeffs[ 42]	<= 0;
			coeffs[ 43]	<= 0;
			coeffs[ 44]	<= 0;
			coeffs[ 45]	<= 0;
			coeffs[ 46]	<= 0;
			coeffs[ 47]	<= 0;
			coeffs[ 48]	<= 0;
			coeffs[ 49]	<= 0;
			coeffs[ 50]	<= 0;
			coeffs[ 51]	<= 0;
			coeffs[ 52]	<= 0;
			coeffs[ 53]	<= 0;
			coeffs[ 54]	<= 0;
			coeffs[ 55]	<= 0;
			coeffs[ 56]	<= 0;
			coeffs[ 57]	<= 0;
			coeffs[ 58]	<= 0;
			coeffs[ 59]	<= 0;
			coeffs[ 60]	<= 0;
			coeffs[ 61]	<= 0;
			coeffs[ 62]	<= 0;
			coeffs[ 63]	<= 0;
			coeffs[ 64]	<= 0;
			coeffs[ 65]	<= 0;
			coeffs[ 66]	<= 0;
			coeffs[ 67]	<= 0;
			coeffs[ 68]	<= 0;
			coeffs[ 69]	<= 0;
			coeffs[ 70]	<= 0;
			coeffs[ 71]	<= 0;
			coeffs[ 72]	<= 0;
			coeffs[ 73]	<= 0;
			coeffs[ 74]	<= 0;
			coeffs[ 75]	<= 0;
			coeffs[ 76]	<= 0;
			coeffs[ 77]	<= 0;
			coeffs[ 78]	<= 0;
			coeffs[ 79]	<= 0;
			coeffs[ 80]	<= 0;
			coeffs[ 81]	<= 0;
			coeffs[ 82]	<= 0;
			coeffs[ 83]	<= 0;
			coeffs[ 84]	<= 0;
			coeffs[ 85]	<= 0;
			coeffs[ 86]	<= 0;
			coeffs[ 87]	<= 0;
			coeffs[ 88]	<= 0;
			coeffs[ 89]	<= 0;
			coeffs[ 90]	<= 0;
			coeffs[ 91]	<= 0;
			coeffs[ 92]	<= 0;
			coeffs[ 93]	<= 0;
			coeffs[ 94]	<= 0;
			coeffs[ 95]	<= 0;
			coeffs[ 96]	<= 0;
			coeffs[ 97]	<= 0;
			coeffs[ 98]	<= 0;
			coeffs[ 99]	<= 0;
			coeffs[100]	<= 0;
			coeffs[101]	<= 0;
			coeffs[102]	<= 0;
			coeffs[103]	<= 0;
			coeffs[104]	<= 0;
			coeffs[105]	<= 0;
			coeffs[106]	<= 0;
			coeffs[107]	<= 0;
			coeffs[108]	<= 0;
			coeffs[109]	<= 0;
			coeffs[110]	<= 0;
			coeffs[111]	<= 0;
			coeffs[112]	<= 0;
			coeffs[113]	<= 0;
			coeffs[114]	<= 0;
			coeffs[115]	<= 0;
			coeffs[116]	<= 0;
			coeffs[117]	<= 0;
			coeffs[118]	<= 0;
			coeffs[119]	<= 0;
			coeffs[120]	<= 0;
			coeffs[121]	<= 0;
			coeffs[122]	<= 0;
			coeffs[123]	<= 0;
			coeffs[124]	<= 0;
			coeffs[125]	<= 0;
			coeffs[126]	<= 0;
			coeffs[127]	<= 0;
			coeffs[128]	<= 0;
			coeffs[129]	<= 0;
			coeffs[130]	<= 0;
			coeffs[131]	<= 0;
			coeffs[132]	<= 0;
			coeffs[133]	<= 0;
			coeffs[134]	<= 0;
			coeffs[135]	<= 0;
			coeffs[136]	<= 0;
			coeffs[137]	<= 0;
			coeffs[138]	<= 0;
			coeffs[139]	<= 0;
			coeffs[140]	<= 0;
			coeffs[141]	<= 0;
			coeffs[142]	<= 0;
			coeffs[143]	<= 0;
			coeffs[144]	<= 0;
			coeffs[145]	<= 0;
			coeffs[146]	<= 0;
			coeffs[147]	<= 0;
			coeffs[148]	<= 0;
			coeffs[149]	<= 0;
			coeffs[150]	<= 0;
			coeffs[151]	<= 0;
			coeffs[152]	<= 0;
			coeffs[153]	<= 0;
			coeffs[154]	<= 0;
			coeffs[155]	<= 0;
			coeffs[156]	<= 0;
			coeffs[157]	<= 0;
			coeffs[158]	<= 0;
			coeffs[159]	<= 0;
			coeffs[160]	<= 0;
			coeffs[161]	<= 0;
			coeffs[162]	<= 0;
			coeffs[163]	<= 0;
			coeffs[164]	<= 0;
			coeffs[165]	<= 0;
			coeffs[166]	<= 0;
			coeffs[167]	<= 0;
			coeffs[168]	<= 0;
			coeffs[169]	<= 0;
			coeffs[170]	<= 0;
			coeffs[171]	<= 0;
			coeffs[172]	<= 0;
			coeffs[173]	<= 0;
			coeffs[174]	<= 0;
			coeffs[175]	<= 0;
			coeffs[176]	<= 0;
			coeffs[177]	<= 0;
			coeffs[178]	<= 0;
			coeffs[179]	<= 0;
			coeffs[180]	<= 0;
			coeffs[181]	<= 0;
			coeffs[182]	<= 0;
			coeffs[183]	<= 0;
			coeffs[184]	<= 0;
			coeffs[185]	<= 0;
			coeffs[186]	<= 0;
			coeffs[187]	<= 0;
			coeffs[188]	<= 0;
			coeffs[189]	<= 0;
			coeffs[190]	<= 0;
			coeffs[191]	<= 0;
			coeffs[192]	<= 0;
			coeffs[193]	<= 0;
			coeffs[194]	<= 0;
			coeffs[195]	<= 0;
			coeffs[196]	<= 0;
			coeffs[197]	<= 0;
			coeffs[198]	<= 0;
			coeffs[199]	<= 0;
			coeffs[200]	<= 0;
			coeffs[201]	<= 0;
			coeffs[202]	<= 0;
			coeffs[203]	<= 0;
			coeffs[204]	<= 0;
			coeffs[205]	<= 0;
			coeffs[206]	<= 0;
			coeffs[207]	<= 0;
			coeffs[208]	<= 0;
			coeffs[209]	<= 0;
			coeffs[210]	<= 0;
			coeffs[211]	<= 0;
			coeffs[212]	<= 0;
			coeffs[213]	<= 0;
			coeffs[214]	<= 0;
			coeffs[215]	<= 0;
			coeffs[216]	<= 0;
			coeffs[217]	<= 0;
			coeffs[218]	<= 0;
			coeffs[219]	<= 0;
			coeffs[220]	<= 0;
			coeffs[221]	<= 0;
			coeffs[222]	<= 0;
			coeffs[223]	<= 0;
			coeffs[224]	<= 0;
			coeffs[225]	<= 0;
			coeffs[226]	<= 0;
			coeffs[227]	<= 0;
			coeffs[228]	<= 0;
			coeffs[229]	<= 0;
			coeffs[230]	<= 0;
			coeffs[231]	<= 0;
			coeffs[232]	<= 0;
			coeffs[233]	<= 0;
			coeffs[234]	<= 0;
			coeffs[235]	<= 0;
			coeffs[236]	<= 0;
			coeffs[237]	<= 0;
			coeffs[238]	<= 0;
			coeffs[239]	<= 0;
			coeffs[240]	<= 0;
			coeffs[241]	<= 0;
			coeffs[242]	<= 0;
			coeffs[243]	<= 0;
			coeffs[244]	<= 0;
			coeffs[245]	<= 0;
			coeffs[246]	<= 0;
			coeffs[247]	<= 0;
			coeffs[248]	<= 0;
			coeffs[249]	<= 0;
			coeffs[250]	<= 0;
			coeffs[251]	<= 0;
			coeffs[252]	<= 0;
			coeffs[253]	<= 0;
			coeffs[254]	<= 0;
			coeffs[255]	<= 0;
		end else begin
			coeffs[cnt_loop                                        ]	<= d1_cond[0] ? d1[0] : coeffs[cnt_loop                                        ];
			coeffs[cnt_loop +                            d1_cond[0]]	<= d2_cond[0] ? d2[0] : coeffs[cnt_loop +                            d1_cond[0]];
			coeffs[cnt_loop +               d2_cond[0] + d1_cond[0]]	<= d1_cond[1] ? d1[1] : coeffs[cnt_loop +               d2_cond[0] + d1_cond[0]];
			coeffs[cnt_loop +  d1_cond[1] + d2_cond[0] + d1_cond[0]]	<= d2_cond[1] ? d2[1] : coeffs[cnt_loop +  d1_cond[1] + d2_cond[0] + d1_cond[0]];
		end
	end

	// Output Coefficients
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs	<= 0;
		end else begin
			
		end
	end

endmodule
