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
`define NVEC		1		// # of Test Vector
`define	DEBUG

// --------------------------------------------------
//	Infomation
// --------------------------------------------------
//	Maximum InputBytes		: 1184 B
//	Maximum InputBlock		:  168 B
//	Cycles for InputBlock	:  168 B / 64 b = 21 Cycles

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"keccak.v"

module keccak_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[63:0]			o_obytes;
	wire					o_obytes_valid;
	wire					o_ibytes_ready;
	reg		[`BW_CTRL-1:0]	i_mode;
	reg		[63:0]			i_ibytes;
	reg						i_ibytes_valid;
	reg		[10:0]			i_ibyte_len;
	reg		[9:0]			i_obyte_len;
	reg						i_clk;
	reg						i_rstn;
	reg		[7:0]			cnt_ibytes;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_ibytes	<= 0;
		end else begin
			if ((i_ibytes_valid && o_ibytes_ready) && (i_ibyte_len / 8 - 1 > cnt_ibytes) ) begin
				cnt_ibytes	<= cnt_ibytes + 1;
			end else begin
				if (o_obytes_valid) begin
					cnt_ibytes	<= 0;
				end else begin
					cnt_ibytes	<= cnt_ibytes;
				end
			end
		end
	end

	always @(*) i_ibytes	= vi_ibytes[i][vi_ibyte_len[i]*8-1-(64*cnt_ibytes)-:64];

	keccak
	#(
		.BW_DATA			(`BW_DATA			),
		.BW_CTRL			(`BW_CTRL			)
	)
	u_keccak(
		.o_obytes			(o_obytes			),
		.o_obytes_valid		(o_obytes_valid		),
		.o_ibytes_ready		(o_ibytes_ready		),
		.i_mode				(i_mode				),
		.i_ibytes			(i_ibytes			),
		.i_ibytes_valid		(i_ibytes_valid		),
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
	reg		[784*8-1:0]		vo_obytes[0:`NVEC-1];
	reg		[1184*8-1:0]	vi_ibytes[0:`NVEC-1];
	reg		[1:0]			vi_mode[0:`NVEC-1];
	reg		[10:0]			vi_ibyte_len[0:`NVEC-1];
	reg		[9:0]			vi_obyte_len[0:`NVEC-1];

	initial begin
		$readmemh("../../vec/keccak/o_obytes.vec",		vo_obytes);
		$readmemh("../../vec/keccak/i_ibytes.vec",		vi_ibytes);
		$readmemh("../../vec/keccak/i_mode.vec",		vi_mode);
		$readmemh("../../vec/keccak/i_ibyte_len.vec",	vi_ibyte_len);
		$readmemh("../../vec/keccak/i_obyte_len.vec",	vi_obyte_len);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_mode			= 0;
			i_ibytes		= 0;
			i_ibytes_valid	= 0;
			i_ibyte_len		= 0;
			i_obyte_len		= 0;
			i_clk			= 1;
			i_rstn			= 0;
			cnt_ibytes		= 0;
		end
	endtask

	task resetNCycle;
		input	[9:0]	i;
		begin
			taskState	= "Reset";
			i_rstn		= 1'b0;
			#(i*1000/`CLKFREQ);
			i_rstn		= 1'b1;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			i_mode			= vi_mode[i];
			i_ibyte_len		= vi_ibyte_len[i];
			i_obyte_len		= vi_obyte_len[i];
			i_ibytes_valid	= 1;
			while (i_ibytes_valid && o_ibytes_ready) begin
				@ (posedge i_clk) begin
					i_ibytes		= vi_ibytes[i][vi_ibyte_len[i]*8-1-(64*cnt_ibytes)-:64];
				end
			end
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			cnt_ibytes		= 0;
			#(0.1*1000/`CLKFREQ);
			if (	o_obytes	!= vo_obytes[i])  begin $display("[Idx: %3d] Mismatched o_obytes", i); end
			if ((	o_obytes	!= vo_obytes[i])) begin err++; end
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
			@ (negedge o_obytes_valid) begin
				vecVerify(i);
				i_ibytes_valid	= 0;
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
