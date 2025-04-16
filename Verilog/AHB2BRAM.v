//  --========================================================================--
//  Version and Release Control Information:
//
//  File Name           : AHB2BRAM.v
//  File Revision       : 1.60
//
//  ----------------------------------------------------------------------------
//  Purpose             : Basic AHBLITE Internal Memory Default Size = 16KB
//                        
//  --========================================================================--
module AHB2MEM
#(parameter MEMWIDTH = 14)					// SIZE[Bytes] = 2 ^ MEMWIDTH[Bytes] = 2 ^ MEMWIDTH / 4[Entries]
  (
  //AHBLITE INTERFACE
  //Subordinate Select Signals
  input wire HSEL,
  //Global Signal
  input wire HCLK,
  input wire HRESETn,
  //Address, Control & Write Data
  input wire HREADY,
  input wire [31:0] HADDR,
  input wire [1:0] HTRANS,
  input wire HWRITE,
  input wire [2:0] HSIZE,
  
  input wire [31:0] HWDATA,
  // Transfer Response & Read Data
  output wire HREADYOUT,
  output reg [31:0] HRDATA
  );

  assign HREADYOUT = 1'b1; // Always ready

  // Memory Array
  reg [31:0] memory[0:(2**(MEMWIDTH-2)-1)];

//  initial
//  begin
//    $readmemh("code.hex", memory);
//  end
  
  // Registers to store Adress Phase Signals
  reg APhase_HSEL;
  reg APhase_HWRITE;
  reg [31:0] APhase_HADDR;

  // Sample the Address Phase   
  always @(posedge HCLK or negedge HRESETn)
  begin
    if(!HRESETn)
    begin
      APhase_HSEL <= 1'b0;
      APhase_HWRITE <= 1'b0;
      APhase_HADDR <= 32'h0;
    end
    else if(HREADY)
    begin
      APhase_HSEL <= HSEL;
      APhase_HWRITE <= HWRITE;
      APhase_HADDR <= HADDR;
    end
  end

  always @ (posedge HCLK)
  begin
    if(APhase_HSEL & APhase_HWRITE)
        memory[APhase_HADDR[MEMWIDTH:2]] <= HWDATA;
        
    HRDATA <= memory[HADDR[MEMWIDTH:2]];
  end

endmodule
