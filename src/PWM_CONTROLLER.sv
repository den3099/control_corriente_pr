module PWM_CONTROLLER (

    input  logic clk,
    input  logic rst,

    // AXI4-Lite Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // AXI4-Lite Read Data Channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Salidas del puente H
    output logic pwm_AH,
    output logic pwm_AL,
    output logic pwm_BH,
    output logic pwm_BL

);

    // ------------------------------------------------
    // Señales internas AXI
    // ------------------------------------------------

    logic        wr_en;
    logic [7:0]  wr_addr;
    logic [31:0] wr_data;
    logic [3:0]  wr_strb;

    logic [7:0]  rd_addr;
    logic [31:0] rd_data;

    // ------------------------------------------------
    // Señales del banco de registros
    // ------------------------------------------------

    logic enable;
    logic [1:0] freq_sel;
    logic running;

    logic signed [15:0] duty_ref;

    // ------------------------------------------------
    // Señales del generador de frecuencia
    // ------------------------------------------------

    logic [13:0] carrier;
    logic [13:0] max_count;

    // ------------------------------------------------
    // Señales del modulador
    // ------------------------------------------------

    logic raw_pwm_A;
    logic raw_pwm_B;

    // ------------------------------------------------
    // AXI LITE INTERFACE
    // ------------------------------------------------

    AXI_LITE_INTERFACE AXI_INTERFACE (

        .clk(clk),
        .rst(rst),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_strb(wr_strb),

        .rd_addr(rd_addr),
        .rd_data(rd_data)

    );

    // ------------------------------------------------
    // PWM REGISTERS
    // ------------------------------------------------

    PWM_REGISTERS REGISTERS (

        .clk(clk),
        .rst(rst),

        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_strb(wr_strb),

        .rd_addr(rd_addr),
        .rd_data(rd_data),

        .enable(enable),
        .freq_sel(freq_sel),
        .running(running),
        .duty_ref(duty_ref)

    );

    // ------------------------------------------------
    // PWM FREQUENCY GENERATOR
    // ------------------------------------------------

    PWM_FREQUENCY_GENERATOR FREQUENCY_GENERATOR (

        .clk(clk),
        .rst(rst),
        .enable(running),
        .freq_sel(freq_sel),

        .carrier(carrier),
        .max_count(max_count)

    );

    // ------------------------------------------------
    // UNIPOLAR MODULATOR
    // ------------------------------------------------

    UNIPOLAR_MODULATOR MODULATOR (

        .enable(running),
        .duty_ref(duty_ref),
        .carrier(carrier),
        .max_count(max_count),

        .raw_pwm_A(raw_pwm_A),
        .raw_pwm_B(raw_pwm_B)

    );

    // ------------------------------------------------
    // DEAD TIME GENERATOR
    // ------------------------------------------------

    DEAD_TIME_GENERATOR #(

        .DEAD_TIME_CYCLES(50)

    ) DEAD_TIME (

        .clk(clk),
        .rst(rst),
        .enable(running),

        .raw_pwm_A(raw_pwm_A),
        .raw_pwm_B(raw_pwm_B),

        .pwm_AH(pwm_AH),
        .pwm_AL(pwm_AL),
        .pwm_BH(pwm_BH),
        .pwm_BL(pwm_BL)

    );

endmodule