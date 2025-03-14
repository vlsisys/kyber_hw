// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak.v
//	* Description	: 
// ==================================================

`include	"keccakf1600.v"

module keccak
#(	
	parameter	BW_DATA			= 64*5*5,
	parameter	BW_CTRL			= 2
)
(	
	output reg	[63:0]			o_bytes,
	output reg					o_bytes_valid,
	input		[BW_CTRL-1:0]	i_mode,
	input		[63:0]			i_bytes,
	input						i_bytes_valid,
	input		[10:0]			i_ibyte_len,
	input		[9:0]			i_obyte_len,
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

	reg			[7:0]			rate;	// Bytes
	always @(*) begin
		case (i_mode)
			SHAKE128:	rate	= 168;
			SHAKE256:	rate	= 136;
			SHA3_256:	rate	= 136;
			SHA3_512:	rate	=  72;
		endcase
	end

	reg			[7:0]			suffix;
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	suffix	= 8'h1F;
			SHA3_256,
			SHA3_512:	suffix	= 8'h06;
		endcase
	end

	reg			[9:0]			obyte_len_init;
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	obyte_len_init	= i_obyte_len ;
			SHA3_256:	obyte_len_init	= 32          ;
			SHA3_512:	obyte_len_init	= 64          ;
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

	reg			[2:0]			c_state      ;
	reg			[2:0]			n_state      ;
	reg			[4:0]			cnt_fetch    ;
	reg			[7:0]			block_size   ;
	reg			[10:0]			input_offset ;
	reg			[9:0]			obyte_len    ;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			c_state	<= S_IDLE;
		end else begin
			c_state	<= n_state;
		end
	end

	reg			[127:0]			ASCII_C_STATE;
	`ifdef DEBUG
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
	`endif

	// Next State Logic
	always @(*) begin
		case(c_state)
			S_IDLE			: n_state	=	(i_bytes_valid				)	? S_FETCH		: S_IDLE;
			S_FETCH			: n_state	=	(cnt_fetch  == rate/8-1		)	? S_ABSB		: S_FETCH;
			S_ABSB			: n_state	=	(block_size == rate			)	? S_ABSB_KECCAK : S_PADD_KECCAK;
			S_ABSB_KECCAK	: n_state	=	(!keccak_o_valid			)	? S_ABSB_KECCAK	: S_FETCH;
			S_PADD_KECCAK	: n_state	=	(!keccak_o_valid			)	? S_PADD_KECCAK	: S_SQUZ;
			S_SQUZ			: n_state	=	(obyte_len - block_size > 0	)	? S_SQUZ_KECCAK	: S_DONE;
			S_SQUZ_KECCAK	: n_state	=	(!keccak_o_valid			)	? S_SQUZ_KECCAK	: S_SQUZ;
			S_DONE			: n_state	=	(cnt_obyte < i_obyte_len/8	)	? S_DONE		: S_IDLE;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_fetch	<= 0;
		end else begin
			if (c_state == S_FETCH) begin
				cnt_fetch	<= cnt_fetch + 1;
			end else begin
				cnt_fetch	<= 0;
			end
		end
	end

	always @(*) begin
		case (c_state)
			S_FETCH			: block_size	= ((i_ibyte_len - input_offset) > rate	) ? rate : i_ibyte_len - input_offset;
			S_ABSB_KECCAK	: block_size	= 0;
			S_SQUZ			: block_size	= (obyte_len > rate						) ? rate : obyte_len;
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
			obyte_len	<= 0;
		end else begin
			case (c_state)
				S_FETCH		: obyte_len		<= obyte_len_init;
				S_SQUZ		: obyte_len		<= obyte_len - block_size;
				default		: obyte_len		<= obyte_len;
			endcase
		end
	end

// --------------------------------------------------
//	Absorb
// --------------------------------------------------
	reg			[63:0]			ibyteblocks[0:20];
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibyteblocks[ 0]	<= 0;
			ibyteblocks[ 1]	<= 0;
			ibyteblocks[ 2]	<= 0;
			ibyteblocks[ 3]	<= 0;
			ibyteblocks[ 4]	<= 0;
			ibyteblocks[ 5]	<= 0;
			ibyteblocks[ 6]	<= 0;
			ibyteblocks[ 7]	<= 0;
			ibyteblocks[ 8]	<= 0;
			ibyteblocks[ 9]	<= 0;
			ibyteblocks[10]	<= 0;
			ibyteblocks[11]	<= 0;
			ibyteblocks[12]	<= 0;
			ibyteblocks[13]	<= 0;
			ibyteblocks[14]	<= 0;
			ibyteblocks[15]	<= 0;
			ibyteblocks[16]	<= 0;
			ibyteblocks[17]	<= 0;
			ibyteblocks[18]	<= 0;
			ibyteblocks[19]	<= 0;
			ibyteblocks[20]	<= 0;
		end else begin
			case (c_state)
				S_FETCH			: ibyteblocks[cnt_fetch]	<= i_bytes;
				S_ABSB_KECCAK	: begin
					ibyteblocks[ 0]	<= 0;
					ibyteblocks[ 1]	<= 0;
					ibyteblocks[ 2]	<= 0;
					ibyteblocks[ 3]	<= 0;
					ibyteblocks[ 4]	<= 0;
					ibyteblocks[ 5]	<= 0;
					ibyteblocks[ 6]	<= 0;
					ibyteblocks[ 7]	<= 0;
					ibyteblocks[ 8]	<= 0;
					ibyteblocks[ 9]	<= 0;
					ibyteblocks[10]	<= 0;
					ibyteblocks[11]	<= 0;
					ibyteblocks[12]	<= 0;
					ibyteblocks[13]	<= 0;
					ibyteblocks[14]	<= 0;
					ibyteblocks[15]	<= 0;
					ibyteblocks[16]	<= 0;
					ibyteblocks[17]	<= 0;
					ibyteblocks[18]	<= 0;
					ibyteblocks[19]	<= 0;
					ibyteblocks[20]	<= 0;
				end
				default		: begin
					ibyteblocks[ 0]	<= ibyteblocks[ 0];
					ibyteblocks[ 1]	<= ibyteblocks[ 1];
					ibyteblocks[ 2]	<= ibyteblocks[ 2];
					ibyteblocks[ 3]	<= ibyteblocks[ 3];
					ibyteblocks[ 4]	<= ibyteblocks[ 4];
					ibyteblocks[ 5]	<= ibyteblocks[ 5];
					ibyteblocks[ 6]	<= ibyteblocks[ 6];
					ibyteblocks[ 7]	<= ibyteblocks[ 7];
					ibyteblocks[ 8]	<= ibyteblocks[ 8];
					ibyteblocks[ 9]	<= ibyteblocks[ 9];
					ibyteblocks[10]	<= ibyteblocks[10];
					ibyteblocks[11]	<= ibyteblocks[11];
					ibyteblocks[12]	<= ibyteblocks[12];
					ibyteblocks[13]	<= ibyteblocks[13];
					ibyteblocks[14]	<= ibyteblocks[14];
					ibyteblocks[15]	<= ibyteblocks[15];
					ibyteblocks[16]	<= ibyteblocks[16];
					ibyteblocks[17]	<= ibyteblocks[17];
					ibyteblocks[18]	<= ibyteblocks[18];
					ibyteblocks[19]	<= ibyteblocks[19];
					ibyteblocks[20]	<= ibyteblocks[20];
				end
			endcase
		end
	end

	wire	[168*8-1:0]	ibyteblock;
	assign	ibyteblock	= {	ibyteblocks[ 0],
							ibyteblocks[ 1],
							ibyteblocks[ 2],
							ibyteblocks[ 3],
							ibyteblocks[ 4],
							ibyteblocks[ 5],
							ibyteblocks[ 6],
							ibyteblocks[ 7],
							ibyteblocks[ 8],
							ibyteblocks[ 9],
							ibyteblocks[10],
							ibyteblocks[11],
							ibyteblocks[12],
							ibyteblocks[13],
							ibyteblocks[14],
							ibyteblocks[15],
							ibyteblocks[16],
							ibyteblocks[17],
							ibyteblocks[18],
							ibyteblocks[19],
							ibyteblocks[20]};


// --------------------------------------------------
//	KeccakF1600
// --------------------------------------------------
	wire 		[BW_DATA-1:0]	keccak_o_state;
	wire 						keccak_o_valid;
	reg			[BW_DATA-1:0]	keccak_i_state;
	reg							keccak_i_valid;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_i_state	<= 0;
		end else begin
			case (c_state)
				S_ABSB			:	keccak_i_state[BW_DATA-1-:168*8]				<= keccak_i_state[BW_DATA-1-:168*8] ^ ibyteblock;
				S_ABSB_KECCAK	:	keccak_i_state									<= keccak_o_valid ? keccak_o_state : keccak_i_state;
				S_PADD_KECCAK	:	begin
									if (!keccak_o_valid) begin
										keccak_i_state[BW_DATA-1-block_size*8-:8]	<= keccak_i_state[BW_DATA-1-block_size*8-:8] ^ suffix;
										keccak_i_state[BW_DATA-1-(rate-1)*8-:8]		<= keccak_i_state[BW_DATA-1-(rate-1)*8-:8] ^ 8'h80;
									end else begin
										keccak_i_state								<= keccak_o_state;
									end
				end
				S_SQUZ_KECCAK	:	keccak_i_state									<= keccak_o_valid ? keccak_o_state : keccak_i_state;
				default			:	keccak_i_state									<= keccak_i_state;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_i_valid	<= 0;
		end else begin
			case (c_state)
				S_ABSB_KECCAK	,	
				S_PADD_KECCAK	,
				S_SQUZ_KECCAK	:	keccak_i_valid	<= 1;
				default			:	keccak_i_valid	<= 0;
			endcase
		end
	end

	keccakf1600
	#(
			.BW_DATA		(BW_DATA			)
	 )
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
	reg			[7:0]			cnt_obyte;
	reg			[63:0]			obyte[0:20];

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_obyte	<=	0;
		end else begin
			case (c_state)
				S_IDLE			: cnt_obyte	<= 0;
				S_DONE			: cnt_obyte	<= cnt_obyte + 1;
				default			: cnt_obyte <= cnt_obyte;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			obyte[ 0]	<=	0;
			obyte[ 1]	<=	0;
			obyte[ 2]	<=	0;
			obyte[ 3]	<=	0;
			obyte[ 4]	<=	0;
			obyte[ 5]	<=	0;
			obyte[ 6]	<=	0;
			obyte[ 7]	<=	0;
			obyte[ 8]	<=	0;
			obyte[ 9]	<=	0;
			obyte[10]	<=	0;
			obyte[11]	<=	0;
			obyte[12]	<=	0;
			obyte[13]	<=	0;
			obyte[14]	<=	0;
			obyte[15]	<=	0;
			obyte[16]	<=	0;
			obyte[17]	<=	0;
			obyte[18]	<=	0;
			obyte[19]	<=	0;
			obyte[20]	<=	0;
		end else begin
			case (c_state)
				S_SQUZ	: begin
					obyte[ 0]	<=	keccak_o_state[BW_DATA-1-( 0*64)-:64];
					obyte[ 1]	<=	keccak_o_state[BW_DATA-1-( 1*64)-:64];
					obyte[ 2]	<=	keccak_o_state[BW_DATA-1-( 2*64)-:64];
					obyte[ 3]	<=	keccak_o_state[BW_DATA-1-( 3*64)-:64];
					obyte[ 4]	<=	keccak_o_state[BW_DATA-1-( 4*64)-:64];
					obyte[ 5]	<=	keccak_o_state[BW_DATA-1-( 5*64)-:64];
					obyte[ 6]	<=	keccak_o_state[BW_DATA-1-( 6*64)-:64];
					obyte[ 7]	<=	keccak_o_state[BW_DATA-1-( 7*64)-:64];
					obyte[ 8]	<=	keccak_o_state[BW_DATA-1-( 8*64)-:64];
					obyte[ 9]	<=	keccak_o_state[BW_DATA-1-( 9*64)-:64];
					obyte[10]	<=	keccak_o_state[BW_DATA-1-(10*64)-:64];
					obyte[11]	<=	keccak_o_state[BW_DATA-1-(11*64)-:64];
					obyte[12]	<=	keccak_o_state[BW_DATA-1-(12*64)-:64];
					obyte[13]	<=	keccak_o_state[BW_DATA-1-(13*64)-:64];
					obyte[14]	<=	keccak_o_state[BW_DATA-1-(14*64)-:64];
					obyte[15]	<=	keccak_o_state[BW_DATA-1-(15*64)-:64];
					obyte[16]	<=	keccak_o_state[BW_DATA-1-(16*64)-:64];
					obyte[17]	<=	keccak_o_state[BW_DATA-1-(17*64)-:64];
					obyte[18]	<=	keccak_o_state[BW_DATA-1-(18*64)-:64];
					obyte[19]	<=	keccak_o_state[BW_DATA-1-(19*64)-:64];
					obyte[20]	<=	keccak_o_state[BW_DATA-1-(20*64)-:64];
				end
				default	: begin
					obyte[ 0]	<=	obyte[ 0];
					obyte[ 1]	<=	obyte[ 1];
					obyte[ 2]	<=	obyte[ 2];
					obyte[ 3]	<=	obyte[ 3];
					obyte[ 4]	<=	obyte[ 4];
					obyte[ 5]	<=	obyte[ 5];
					obyte[ 6]	<=	obyte[ 6];
					obyte[ 7]	<=	obyte[ 7];
					obyte[ 8]	<=	obyte[ 8];
					obyte[ 9]	<=	obyte[ 9];
					obyte[10]	<=	obyte[10];
					obyte[11]	<=	obyte[11];
					obyte[12]	<=	obyte[12];
					obyte[13]	<=	obyte[13];
					obyte[14]	<=	obyte[14];
					obyte[15]	<=	obyte[15];
					obyte[16]	<=	obyte[16];
					obyte[17]	<=	obyte[17];
					obyte[18]	<=	obyte[18];
					obyte[19]	<=	obyte[19];
					obyte[20]	<=	obyte[20];
				end
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_bytes			<= 0;
			o_bytes_valid	<= 0;
		end else begin
			case (c_state)
				S_DONE	: begin
					o_bytes			<= obyte[cnt_obyte];
					o_bytes_valid	<= 1;
				end
				default	: begin
					o_bytes			<= o_bytes;
					o_bytes_valid	<= 0;
				end
			endcase
		end
	end

endmodule
