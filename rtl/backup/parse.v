// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: parse.v
//	* Description	: 
// ==================================================

`include	"../configs.v"

module parse
(	
	output reg	[4*12-1:0]	o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_done,
	input		[    63:0]	i_ibytes,
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
//	Counters for Control
// --------------------------------------------------
	reg			[6:0]		cnt_in           ; // 768 / 8 = 96
	reg			[9:0]		cnt_idx          ; // 0 ~ 768

	// Counter for Input Bytes
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_in	<= 0;
		end else begin

			case (c_state)
				S_DONE	: cnt_in 	<= 0;
				default	: cnt_in 	<= i_ibytes_valid && (cnt_in < 96) ? cnt_in + 1 : cnt_in;
			endcase
		end
	end

	// Counter for Index of Input Bytes
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_idx	<= 0;
		end else begin
			case (c_state)
				S_COMP	: cnt_idx	<= (cnt_loop < 255) ? cnt_idx + 6 : cnt_idx;
				default	: cnt_idx	<= 0;
			endcase
		end
	end

	//	Input Register
	reg			[768*8-1:0]		ibytes;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibytes	<= 0;
		end else begin
			if (i_ibytes_valid) begin
				ibytes[768*8-1-(64*cnt_in)-:64]	<= i_ibytes;
			end else begin
				ibytes	<= ibytes;
			end
		end
	end

	//	D1, D2 Computation & Related If Statement
	reg			[11:0]		d1[0:1];
	reg			[11:0]		d2[0:1];
	wire					d1_cond[0:1];
	wire					d2_cond[0:1];

	always @(*) begin
		d1[0] = (ibytes[768*8-8*((cnt_idx+0)  )-1-:8]		) + 256*(ibytes[768*8-8*((cnt_idx+0)+1)-1-:8]%16);
		d2[0] = (ibytes[768*8-8*((cnt_idx+0)+1)-1-:8] >> 4	) +  16*(ibytes[768*8-8*((cnt_idx+0)+2)-1-:8]   );
		d1[1] = (ibytes[768*8-8*((cnt_idx+3)  )-1-:8]		) + 256*(ibytes[768*8-8*((cnt_idx+3)+1)-1-:8]%16);
		d2[1] = (ibytes[768*8-8*((cnt_idx+3)+1)-1-:8] >> 4	) +  16*(ibytes[768*8-8*((cnt_idx+3)+2)-1-:8]   );
	end

	assign	d1_cond[0] = (d1[0] < `KYBER_CONFIG_Q)																			? 1:0;
	assign	d2_cond[0] = (d2[0] < `KYBER_CONFIG_Q) && ((cnt_loop + d1_cond[0])							 < `KYBER_CONFIG_N)	? 1:0;
	assign	d1_cond[1] = (d1[1] < `KYBER_CONFIG_Q)																			? 1:0;
	assign	d2_cond[1] = (d2[1] < `KYBER_CONFIG_Q) && ((cnt_loop + d1_cond[0] + d2_cond[0] + d1_cond[1]) < `KYBER_CONFIG_N)	? 1:0;

	//	Counter for While Loop
	wire		[2:0]		add_cond;
	reg			[7:0]		cnt_loop;	// 0 ~ 255

	assign	add_cond = d1_cond[0] + d2_cond[0] + d1_cond[1] + d2_cond[1];

	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_loop	<= 0;
		end else begin
			case (c_state)
				S_COMP	: begin
					case (add_cond)
						3'd0	: cnt_loop	<= (cnt_loop + 0) <= 255 ? cnt_loop + 0 : cnt_loop;
						3'd1	: cnt_loop	<= (cnt_loop + 1) <= 255 ? cnt_loop + 1 : cnt_loop;
						3'd2	: cnt_loop	<= (cnt_loop + 2) <= 255 ? cnt_loop + 2 : cnt_loop;
						3'd3	: cnt_loop	<= (cnt_loop + 3) <= 255 ? cnt_loop + 3 : cnt_loop;
						3'd4	: cnt_loop	<= (cnt_loop + 4) <= 255 ? cnt_loop + 4 : cnt_loop;
						default	: cnt_loop	<= cnt_loop;
					endcase
				end
				default	: cnt_loop	<= 0;
			endcase
		end
	end

	// Coefficients Buffer
	reg			[11:0]		coeffs[0:255] ;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			coeffs[  0]	<= 0; coeffs[  1]	<= 0; coeffs[  2]	<= 0; coeffs[  3]	<= 0; coeffs[  4]	<= 0; coeffs[  5]	<= 0; coeffs[  6]	<= 0; coeffs[  7]	<= 0; coeffs[  8]	<= 0; coeffs[  9]	<= 0; coeffs[ 10]	<= 0; coeffs[ 11]	<= 0; coeffs[ 12]	<= 0; coeffs[ 13]	<= 0; coeffs[ 14]	<= 0; coeffs[ 15]	<= 0; coeffs[ 16]	<= 0; coeffs[ 17]	<= 0; coeffs[ 18]	<= 0; coeffs[ 19]	<= 0; coeffs[ 20]	<= 0; coeffs[ 21]	<= 0; coeffs[ 22]	<= 0; coeffs[ 23]	<= 0; coeffs[ 24]	<= 0; coeffs[ 25]	<= 0; coeffs[ 26]	<= 0; coeffs[ 27]	<= 0; coeffs[ 28]	<= 0; coeffs[ 29]	<= 0; coeffs[ 30]	<= 0; coeffs[ 31]	<= 0; coeffs[ 32]	<= 0; coeffs[ 33]	<= 0; coeffs[ 34]	<= 0; coeffs[ 35]	<= 0; coeffs[ 36]	<= 0; coeffs[ 37]	<= 0; coeffs[ 38]	<= 0; coeffs[ 39]	<= 0; coeffs[ 40]	<= 0; coeffs[ 41]	<= 0; coeffs[ 42]	<= 0; coeffs[ 43]	<= 0; coeffs[ 44]	<= 0; coeffs[ 45]	<= 0; coeffs[ 46]	<= 0; coeffs[ 47]	<= 0; coeffs[ 48]	<= 0; coeffs[ 49]	<= 0; coeffs[ 50]	<= 0; coeffs[ 51]	<= 0; coeffs[ 52]	<= 0; coeffs[ 53]	<= 0; coeffs[ 54]	<= 0; coeffs[ 55]	<= 0; coeffs[ 56]	<= 0; coeffs[ 57]	<= 0; coeffs[ 58]	<= 0; coeffs[ 59]	<= 0; coeffs[ 60]	<= 0; coeffs[ 61]	<= 0; coeffs[ 62]	<= 0; coeffs[ 63]	<= 0; coeffs[ 64]	<= 0; coeffs[ 65]	<= 0; coeffs[ 66]	<= 0; coeffs[ 67]	<= 0; coeffs[ 68]	<= 0; coeffs[ 69]	<= 0; coeffs[ 70]	<= 0; coeffs[ 71]	<= 0; coeffs[ 72]	<= 0; coeffs[ 73]	<= 0; coeffs[ 74]	<= 0; coeffs[ 75]	<= 0; coeffs[ 76]	<= 0; coeffs[ 77]	<= 0; coeffs[ 78]	<= 0; coeffs[ 79]	<= 0; coeffs[ 80]	<= 0; coeffs[ 81]	<= 0; coeffs[ 82]	<= 0; coeffs[ 83]	<= 0; coeffs[ 84]	<= 0; coeffs[ 85]	<= 0; coeffs[ 86]	<= 0; coeffs[ 87]	<= 0; coeffs[ 88]	<= 0; coeffs[ 89]	<= 0; coeffs[ 90]	<= 0; coeffs[ 91]	<= 0; coeffs[ 92]	<= 0; coeffs[ 93]	<= 0; coeffs[ 94]	<= 0; coeffs[ 95]	<= 0; coeffs[ 96]	<= 0; coeffs[ 97]	<= 0; coeffs[ 98]	<= 0; coeffs[ 99]	<= 0; coeffs[100]	<= 0; coeffs[101]	<= 0; coeffs[102]	<= 0; coeffs[103]	<= 0; coeffs[104]	<= 0; coeffs[105]	<= 0; coeffs[106]	<= 0; coeffs[107]	<= 0; coeffs[108]	<= 0; coeffs[109]	<= 0; coeffs[110]	<= 0; coeffs[111]	<= 0; coeffs[112]	<= 0; coeffs[113]	<= 0; coeffs[114]	<= 0; coeffs[115]	<= 0; coeffs[116]	<= 0; coeffs[117]	<= 0; coeffs[118]	<= 0; coeffs[119]	<= 0; coeffs[120]	<= 0; coeffs[121]	<= 0; coeffs[122]	<= 0; coeffs[123]	<= 0; coeffs[124]	<= 0; coeffs[125]	<= 0; coeffs[126]	<= 0; coeffs[127]	<= 0; coeffs[128]	<= 0; coeffs[129]	<= 0; coeffs[130]	<= 0; coeffs[131]	<= 0; coeffs[132]	<= 0; coeffs[133]	<= 0; coeffs[134]	<= 0; coeffs[135]	<= 0; coeffs[136]	<= 0; coeffs[137]	<= 0; coeffs[138]	<= 0; coeffs[139]	<= 0; coeffs[140]	<= 0; coeffs[141]	<= 0; coeffs[142]	<= 0; coeffs[143]	<= 0; coeffs[144]	<= 0; coeffs[145]	<= 0; coeffs[146]	<= 0; coeffs[147]	<= 0; coeffs[148]	<= 0; coeffs[149]	<= 0; coeffs[150]	<= 0; coeffs[151]	<= 0; coeffs[152]	<= 0; coeffs[153]	<= 0; coeffs[154]	<= 0; coeffs[155]	<= 0; coeffs[156]	<= 0; coeffs[157]	<= 0; coeffs[158]	<= 0; coeffs[159]	<= 0; coeffs[160]	<= 0; coeffs[161]	<= 0; coeffs[162]	<= 0; coeffs[163]	<= 0; coeffs[164]	<= 0; coeffs[165]	<= 0; coeffs[166]	<= 0; coeffs[167]	<= 0; coeffs[168]	<= 0; coeffs[169]	<= 0; coeffs[170]	<= 0; coeffs[171]	<= 0; coeffs[172]	<= 0; coeffs[173]	<= 0; coeffs[174]	<= 0; coeffs[175]	<= 0; coeffs[176]	<= 0; coeffs[177]	<= 0; coeffs[178]	<= 0; coeffs[179]	<= 0; coeffs[180]	<= 0; coeffs[181]	<= 0; coeffs[182]	<= 0; coeffs[183]	<= 0; coeffs[184]	<= 0; coeffs[185]	<= 0; coeffs[186]	<= 0; coeffs[187]	<= 0; coeffs[188]	<= 0; coeffs[189]	<= 0; coeffs[190]	<= 0; coeffs[191]	<= 0; coeffs[192]	<= 0; coeffs[193]	<= 0; coeffs[194]	<= 0; coeffs[195]	<= 0; coeffs[196]	<= 0; coeffs[197]	<= 0; coeffs[198]	<= 0; coeffs[199]	<= 0; coeffs[200]	<= 0; coeffs[201]	<= 0; coeffs[202]	<= 0; coeffs[203]	<= 0; coeffs[204]	<= 0; coeffs[205]	<= 0; coeffs[206]	<= 0; coeffs[207]	<= 0; coeffs[208]	<= 0; coeffs[209]	<= 0; coeffs[210]	<= 0; coeffs[211]	<= 0; coeffs[212]	<= 0; coeffs[213]	<= 0; coeffs[214]	<= 0; coeffs[215]	<= 0; coeffs[216]	<= 0; coeffs[217]	<= 0; coeffs[218]	<= 0; coeffs[219]	<= 0; coeffs[220]	<= 0; coeffs[221]	<= 0; coeffs[222]	<= 0; coeffs[223]	<= 0; coeffs[224]	<= 0; coeffs[225]	<= 0; coeffs[226]	<= 0; coeffs[227]	<= 0; coeffs[228]	<= 0; coeffs[229]	<= 0; coeffs[230]	<= 0; coeffs[231]	<= 0; coeffs[232]	<= 0; coeffs[233]	<= 0; coeffs[234]	<= 0; coeffs[235]	<= 0; coeffs[236]	<= 0; coeffs[237]	<= 0; coeffs[238]	<= 0; coeffs[239]	<= 0; coeffs[240]	<= 0; coeffs[241]	<= 0; coeffs[242]	<= 0; coeffs[243]	<= 0; coeffs[244]	<= 0; coeffs[245]	<= 0; coeffs[246]	<= 0; coeffs[247]	<= 0; coeffs[248]	<= 0; coeffs[249]	<= 0; coeffs[250]	<= 0; coeffs[251]	<= 0; coeffs[252]	<= 0; coeffs[253]	<= 0; coeffs[254]	<= 0; coeffs[255]	<= 0;
		end else begin
			if ((c_state == S_COMP) && !(cnt_out >= 63 && acc_cond >= 4)) begin
				coeffs[cnt_loop                                       ]	<= d1_cond[0] && (cnt_loop                                       ) <= 255 ? d1[0] : coeffs[cnt_loop                                        ];
				coeffs[cnt_loop +                           d1_cond[0]]	<= d2_cond[0] && (cnt_loop +                           d1_cond[0]) <= 255 ? d2[0] : coeffs[cnt_loop +                            d1_cond[0]];
				coeffs[cnt_loop +              d2_cond[0] + d1_cond[0]]	<= d1_cond[1] && (cnt_loop +              d2_cond[0] + d1_cond[0]) <= 255 ? d1[1] : coeffs[cnt_loop +               d2_cond[0] + d1_cond[0]];
				coeffs[cnt_loop + d1_cond[1] + d2_cond[0] + d1_cond[0]]	<= d2_cond[1] && (cnt_loop + d1_cond[1] + d2_cond[0] + d1_cond[0]) <= 255 ? d2[1] : coeffs[cnt_loop +  d1_cond[1] + d2_cond[0] + d1_cond[0]];
			end else begin
				coeffs[  0]	<= coeffs[  0];
				coeffs[  1]	<= coeffs[  1];
				coeffs[  2]	<= coeffs[  2];
				coeffs[  3]	<= coeffs[  3];
				coeffs[  4]	<= coeffs[  4];
				coeffs[  5]	<= coeffs[  5];
				coeffs[  6]	<= coeffs[  6];
				coeffs[  7]	<= coeffs[  7];
				coeffs[  8]	<= coeffs[  8];
				coeffs[  9]	<= coeffs[  9];
				coeffs[ 10]	<= coeffs[ 10];
				coeffs[ 11]	<= coeffs[ 11];
				coeffs[ 12]	<= coeffs[ 12];
				coeffs[ 13]	<= coeffs[ 13];
				coeffs[ 14]	<= coeffs[ 14];
				coeffs[ 15]	<= coeffs[ 15];
				coeffs[ 16]	<= coeffs[ 16];
				coeffs[ 17]	<= coeffs[ 17];
				coeffs[ 18]	<= coeffs[ 18];
				coeffs[ 19]	<= coeffs[ 19];
				coeffs[ 20]	<= coeffs[ 20];
				coeffs[ 21]	<= coeffs[ 21];
				coeffs[ 22]	<= coeffs[ 22];
				coeffs[ 23]	<= coeffs[ 23];
				coeffs[ 24]	<= coeffs[ 24];
				coeffs[ 25]	<= coeffs[ 25];
				coeffs[ 26]	<= coeffs[ 26];
				coeffs[ 27]	<= coeffs[ 27];
				coeffs[ 28]	<= coeffs[ 28];
				coeffs[ 29]	<= coeffs[ 29];
				coeffs[ 30]	<= coeffs[ 30];
				coeffs[ 31]	<= coeffs[ 31];
				coeffs[ 32]	<= coeffs[ 32];
				coeffs[ 33]	<= coeffs[ 33];
				coeffs[ 34]	<= coeffs[ 34];
				coeffs[ 35]	<= coeffs[ 35];
				coeffs[ 36]	<= coeffs[ 36];
				coeffs[ 37]	<= coeffs[ 37];
				coeffs[ 38]	<= coeffs[ 38];
				coeffs[ 39]	<= coeffs[ 39];
				coeffs[ 40]	<= coeffs[ 40];
				coeffs[ 41]	<= coeffs[ 41];
				coeffs[ 42]	<= coeffs[ 42];
				coeffs[ 43]	<= coeffs[ 43];
				coeffs[ 44]	<= coeffs[ 44];
				coeffs[ 45]	<= coeffs[ 45];
				coeffs[ 46]	<= coeffs[ 46];
				coeffs[ 47]	<= coeffs[ 47];
				coeffs[ 48]	<= coeffs[ 48];
				coeffs[ 49]	<= coeffs[ 49];
				coeffs[ 50]	<= coeffs[ 50];
				coeffs[ 51]	<= coeffs[ 51];
				coeffs[ 52]	<= coeffs[ 52];
				coeffs[ 53]	<= coeffs[ 53];
				coeffs[ 54]	<= coeffs[ 54];
				coeffs[ 55]	<= coeffs[ 55];
				coeffs[ 56]	<= coeffs[ 56];
				coeffs[ 57]	<= coeffs[ 57];
				coeffs[ 58]	<= coeffs[ 58];
				coeffs[ 59]	<= coeffs[ 59];
				coeffs[ 60]	<= coeffs[ 60];
				coeffs[ 61]	<= coeffs[ 61];
				coeffs[ 62]	<= coeffs[ 62];
				coeffs[ 63]	<= coeffs[ 63];
				coeffs[ 64]	<= coeffs[ 64];
				coeffs[ 65]	<= coeffs[ 65];
				coeffs[ 66]	<= coeffs[ 66];
				coeffs[ 67]	<= coeffs[ 67];
				coeffs[ 68]	<= coeffs[ 68];
				coeffs[ 69]	<= coeffs[ 69];
				coeffs[ 70]	<= coeffs[ 70];
				coeffs[ 71]	<= coeffs[ 71];
				coeffs[ 72]	<= coeffs[ 72];
				coeffs[ 73]	<= coeffs[ 73];
				coeffs[ 74]	<= coeffs[ 74];
				coeffs[ 75]	<= coeffs[ 75];
				coeffs[ 76]	<= coeffs[ 76];
				coeffs[ 77]	<= coeffs[ 77];
				coeffs[ 78]	<= coeffs[ 78];
				coeffs[ 79]	<= coeffs[ 79];
				coeffs[ 80]	<= coeffs[ 80];
				coeffs[ 81]	<= coeffs[ 81];
				coeffs[ 82]	<= coeffs[ 82];
				coeffs[ 83]	<= coeffs[ 83];
				coeffs[ 84]	<= coeffs[ 84];
				coeffs[ 85]	<= coeffs[ 85];
				coeffs[ 86]	<= coeffs[ 86];
				coeffs[ 87]	<= coeffs[ 87];
				coeffs[ 88]	<= coeffs[ 88];
				coeffs[ 89]	<= coeffs[ 89];
				coeffs[ 90]	<= coeffs[ 90];
				coeffs[ 91]	<= coeffs[ 91];
				coeffs[ 92]	<= coeffs[ 92];
				coeffs[ 93]	<= coeffs[ 93];
				coeffs[ 94]	<= coeffs[ 94];
				coeffs[ 95]	<= coeffs[ 95];
				coeffs[ 96]	<= coeffs[ 96];
				coeffs[ 97]	<= coeffs[ 97];
				coeffs[ 98]	<= coeffs[ 98];
				coeffs[ 99]	<= coeffs[ 99];
				coeffs[100]	<= coeffs[100];
				coeffs[101]	<= coeffs[101];
				coeffs[102]	<= coeffs[102];
				coeffs[103]	<= coeffs[103];
				coeffs[104]	<= coeffs[104];
				coeffs[105]	<= coeffs[105];
				coeffs[106]	<= coeffs[106];
				coeffs[107]	<= coeffs[107];
				coeffs[108]	<= coeffs[108];
				coeffs[109]	<= coeffs[109];
				coeffs[110]	<= coeffs[110];
				coeffs[111]	<= coeffs[111];
				coeffs[112]	<= coeffs[112];
				coeffs[113]	<= coeffs[113];
				coeffs[114]	<= coeffs[114];
				coeffs[115]	<= coeffs[115];
				coeffs[116]	<= coeffs[116];
				coeffs[117]	<= coeffs[117];
				coeffs[118]	<= coeffs[118];
				coeffs[119]	<= coeffs[119];
				coeffs[120]	<= coeffs[120];
				coeffs[121]	<= coeffs[121];
				coeffs[122]	<= coeffs[122];
				coeffs[123]	<= coeffs[123];
				coeffs[124]	<= coeffs[124];
				coeffs[125]	<= coeffs[125];
				coeffs[126]	<= coeffs[126];
				coeffs[127]	<= coeffs[127];
				coeffs[128]	<= coeffs[128];
				coeffs[129]	<= coeffs[129];
				coeffs[130]	<= coeffs[130];
				coeffs[131]	<= coeffs[131];
				coeffs[132]	<= coeffs[132];
				coeffs[133]	<= coeffs[133];
				coeffs[134]	<= coeffs[134];
				coeffs[135]	<= coeffs[135];
				coeffs[136]	<= coeffs[136];
				coeffs[137]	<= coeffs[137];
				coeffs[138]	<= coeffs[138];
				coeffs[139]	<= coeffs[139];
				coeffs[140]	<= coeffs[140];
				coeffs[141]	<= coeffs[141];
				coeffs[142]	<= coeffs[142];
				coeffs[143]	<= coeffs[143];
				coeffs[144]	<= coeffs[144];
				coeffs[145]	<= coeffs[145];
				coeffs[146]	<= coeffs[146];
				coeffs[147]	<= coeffs[147];
				coeffs[148]	<= coeffs[148];
				coeffs[149]	<= coeffs[149];
				coeffs[150]	<= coeffs[150];
				coeffs[151]	<= coeffs[151];
				coeffs[152]	<= coeffs[152];
				coeffs[153]	<= coeffs[153];
				coeffs[154]	<= coeffs[154];
				coeffs[155]	<= coeffs[155];
				coeffs[156]	<= coeffs[156];
				coeffs[157]	<= coeffs[157];
				coeffs[158]	<= coeffs[158];
				coeffs[159]	<= coeffs[159];
				coeffs[160]	<= coeffs[160];
				coeffs[161]	<= coeffs[161];
				coeffs[162]	<= coeffs[162];
				coeffs[163]	<= coeffs[163];
				coeffs[164]	<= coeffs[164];
				coeffs[165]	<= coeffs[165];
				coeffs[166]	<= coeffs[166];
				coeffs[167]	<= coeffs[167];
				coeffs[168]	<= coeffs[168];
				coeffs[169]	<= coeffs[169];
				coeffs[170]	<= coeffs[170];
				coeffs[171]	<= coeffs[171];
				coeffs[172]	<= coeffs[172];
				coeffs[173]	<= coeffs[173];
				coeffs[174]	<= coeffs[174];
				coeffs[175]	<= coeffs[175];
				coeffs[176]	<= coeffs[176];
				coeffs[177]	<= coeffs[177];
				coeffs[178]	<= coeffs[178];
				coeffs[179]	<= coeffs[179];
				coeffs[180]	<= coeffs[180];
				coeffs[181]	<= coeffs[181];
				coeffs[182]	<= coeffs[182];
				coeffs[183]	<= coeffs[183];
				coeffs[184]	<= coeffs[184];
				coeffs[185]	<= coeffs[185];
				coeffs[186]	<= coeffs[186];
				coeffs[187]	<= coeffs[187];
				coeffs[188]	<= coeffs[188];
				coeffs[189]	<= coeffs[189];
				coeffs[190]	<= coeffs[190];
				coeffs[191]	<= coeffs[191];
				coeffs[192]	<= coeffs[192];
				coeffs[193]	<= coeffs[193];
				coeffs[194]	<= coeffs[194];
				coeffs[195]	<= coeffs[195];
				coeffs[196]	<= coeffs[196];
				coeffs[197]	<= coeffs[197];
				coeffs[198]	<= coeffs[198];
				coeffs[199]	<= coeffs[199];
				coeffs[200]	<= coeffs[200];
				coeffs[201]	<= coeffs[201];
				coeffs[202]	<= coeffs[202];
				coeffs[203]	<= coeffs[203];
				coeffs[204]	<= coeffs[204];
				coeffs[205]	<= coeffs[205];
				coeffs[206]	<= coeffs[206];
				coeffs[207]	<= coeffs[207];
				coeffs[208]	<= coeffs[208];
				coeffs[209]	<= coeffs[209];
				coeffs[210]	<= coeffs[210];
				coeffs[211]	<= coeffs[211];
				coeffs[212]	<= coeffs[212];
				coeffs[213]	<= coeffs[213];
				coeffs[214]	<= coeffs[214];
				coeffs[215]	<= coeffs[215];
				coeffs[216]	<= coeffs[216];
				coeffs[217]	<= coeffs[217];
				coeffs[218]	<= coeffs[218];
				coeffs[219]	<= coeffs[219];
				coeffs[220]	<= coeffs[220];
				coeffs[221]	<= coeffs[221];
				coeffs[222]	<= coeffs[222];
				coeffs[223]	<= coeffs[223];
				coeffs[224]	<= coeffs[224];
				coeffs[225]	<= coeffs[225];
				coeffs[226]	<= coeffs[226];
				coeffs[227]	<= coeffs[227];
				coeffs[228]	<= coeffs[228];
				coeffs[229]	<= coeffs[229];
				coeffs[230]	<= coeffs[230];
				coeffs[231]	<= coeffs[231];
				coeffs[232]	<= coeffs[232];
				coeffs[233]	<= coeffs[233];
				coeffs[234]	<= coeffs[234];
				coeffs[235]	<= coeffs[235];
				coeffs[236]	<= coeffs[236];
				coeffs[237]	<= coeffs[237];
				coeffs[238]	<= coeffs[238];
				coeffs[239]	<= coeffs[239];
				coeffs[240]	<= coeffs[240];
				coeffs[241]	<= coeffs[241];
				coeffs[242]	<= coeffs[242];
				coeffs[243]	<= coeffs[243];
				coeffs[244]	<= coeffs[244];
				coeffs[245]	<= coeffs[245];
				coeffs[246]	<= coeffs[246];
				coeffs[247]	<= coeffs[247];
				coeffs[248]	<= coeffs[248];
				coeffs[249]	<= coeffs[249];
				coeffs[250]	<= coeffs[250];
				coeffs[251]	<= coeffs[251];
				coeffs[252]	<= coeffs[252];
				coeffs[253]	<= coeffs[253];
				coeffs[254]	<= coeffs[254];
				coeffs[255]	<= coeffs[255];
			end
		end
	end

	// Output Coefficients
	reg			[2:0]		acc_cond;
	reg			[5:0]		cnt_out;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			acc_cond		<= 0;
			cnt_out			<= 0;
			o_coeffs		<= 0;
			o_coeffs_valid	<= 0;
		end else begin
			if (c_state == S_COMP) begin
				if ((acc_cond) >= 4) begin
					acc_cond		<= acc_cond + add_cond - 4;
					cnt_out			<= cnt_out + 1;
					o_coeffs		<= {coeffs[4*cnt_out+0], coeffs[4*cnt_out+1], coeffs[4*cnt_out+2], coeffs[4*cnt_out+3]};
					o_coeffs_valid	<= 1;
				end else begin
					acc_cond		<= acc_cond + add_cond;
					cnt_out			<= cnt_out;
					o_coeffs		<= o_coeffs;
					o_coeffs_valid	<= 0;
				end
			end else begin
				acc_cond		<= 0;
				cnt_out			<= 0;
				o_coeffs		<= 0;
				o_coeffs_valid	<= 0;
			end
		end
	end

	`ifdef DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE	: ASCII_C_STATE = "IDLE";
			S_COMP	: ASCII_C_STATE = "COMP";
			S_DONE	: ASCII_C_STATE = "DONE";
		endcase
	end

	wire		[12*256-1:0]	dbug_o_coeffs;
	assign	dbug_o_coeffs = {	coeffs[  0],
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
	`endif

endmodule
