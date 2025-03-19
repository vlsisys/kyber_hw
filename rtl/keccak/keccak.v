// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak.v
//	* Description	: 
// ==================================================

`include	"config_keccak.v"
`include	"keccakf1600.v"

module keccak
(	
	output reg	[ `BW_DATA-1:0]	o_obytes,
	output reg					o_obytes_done,
	output reg					o_obytes_valid,
	output reg					o_ibytes_ready,
	input		[          1:0]	i_mode,
	input		[ `BW_DATA-1:0]	i_ibytes,
	input						i_ibytes_valid,
	input		[`BW_IBLEN-1:0]	i_ibytes_len,
	input		[`BW_OBLEN-1:0]	i_obytes_len,
	input						i_clk,
	input						i_rstn
);

// --------------------------------------------------
//	Parameters
// --------------------------------------------------
	localparam					SHAKE128	= 2'b00;
	localparam					SHAKE256	= 2'b01;
	localparam					SHA3_256	= 2'b10;
	localparam					SHA3_512	= 2'b11;

	reg			[`BW_IBLEN-1:0]	ibytes_len         ;
	reg			[          7:0]	rate               ; // Bytes
	reg			[          7:0]	suffix             ;
	reg			[`BW_DATA -1:0]	block_buffer[0:20] ;
	reg			[`BW_IBCNT-1:0]	cnt_ibytes         ;
	reg			[`BW_OBCNT-1:0]	cnt_obytes         ;
	reg			[`BW_OBLEN-1:0]	obytes_len_init    ;

	// InputByteLen Modification
	always @(*) begin
		ibytes_len	= |i_ibytes_len[2:0] ? {i_ibytes_len[`BW_IBLEN-1:3], 3'b0} + 8 : i_ibytes_len;
	end

	// Rate (Bytes)
	always @(*) begin
		case (i_mode)
			SHAKE128:	rate	= 168;
			SHAKE256,
			SHA3_256:	rate	= 136;
			SHA3_512:	rate	=  72;
		endcase
	end

	// Delimted Suffix
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	suffix	= 8'h1F;
			SHA3_256,
			SHA3_512:	suffix	= 8'h06;
		endcase
	end

	// Output Byte Length
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	obytes_len_init	= i_obytes_len ; // outputByteLen
			SHA3_256:	obytes_len_init	= 32           ; // 32 bytes
			SHA3_512:	obytes_len_init	= 64           ; // 64 bytes
		endcase
	end

// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE			= 3'd0;
	localparam	S_FETCH			= 3'd1;	// 168*8-bits (21 Cycles)
	localparam	S_ABSB			= 3'd2;
	localparam	S_ABSB_KECCAK	= 3'd3;
	localparam	S_PADD_KECCAK	= 3'd4;
	localparam	S_SQUZ			= 3'd5;
	localparam	S_SQUZ_KECCAK	= 3'd6;
	localparam	S_DONE			= 3'd7;

	reg			[2:0]			p_state      ;
	reg			[2:0]			c_state      ;
	reg			[2:0]			n_state      ;
	reg			[`BW_BLOCK-1:0]	block_size   ;
	reg			[`BW_IBLEN-1:0]	input_offset ;
	reg			[`BW_OBLEN-1:0]	obytes_len   ;

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
			S_IDLE			: n_state	=	i_ibytes_valid															? S_FETCH		: S_IDLE  ;
			S_FETCH			: n_state	=	(cnt_ibytes % 21 == 20) || (cnt_ibytes == (ibytes_len*8/`BW_DATA)-1)	? S_ABSB		: S_FETCH ;
			S_ABSB			: n_state	=	block_size == rate														? S_ABSB_KECCAK :
											cnt_ibytes == (ibytes_len*8/`BW_DATA-1)									? S_PADD_KECCAK : S_FETCH ;
			S_ABSB_KECCAK	: n_state	=	!keccak_o_valid															? S_ABSB_KECCAK	: S_FETCH ;
			S_PADD_KECCAK	: n_state	=	!keccak_o_valid															? S_PADD_KECCAK	: S_SQUZ  ;
			S_SQUZ			: n_state	=	cnt_obytes == (i_obytes_len*8/`BW_DATA-1)								? S_DONE		:
											(cnt_obytes % 21 == 20)	&& (obytes_len > 0)								? S_SQUZ_KECCAK	: S_SQUZ  ;
			S_SQUZ_KECCAK	: n_state	=	!keccak_o_valid															? S_SQUZ_KECCAK	: S_SQUZ  ;
			S_DONE			: n_state	=	S_IDLE;
		endcase
	end

	always @(*) begin
		case (c_state)
//			S_IDLE			,
			S_FETCH			: o_ibytes_ready	= 1;
			default			: o_ibytes_ready	= 0;
		endcase
	end

	always @(*) begin
		case (c_state)
			S_DONE			: o_obytes_done		= 1;
			default			: o_obytes_done		= 0;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_ibytes	<= 0;
		end else begin
			if ((c_state == S_FETCH && n_state == S_FETCH) && i_ibytes_valid) begin
				cnt_ibytes	<= cnt_ibytes + 1;
			end else begin
				cnt_ibytes	<= o_obytes_done ? 0 : cnt_ibytes;
			end
		end
	end

	always @(*) begin
		case (c_state)
			S_FETCH			: block_size	= ((ibytes_len - input_offset) > rate	)	? rate : ibytes_len - input_offset;
			S_ABSB_KECCAK	: block_size	= 0;
			S_SQUZ			: block_size	= (obytes_len > rate) 						? rate : obytes_len;
			default			: block_size	= block_size;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			input_offset	<= 0;
		end else begin
			case (c_state)
				S_ABSB		: input_offset	<= input_offset + block_size;
				S_DONE		: input_offset	<= 0;
				default		: input_offset	<= input_offset;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			obytes_len	<= 0;
		end else begin
			case (c_state)
				S_FETCH		: obytes_len	<= obytes_len_init;
				S_SQUZ		: obytes_len	<= (cnt_obytes % 21 == 20) ? obytes_len - block_size : obytes_len;
				default		: obytes_len	<= obytes_len;
			endcase
		end
	end

// --------------------------------------------------
//	Absorb
// --------------------------------------------------
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			block_buffer[ 0]	<= 0;
			block_buffer[ 1]	<= 0;
			block_buffer[ 2]	<= 0;
			block_buffer[ 3]	<= 0;
			block_buffer[ 4]	<= 0;
			block_buffer[ 5]	<= 0;
			block_buffer[ 6]	<= 0;
			block_buffer[ 7]	<= 0;
			block_buffer[ 8]	<= 0;
			block_buffer[ 9]	<= 0;
			block_buffer[10]	<= 0;
			block_buffer[11]	<= 0;
			block_buffer[12]	<= 0;
			block_buffer[13]	<= 0;
			block_buffer[14]	<= 0;
			block_buffer[15]	<= 0;
			block_buffer[16]	<= 0;
			block_buffer[17]	<= 0;
			block_buffer[18]	<= 0;
			block_buffer[19]	<= 0;
			block_buffer[20]	<= 0;
		end else begin
			case (c_state)
				S_FETCH			:	block_buffer[cnt_ibytes]	<= i_ibytes;
				S_ABSB_KECCAK	: begin
									block_buffer[ 0]	<= 0;
									block_buffer[ 1]	<= 0;
									block_buffer[ 2]	<= 0;
									block_buffer[ 3]	<= 0;
									block_buffer[ 4]	<= 0;
									block_buffer[ 5]	<= 0;
									block_buffer[ 6]	<= 0;
									block_buffer[ 7]	<= 0;
									block_buffer[ 8]	<= 0;
									block_buffer[ 9]	<= 0;
									block_buffer[10]	<= 0;
									block_buffer[11]	<= 0;
									block_buffer[12]	<= 0;
									block_buffer[13]	<= 0;
									block_buffer[14]	<= 0;
									block_buffer[15]	<= 0;
									block_buffer[16]	<= 0;
									block_buffer[17]	<= 0;
									block_buffer[18]	<= 0;
									block_buffer[19]	<= 0;
									block_buffer[20]	<= 0;
				end
				S_SQUZ			: begin
									block_buffer[ 0]	<= keccak_o_state[`BW_KCCK-1-( 0*`BW_DATA)-:`BW_DATA];
									block_buffer[ 1]	<= keccak_o_state[`BW_KCCK-1-( 1*`BW_DATA)-:`BW_DATA];
									block_buffer[ 2]	<= keccak_o_state[`BW_KCCK-1-( 2*`BW_DATA)-:`BW_DATA];
									block_buffer[ 3]	<= keccak_o_state[`BW_KCCK-1-( 3*`BW_DATA)-:`BW_DATA];
									block_buffer[ 4]	<= keccak_o_state[`BW_KCCK-1-( 4*`BW_DATA)-:`BW_DATA];
									block_buffer[ 5]	<= keccak_o_state[`BW_KCCK-1-( 5*`BW_DATA)-:`BW_DATA];
									block_buffer[ 6]	<= keccak_o_state[`BW_KCCK-1-( 6*`BW_DATA)-:`BW_DATA];
									block_buffer[ 7]	<= keccak_o_state[`BW_KCCK-1-( 7*`BW_DATA)-:`BW_DATA];
									block_buffer[ 8]	<= keccak_o_state[`BW_KCCK-1-( 8*`BW_DATA)-:`BW_DATA];
									block_buffer[ 9]	<= keccak_o_state[`BW_KCCK-1-( 9*`BW_DATA)-:`BW_DATA];
									block_buffer[10]	<= keccak_o_state[`BW_KCCK-1-(10*`BW_DATA)-:`BW_DATA];
									block_buffer[11]	<= keccak_o_state[`BW_KCCK-1-(11*`BW_DATA)-:`BW_DATA];
									block_buffer[12]	<= keccak_o_state[`BW_KCCK-1-(12*`BW_DATA)-:`BW_DATA];
									block_buffer[13]	<= keccak_o_state[`BW_KCCK-1-(13*`BW_DATA)-:`BW_DATA];
									block_buffer[14]	<= keccak_o_state[`BW_KCCK-1-(14*`BW_DATA)-:`BW_DATA];
									block_buffer[15]	<= keccak_o_state[`BW_KCCK-1-(15*`BW_DATA)-:`BW_DATA];
									block_buffer[16]	<= keccak_o_state[`BW_KCCK-1-(16*`BW_DATA)-:`BW_DATA];
									block_buffer[17]	<= keccak_o_state[`BW_KCCK-1-(17*`BW_DATA)-:`BW_DATA];
									block_buffer[18]	<= keccak_o_state[`BW_KCCK-1-(18*`BW_DATA)-:`BW_DATA];
									block_buffer[19]	<= keccak_o_state[`BW_KCCK-1-(19*`BW_DATA)-:`BW_DATA];
									block_buffer[20]	<= keccak_o_state[`BW_KCCK-1-(20*`BW_DATA)-:`BW_DATA];
				end
				default		: begin
									block_buffer[ 0]	<= block_buffer[ 0];
									block_buffer[ 1]	<= block_buffer[ 1];
									block_buffer[ 2]	<= block_buffer[ 2];
									block_buffer[ 3]	<= block_buffer[ 3];
									block_buffer[ 4]	<= block_buffer[ 4];
									block_buffer[ 5]	<= block_buffer[ 5];
									block_buffer[ 6]	<= block_buffer[ 6];
									block_buffer[ 7]	<= block_buffer[ 7];
									block_buffer[ 8]	<= block_buffer[ 8];
									block_buffer[ 9]	<= block_buffer[ 9];
									block_buffer[10]	<= block_buffer[10];
									block_buffer[11]	<= block_buffer[11];
									block_buffer[12]	<= block_buffer[12];
									block_buffer[13]	<= block_buffer[13];
									block_buffer[14]	<= block_buffer[14];
									block_buffer[15]	<= block_buffer[15];
									block_buffer[16]	<= block_buffer[16];
									block_buffer[17]	<= block_buffer[17];
									block_buffer[18]	<= block_buffer[18];
									block_buffer[19]	<= block_buffer[19];
									block_buffer[20]	<= block_buffer[20];
				end
			endcase
		end
	end

	wire	[`BLOCK_SIZE*8-1:0]	block;
	assign	block		= {	block_buffer[ 0],
							block_buffer[ 1],
							block_buffer[ 2],
							block_buffer[ 3],
							block_buffer[ 4],
							block_buffer[ 5],
							block_buffer[ 6],
							block_buffer[ 7],
							block_buffer[ 8],
							block_buffer[ 9],
							block_buffer[10],
							block_buffer[11],
							block_buffer[12],
							block_buffer[13],
							block_buffer[14],
							block_buffer[15],
							block_buffer[16],
							block_buffer[17],
							block_buffer[18],
							block_buffer[19],
							block_buffer[20]};

// --------------------------------------------------
//	KeccakF1600
// --------------------------------------------------
	wire 		[`BW_KCCK-1:0]	keccak_o_state;
	wire 						keccak_o_valid;
	reg			[`BW_KCCK-1:0]	keccak_i_state;
	reg							keccak_i_valid;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_i_state	<= 0;
		end else begin
			case (c_state)
				S_ABSB			:	keccak_i_state[`BW_KCCK-1-:`BLOCK_SIZE*8]		<= keccak_i_state[`BW_KCCK-1-:`BLOCK_SIZE*8] ^ block   ;
				S_ABSB_KECCAK	:	keccak_i_state									<= keccak_o_valid ? keccak_o_state : keccak_i_state      ;
				S_PADD_KECCAK	:	begin
								if (p_state == S_ABSB) begin
									keccak_i_state[`BW_KCCK-1-block_size*8-:8]	<= keccak_i_state[`BW_KCCK-1-block_size*8-:8] ^ suffix ;
									keccak_i_state[`BW_KCCK-1-(rate-1)*8-:8]		<= keccak_i_state[`BW_KCCK-1-(rate-1)*8-:8]   ^ 8'h80  ;
								end else begin
									keccak_i_state									<= keccak_o_valid ? keccak_o_state : keccak_i_state      ;
								end
				end
				S_SQUZ_KECCAK	:	keccak_i_state									<= keccak_o_valid ? keccak_o_state : keccak_i_state      ;
				default			:	keccak_i_state									<= keccak_i_state                                        ;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_i_valid	<= 0;
		end else begin
			case (n_state)
				S_ABSB_KECCAK	,	
				S_SQUZ_KECCAK	:	keccak_i_valid	<= 1;
				S_PADD_KECCAK	:	keccak_i_valid	<= (c_state == S_PADD_KECCAK) ?	1:0;
				default			:	keccak_i_valid	<= 0;
			endcase
		end
	end

	keccakf1600
	u_keccakf1600(
		.o_state			(keccak_o_state		),
		.o_valid			(keccak_o_valid		),
		.i_state			(keccak_i_state		),
		.i_valid			(keccak_i_valid		),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

// --------------------------------------------------
//	Output Bytes
// --------------------------------------------------

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_obytes		<= 0;
			o_obytes		<= 0;
			o_obytes_valid	<= 0;
		end else begin
			if (c_state == S_SQUZ && p_state == S_SQUZ) begin
				cnt_obytes		<= cnt_obytes + 1;
				o_obytes		<= block_buffer[cnt_obytes % 21];
				o_obytes_valid	<= 1;
			end else begin
				cnt_obytes		<= o_obytes_done ? 0: cnt_obytes;
				o_obytes		<= o_obytes;
				o_obytes_valid	<= 0;
			end
		end
	end

	`ifdef DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE			: ASCII_C_STATE = " IDLE       ";
			S_FETCH			: ASCII_C_STATE = " FETCH      ";
			S_ABSB			: ASCII_C_STATE = " ABSB       ";
			S_ABSB_KECCAK	: ASCII_C_STATE = " ABSB_KECCAK";
			S_PADD_KECCAK	: ASCII_C_STATE = " PADD_KECCAK";
			S_SQUZ			: ASCII_C_STATE = " SQUZ       ";
			S_SQUZ_KECCAK	: ASCII_C_STATE = " SQUZ_KECCAK";
			S_DONE			: ASCII_C_STATE = " DONE       ";
		endcase
	end

	reg			[`MAX_IBYTES*8-1:0]		IBYTES;
	reg			[`MAX_OBYTES*8-1:0]		OBYTES;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			IBYTES		<= 0;
		end else begin
			case (c_state)
				S_IDLE	: IBYTES													<= 0        ;
				S_FETCH	: IBYTES[ibytes_len*8-1-(`BW_DATA*cnt_ibytes)-:`BW_DATA]	<= i_ibytes ;
				default	: IBYTES													<= IBYTES   ;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			OBYTES		<= 0;
		end else begin
			if (o_obytes_valid) begin
				OBYTES[i_obytes_len*8-1-(`BW_DATA*(cnt_obytes-1))-:`BW_DATA]		<= o_obytes;
			end else begin
				if (c_state == S_PADD_KECCAK) begin
					OBYTES		<= 0;
				end else begin
					OBYTES		<= OBYTES;
				end
			end
		end
	end
	`endif

endmodule
