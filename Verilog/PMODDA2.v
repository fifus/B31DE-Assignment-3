module AHBDA2(
  input wire HCLK,
  input wire HRESETn,
  input wire [31:0] HADDR,
  input wire [1:0] HTRANS,
  input wire [31:0] HWDATA,
  input wire HWRITE,
  input wire HSEL,
  input wire HREADY, 
	
	//Output
  output wire HREADYOUT,
  output wire [31:0] HRDATA,
  
  //DA2 signals
  output wire DA2_cs,         // also referred to as clock select		
  output wire DA2_channelA,
  output wire DA2_channelB,		// not used, but here for expansion
  output wire DA2_SCLK
  );

  //AHB-Lite registers
  reg [31:0] last_HADDR;
  reg [1:0] last_HTRANS;
  reg last_HWRITE;
  reg last_HSEL;
  
  //Internal Registers
  reg [11:0] rSample; 
  reg [4:0]	rCounter;
  
  reg rDA2_cs;
  reg rDA2_channelA;
  reg rDA2_channelB;
  
  localparam [23:0] DA2_SAMPLE = 23'h00_0000;
 
  assign HREADYOUT = 1'b1;
  
  wire pCLK; 
   
  // prescale system clock to clk/2, as dac module only works up to 30MHz
  prescaler uprescaler2(
	.inclk(HCLK),
	.outclk(pCLK)
  );
  
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
  
  // AHB write sequence for DA2 sample register
  always @(posedge HCLK, negedge HRESETn)
  begin
	if(!HRESETn)
		rSample <= 12'b00;
	else if(last_HWRITE & last_HSEL & last_HTRANS[1])
		if(last_HADDR[23:0] == DA2_SAMPLE)
			rSample <= HWDATA;
  end
  
  // write sequence begins by pulling sync HIGH
  // write sequence ends after 16 sCLK edges (sync remains low) 
  // starts with most significant bit and ends with least
  // write sequence is ended by bringing sync HIGH
  // use counter to keep track of clk cycle, should reset after 16 counts (5'b100000)
  // first two bits can be anything, next two bits should be 0 for normal operation
  always@(posedge pCLK) begin
	if (rCounter == 5'b00000)
		rDA2_cs <= 1'b0;  // pull clock select line low to start write sequence
	case(rCounter)
	// Assign channelA equal to each bit of sample register, starting with MSB
		5'b00: 		rDA2_channelA <= 1'b0;
		5'b01: 		rDA2_channelA <= 1'b0;
		5'b10: 		rDA2_channelA <= 1'b0;
		5'b11: 		rDA2_channelA <= 1'b0;
		5'b100: 	rDA2_channelA <= rSample[11];
		5'b101: 	rDA2_channelA <= rSample[10];
		5'b110: 	rDA2_channelA <= rSample[9];
		5'b111: 	rDA2_channelA <= rSample[8];
		5'b1000: 	rDA2_channelA <= rSample[7];
		5'b1001: 	rDA2_channelA <= rSample[6];
		5'b1010: 	rDA2_channelA <= rSample[5];
		5'b1011: 	rDA2_channelA <= rSample[4];
		5'b1100: 	rDA2_channelA <= rSample[3];
		5'b1101: 	rDA2_channelA <= rSample[2];
		5'b1110: 	rDA2_channelA <= rSample[1];
		5'b1111: 	rDA2_channelA <= rSample[0];
	endcase
	
	if(rCounter == 5'b10000)
	begin	
	   // pull clock select high to signal end of transfer
		rDA2_cs <= 1'b1;
		// reset counter for next sample
		rCounter <= 5'b00;
	end
	rCounter <= rCounter + 1;
   end
  
  // allow contents of sample address to be read       
  assign HRDATA = (last_HADDR[23:0] == DA2_SAMPLE) ? {16'h0000,rSample} : 32'h0000;
  // Assign output wires equal to contents of corresponding internal registers 
  assign DA2_cs = rDA2_cs;
  assign DA2_channelA = rDA2_channelA;
  assign DA2_channelB = rDA2_channelB;
  assign DA2_SCLK = pCLK;

endmodule
