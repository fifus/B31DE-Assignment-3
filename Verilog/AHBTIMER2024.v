// simple 2024 version
// read only (at just one address. otherwise will return zero)
// increments at 50 MHz / 16 continually (3.125 MHz)
// resets to zero
// interrupts at counts of 65536 = 2^16 i.e. 47 Hz
// interrupt is held high for 16 HCLK cycles

module AHBTIMER (
    input wire HCLK,
    input wire HRESETn,
    input wire [31:0] HADDR,
    input wire [31:0] HWDATA,
    input wire [1:0] HTRANS,
    input wire HWRITE,
    input wire HSEL,
    input wire HREADY,

    output wire [31:0] HRDATA,
    output wire HREADYOUT,
    output reg timer_irq
);

    localparam [23:0] VALADDR = 24'h00_0000; // could change this address

    reg  last_HWRITE;
    reg  [31:0] last_HADDR;
    reg  last_HSEL;
    reg  [ 1:0] last_HTRANS;

    //internal registers
    reg  [31:0] value = 0;

    // Prescaled clock
    // Used only to update the timer value using the given control logic
    wire        clk16;

prescaler uprescaler16(
.inclk(HCLK),
.outclk(clk16)
);

    assign HREADYOUT = 1'b1;  //Always ready

    // address phase latch AHB-Lite signals
    always @(posedge HCLK)
        if (HREADY) begin
            last_HWRITE <= HWRITE;
            last_HSEL   <= HSEL;
            last_HADDR  <= HADDR;
            last_HTRANS <= HTRANS;
        end

    always @(posedge clk16)
        if (!HRESETn) 
          begin
            value <= 32'h0000_0000;
            timer_irq <= 1'b0;
          end
        else
        begin
            value <= value + 1;
            if (value[15:0] == 16'h0000) // defines frequency of interrupts
              timer_irq <= 1; else timer_irq <= 0;
         end 

// could be done in a number of different ways
// 8 MSBs of 32-bit address will have activated HSEL for this peripheral
// and will switch HRDATA output through MUX
// leaving 2^24 possible different addresses
// we will allow only one of these - VALADDR - to read counter value
// any other will return zero
    assign HRDATA = (last_HADDR[23:0] == VALADDR) ? value : 32'h0000_0000;
//assign HRDATA = value;
endmodule
