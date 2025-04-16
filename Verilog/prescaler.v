module prescaler #( parameter WIDTH = 4)(
    input  wire inclk,
    output wire outclk
);

    reg [WIDTH-1:0] counter;

    always @(posedge inclk) counter <= counter + 1'b1;

    assign outclk = counter[0];

endmodule
