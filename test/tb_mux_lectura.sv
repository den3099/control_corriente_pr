`timescale 1ns/1ps
module tb_esclavo_lectura #(
    parameter logic [31:0] ID    = 32'h0,
    parameter int          LAT   = 0,          // ciclos extra antes de rvalid
    parameter logic [1:0]  RRESP = 2'b00
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,
    output int          ar_count
);
    logic        busy;
    int          cnt;
    logic [31:0] data_q;

    assign arready = !busy;
    assign rdata   = data_q;
    assign rresp   = RRESP;

    always_ff @(posedge clk) begin
        if (rst) begin
            busy     <= 1'b0;
            rvalid   <= 1'b0;
            cnt      <= 0;
            data_q   <= '0;
            ar_count <= 0;
        end else begin
            if (arvalid && arready) begin
                busy     <= 1'b1;
                data_q   <= ID ^ araddr;
                cnt      <= LAT;
                ar_count <= ar_count + 1;
            end else if (busy && !rvalid) begin
                if (cnt == 0) rvalid <= 1'b1;
                else          cnt    <= cnt - 1;
            end
            if (rvalid && rready) begin
                rvalid <= 1'b0;
                busy   <= 1'b0;
            end
        end
    end
endmodule


// ----------------------------------------------------------------------------
// Testbench
// ----------------------------------------------------------------------------
module tb_mux_lectura;

    parameter bit VERBOSE = 1'b1;   // 1: imprime tambien los [PASS]

    // Mapa de direcciones
    localparam logic [31:0] GPIO_BASE = 32'h4001_0000;
    localparam logic [31:0] ADC_BASE  = 32'h4002_0000;
    localparam logic [31:0] PWM_BASE  = 32'h4003_0000;
    localparam logic [31:0] UART_BASE = 32'h4004_0000;

    localparam int REGION_BITS = 16;

    localparam logic [2:0] SEL_GPIO = 3'd0;
    localparam logic [2:0] SEL_UART = 3'd1;
    localparam logic [2:0] SEL_ADC  = 3'd2;
    localparam logic [2:0] SEL_PWM  = 3'd3;
    localparam logic [2:0] SEL_NONE = 3'd7;

    // ID de cada esclavo (rdata = ID ^ araddr)
    localparam logic [31:0] GPIO_ID = 32'h1000_0000;
    localparam logic [31:0] UART_ID = 32'h2000_0000;
    localparam logic [31:0] ADC_ID  = 32'h3000_0000;
    localparam logic [31:0] PWM_ID  = 32'h4000_0000;

    // ------------------------------------------------------------------
    // Reloj y reset
    // ------------------------------------------------------------------
    logic clk = 1'b0;
    logic rst = 1'b1;
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------
    // Maestro
    // ------------------------------------------------------------------
    logic [31:0] s_axi_araddr  = '0;
    logic        s_axi_arvalid = 1'b0;
    logic        s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready  = 1'b0;

    // ------------------------------------------------------------------
    // Esclavos
    // ------------------------------------------------------------------
    logic [31:0] s_gpio_araddr, s_gpio_rdata;  logic s_gpio_arvalid, s_gpio_arready, s_gpio_rvalid, s_gpio_rready;  logic [1:0] s_gpio_rresp;
    logic [31:0] s_uart_araddr, s_uart_rdata;  logic s_uart_arvalid, s_uart_arready, s_uart_rvalid, s_uart_rready;  logic [1:0] s_uart_rresp;
    logic [31:0] s_adc_araddr,  s_adc_rdata;   logic s_adc_arvalid,  s_adc_arready,  s_adc_rvalid,  s_adc_rready;   logic [1:0] s_adc_rresp;
    logic [31:0] s_pwm_araddr,  s_pwm_rdata;   logic s_pwm_arvalid,  s_pwm_arready,  s_pwm_rvalid,  s_pwm_rready;   logic [1:0] s_pwm_rresp;

    int gpio_ar_count, uart_ar_count, adc_ar_count, pwm_ar_count;

    tb_esclavo_lectura #(.ID(GPIO_ID), .LAT(0), .RRESP(2'b00)) u_s_gpio (
        .clk(clk), .rst(rst),
        .araddr(s_gpio_araddr), .arvalid(s_gpio_arvalid), .arready(s_gpio_arready),
        .rdata(s_gpio_rdata), .rresp(s_gpio_rresp), .rvalid(s_gpio_rvalid), .rready(s_gpio_rready),
        .ar_count(gpio_ar_count));

    tb_esclavo_lectura #(.ID(UART_ID), .LAT(1), .RRESP(2'b00)) u_s_uart (
        .clk(clk), .rst(rst),
        .araddr(s_uart_araddr), .arvalid(s_uart_arvalid), .arready(s_uart_arready),
        .rdata(s_uart_rdata), .rresp(s_uart_rresp), .rvalid(s_uart_rvalid), .rready(s_uart_rready),
        .ar_count(uart_ar_count));

    tb_esclavo_lectura #(.ID(ADC_ID), .LAT(2), .RRESP(2'b10)) u_s_adc (
        .clk(clk), .rst(rst),
        .araddr(s_adc_araddr), .arvalid(s_adc_arvalid), .arready(s_adc_arready),
        .rdata(s_adc_rdata), .rresp(s_adc_rresp), .rvalid(s_adc_rvalid), .rready(s_adc_rready),
        .ar_count(adc_ar_count));

    tb_esclavo_lectura #(.ID(PWM_ID), .LAT(3), .RRESP(2'b00)) u_s_pwm (
        .clk(clk), .rst(rst),
        .araddr(s_pwm_araddr), .arvalid(s_pwm_arvalid), .arready(s_pwm_arready),
        .rdata(s_pwm_rdata), .rresp(s_pwm_rresp), .rvalid(s_pwm_rvalid), .rready(s_pwm_rready),
        .ar_count(pwm_ar_count));

    // ------------------------------------------------------------------
    // Modelo del generador de seleccion
    // ------------------------------------------------------------------
    function automatic logic [2:0] decode_addr(input logic [31:0] a);
        if      (a[31:REGION_BITS] == GPIO_BASE[31:REGION_BITS]) return SEL_GPIO;
        else if (a[31:REGION_BITS] == UART_BASE[31:REGION_BITS]) return SEL_UART;
        else if (a[31:REGION_BITS] == ADC_BASE [31:REGION_BITS]) return SEL_ADC;
        else if (a[31:REGION_BITS] == PWM_BASE [31:REGION_BITS]) return SEL_PWM;
        else                                                     return SEL_NONE;
    endfunction

    logic       rd_busy;
    logic [2:0] rd_sel;
    logic [2:0] rd_sel_q;
    logic       ar_fire, r_fire;

    assign ar_fire = s_axi_arvalid && s_axi_arready;
    assign r_fire  = s_axi_rvalid  && s_axi_rready;

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_busy  <= 1'b0;
            rd_sel_q <= SEL_NONE;
        end else begin
            if (ar_fire) begin
                rd_busy  <= 1'b1;
                rd_sel_q <= decode_addr(s_axi_araddr);
            end
            if (r_fire)
                rd_busy  <= 1'b0;
        end
    end

    assign rd_sel = rd_busy ? rd_sel_q : decode_addr(s_axi_araddr);

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    mux_lectura u_dut (
        .clk(clk), .rst(rst),
        .rd_sel(rd_sel), .rd_busy(rd_busy),

        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),

        .s_gpio_araddr(s_gpio_araddr), .s_gpio_arvalid(s_gpio_arvalid), .s_gpio_arready(s_gpio_arready),
        .s_gpio_rdata(s_gpio_rdata), .s_gpio_rresp(s_gpio_rresp), .s_gpio_rvalid(s_gpio_rvalid), .s_gpio_rready(s_gpio_rready),

        .s_uart_araddr(s_uart_araddr), .s_uart_arvalid(s_uart_arvalid), .s_uart_arready(s_uart_arready),
        .s_uart_rdata(s_uart_rdata), .s_uart_rresp(s_uart_rresp), .s_uart_rvalid(s_uart_rvalid), .s_uart_rready(s_uart_rready),

        .s_adc_araddr(s_adc_araddr), .s_adc_arvalid(s_adc_arvalid), .s_adc_arready(s_adc_arready),
        .s_adc_rdata(s_adc_rdata), .s_adc_rresp(s_adc_rresp), .s_adc_rvalid(s_adc_rvalid), .s_adc_rready(s_adc_rready),

        .s_pwm_araddr(s_pwm_araddr), .s_pwm_arvalid(s_pwm_arvalid), .s_pwm_arready(s_pwm_arready),
        .s_pwm_rdata(s_pwm_rdata), .s_pwm_rresp(s_pwm_rresp), .s_pwm_rvalid(s_pwm_rvalid), .s_pwm_rready(s_pwm_rready)
    );

    // ======================================================================
    // Contadores y utilidades de chequeo
    // ======================================================================
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input bit cond, input string msg);
        if (cond) begin
            pass_count++;
            if (VERBOSE) $display("[%0t] [PASS] %s", $time, msg);
        end else begin
            fail_count++;
            $display("[%0t] [FAIL] %s", $time, msg);
        end
    endtask

    task automatic reporte_final();
        $display("");
        $display("==================================================================");
        $display(" PRUEBA TERMINADA: tb_mux_lectura");
        $display("   Pruebas logradas (aciertos) : %0d", pass_count);
        $display("   Pruebas falladas (errores)  : %0d", fail_count);
        if (fail_count == 0) $display("   RESULTADO: TODAS LAS PRUEBAS PASARON");
        else                 $display("   RESULTADO: HAY PRUEBAS FALLIDAS");
        $display("==================================================================");
    endtask

    // Watchdog: si algun handshake se cuelga, el TB termina e informa
    initial begin
        #2_000_000;
        $display("[%0t] [FAIL] TIMEOUT: el testbench se colgo (handshake sin completar)", $time);
        fail_count++;
        reporte_final();
        $finish;
    end

    // ======================================================================
    // Funciones auxiliares
    // ======================================================================
    function automatic logic [31:0] base(input int p);
        case (p)
            0: return GPIO_BASE;
            1: return UART_BASE;
            2: return ADC_BASE;
            default: return PWM_BASE;
        endcase
    endfunction

    function automatic logic [31:0] id_per(input int p);
        case (p)
            0: return GPIO_ID;
            1: return UART_ID;
            2: return ADC_ID;
            default: return PWM_ID;
        endcase
    endfunction

    function automatic logic [1:0] resp_per(input int p);
        return (p == 2) ? 2'b10 : 2'b00;      // el ADC responde SLVERR a proposito
    endfunction

    function automatic string nombre(input int p);
        case (p)
            0: return "GPIO";
            1: return "UART";
            2: return "ADC";
            default: return "PWM";
        endcase
    endfunction

    function automatic int get_cnt(input int p);
        case (p)
            0: return gpio_ar_count;
            1: return uart_ar_count;
            2: return adc_ar_count;
            default: return pwm_ar_count;
        endcase
    endfunction

    // ======================================================================
    // Maestro AXI-Lite
    // ======================================================================
    task automatic axi_read(input  logic [31:0] addr, input int r_dly,
                            output logic [31:0] data, output logic [1:0] resp, output bit hold_ok);
        // ---- Canal AR
        @(negedge clk);
        s_axi_araddr  = addr;
        s_axi_arvalid = 1'b1;
        #1;
        while (!s_axi_arready) begin
            @(negedge clk);
            #1;
        end
        @(negedge clk);                    // handshake AR en el posedge previo
        s_axi_arvalid = 1'b0;
        s_axi_araddr  = 32'hFFFF_FFFF;     // basura: la seleccion debe haberse registrado

        // ---- Canal R
        s_axi_rready = 1'b0;
        hold_ok      = 1'b1;
        if (r_dly > 0) begin
            repeat (r_dly) @(negedge clk);
            #1;
            hold_ok = s_axi_rvalid;        // rvalid debe seguir arriba sin rready
        end
        s_axi_rready = 1'b1;
        #1;
        while (!s_axi_rvalid) begin
            @(negedge clk);
            #1;
        end
        data = s_axi_rdata;
        resp = s_axi_rresp;
        @(negedge clk);                    // handshake R en el posedge previo
        s_axi_rready = 1'b0;
    endtask

    // Lectura a un periferico + chequeo (dato, rresp, enrutamiento exclusivo)
    task automatic leer_per(input int p, input int off, input int r_dly, input string tag);
        logic [31:0] data;
        logic [1:0]  resp;
        bit          hold;
        logic [31:0] addr;
        int          c0 [4];
        bit          solo_destino;

        addr = base(p) + off;
        for (int q = 0; q < 4; q++) c0[q] = get_cnt(q);

        axi_read(addr, r_dly, data, resp, hold);
        repeat (2) @(negedge clk);

        check(data === (id_per(p) ^ addr),
              $sformatf("%s [%s off=0x%0h]: rdata = %h (esperado %h)", tag, nombre(p), off, data, id_per(p) ^ addr));
        check(resp === resp_per(p),
              $sformatf("%s [%s]: rresp = %b (esperado %b)", tag, nombre(p), resp, resp_per(p)));
        solo_destino = 1'b1;
        for (int q = 0; q < 4; q++) begin
            if (q == p) solo_destino = solo_destino && (get_cnt(q) == c0[q] + 1);
            else        solo_destino = solo_destino && (get_cnt(q) == c0[q]);
        end
        check(solo_destino, $sformatf("%s [%s]: el AR llego solo al periferico destino", tag, nombre(p)));
        if (r_dly > 0)
            check(hold, $sformatf("%s [%s]: rvalid se mantiene sin rready", tag, nombre(p)));
    endtask

    // Lectura a direccion no mapeada
    task automatic leer_unmapped(input logic [31:0] addr, input string tag);
        logic [31:0] data;
        logic [1:0]  resp;
        bit          hold;
        int          c0 [4];
        bit          sin_cambios;

        for (int q = 0; q < 4; q++) c0[q] = get_cnt(q);
        axi_read(addr, 0, data, resp, hold);
        repeat (2) @(negedge clk);

        check(resp === 2'b11, $sformatf("%s [addr=%h]: rresp = DECERR (obtenido %b)", tag, addr, resp));
        check(data === 32'h0, $sformatf("%s [addr=%h]: rdata = 0 (obtenido %h)", tag, addr, data));
        sin_cambios = 1'b1;
        for (int q = 0; q < 4; q++) sin_cambios = sin_cambios && (get_cnt(q) == c0[q]);
        check(sin_cambios, $sformatf("%s [addr=%h]: ningun periferico recibio AR", tag, addr));
    endtask

    // Segundo AR mientras hay una lectura en curso
    task automatic test_bloqueo_ar();
        logic [31:0] a1, a2;
        int          c_pwm0;

        a1     = GPIO_BASE + 32'h8;
        a2     = PWM_BASE  + 32'h4;
        c_pwm0 = get_cnt(3);

        @(negedge clk);
        s_axi_araddr  = a1;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b0;
        #1;
        while (!s_axi_arready) begin
            @(negedge clk);
            #1;
        end
        @(negedge clk);                    // AR1 aceptado; rd_busy = 1
        s_axi_araddr = a2;                 // arvalid sigue en 1: segundo AR (a PWM)
        #1;
        check(!s_axi_arready, "Bloqueo: arready = 0 mientras hay una lectura en curso");
        check(!s_pwm_arvalid, "Bloqueo: el segundo AR no llega al PWM mientras hay lectura en curso");

        while (!s_axi_rvalid) begin
            @(negedge clk);
            #1;
        end
        check(s_axi_rdata === (GPIO_ID ^ a1), $sformatf("Bloqueo: R1 correcto del GPIO (%h)", s_axi_rdata));
        check(get_cnt(3) == c_pwm0, "Bloqueo: el PWM aun no ha recibido AR");

        s_axi_rready = 1'b1;
        @(negedge clk);                    // handshake R1 hecho; rd_busy = 0
        #1;
        check(s_axi_arready, "Bloqueo: el segundo AR se acepta al liberar R1");
        @(negedge clk);                    // handshake AR2 hecho
        s_axi_arvalid = 1'b0;
        s_axi_araddr  = 32'hFFFF_FFFF;
        #1;
        while (!s_axi_rvalid) begin
            @(negedge clk);
            #1;
        end
        check(s_axi_rdata === (PWM_ID ^ a2), $sformatf("Bloqueo: R2 correcto del PWM (%h)", s_axi_rdata));
        @(negedge clk);
        s_axi_rready = 1'b0;
        repeat (2) @(negedge clk);
        check(get_cnt(3) == c_pwm0 + 1, "Bloqueo: el PWM recibio exactamente un AR (el segundo)");
    endtask

    // ======================================================================
    // Secuencia principal
    // ======================================================================
    int k;

    initial begin
        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        $display("");
        $display("---- Prueba 1: estado despues del reset ----");
        check(s_axi_rvalid === 1'b0, "rvalid = 0 en reposo");
        check(rd_busy === 1'b0,      "rd_busy = 0 en reposo");
        check(!(s_gpio_arvalid || s_uart_arvalid || s_adc_arvalid || s_pwm_arvalid),
              "ningun arvalid hacia perifericos en reposo");

        $display("");
        $display("---- Prueba 2: lectura de cada periferico ----");
        for (int p = 0; p < 4; p++) begin
            leer_per(p, 32'h00, 0, "Lectura");
            leer_per(p, 32'h04, 0, "Lectura");
            leer_per(p, 32'h3C, 0, "Lectura");
        end

        $display("");
        $display("---- Prueba 3: contrapresion en el canal R ----");
        for (int p = 0; p < 4; p++)
            leer_per(p, 32'h08, 6, "rready retrasado");

        $display("");
        $display("---- Prueba 4: rafaga de lecturas consecutivas (periferico alternado) ----");
        for (k = 0; k < 16; k++)
            leer_per(k % 4, 4 * (k + 1), 0, $sformatf("Rafaga #%0d", k));

        $display("");
        $display("---- Prueba 5: bloqueo de segundo AR con lectura en curso ----");
        test_bloqueo_ar();

        $display("");
        $display("---- Prueba 6: direcciones no mapeadas (DECERR) ----");
        leer_unmapped(32'h5000_0000, "No mapeada");
        leer_unmapped(32'h4000_0000, "Region LEDs/sin periferico");
        leer_unmapped(32'h4005_0000, "Justo despues de UART");
        leer_unmapped(32'h0000_0000, "Direccion 0");
        leer_per(2, 32'h10, 0, "Recuperacion tras DECERR");

        repeat (5) @(negedge clk);
        reporte_final();
        $finish;
    end

endmodule
