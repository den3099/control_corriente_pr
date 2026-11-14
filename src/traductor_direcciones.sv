module traductor_direcciones (
    input  logic        clk,
    input  logic        rst,

    // Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    output logic [31:0] s_gpio_awaddr,
    output logic        s_gpio_awvalid,
    input  logic        s_gpio_awready,

    output logic [31:0] s_uart_awaddr,
    output logic        s_uart_awvalid,
    input  logic        s_uart_awready,

    output logic [31:0] s_adc_awaddr,
    output logic        s_adc_awvalid,
    input  logic        s_adc_awready,

    output logic [31:0] s_pwm_awaddr,
    output logic        s_pwm_awvalid,
    input  logic        s_pwm_awready,

    // Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    output logic [31:0] s_gpio_wdata,
    output logic [3:0]  s_gpio_wstrb,
    output logic        s_gpio_wvalid,
    input  logic        s_gpio_wready,

    output logic [31:0] s_uart_wdata,
    output logic [3:0]  s_uart_wstrb,
    output logic        s_uart_wvalid,
    input  logic        s_uart_wready,

    output logic [31:0] s_adc_wdata,
    output logic [3:0]  s_adc_wstrb,
    output logic        s_adc_wvalid,
    input  logic        s_adc_wready,

    output logic [31:0] s_pwm_wdata,
    output logic [3:0]  s_pwm_wstrb,
    output logic        s_pwm_wvalid,
    input  logic        s_pwm_wready,

    // Write Response Channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [1:0]  s_gpio_bresp,
    input  logic        s_gpio_bvalid,
    output logic        s_gpio_bready,

    input  logic [1:0]  s_uart_bresp,
    input  logic        s_uart_bvalid,
    output logic        s_uart_bready,

    input  logic [1:0]  s_adc_bresp,
    input  logic        s_adc_bvalid,
    output logic        s_adc_bready,

    input  logic [1:0]  s_pwm_bresp,
    input  logic        s_pwm_bvalid,
    output logic        s_pwm_bready,

    // Seleccion MUX
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    input  logic        s_axi_arready,   // viene de mux_lectura
    input  logic        s_axi_rvalid,    // viene de mux_lectura
    input  logic        s_axi_rready,    // viene del maestro

    output logic [2:0]  rd_sel,          // periferico seleccionado (SEL_*)
    output logic        rd_busy          // 1 = lectura en curso (AR aceptado, R pendiente)
);

    // Mapa de direcciones
    localparam int           REGION_BITS = 16;
    localparam logic [31:0]  GPIO_ADDR   = 32'h4001_0000;
    localparam logic [31:0]  ADC_ADDR    = 32'h4002_0000;
    localparam logic [31:0]  PWM_ADDR    = 32'h4003_0000;
    localparam logic [31:0]  UART_ADDR   = 32'h4004_0000;

    // Codigos de seleccion
    localparam logic [2:0] SEL_GPIO = 3'd0;
    localparam logic [2:0] SEL_UART = 3'd1;
    localparam logic [2:0] SEL_ADC  = 3'd2;
    localparam logic [2:0] SEL_PWM  = 3'd3;
    localparam logic [2:0] SEL_NONE = 3'd7;   // direccion no mapeada

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    function automatic logic [2:0] decode_addr(input logic [31:0] addr);
        if      (addr[31:REGION_BITS] == GPIO_ADDR[31:REGION_BITS]) return SEL_GPIO;
        else if (addr[31:REGION_BITS] == UART_ADDR[31:REGION_BITS]) return SEL_UART;
        else if (addr[31:REGION_BITS] == ADC_ADDR [31:REGION_BITS]) return SEL_ADC;
        else if (addr[31:REGION_BITS] == PWM_ADDR [31:REGION_BITS]) return SEL_PWM;
        else                                                        return SEL_NONE;
    endfunction

    //ESCRITURA
    logic [2:0] aw_sel;          // decodificacion combinacional de awaddr
    logic [2:0] wr_sel_q;        // periferico de la transaccion en curso
    logic       wr_busy;         // AW aceptado, B aun no completado
    logic       w_done_q;        // W ya aceptado

    logic       aw_fire, w_fire, b_fire;

    assign aw_sel  = decode_addr(s_axi_awaddr);

    assign aw_fire = s_axi_awvalid && s_axi_awready;
    assign w_fire  = s_axi_wvalid  && s_axi_wready;
    assign b_fire  = s_axi_bvalid  && s_axi_bready;

    // Datos, strobes y direccion pasan directos; solo los valid/ready se filtran
    assign s_gpio_awaddr = s_axi_awaddr;
    assign s_uart_awaddr = s_axi_awaddr;
    assign s_adc_awaddr  = s_axi_awaddr;
    assign s_pwm_awaddr  = s_axi_awaddr;

    assign s_gpio_wdata = s_axi_wdata;   assign s_gpio_wstrb = s_axi_wstrb;
    assign s_uart_wdata = s_axi_wdata;   assign s_uart_wstrb = s_axi_wstrb;
    assign s_adc_wdata  = s_axi_wdata;   assign s_adc_wstrb  = s_axi_wstrb;
    assign s_pwm_wdata  = s_axi_wdata;   assign s_pwm_wstrb  = s_axi_wstrb;

    // Registro de estado de escritura
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_busy  <= 1'b0;
            w_done_q <= 1'b0;
            wr_sel_q <= SEL_NONE;
        end else begin
            if (aw_fire) begin
                wr_busy  <= 1'b1;
                wr_sel_q <= aw_sel;
            end
            if (w_fire)
                w_done_q <= 1'b1;
            if (b_fire) begin          // ultimo: libera el traductor
                wr_busy  <= 1'b0;
                w_done_q <= 1'b0;
            end
        end
    end

    // Enrutamiento combinacional de escritura
    logic w_open;                      // W puede fluir
    assign w_open = wr_busy && !w_done_q;

    always_comb begin
        // Valores por defecto
        s_axi_awready  = 1'b0;
        s_axi_wready   = 1'b0;
        s_axi_bvalid   = 1'b0;
        s_axi_bresp    = RESP_OKAY;

        s_gpio_awvalid = 1'b0;  s_gpio_wvalid = 1'b0;  s_gpio_bready = 1'b0;
        s_uart_awvalid = 1'b0;  s_uart_wvalid = 1'b0;  s_uart_bready = 1'b0;
        s_adc_awvalid  = 1'b0;  s_adc_wvalid  = 1'b0;  s_adc_bready  = 1'b0;
        s_pwm_awvalid  = 1'b0;  s_pwm_wvalid  = 1'b0;  s_pwm_bready  = 1'b0;

        // AW: solo si no hay escritura en curso; periferico = decode(awaddr)
        if (!wr_busy) begin
            case (aw_sel)
                SEL_GPIO: begin s_gpio_awvalid = s_axi_awvalid; s_axi_awready = s_gpio_awready; end
                SEL_UART: begin s_uart_awvalid = s_axi_awvalid; s_axi_awready = s_uart_awready; end
                SEL_ADC : begin s_adc_awvalid  = s_axi_awvalid; s_axi_awready = s_adc_awready;  end
                SEL_PWM : begin s_pwm_awvalid  = s_axi_awvalid; s_axi_awready = s_pwm_awready;  end
                default : s_axi_awready = 1'b1;                 // DECERR: se acepta y se responde error
            endcase
        end

        // W: hacia el periferico registrado
        case (wr_sel_q)
            SEL_GPIO: begin s_gpio_wvalid = s_axi_wvalid && w_open; s_axi_wready = s_gpio_wready && w_open; end
            SEL_UART: begin s_uart_wvalid = s_axi_wvalid && w_open; s_axi_wready = s_uart_wready && w_open; end
            SEL_ADC : begin s_adc_wvalid  = s_axi_wvalid && w_open; s_axi_wready = s_adc_wready  && w_open; end
            SEL_PWM : begin s_pwm_wvalid  = s_axi_wvalid && w_open; s_axi_wready = s_pwm_wready  && w_open; end
            default : s_axi_wready = w_open;                    // DECERR: se descarta el dato
        endcase

        // B: desde el periferico registrado hacia el maestro
        case (wr_sel_q)
            SEL_GPIO: begin
                s_axi_bvalid  = s_gpio_bvalid && wr_busy;
                s_axi_bresp   = s_gpio_bresp;
                s_gpio_bready = s_axi_bready  && wr_busy;
            end
            SEL_UART: begin
                s_axi_bvalid  = s_uart_bvalid && wr_busy;
                s_axi_bresp   = s_uart_bresp;
                s_uart_bready = s_axi_bready  && wr_busy;
            end
            SEL_ADC: begin
                s_axi_bvalid  = s_adc_bvalid  && wr_busy;
                s_axi_bresp   = s_adc_bresp;
                s_adc_bready  = s_axi_bready  && wr_busy;
            end
            SEL_PWM: begin
                s_axi_bvalid  = s_pwm_bvalid  && wr_busy;
                s_axi_bresp   = s_pwm_bresp;
                s_pwm_bready  = s_axi_bready  && wr_busy;
            end
            default: begin                                      // DECERR propio
                s_axi_bvalid  = wr_busy && w_done_q;
                s_axi_bresp   = RESP_DECERR;
            end
        endcase
    end

    // LECTURA: solo seleccion para el MUX
    logic [2:0] rd_sel_dec;
    logic [2:0] rd_sel_q;
    logic       ar_fire, r_fire;

    assign rd_sel_dec = decode_addr(s_axi_araddr);
    assign ar_fire    = s_axi_arvalid && s_axi_arready;
    assign r_fire     = s_axi_rvalid  && s_axi_rready;

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_busy  <= 1'b0;
            rd_sel_q <= SEL_NONE;
        end else begin
            if (ar_fire) begin
                rd_busy  <= 1'b1;
                rd_sel_q <= rd_sel_dec;
            end
            if (r_fire)
                rd_busy  <= 1'b0;
        end
    end

    assign rd_sel = rd_busy ? rd_sel_q : rd_sel_dec;

endmodule
