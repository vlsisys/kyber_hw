// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: parse.v
//	* Description	: 
// ==================================================

`include	"configs.v"

module parse
(	
	output 		[4*12-1:0]	o_coeffs,
	output					o_coeffs_valid,
	input		[    63:0]	i_ibytes,
	input					i_ibytes_valid,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE	= 2'd0;
	localparam	S_COMP	= 2'd1;
	localparam	S_DONE	= 2'd2;

	reg			[7:0]		cnt_loop;
	reg			[9:0]		cnt_i;
	reg			[6:0]		cnt_in;
	reg			[7:0]		ibytes[0:768-1];
	reg			[11:0]		d1[0:1];
	reg			[11:0]		d2[0:1];
	reg			[1:0]		c_state;
	reg			[1:0]		n_state;

	// Counter for Loop
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			d1[0] <= 0                                                ;
			d2[0] <= 0                                                ;
			d1[1] <= 0                                                ;
			d2[1] <= 0                                                ;
		end else begin
			d1[0] <= ibytes[(cnt_i+0)  ]		+ 256*(ibytes[(cnt_i+0)+1]%16);
			d2[0] <= ibytes[(cnt_i+0)+1] >> 4	+  16*(ibytes[(cnt_i+0)+2]);
			d1[0] <= ibytes[(cnt_i+3)  ]		+ 256*(ibytes[(cnt_i+3)+1]%16);
			d2[0] <= ibytes[(cnt_i+3)+1] >> 4	+  16*(ibytes[(cnt_i+3)+2]);
		end
	end

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

	reg			[12-1:0]	coeffs[0:255];

	


endmodule
