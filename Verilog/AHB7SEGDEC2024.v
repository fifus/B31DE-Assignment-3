// 2024 version

module AHB7SEGDEC(

// standard AHB-Lite bus input signals

    input wire HCLK,
    input wire HRESETn,
    input wire [31:0] HADDR,
    input wire [31:0] HWDATA,
    input wire [1:0] HTRANS,
    input wire HWRITE,
    input wire HSEL,
    input wire HREADY,

// standard AHB-Lite bus output signals
    output wire [31:0] HRDATA,
    output wire HREADYOUT,

// output signals to drive 4-digit 7-segment and decimal point display
// seg and dp outputs connected to cathodes on all four digits
// active low will light segment or decimal point only if digit anode is enabled
    output wire [6:0] seg,  // active low to light individual segments (applies to all digits)
    output wire [3:0] an,   // active low 'one-cold' to enable individual digit
    output wire dp          // active low to light decimal point (applies to all digits)
);

// addresses of memory-mapped registers holding hex values to be displayed on each digit
// these are byte addresses of consecutive 32-bit words
// digit 1 is leftmost
    localparam [3:0] DIGIT1_ADDR = 4'h0;
    localparam [3:0] DIGIT2_ADDR = 4'h4;
    localparam [3:0] DIGIT3_ADDR = 4'h8;
    localparam [3:0] DIGIT4_ADDR = 4'hC;
 
    localparam [31:0] REFRESH_PRESCALE = 49999; // 50000 prescale value -> 250Hz refresh rate of entire
// four digit display

// segment patterns to display 16 different hex values on 7-segment digit displays
// when output on seg
// active low bits light segment
    localparam [6:0] SEVEN_SEG_0 = 7'b1000000;
    localparam [6:0] SEVEN_SEG_1 = 7'b1111001;
    localparam [6:0] SEVEN_SEG_2 = 7'b0100100;
    localparam [6:0] SEVEN_SEG_3 = 7'b0110000;
    localparam [6:0] SEVEN_SEG_4 = 7'b0011001;
    localparam [6:0] SEVEN_SEG_5 = 7'b0010010;
    localparam [6:0] SEVEN_SEG_6 = 7'b0000010;
    localparam [6:0] SEVEN_SEG_7 = 7'b1111000;
    localparam [6:0] SEVEN_SEG_8 = 7'b0000000;
    localparam [6:0] SEVEN_SEG_9 = 7'b0010000;
    localparam [6:0] SEVEN_SEG_A = 7'b0001000;
    localparam [6:0] SEVEN_SEG_B = 7'b0000011;
    localparam [6:0] SEVEN_SEG_C = 7'b0100111;
    localparam [6:0] SEVEN_SEG_D = 7'b0100001;
    localparam [6:0] SEVEN_SEG_E = 7'b0000110;
    localparam [6:0] SEVEN_SEG_F = 7'b0001110;


// registers to hold AHB-Lite values sampled during address phase
    reg last_HWRITE;
    reg [31:0] last_HADDR;
    reg last_HSEL;
    reg [1:0] last_HTRANS;

// registers to hold hex values to be displayed
// initialised to values 0, 1, 2, 3 for debugging purposes
    reg [3:0] DIGIT1 = 4'h0;
    reg [3:0] DIGIT2 = 4'h1;
    reg [3:0] DIGIT3 = 4'h2;
    reg [3:0] DIGIT4 = 4'h3;

    assign HREADYOUT = 1'b1;  // AHB-Lite bus output always ready
    assign dp = 1'b1;         // decimal point never lit in this implementation
    reg  [31:0] counter;
// 4-bit 'one-cold' anode value is output to 7-segment display to enable one digit
// and is used to select one of four digit values to be displayed
// via multiplexer
   reg  [ 3:0] anode = 4'b0111;

    wire [3:0] hex_digit_value;
    assign an  = anode;



// standard AHB-Lite bus address phase samples bus input values  

    always @(posedge HCLK)
        if (HREADY) begin
            last_HWRITE <= HWRITE;
            last_HSEL   <= HSEL;
            last_HADDR  <= HADDR;
            last_HTRANS <= HTRANS;
        end
// standard AHB-Lite bus data phase potentially writes values from HWDATA input to
// hex digit registers
// each of these registers has an address that is decoded
// and contains a 4-bit hex value read from the 4 LSBs of the 32-bit HWDATA input

    always @(posedge HCLK, negedge HRESETn) begin

// on reset, hex digit values are initialised to A, B, C, D
        if (!HRESETn) begin
            DIGIT1 <= 4'h1;
            DIGIT2 <= 4'h5;
            DIGIT3 <= 4'h6;
            DIGIT4 <= 4'hf;
        end else if (last_HWRITE & last_HSEL & last_HTRANS[1]) begin
                 if (last_HADDR[3:0] == DIGIT1_ADDR) DIGIT1 <= HWDATA[3:0];
            else if (last_HADDR[3:0] == DIGIT2_ADDR) DIGIT2 <= HWDATA[3:0];
            else if (last_HADDR[3:0] == DIGIT3_ADDR) DIGIT3 <= HWDATA[3:0];
            else if (last_HADDR[3:0] == DIGIT4_ADDR) DIGIT4 <= HWDATA[3:0];
        end
    end

    assign HRDATA = (last_HADDR[3:0] == DIGIT1_ADDR) ? {28'h000_0000,DIGIT1} :
                  (last_HADDR[3:0] == DIGIT2_ADDR) ? {28'h000_0000,DIGIT2} :
                  (last_HADDR[3:0] == DIGIT3_ADDR) ? {28'h000_0000,DIGIT3} :
                  (last_HADDR[3:0] == DIGIT4_ADDR) ? {28'h000_0000,DIGIT4} :
                   32'h0000_0000;


// increment counter on HCLK positive edge
// if it reaches refressh prescale value, reset to zero and rotate anode regiter contents left
// to select next digit
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) counter <= 32'h0000_0000;
        else  if (counter == REFRESH_PRESCALE) 
           begin
             counter <= 0;
             anode <= {anode[2:0],anode[3]};
           end else 
         counter <= counter + 1'b1;
    end

// multiplexer    

    assign hex_digit_value =
	(anode == 4'b0111) ? DIGIT1[3:0] :
	(anode == 4'b1110) ? DIGIT4[3:0] :
	(anode == 4'b1101) ? DIGIT3[3:0] :
	(anode == 4'b1011) ? DIGIT2[3:0] :
		4'b1111;

 // another multiplexer effectively decodes

// hex digit value to pattern of segments in display

    assign seg =
    (hex_digit_value[3:0] == 4'h0) ? SEVEN_SEG_0 :
    (hex_digit_value[3:0] == 4'h1) ? SEVEN_SEG_1 :
    (hex_digit_value[3:0] == 4'h2) ? SEVEN_SEG_2 :
    (hex_digit_value[3:0] == 4'h3) ? SEVEN_SEG_3 :
    (hex_digit_value[3:0] == 4'h4) ? SEVEN_SEG_4 :
    (hex_digit_value[3:0] == 4'h5) ? SEVEN_SEG_5 :
    (hex_digit_value[3:0] == 4'h6) ? SEVEN_SEG_6 :
    (hex_digit_value[3:0] == 4'h7) ? SEVEN_SEG_7 :
    (hex_digit_value[3:0] == 4'h8) ? SEVEN_SEG_8 :
    (hex_digit_value[3:0] == 4'h9) ? SEVEN_SEG_9 :
    (hex_digit_value[3:0] == 4'hA) ? SEVEN_SEG_A :
    (hex_digit_value[3:0] == 4'hB) ? SEVEN_SEG_B :
    (hex_digit_value[3:0] == 4'hC) ? SEVEN_SEG_C :
    (hex_digit_value[3:0] == 4'hD) ? SEVEN_SEG_D :
    (hex_digit_value[3:0] == 4'hE) ? SEVEN_SEG_E :
    (hex_digit_value[3:0] == 4'hF) ? SEVEN_SEG_F :
        7'b111_1111;

endmodule
