module mux_lectura (
    input  logic        clk,
    input  logic        rst,

    // Seleccion desde traductor_direcciones
    input  logic [2:0]  rd_sel,
    input  logic        rd_busy,

    // Lado maestro
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Perifericos
    output logic [31:0] s_gpio_araddr,
    output logic        s_gpio_arvalid,
    input  logic        s_gpio_arready,
    input  logic [31:0] s_gpio_rdata,
    input  logic [1:0]  s_gpio_rresp,
    input  logic        s_gpio_rvalid,
    output logic        s_gpio_rready,

    output logic [31:0] s_uart_araddr,
    output logic        s_uart_arvalid,
    input  logic        s_uart_arready,
    input  logic [31:0] s_uart_rdata,
    input  logic [1:0]  s_uart_rresp,
    input  logic        s_uart_rvalid,
    output logic        s_uart_rready,

    output logic [31:0] s_adc_araddr,
    output logic        s_adc_arvalid,
    input  logic        s_adc_arready,
    input  logic [31:0] s_adc_rdata,
    input  logic [1:0]  s_adc_rresp,
    input  logic        s_adc_rvalid,
    output logic        s_adc_rready,

    output logic [31:0] s_pwm_araddr,
    output logic        s_pwm_arvalid,
    input  logic        s_pwm_arready,
    input  logic [31:0] s_pwm_rdata,
    input  logic [1:0]  s_pwm_rresp,
    input  logic        s_pwm_rvalid,
    output logic        s_pwm_rready
);

    // Codigos de seleccion
    localparam logic [2:0] SEL_GPIO = 3'd0;
    localparam logic [2:0] SEL_UART = 3'd1;
    localparam logic [2:0] SEL_ADC  = 3'd2;
    localparam logic [2:0] SEL_PWM  = 3'd3;
    localparam logic [2:0] SEL_NONE = 3'd7;

    localparam logic [1:0] RESP_DECERR = 2'b11;

    // La direccion pasa directa a todos; solo arvalid/rready se filtran
    assign s_gpio_araddr = s_axi_araddr;
    assign s_uart_araddr = s_axi_araddr;
    assign s_adc_araddr  = s_axi_araddr;
    assign s_pwm_araddr  = s_axi_araddr;

    // Respuesta de error propia (direccion no mapeada)
    logic err_rvalid_q;
    logic err_ar_fire;
    assign err_ar_fire = s_axi_arvalid && s_axi_arready && (rd_sel == SEL_NONE);

    always_ff @(posedge clk) begin
        if (rst)
            err_rvalid_q <= 1'b0;
        else if (err_ar_fire)
            err_rvalid_q <= 1'b1;
        else if (s_axi_rvalid && s_axi_rready)
            err_rvalid_q <= 1'b0;
    end

    // Enrutamiento combinacional
    always_comb begin
        // Valores por defecto
        s_axi_arready  = 1'b0;
        s_axi_rdata    = 32'd0;
        s_axi_rresp    = 2'b00;
        s_axi_rvalid   = 1'b0;

        s_gpio_arvalid = 1'b0;  s_gpio_rready = 1'b0;
        s_uart_arvalid = 1'b0;  s_uart_rready = 1'b0;
        s_adc_arvalid  = 1'b0;  s_adc_rready  = 1'b0;
        s_pwm_arvalid  = 1'b0;  s_pwm_rready  = 1'b0;

        // Canal AR (solo si no hay lectura en curso)
        if (!rd_busy) begin
            case (rd_sel)
                SEL_GPIO: begin s_gpio_arvalid = s_axi_arvalid; s_axi_arready = s_gpio_arready; end
                SEL_UART: begin s_uart_arvalid = s_axi_arvalid; s_axi_arready = s_uart_arready; end
                SEL_ADC : begin s_adc_arvalid  = s_axi_arvalid; s_axi_arready = s_adc_arready;  end
                SEL_PWM : begin s_pwm_arvalid  = s_axi_arvalid; s_axi_arready = s_pwm_arready;  end
                default : s_axi_arready = 1'b1;                 // DECERR
            endcase
        end

        // Canal R (rd_sel esta registrado mientras rd_busy = 1)
        if (rd_busy) begin
            case (rd_sel)
                SEL_GPIO: begin
                    s_axi_rdata   = s_gpio_rdata;
                    s_axi_rresp   = s_gpio_rresp;
                    s_axi_rvalid  = s_gpio_rvalid;
                    s_gpio_rready = s_axi_rready;
                end
                SEL_UART: begin
                    s_axi_rdata   = s_uart_rdata;
                    s_axi_rresp   = s_uart_rresp;
                    s_axi_rvalid  = s_uart_rvalid;
                    s_uart_rready = s_axi_rready;
                end
                SEL_ADC: begin
                    s_axi_rdata   = s_adc_rdata;
                    s_axi_rresp   = s_adc_rresp;
                    s_axi_rvalid  = s_adc_rvalid;
                    s_adc_rready  = s_axi_rready;
                end
                SEL_PWM: begin
                    s_axi_rdata   = s_pwm_rdata;
                    s_axi_rresp   = s_pwm_rresp;
                    s_axi_rvalid  = s_pwm_rvalid;
                    s_pwm_rready  = s_axi_rready;
                end
                default: begin                                  // DECERR propio
                    s_axi_rdata   = 32'd0;
                    s_axi_rresp   = RESP_DECERR;
                    s_axi_rvalid  = err_rvalid_q;
                end
            endcase
        end
    end

endmodule
