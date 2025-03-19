// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccakf1600_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		5		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"keccakf1600.v"

module keccakf1600_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------

	output 		[`BW_KCCK-1:0]	o_state;
	output 						o_valid;
	reg			[`BW_KCCK-1:0]	i_state;
	reg							i_valid;
	reg							i_clk;
	reg							i_rstn;

	keccakf1600
	u_keccakf1600(
		.o_state				(o_state			),
		.o_valid				(o_valid			),
		.i_state				(i_state			),
		.i_valid				(i_valid			),
		.i_clk					(i_clk				),
		.i_rstn					(i_rstn				)
	);

// --------------------------------------------------
//	Clock
// --------------------------------------------------
	always	#(500/`CLKFREQ)		i_clk = ~i_clk;

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg			[1184*8-1:0]	vo_state[0:`NVEC-1];
	reg			[1184*8-1:0]	vi_state[0:`NVEC-1];

	initial begin
		$readmemh("../../vec/keccakf1600/o_state.vec",		vo_state);
		$readmemh("../../vec/keccakf1600/i_state.vec",		vi_state);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_state				= 0;
			i_valid				= 0;
			i_clk				= 0;
			i_rstn				= 0;
		end
	endtask

	task resetNCycle;
		input	[9:0]	i;
		begin
			taskState		= "Reset";
			i_rstn	= 1'b0;
			#(i*1000/`CLKFREQ);
			i_rstn	= 1'b1;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			i_state				= vi_state[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_state			!= vo_state[i]) begin $display("[Idx: %3d] Mismatched o_state", i); end
			if ((o_state != vo_state[i])) begin err++; end
			#(0.9*1000/`CLKFREQ);
		end
	endtask

// --------------------------------------------------
//	Test Stimulus
// --------------------------------------------------
	integer		i, j;
	initial begin
		init();
		resetNCycle(4);

		for (i=0; i<`SIMCYCLE; i++) begin
			vecInsert(i);
			i_valid	= 1'b1;
			#(1000/`CLKFREQ);
			i_valid	= 1'b0;
			#(24*1000/`CLKFREQ);
			vecVerify(i);
		end
		#(1000/`CLKFREQ);
		$finish;
	end

// --------------------------------------------------
//	Dump VCD
// --------------------------------------------------
	reg	[8*32-1:0]	vcd_file;
	initial begin
		if ($value$plusargs("vcd_file=%s", vcd_file)) begin
			$dumpfile(vcd_file);
			$dumpvars;
		end else begin
			$dumpfile("keccakf1600_tb.vcd");
			$dumpvars;
		end
	end

endmodule
