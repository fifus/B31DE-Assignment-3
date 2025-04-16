// 16-bit switch input 2024

module AHBSW(
  input wire HCLK,
  input wire HRESETn,
  input wire [31:0] HADDR,
  input wire [1:0] HTRANS,
  input wire [31:0] HWDATA,
  input wire HWRITE,
  input wire HSEL,
  input wire HREADY,
  input wire [15:0] SWITCH,
  
	
	//Output
  output wire HREADYOUT,
  output wire [31:0] HRDATA
  );
  
  localparam [23:0] SWITCH_ADDR = 24'h00_0004;
  
  reg [15:0] switch_datain;
  reg [31:0] last_HADDR;
  reg [1:0] last_HTRANS;
  reg last_HWRITE;
  reg last_HSEL;
    
  assign HREADYOUT = 1'b1;
  
// Set Registers from address phase  
  always @(posedge HCLK)
  begin
    if(HREADY)
    begin
      last_HADDR <= HADDR;
      last_HTRANS <= HTRANS;
      last_HWRITE <= HWRITE;
      last_HSEL <= HSEL;
    end
  end
  
  
  // Update input value
  always @(posedge HCLK, negedge HRESETn)
  begin
    if(!HRESETn)
    begin
      switch_datain <= 16'h0000;
    end
    else 
    begin
      switch_datain <= SWITCH;
    end
      
  end
         
//  assign HRDATA[15:0] = switch_datain;  
    assign HRDATA = (last_HADDR[23:0] == SWITCH_ADDR) ? {16'h0000,switch_datain} : 32'hbada_bada;
endmodule
