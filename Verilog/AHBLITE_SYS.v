// 2024 version of Cameron's simple system
module AHBLITE_SYS (
    // On board oscillator is 100MHz
    input wire clk,  // Note that system clocks fclk and HCLK will be half of this 50MHz

    // Switches
    input wire [15:0] sw,

    // LEDS
    output wire [15:0] led,

    // 7 segment display
    output wire [6:0] seg,
    output wire dp,  // Decimal point
    output wire [3:0] an,  // Digit select
    
    // DA2
    //output wire sync,

    // Buttons
    input wire btnC,
    input wire btnU,
    input wire btnL,
    input wire btnR,  // Mapped to !reset_n
    input wire btnD,

    // PMOD GPIO
    // DEBUG
    output wire TDO,  // SWV     / JTAG TDO
    input  wire TCK,  // SWD Clk / JTAG TCK
    inout  wire TMS,  // SWD I/O / JTAG TMS
    input  wire TDI,  // JTAG TDI

    // PMOD PORTS
    inout wire [7:0] JA,  // Top left
    inout wire [7:0] JB,  // Top right
    inout wire [7:0] JC,  // Bottom right
    inout wire [7:0] JXADC, // Bottom left - built in Analogue to Digital converter

    // VGA
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire       Hsync,     // VGA Horizontal Sync
    output wire       Vsync,     // VGA Vertical Sync

    // USB RS232 (Type Micro-B)
    input  wire RsRx,  // Receive
    output wire RsTx,  // Transmit

    // USB HID (Type A)
    inout wire PS2Clk,
    inout wire PS2Data,

    // QSPI flash
    inout wire [3:0] QspiDB,
    inout wire QspiCSn
);

    // Clock
    wire fclk;  // Free running clock

    // Clock divider, divide the frequency by two, hence less time constraint.
    // 100MHz --> 50MHz
    reg  clk_div;
    always @(posedge clk) begin
        clk_div = ~clk_div;
    end

    // Instantiating the clock buffer primative
    // By doing this the clock signal will be implemented on dedicated pathways on the FPGA to ensure good clock properties
    // Clock signals are high fanout (the signal is used by many different modules) and thus we want it to be low skew (the timing of the clock is not changed across the fpga)
    BUFG BUFG_CLK (
        .O(fclk),
        .I(clk_div)
    );

    // Reset (pressing the right button resets the system)
    wire reset_n = !btnR;

    // Subordinate select signals
    wire    [ 3:0] mux_sel;
    wire    hsel_mem;
 // wire    hsel_vga;
    wire    hsel_timer;
    wire    hsel_switch;
    wire    hsel_7seg;
    wire    hsel_r2r;
 // wire    hsel_led;
    wire    hsel_da2;

    // Subordinate read data
    wire    [31:0] hrdata_mem;
  //  wire  [31:0] hrdata_vga;
    wire    [31:0] hrdata_timer;
    wire    [31:0] hrdata_switch;
    wire    [31:0] hrdata_7seg;
    wire    [31:0] hrdata_r2r;
//    wire  [31:0] hrdata_led;
    wire    [31:0] hrdata_da2;

    // Subordinate hready
    wire    hready_mem;
    //wire  hready_vga;
    wire    hready_timer;
    wire    hready_switch;
    wire    hready_7seg;
    wire    hready_r2r;
  //  wire  hready_led;
    wire    hready_da2;

    // Interrupt signals
//    wire                         uart_irq;
    wire    timer_irq;
    assign irq = {31'b0, timer_irq};

    // CPU System Bus
    wire    [31:0] haddrs;
    wire    [2:0] hbursts;
    wire    hmastlocks;
    wire    [3:0] hprots;
    wire    [2:0] hsizes;
    wire    [1:0] htranss;
    wire    [31:0] hwdatas;
    wire    hwrites;
    wire    [31:0] hrdatas;
    wire    hreadys;
    wire    [1:0] hresps = 2'b00;  // System generates no error response
    wire    exresps = 1'b0;

    // Debug signals (TDO pin is used for SWV unless JTAG mode is active)
    wire dbg_tdo;  // SWV / JTAG TDO
    wire dbg_tdo_nen;  // SWV / JTAG TDO tristate enable (active low)
    wire dbg_swdo;  // SWD I/O 3-state output
    wire dbg_swdo_en;  // SWD I/O 3-state enable
    wire dbg_jtag_nsw;  // SWD in JTAG state (HIGH)
    wire dbg_swo;  // Serial wire viewer/output
    wire tdo_enable = !dbg_tdo_nen | !dbg_jtag_nsw;
    wire tdo_tms = dbg_jtag_nsw ? dbg_tdo : dbg_swo;
    assign TMS = dbg_swdo_en ? dbg_swdo : 1'bz;
    assign TDO = tdo_enable ? tdo_tms : 1'bz;


    // ABH-Lite Address Logic

    // AHB-Lite Address Decoder 
   AHBDCD uAHBDCD (
        .HADDR(haddrs),

        .HSEL_S0(hsel_mem),     // 0x00000000
        .HSEL_S1(hsel_vga),
        .HSEL_S2(hsel_timer),   // 0x51000000
        .HSEL_S3(hsel_switch),    // 0x52000000
        .HSEL_S4(hsel_7seg),    // 0x53000000
        .HSEL_S5(hsel_da2),     // 0x54000000
        .HSEL_S6(),
        .HSEL_S7(),
        .HSEL_S8(),
        .HSEL_S9(),
        .HSEL_NOMAP(),

        .MUX_SEL(mux_sel[3:0])
    );

    // Subordinate to Master Mulitplexor
    AHBMUX uAHBMUX (
        .HCLK(fclk),
        .HRESETn(hresetn),
        .MUX_SEL(mux_sel[3:0]),

        .HRDATA_S0(hrdata_mem),
        .HRDATA_S1(hrdata_vga),
        .HRDATA_S2(hrdata_timer),
        .HRDATA_S3(hrdata_switch),
        .HRDATA_S4(hrdata_7seg),
        .HRDATA_S5(hrdata_da2),
        .HRDATA_S6(),
        .HRDATA_S7(),
        .HRDATA_S8(),
        .HRDATA_S9(),
        .HRDATA_NOMAP(32'hDEADBEEF),

        .HREADYOUT_S0(hready_mem),
        .HREADYOUT_S1(hready_vga),
        .HREADYOUT_S2(hready_timer),
        .HREADYOUT_S3(hready_switch),
        .HREADYOUT_S4(hready_7seg),
        .HREADYOUT_S5(hready_da2),
        .HREADYOUT_S6(1'b1),
        .HREADYOUT_S7(1'b1),
        .HREADYOUT_S8(1'b1),
        .HREADYOUT_S9(1'b1),
        .HREADYOUT_NOMAP(1'b1),

        .HRDATA(hrdatas),
        .HREADY(hreadys)
    );

    // AHB-Lite Peripherals

    // AHB-Lite Block RAM 64KB // check size !!
    // 0x0000_0000 to 0x00FF_FFFF
    AHB2MEM uAHB2RAM (
        //AHBLITE Signals
        .HSEL(hsel_mem),
        .HCLK(fclk),
        .HRESETn(hresetn),
        .HREADY(hreadys),
        .HADDR(haddrs),
        .HTRANS(htranss),
        .HWRITE(hwrites),
        .HSIZE(hsizes),
        .HWDATA(hwdatas),
        .HRDATA(hrdata_mem),
        .HREADYOUT(hready_mem)
    );

    // AHB-Lite VGA Controller
    // 0x5000_0000 to 0x50FF_FFFF
    //AHBVGA uAHBVGA (
      //  .HCLK(fclk),
      //  .HRESETn(hresetn),
      //  .HADDR(haddrs),
      //  .HWDATA(hwdatas),
      //  .HREADY(hreadys),
      //  .HWRITE(hwrites),
      //  .HTRANS(htranss),
      //  .HSEL(hsel_vga),
      //  .HRDATA(hrdata_vga),
      //  .HREADYOUT(hready_vga),

        // VGA Pins
      //  .hsync(Hsync),
      //  .vsync(Vsync),
      //  .rgb  ({vgaRed, vgaGreen, vgaBlue})
//    );

    // AHB-Lite Timer
    // 0x5100_0000 to 0x51FF_FFFF
    AHBTIMER uAHBTIMER (
        .HCLK(fclk),
        .HRESETn(hresetn),
        .HADDR(haddrs),
        .HTRANS(htranss),
        .HWDATA(hwdatas),
        .HWRITE(hwrites),
        .HREADY(hreadys),
        .HREADYOUT(hready_timer),
        .HRDATA(hrdata_timer),
        .HSEL(hsel_timer),

        .timer_irq(timer_irq)  // Timer interrupt request
    );


    // AHB-Lite switch
    // 0x5200_0000 to 0x52FF_FFFF
    AHBSW uAHBSW (
        .HCLK(fclk),
        .HRESETn(hresetn),
        .HADDR(haddrs),
        .HWRITE(hwrites),
        .HWDATA(hwdatas),
        .HTRANS(htranss),
        .HSEL(hsel_switch),
        .HREADY(hreadys),
        .HREADYOUT(hready_switch),
        .HRDATA(hrdata_switch),

        // switch (input) pins
        .SWITCH(sw)
    );

    // AHB-Lite 7-Segment Display
    // 0x5300_0000 to 0x53FF_FFFF
    AHB7SEGDEC uAHB7SEGDEC (
        .HCLK(fclk),
        .HRESETn(hresetn),
        .HADDR(haddrs),
        .HTRANS(htranss),
        .HWDATA(hwdatas),
        .HWRITE(hwrites),
        .HREADY(hreadys),
        .HREADYOUT(hready_7seg),
        .HRDATA(hrdata_7seg),
        .HSEL(hsel_7seg),

        .seg(seg),  // Digits segments
        .an (an),   // Digit select
        .dp (dp)    // Decimal point
    );

//    // AHB-Lite r2r
//    // 0x5400_0000 to 0x54FF_FFFF
//    AHBR2R uAHBR2R (
//        .HCLK(fclk),
//        .HRESETn(hresetn),
//        .HADDR(haddrs),
//        .HWRITE(hwrites),
//        .HWDATA(hwdatas),
//        .HTRANS(htranss),
//        .HSEL(hsel_r2r),
//        .HREADY(hreadys),
//        .HREADYOUT(hready_r2r),
//        .HRDATA(hrdata_r2r),

//        .R2R(JA)
//    );


    // AHB-Lite LED
    // 0x5500_0000 to 0x55FF_FFFF
   // AHBLED uAHBLED (
     //   .HCLK(fclk),
     //   .HRESETn(hresetn),
     //   .HADDR(haddrs),
     //   .HWRITE(hwrites),
     //   .HWDATA(hwdatas),
     //   .HTRANS(htranss),
     //   .HSEL(hsel_led),
     //   .HREADY(hreadys),
     //   .HREADYOUT(hready_led),
     //   .HRDATA(hrdata_led),

     //   .LED(led)
    //);
    
    AHBDA2 uPMODDA2 (
        .HCLK(fclk),
        .HRESETn(hresetn),
        .HADDR(haddrs),
        .HWRITE(hwrites),
        .HWDATA(hwdatas),
        .HTRANS(htranss),
        .HSEL(hsel_da2),
        .HREADY(hreadys),
        .HREADYOUT(hready_da2),
        .HRDATA(hrdata_da2),
        
        .DA2_cs(JA[0]),
        .DA2_channelA(JA[1]),
        .DA2_channelB(JA[2]),
        .DA2_SCLK(JA[3])
    );


    // CORTEX-M0 integration

    // CoreSight requires a loopback from REQ to ACK for a minimal
    // debug power control implementation
    wire cpu0cdbgpwrupreq;
    wire cpu0cdbgpwrupack;
    assign cpu0cdbgpwrupack = cpu0cdbgpwrupreq;

    // CM-DS Sideband signals
    wire lockup;
    wire lockup_reset_req;
    wire sys_reset_req;
    wire txev;
    wire sleeping;

    // Reset synchronizer
    reg [4:0] reset_sync_reg;
    always @(posedge fclk or negedge reset_n) begin
        if (!reset_n) reset_sync_reg <= 5'b00000;
        else begin
            reset_sync_reg[3:0] <= {reset_sync_reg[2:0], 1'b1};
            reset_sync_reg[4]   <= reset_sync_reg[2] & (~sys_reset_req);
        end
    end

    assign hresetn = reset_sync_reg[4];

    // DesignStart simplified integration level
    CORTEXM0INTEGRATION u_CORTEXM0INTEGRATION (
        // CLOCK AND RESETS
        .FCLK     (fclk),               // Free running clock
        .SCLK     (fclk),               // System clock
        .HCLK     (fclk),               // AHB clock
        .DCLK     (fclk),               // Debug system clock
        .PORESETn (reset_sync_reg[2]),  // Power on reset
        .DBGRESETn(reset_sync_reg[3]),  // Debug reset
        .HRESETn  (hresetn),            // AHB and System reset

        // AHB-LITE MASTER PORT
        .HADDR    (haddrs),
        .HBURST   (hbursts),
        .HMASTLOCK(hmastlocks),
        .HPROT    (hprots),
        .HSIZE    (hsizes),
        .HTRANS   (htranss),
        .HWDATA   (hwdatas),
        .HWRITE   (hwrites),
        .HRDATA   (hrdatas),
        .HREADY   (hreadys),
        .HRESP    (hresps),
        .HMASTER  (),

        // CODE SEQUENTIALITY AND SPECULATION
        .CODENSEQ  (),
        .CODEHINTDE(),
        .SPECHTRANS(),

        // DEBUG
        .nTRST(1'b1),
        .SWCLKTCK(TCK),
        .SWDITMS(TMS),
        .TDI(TDI),
        .SWDO(dbg_swdo),
        .SWDOEN(dbg_swdo_en),
        .TDO(dbg_tdo),
        .nTDOEN(dbg_tdo_nen),
        .DBGRESTART    (1'b0),               // Debug Restart request - Not needed in a single CPU system
        .DBGRESTARTED(),
        .EDBGRQ(1'b0),  // External Debug request to CPU
        .HALTED(),

        // MISC
        .NMI(1'b0),  // Non-maskable interrupt input
        .IRQ(irq),  // Interrupt request inputs
        .TXEV(),  // Event output (SEV executed)
        .RXEV(1'b0),  // Event input
        .LOCKUP(lockup),  // Core is locked-up
        .SYSRESETREQ(sys_reset_req),  // System reset request
        .STCALIB({
            1'b1,  // No alternative clock source
            1'b0,  // Exact multiple of 10ms from FCLK
            24'h007A11F
        }),  // Calibration value for SysTick for 50 MHz source
        .STCLKEN(1'b0),  // SysTick SCLK clock disable
        .IRQLATENCY(8'h00),
        .ECOREVNUM(28'h0),

        // POWER MANAGEMENT
        .GATEHCLK(),  // When high, HCLK can be turned off
        .SLEEPING(),  // Core and NVIC sleeping
        .SLEEPDEEP(),  // The processor is in deep sleep mode
        .WAKEUP        (),                   // Active HIGH signal from WIC to the PMU that indicates a wake-up event has
                                             // occurred and the system requires clocks and power
        .WICSENSE(),
        .SLEEPHOLDREQn(1'b1),  // Extend Sleep request
        .SLEEPHOLDACKn(),  // Acknowledge for SLEEPHOLDREQn
        .WICENREQ      (1'b0),               // Active HIGH request for deep sleep to be WIC-based deep sleep
        .WICENACK      (),                   // Acknowledge for WICENREQ - WIC operation deep sleep mode
        .CDBGPWRUPREQ(cpu0cdbgpwrupreq),  // Debug Power Domain up request
        .CDBGPWRUPACK(cpu0cdbgpwrupack),  // Debug Power Domain up acknowledge.

        // SCAN IO
        .SE(1'b0),  // DFT is tied off in this example
        .RSTBYPASS     (1'b0)                // Reset bypass - active high to disable internal generated reset for testing
    );

endmodule
