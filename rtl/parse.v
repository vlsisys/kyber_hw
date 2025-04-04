// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: parse.v
//	* Description	: 
// ==================================================

`include	"configs.v"

module parse
(	
	output reg	[4*12-1:0]	o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_ibytes_ready,
	output reg				o_done,
	input		[    63:0]	i_ibytes,
	input					i_ibytes_valid,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM (Control)
// --------------------------------------------------
	localparam	S_IDLE		= 3'd0  ;
	localparam	S_PRS0		= 3'd1  ;
	localparam	S_PRS1		= 3'd2  ;
	localparam	S_PRS2		= 3'd3  ;
	localparam	S_PRS3		= 3'd4  ;
	localparam	S_DONE		= 3'd5  ;

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
			S_IDLE	: n_state = (i_ibytes_valid)	? S_PRS0 : S_IDLE;
			S_PRS0	: n_state = S_PRS1;
			S_PRS1	: n_state = S_PRS2;
			S_PRS2	: n_state = S_PRS3;
			S_PRS3	: n_state = (cnt_coeff == 63)	? S_DONE	: S_PRS3;
			S_DONE	: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE	: o_done			= 1;
			default	: o_done			= 0;
		endcase
	end

	always @(*) begin
		case(c_state)
			S_PRS0	,
			S_PRS1	,
			S_PRS2	: o_ibytes_ready	= 1;
			default	: o_ibytes_ready	= 0;
		endcase
	end

// --------------------------------------------------
//	Input Byte Register
// --------------------------------------------------
	reg			[63:0]		ibytes_reg;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibytes_reg	<= 0;
		end else begin
			if (i_ibytes_valid && o_ibytes_ready) begin
				ibytes_reg	<= i_ibytes;
			end else begin
				ibytes_reg	<= ibytes_reg;
			end
		end
	end

// --------------------------------------------------
//	D1, D2 Computation
// --------------------------------------------------
	reg			[11:0]		d1[0:1];
	reg			[11:0]		d2[0:1];
	wire					d1_if[0:1];
	wire					d2_if[0:1];

	always @(*) begin
		case (c_state)
			S_PRS0	: begin
				d1[0] = (i_ibytes  [64-1-8*0-:8]		) + 256*(i_ibytes  [64-1-8*1-:8] % 16);
				d2[0] = (i_ibytes  [64-1-8*1-:8] >> 4	) +  16*(i_ibytes  [64-1-8*2-:8]     );
				d1[1] = (i_ibytes  [64-1-8*3-:8]		) + 256*(i_ibytes  [64-1-8*4-:8] % 16);
				d2[1] = (i_ibytes  [64-1-8*4-:8] >> 4	) +  16*(i_ibytes  [64-1-8*5-:8]     );
			end
			S_PRS1	: begin
				d1[0] = (ibytes_reg[64-1-8*6-:8]		) + 256*(ibytes_reg[64-1-8*7-:8] % 16);
				d2[0] = (ibytes_reg[64-1-8*7-:8] >> 4	) +  16*(i_ibytes  [64-1-8*0-:8]     );
				d1[1] = (i_ibytes  [64-1-8*1-:8]		) + 256*(i_ibytes  [64-1-8*2-:8] % 16);
				d2[1] = (i_ibytes  [64-1-8*2-:8] >> 4	) +  16*(i_ibytes  [64-1-8*3-:8]     );
			end
			S_PRS2	: begin
				d1[0] = (ibytes_reg[64-1-8*4-:8]		) + 256*(ibytes_reg[64-1-8*5-:8] % 16);
				d2[0] = (ibytes_reg[64-1-8*5-:8] >> 4	) +  16*(ibytes_reg[64-1-8*6-:8]     );
				d1[1] = (ibytes_reg[64-1-8*7-:8]		) + 256*(i_ibytes  [64-1-8*0-:8] % 16);
				d2[1] = (i_ibytes  [64-1-8*0-:8] >> 4	) +  16*(i_ibytes  [64-1-8*1-:8]     );
			end
			S_PRS3	: begin
				d1[0] = (ibytes_reg[64-1-8*2-:8]		) + 256*(ibytes_reg[64-1-8*3-:8] % 16);
				d2[0] = (ibytes_reg[64-1-8*3-:8] >> 4	) +  16*(ibytes_reg[64-1-8*4-:8]     );
				d1[1] = (ibytes_reg[64-1-8*5-:8]		) + 256*(ibytes_reg[64-1-8*6-:8] % 16);
				d2[1] = (ibytes_reg[64-1-8*6-:8] >> 4	) +  16*(ibytes_reg[64-1-8*7-:8]     );
			end
			default	: begin
				d1[0] = 0;
				d2[0] = 0;
				d1[1] = 0;
				d2[1] = 0;
			end
		endcase
	end

	assign	d1_if[0] = (d1[0] < `KYBER_CONFIG_Q)																	? 1:0;
	assign	d2_if[0] = (d2[0] < `KYBER_CONFIG_Q) && ((cnt_loop + d1_if[0])	< `KYBER_CONFIG_N)						? 1:0;
	assign	d1_if[1] = (d1[1] < `KYBER_CONFIG_Q)																	? 1:0;
	assign	d2_if[1] = (d2[1] < `KYBER_CONFIG_Q) && ((cnt_loop + d1_if[0] + d2_if[0] + d1_if[1]) < `KYBER_CONFIG_N)	? 1:0;

	//	Counter for While Loop
	wire		[2:0]		add_if;
	reg			[7:0]		cnt_loop;	// 0 ~ 255

	assign	add_if = ((c_state == S_IDLE) || (c_state == S_DONE))	? 0 : d1_if[0] + d2_if[0] + d1_if[1] + d2_if[1];

	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_loop	<= 0;
		end else begin
			case (c_state)
				S_PRS0	,
				S_PRS1	,
				S_PRS2	,
				S_PRS3	: begin
					case (add_if)
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

// --------------------------------------------------
//	FSM (Output Coefficients)
// --------------------------------------------------
	localparam	CFF_EMPTY		= 2'd0  ;
	localparam	CFF_FILL1		= 2'd1  ;
	localparam	CFF_FILL2		= 2'd2  ;
	localparam	CFF_FILL3		= 2'd3  ;

	reg			[1:0]		c_state_cff;
	reg			[1:0]		n_state_cff;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			c_state_cff	<= CFF_EMPTY;
		end else begin
			c_state_cff	<= n_state_cff;
		end
	end

	// Next State Logic
	always @(*) begin
		case(c_state)
			CFF_EMPTY	: begin
				case (add_if)
					0		: n_state_cff	= CFF_EMPTY;
					1		: n_state_cff	= CFF_FILL1;
					2		: n_state_cff	= CFF_FILL2;
					3		: n_state_cff	= CFF_FILL3;
					4		: n_state_cff	= CFF_EMPTY;
					default	: n_state_cff	= CFF_EMPTY;
				endcase
			end
			CFF_FILL1: begin
				case (add_if)
					0		: n_state_cff	= CFF_FILL1;
					1		: n_state_cff	= CFF_FILL2;
					2		: n_state_cff	= CFF_FILL3;
					3		: n_state_cff	= CFF_EMPTY;
					4		: n_state_cff	= CFF_FILL1;
					default	: n_state_cff	= CFF_EMPTY;
				endcase
			end
			CFF_FILL2: begin
				case (add_if)
					0		: n_state_cff	= CFF_FILL2;
					1		: n_state_cff	= CFF_FILL3;
					2		: n_state_cff	= CFF_EMPTY;
					3		: n_state_cff	= CFF_FILL1;
					4		: n_state_cff	= CFF_FILL2;
					default	: n_state_cff	= CFF_EMPTY;
				endcase
			end
			CFF_FILL3: begin
				case (add_if)
					0		: n_state_cff	= CFF_FILL3;
					1		: n_state_cff	= CFF_EMPTY;
					2		: n_state_cff	= CFF_FILL1;
					3		: n_state_cff	= CFF_FILL2;
					4		: n_state_cff	= CFF_FILL3;
					default	: n_state_cff	= CFF_EMPTY;
				endcase
			end
		endcase
	end

// --------------------------------------------------
//	Coefficients Register
// --------------------------------------------------
	reg		[3*12-1:0]		coeffs_reg;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			coeffs_reg	<= 0;
		end else begin
			case (c_state_cff)
				CFF_EMPTY	: begin
					case ({d1_if[0], d2_if[0], d1_if[1], d2_if[1]})
						4'b0000	:	coeffs_reg	<= coeffs_reg;
						4'b0001	:	coeffs_reg	<= coeffs_reg;
						4'b0010	:	coeffs_reg	<= coeffs_reg;
						4'b0011	:	coeffs_reg	<= coeffs_reg;
						4'b0100	:	coeffs_reg	<= coeffs_reg;
						4'b0101	:	coeffs_reg	<= coeffs_reg;
						4'b0110	:	coeffs_reg	<= coeffs_reg;
						4'b0111	:	coeffs_reg	<= coeffs_reg;
						4'b1000	:	coeffs_reg	<= coeffs_reg;
						4'b1001	:	coeffs_reg	<= coeffs_reg;
						4'b1010	:	coeffs_reg	<= coeffs_reg;
						4'b1011	:	coeffs_reg	<= coeffs_reg;
						4'b1100	:	coeffs_reg	<= coeffs_reg;
						4'b1101	:	coeffs_reg	<= coeffs_reg;
						4'b1110	:	coeffs_reg	<= coeffs_reg;
						4'b1111	:	coeffs_reg	<= coeffs_reg;
					endcase
				end
			endcase
		end
	end
	reg		[5:0]			cnt_coeff;




	`ifdef DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE	: ASCII_C_STATE = "IDLE";
			S_PRS0	: ASCII_C_STATE = "PRS0";
			S_PRS1	: ASCII_C_STATE = "PRS1";
			S_PRS2	: ASCII_C_STATE = "PRS2";
			S_PRS3	: ASCII_C_STATE = "PRS3";
			S_DONE	: ASCII_C_STATE = "DONE";
		endcase
	end
	`endif

endmodule
