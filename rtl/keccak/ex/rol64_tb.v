// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: rol64_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100
`define	SIMCYCLE	`NVEC
`define BW_A		64		// Bitwidth of ~~
`define BW_N		9		// Bitwidth of ~~
`define NVEC		100		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"rol64.v"

module rol64_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[`BW_A-1:0]		o_rol64;
	reg		[`BW_A-1:0]		i_a;
	reg		[`BW_N-1:0]		i_n;

	rol64
	#(
		.BW_A				(`BW_A				),
		.BW_N				(`BW_N				)
	)
	u_rol64(
		.o_rol64			(o_rol64			),
		.i_a				(i_a				),
		.i_n				(i_n				)
	);

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[`BW_A-1:0]		vo_rol64[0:`NVEC-1];
	reg		[`BW_A-1:0]		vi_a[0:`NVEC-1];
	reg		[`BW_N-1:0]		vi_n[0:`NVEC-1];

	initial begin
		$readmemb("./vec/ROL64/out.vec",		vo_rol64);
		$readmemb("./vec/ROL64/a.vec",			vi_a);
		$readmemb("./vec/ROL64/n.vec",			vi_n);
	end

	// --------------------------------------------------
	//	Tasks
	// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_a					= 0;
			i_n					= 0;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			i_a					= vi_a[i];
			i_n					= vi_n[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_rol64	!= vo_rol64[i]) begin $display("[Idx: %3d] Mismatched o_rol64", i); end
			if ((o_rol64 != vo_rol64[i])) begin err++; end
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
			$dumpvars;
		end else begin
			$dumpfile("rol64_tb.vcd");
			$dumpvars;
		end
	end

endmodule
