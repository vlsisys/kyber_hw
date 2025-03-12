// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak.v
//	* Description	: 
// ==================================================

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

	reg			[9:0]			obytes_len;
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	obytes_len	= i_obyte_len ;
			SHA3_256:	obytes_len	= 32          ;
			SHA3_512:	obytes_len	= 64          ;
		endcase
	end

// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE			= 3'd0;
	localparam	S_FETCH			= 3'd1;	// 168*8-bits for blockSize (21 Cycles)
	localparam	S_ABSB			= 3'd2;
	localparam	S_ABSB_KECCAK	= 3'd3;
	localparam	S_PADD_KECCAK	= 3'd4;
	localparam	S_SQUZ			= 3'd5;
	localparam	S_SQUZ_KECCAK	= 3'd6;
	localparam	S_DONE			= 3'd7;

	reg			[1:0]			c_state      ;
	reg			[1:0]			n_state      ;
	reg			[4:0]			cnt_fetch    ;
	reg			[10:0]			input_offset ;
	reg			[7:0]			block_size   ;
	reg			[9:0]			obyte_len    ;

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
			S_IDLE			: n_state	=	(i_bytes_valid				)	? S_FETCH		: S_IDLE;
			S_FETCH			: n_state	=	(cnt_fetch  == rate/8		)	? S_ABSB		: S_FETCH;
			S_ABSB			: n_state	=	(block_size == rate			)	? S_ABSB_KECCAK : S_PADD_KECCAK;
			S_ABSB_KECCAK	: n_state	=	(!keccak_o_valid			)	? S_ABSB_KECCAK	: S_ABSB;
			S_PADD_KECCAK	: n_state	=	(!keccak_o_valid			)	? S_PADD_KECCAK	: S_SQUZ;
			S_SQUZ			: n_state	=	(obyte_len > 0				)	? S_SQUZ_KECCAK	: S_DONE;
			S_SQUZ_KECCAK	: n_state	=	(!keccak_o_valid			)	? S_SQUZ_KECCAK	: S_SQUZ;
			S_DONE			: n_state	=	S_IDLE;
		endcase
	end

// --------------------------------------------------
//	InputBytes Register
// --------------------------------------------------
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


	reg			[BW_DATA-1:0]	state;
// --------------------------------------------------
//	KeccakF1600
// --------------------------------------------------
	wire 		[BW_DATA-1:0]	keccak_o_state;
	wire 						keccak_o_valid;
	reg			[BW_DATA-1:0]	keccak_i_state;
	reg							keccak_i_valid;

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
//	Absorb
// --------------------------------------------------
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			
		end else begin
			
		end
	end



endmodule
