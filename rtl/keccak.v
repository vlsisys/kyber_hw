// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak.v
//	* Description	: 
// ==================================================

`include	"keccakf1600.v"

module keccak
(	
	output reg	[64-1:0]	o_obytes,
	output reg				o_obytes_done,
	output reg				o_obytes_valid,
	output reg				o_ibytes_ready,
	input		[   1:0]	i_mode,
	input		[64-1:0]	i_ibytes,
	input					i_ibytes_valid,
	input		[11-1:0]	i_ibytes_len,
	input		[10-1:0]	i_obytes_len,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	Parameters
// --------------------------------------------------
	localparam				SHAKE128	= 2'b00;
	localparam				SHAKE256	= 2'b01;
	localparam				SHA3_256	= 2'b10;
	localparam				SHA3_512	= 2'b11;

	reg			[11-1:0]	ibytes_len         ;
	reg			[   7:0]	rate               ; // Bytes
	reg			[   7:0]	suffix             ;
	reg			[64-1:0]	block_buffer[0:20] ;
	reg			[ 8-1:0]	cnt_ibytes         ;
	reg			[ 7-1:0]	cnt_obytes         ;
	reg			[ 8-1:0]	cnt_blocks         ;
	reg			[10-1:0]	obytes_len_init    ;

	// InputByteLen Modification
	always @(*) begin
		ibytes_len	= |i_ibytes_len[2:0] ? {i_ibytes_len[11-1:3], 3'b0} + 8 : i_ibytes_len;
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

	reg			[   2:0]	p_state      ;
	reg			[   2:0]	c_state      ;
	reg			[   2:0]	n_state      ;
	reg			[ 8-1:0]	block_size   ;
	reg			[11-1:0]	input_offset ;
	reg			[10-1:0]	obytes_len   ;

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
			S_IDLE			: n_state	=	i_ibytes_valid																				? S_FETCH		: S_IDLE  ;
			S_FETCH			: n_state	=	(cnt_blocks == (block_size/8-1+|i_ibytes_len[2:0])) || (cnt_ibytes == (ibytes_len*8/64)-1)	? S_ABSB		: S_FETCH ;
			S_ABSB			: n_state	=	block_size == rate																			? S_ABSB_KECCAK :
											cnt_ibytes >= (ibytes_len*8/64-1)															? S_PADD_KECCAK : S_FETCH ;
			S_ABSB_KECCAK	: n_state	=	!keccak_ostate_valid																		? S_ABSB_KECCAK	:
											(cnt_ibytes == (ibytes_len*8/64)-1)															? S_PADD_KECCAK : S_ABSB  ;
			S_PADD_KECCAK	: n_state	=	!keccak_ostate_valid																		? S_PADD_KECCAK	: S_SQUZ  ;
			S_SQUZ			: n_state	=	cnt_obytes == (i_obytes_len*8/64-1)															? S_DONE		:
											(cnt_blocks == (block_size/8-1)) && (obytes_len > 0)										? S_SQUZ_KECCAK	: S_SQUZ  ;
			S_SQUZ_KECCAK	: n_state	=	!keccak_ostate_valid																		? S_SQUZ_KECCAK	: S_SQUZ  ;
			S_DONE			: n_state	=	S_IDLE;
		endcase
	end

	always @(*) begin
		case (c_state)
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

	always @(*) begin
		case (c_state)
			S_FETCH			: block_size	= ((i_ibytes_len - input_offset) > rate	)	? rate : i_ibytes_len - input_offset;
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
				S_SQUZ		: obytes_len	<= n_state != S_SQUZ ? obytes_len - block_size : obytes_len;
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
				S_FETCH			: begin
					block_buffer[cnt_blocks]	<= i_ibytes;
				end
				S_ABSB_KECCAK	,
				S_DONE			: begin
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
					block_buffer[ 0]	<= keccak_ostate[1600-1-( 0*64)-:64];
					block_buffer[ 1]	<= keccak_ostate[1600-1-( 1*64)-:64];
					block_buffer[ 2]	<= keccak_ostate[1600-1-( 2*64)-:64];
					block_buffer[ 3]	<= keccak_ostate[1600-1-( 3*64)-:64];
					block_buffer[ 4]	<= keccak_ostate[1600-1-( 4*64)-:64];
					block_buffer[ 5]	<= keccak_ostate[1600-1-( 5*64)-:64];
					block_buffer[ 6]	<= keccak_ostate[1600-1-( 6*64)-:64];
					block_buffer[ 7]	<= keccak_ostate[1600-1-( 7*64)-:64];
					block_buffer[ 8]	<= keccak_ostate[1600-1-( 8*64)-:64];
					block_buffer[ 9]	<= keccak_ostate[1600-1-( 9*64)-:64];
					block_buffer[10]	<= keccak_ostate[1600-1-(10*64)-:64];
					block_buffer[11]	<= keccak_ostate[1600-1-(11*64)-:64];
					block_buffer[12]	<= keccak_ostate[1600-1-(12*64)-:64];
					block_buffer[13]	<= keccak_ostate[1600-1-(13*64)-:64];
					block_buffer[14]	<= keccak_ostate[1600-1-(14*64)-:64];
					block_buffer[15]	<= keccak_ostate[1600-1-(15*64)-:64];
					block_buffer[16]	<= keccak_ostate[1600-1-(16*64)-:64];
					block_buffer[17]	<= keccak_ostate[1600-1-(17*64)-:64];
					block_buffer[18]	<= keccak_ostate[1600-1-(18*64)-:64];
					block_buffer[19]	<= keccak_ostate[1600-1-(19*64)-:64];
					block_buffer[20]	<= keccak_ostate[1600-1-(20*64)-:64];
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

	wire	[168*8-1:0]	block;
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
	wire 		[1600-1:0]	keccak_ostate;
	wire 					keccak_ostate_valid;
	wire 					keccak_istate_ready;
	reg			[1600-1:0]	keccak_istate;
	reg						keccak_istate_valid;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_istate	<= 0;
		end else begin
			case (c_state)
				S_DONE			:	keccak_istate							<= 0;
				S_ABSB			:	keccak_istate[1600-1-:168*8]			<= keccak_istate[1600-1-:168*8] ^ block					;
				S_ABSB_KECCAK	:	keccak_istate							<= keccak_ostate_valid ? keccak_ostate : keccak_istate	;
				S_PADD_KECCAK	:	begin
								if (p_state == S_ABSB) begin
									keccak_istate[1600-1-block_size*8-:8]	<= keccak_istate[1600-1-block_size*8-:8] ^ suffix		;
									keccak_istate[1600-1-(rate-1)*8-:8]		<= keccak_istate[1600-1-(rate-1)*8-:8]   ^ 8'h80		;
								end else begin
									keccak_istate							<= keccak_ostate_valid ? keccak_ostate : keccak_istate	;
								end
				end
				S_SQUZ_KECCAK	:	keccak_istate							<= keccak_ostate_valid ? keccak_ostate : keccak_istate	;
				default			:	keccak_istate							<= keccak_istate										;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_istate_valid	<= 0;
		end else begin
			case (n_state)
				S_ABSB_KECCAK	,	
				S_SQUZ_KECCAK	:	keccak_istate_valid	<= 1;
				S_PADD_KECCAK	:	keccak_istate_valid	<= (c_state == S_PADD_KECCAK) ?	1:0;
				default			:	keccak_istate_valid	<= 0;
			endcase
		end
	end

	keccakf1600
	u_keccakf1600(
		.o_ostate			(keccak_ostate			),
		.o_ostate_valid		(keccak_ostate_valid	),
		.o_istate_ready		(keccak_istate_ready	),
		.i_istate			(keccak_istate			),
		.i_istate_valid		(keccak_istate_valid	),
		.i_clk				(i_clk					),
		.i_rstn				(i_rstn					)
	);

// --------------------------------------------------
//	Output Bytes
// --------------------------------------------------
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_ibytes		<= 0;
			cnt_obytes		<= 0;
			cnt_blocks		<= 0;
			o_obytes		<= 0;
			o_obytes_valid	<= 0;
		end else if (c_state == S_FETCH && i_ibytes_valid) begin
			cnt_ibytes		<= cnt_ibytes + 1;
			cnt_obytes		<= 0;
			cnt_blocks		<= cnt_blocks + 1;
			o_obytes		<= 0;
			o_obytes_valid	<= 0;
		//end else if (c_state == S_SQUZ  && p_state == S_SQUZ) begin
		end else if (c_state == S_SQUZ) begin
			cnt_ibytes		<= 0;
			cnt_obytes		<= cnt_obytes + 1;
			cnt_blocks		<= cnt_blocks + 1;
			o_obytes		<= cnt_blocks == 0 ? keccak_ostate[1600-1-( 0*64)-:64] : block_buffer[cnt_blocks];
			o_obytes_valid	<= 1;
		end else if (c_state == S_DONE) begin
			cnt_ibytes		<= 0;
			cnt_obytes		<= 0;
			cnt_blocks		<= 0;
			o_obytes		<= 0;
			o_obytes_valid	<= 0;
			cnt_ibytes		<= 0;
		end else begin
			cnt_ibytes		<= cnt_ibytes;
			cnt_obytes		<= cnt_obytes;
			cnt_blocks		<= 0;
			o_obytes		<= 0;
			o_obytes_valid	<= 0;
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

	reg			[1568*8-1:0]		IBYTES;
	reg			[784*8-1:0]		OBYTES;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			IBYTES		<= 0;
		end else begin
			case (c_state)
				S_IDLE	: IBYTES													<= 0        ;
				S_FETCH	: IBYTES[ibytes_len*8-1-(64*cnt_ibytes)-:64]	<= i_ibytes ;
				default	: IBYTES													<= IBYTES   ;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			OBYTES		<= 0;
		end else begin
			if (o_obytes_valid) begin
				OBYTES[i_obytes_len*8-1-(64*(cnt_obytes-1))-:64]		<= o_obytes;
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
