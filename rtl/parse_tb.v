// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: parse_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		10		// # of Test Vector
`define FINISH		10000	// # of Test Vector
`define DEBUG

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"parse.v"

module parse_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[4*12-1:0]	o_coeffs       ;
	wire				o_coeffs_valid ;
	wire				o_done		   ;
	reg		[    63:0]	i_ibytes       ;
	reg					i_ibytes_valid ;
	reg					i_clk          ;
	reg					i_rstn         ;

	parse
	u_parse(
		.o_coeffs			(o_coeffs			),
		.o_coeffs_valid		(o_coeffs_valid		),
		.o_done				(o_done				),
		.i_ibytes			(i_ibytes			),
		.i_ibytes_valid		(i_ibytes_valid		),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

	always @(*) begin
		if (i_ibytes_valid) begin
			i_ibytes		= vi_ibytes[i][768*8-1-(64*u_parse.cnt_in)-:64];
		end else begin
			i_ibytes		= 0;
		end
	end
// --------------------------------------------------
//	Clock
// --------------------------------------------------
	always	#(500/`CLKFREQ)		i_clk = ~i_clk;

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[4*12-1:0]	vo_coeffs[0:`NVEC-1];
	reg		[768*8-1:0]	vi_ibytes[0:`NVEC-1];

	initial begin
		$readmemh("../vec/parse/o_coeffs.vec",			vo_coeffs       ) ;
		$readmemh("../vec/parse/i_ibytes.vec",			vi_ibytes       ) ;
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
			i_ibytes_valid		= 0;
			i_clk				= 1;
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
			@(posedge i_clk) begin
				i_ibytes_valid	= 1;
			end
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_coeffs != vo_coeffs[i]) begin $display("[Idx: %3d] Mismatched o_coeffs", i); end
			if (o_coeffs != vo_coeffs[i]) begin err++; end
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
		#(4000/`CLKFREQ);
		for (i=0; i<`SIMCYCLE; i++) begin
			vecInsert(i);
			@(negedge o_done) begin
				i_ibytes_valid	= 0;
				#(8000/`CLKFREQ);
				vecVerify(i);
			end
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
			$dumpvars(0, u_parse.d1[0]);
			$dumpvars(0, u_parse.d1[1]);
			$dumpvars(0, u_parse.d2[0]);
			$dumpvars(0, u_parse.d2[1]);
			$dumpvars(0, u_parse.d1_cond[0]);
			$dumpvars(0, u_parse.d1_cond[1]);
			$dumpvars(0, u_parse.d2_cond[0]);
			$dumpvars(0, u_parse.d2_cond[1]);
			for (i=0; i<256; i=i+1) begin
				$dumpvars(0, u_parse.coeffs[i]);
			end
			$dumpvars;
		end else begin
			$dumpfile("parse_tb.vcd");
			$dumpvars;
		end
		#(`FINISH*1000/`CLKFREQ)	$finish;
	end

endmodule
