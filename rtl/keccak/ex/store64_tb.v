// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: store64_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define BW_DATA		64		// Bitwidth of ~~
`define NVEC		100		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"store64.v"

module store64_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	output 	[`BW_DATA-1:0]	o_data;
	reg		[`BW_DATA-1:0]	i_data;

	store64
	#(
		.BW_DATA			(`BW_DATA			)
	)
	u_store64(
		.o_data				(o_data				),
		.i_data				(i_data				)
	);

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[`BW_DATA-1:0]	vo_data[0:`NVEC-1];
	reg		[`BW_DATA-1:0]	vi_data[0:`NVEC-1];

	initial begin
		$readmemb("./vec/store64/o_data.vec",			vo_data);
		$readmemb("./vec/store64/i_data.vec",			vi_data);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_data				= 0;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			i_data				= vi_data[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_data			!= vo_data[i]) begin $display("[Idx: %3d] Mismatched o_data", i); end
			if ((o_data != vo_data[i])) begin err++; end
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
			$dumpfile("store64_tb.vcd");
			$dumpvars;
		end
	end

endmodule
