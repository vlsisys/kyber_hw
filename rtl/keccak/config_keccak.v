// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: config_keccak.v
//	* Description	: 
// ==================================================
`define	BUS(bitwidth)	[((bitwidth)-1):0]

`define	MAX_IBYTES		1184
`define	MAX_OBYTES		784
`define	MAX_IB_CNT		$ceil	(`MAX_IBYTES*8/`BW_DATA )
`define	MAX_OB_CNT		$ceil	(`MAX_OBYTES*8/`BW_DATA )
`define	BLOCK_SIZE		168

`define	BW_DATA			64
`define	BW_KCCK			1600
`define	BW_IBLEN		$clog2	(`MAX_IBYTES            )
`define	BW_OBLEN		$clog2	(`MAX_OBYTES            )
`define	BW_IBCNT		$clog2	(`MAX_IBYTES*8/`BW_DATA )
`define	BW_OBCNT		$clog2	(`MAX_OBYTES*8/`BW_DATA )
`define	BW_BLOCK		$clog2	(`BLOCK_SIZE            )
