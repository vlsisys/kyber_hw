// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak.v
//	* Description	: 
// ==================================================

module keccak
#(	
	parameter	BW_CTRL			= 2
)
(	
	output reg	[192*8-1:0]		o_bytes,
	output reg					o_valid,
	input		[BW_CTRL-1:0]	i_mode,
	input		[1568*8-1:0]	i_bytes,
	input		[10:0]			i_ibyte_len,
	input		[7:0]			i_obyte_len,
	input						i_clk,
	input						i_rstn
);

	localparam					SHAKE128	= 2'b00;
	localparam					SHAKE256	= 2'b01;
	localparam					SHA3_256	= 2'b10;
	localparam					SHA3_512	= 2'b11;

	reg			[7:0]			rate_in_byte;
	always @(*) begin
		case (i_mode)
			SHAKE128:	rate_in_byte	= 168;
			SHAKE256:	rate_in_byte	= 136;
			SHA3_256:	rate_in_byte	= 136;
			SHA3_512:	rate_in_byte	=  72;
		endcase
	end

	reg			[7:0]			block_size;
	reg			[10:0]			input_offset;
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			block_size		<= 0;
			input_offset	<= 0;
		end else begin
			block_size		<= ( (i_ibyte_len - input_offset) > rate_in_byte ) ? rate_in_byte : i_ibyte_len - input_offset;
			input_offset	<= input_offset + block_size;
			
			
		end
	end
	



endmodule
