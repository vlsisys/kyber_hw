// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccakf1600lanes_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define BW_DATA		64*5*5	// Bitwidth of ~~
`define NVEC		5		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"keccakf1600lanes.v"

module keccakf1600lanes_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	output 	[`BW_DATA-1:0]	o_lanes;
	wire	    			o_valid;
	reg		[`BW_DATA-1:0]	i_lanes;
	reg						i_valid;
	reg						i_rstn;
	reg						i_clk = 0;

	keccakf1600lanes
	#(
		.BW_DATA			(`BW_DATA			)
	)
	u_keccakf1600lanes(
		.o_lanes			(o_lanes			),
		.o_valid			(o_valid			),
		.i_lanes			(i_lanes			),
		.i_valid			(i_valid			),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

// --------------------------------------------------
//	Clock
// --------------------------------------------------
	always	#(500/`CLKFREQ)		i_clk = ~i_clk;

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[`BW_DATA-1:0]	vo_lanes[0:`NVEC-1];
	reg		[`BW_DATA-1:0]	vi_lanes[0:`NVEC-1];

	initial begin
		$readmemb("../../vec/KeccakF1600onLanes/o_lanes.vec",		vo_lanes);
		$readmemb("../../vec/KeccakF1600onLanes/i_lanes.vec",		vi_lanes);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_lanes				= 0;
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
			i_lanes				= vi_lanes[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_lanes			!= vo_lanes[i]) begin $display("[Idx: %3d] Mismatched o_lanes", i); end
			if ((o_lanes != vo_lanes[i])) begin err++; end
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
	integer			x,y;
	initial begin
		if ($value$plusargs("vcd_file=%s", vcd_file)) begin
			$dumpfile(vcd_file);
			for (x=0; x<5; x++) begin
				for (y=0; y<5; y++) begin
					//$dumpvars(0, u_keccakf1600lanes.lanes[x][y]);
					//$dumpvars(0, u_keccakf1600lanes.lanes_theta[x][y]);
					//$dumpvars(0, u_keccakf1600lanes.lanes_pi[x][y]);
					//$dumpvars(0, u_keccakf1600lanes.lanes_chi[x][y]);
					//$dumpvars(0, u_keccakf1600lanes.lanes_iota[x][y]);
					//$dumpvars(0, u_keccakf1600lanes.lanes_pre[x][y]);
				end
			end
			$dumpvars;
		end else begin
			$dumpfile("keccakf1600lanes_tb.vcd");
			$dumpvars;
		end
	end

endmodule
