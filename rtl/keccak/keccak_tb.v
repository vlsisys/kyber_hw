// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define BW_DATA		64*5*5	// Bitwidth of ~~
`define BW_CTRL		2		// Bitwidth of ~~
`define NVEC		100		// # of Test Vector
`define	DEBUG

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"keccak.v"

module keccak_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[63:0]			o_bytes;
	wire					o_bytes_valid;
	reg		[`BW_CTRL-1:0]	i_mode;
	reg		[63:0]			i_bytes;
	reg						i_bytes_valid;
	reg		[10:0]			i_ibyte_len;
	reg		[9:0]			i_obyte_len;
	reg						i_clk;
	reg						i_rstn;

	keccak
	#(
		.BW_DATA			(`BW_DATA			),
		.BW_CTRL			(`BW_CTRL			)
	)
	u_keccak(
		.o_bytes			(o_bytes			),
		.o_bytes_valid		(o_bytes_valid		),
		.i_mode				(i_mode				),
		.i_bytes			(i_bytes			),
		.i_bytes_valid		(i_bytes_valid		),
		.i_ibyte_len		(i_ibyte_len		),
		.i_obyte_len		(i_obyte_len		),
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
	reg		[784*8-1:0]		vo_bytes[0:`NVEC-1];
	reg		[1184*8-1:0]	vi_bytes[0:`NVEC-1];
	reg		[1:0]			vi_mode[0:`NVEC-1];
	reg		[10:0]			vi_ibyte_len[0:`NVEC-1];
	reg		[9:0]			vi_obyte_len[0:`NVEC-1];

	initial begin
		$readmemb("../../vec/keccak/o_bytes.vec",		vo_bytes);
		$readmemb("../../vec/keccak/i_bytes.vec",		vi_bytes);
		$readmemb("../../vec/keccak/i_mode.vec",		vi_mode);
		$readmemb("../../vec/keccak/i_ibyte_len.vec",	vi_ibyte_len);
		$readmemb("../../vec/keccak/i_obyte_len.vec",	vi_obyte_len);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_mode				= 0;
			i_bytes				= 0;
			i_bytes_valid		= 0;
			i_ibyte_len			= 0;
			i_obyte_len			= 0;
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
			i_mode				= vi_mode[i];
			i_bytes				= vi_bytes[i][vi_ibyte_len[i]*8-1-:64];
			i_ibyte_len			= vi_ibyte_len[i];
			i_obyte_len			= vi_obyte_len[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (	o_bytes	!= vo_bytes[i])  begin $display("[Idx: %3d] Mismatched o_bytes", i); end
			if ((	o_bytes != vo_bytes[i])) begin err++; end
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
			i_bytes_valid	= 1;
			wait (o_bytes_valid) begin
				vecVerify(i);
				i_bytes_valid	= 0;
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
			$dumpvars;
		end else begin
			$dumpfile("keccak_tb.vcd");
			$dumpvars;
		end
	end

endmodule
