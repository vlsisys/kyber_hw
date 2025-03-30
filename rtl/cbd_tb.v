// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: cbd_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define BW_DATA		32		// Bitwidth of ~~
`define BW_ADDR		5		// Bitwidth of ~~
`define BW_CTRL		4		// Bitwidth of ~~
`define NVEC		50		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"cbd.v"

module cbd_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[256*3-1:0]	o_coeffs;
	reg		[192*8-1:0]	i_ibytes;
	reg		[1:0]		i_eta;

	cbd
	u_cbd(
		.o_coeffs			(o_coeffs			),
		.i_ibytes			(i_ibytes			),
		.i_eta				(i_eta				)
	);

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[256*3-1:0]	vo_coeffs[0:`NVEC-1];
	reg		[192*8-1:0]	vi_ibytes[0:`NVEC-1];
	reg		[1:0]		vi_eta[0:`NVEC-1];

	initial begin
		$readmemh("../vec/cbd/o_coeffs.vec",		vo_coeffs);
		$readmemh("../vec/cbd/i_ibytes.vec",		vi_ibytes);
		$readmemh("../vec/cbd/i_eta.vec",			vi_eta);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_ibytes			= 0;
			i_eta				= 0;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			i_ibytes			= vi_ibytes[i];
			i_eta				= vi_eta[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if ( o_coeffs != vo_coeffs[i]) begin $display("[Idx: %3d] Mismatched o_coeffs", i); end
			if ((o_coeffs != vo_coeffs[i])) begin err++; end
			#(0.9*1000/`CLKFREQ);
		end
	endtask

// --------------------------------------------------
//	Test Stimulus
// --------------------------------------------------
	integer		i, j;
	initial begin
		init();

		for (i=0; i<`SIMCYCLE; i++) begin
			vecInsert(i);
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
			for (i=0; i<16; i++) begin
				$dumpvars(0, u_cbd.coeffs[i]);
			end
			$dumpvars;
		end else begin
			$dumpfile("cbd_tb.vcd");
			$dumpvars;
		end
	end

endmodule
