`timescale 1ns/1ps
module tb_banco_regs (
    input  logic        clk,
    input  logic        rst,
    input  logic        wr_en,
    input  logic [7:0]  wr_addr,
    input  logic [31:0] wr_data,
    input  logic [3:0]  wr_strb,
    input  logic [7:0]  rd_addr,
    output logic [31:0] rd_data
);
    logic [31:0] mem [0:63];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 64; i++) mem[i] <= '0;
        end else if (wr_en) begin
            for (int b = 0; b < 4; b++)
                if (wr_strb[b]) mem[wr_addr[7:2]][8*b +: 8] <= wr_data[8*b +: 8];
        end
    end

    assign rd_data = mem[rd_addr[7:2]];
endmodule


// ----------------------------------------------------------------------------
// Testbench
// ----------------------------------------------------------------------------
module tb_traductor_direcciones;

    parameter bit VERBOSE = 1'b1;   // 1: imprime tambien los [PASS]

    // Mapa de direcciones
    localparam logic [31:0] GPIO_BASE = 32'h4001_0000;
    localparam logic [31:0] ADC_BASE  = 32'h4002_0000;
    localparam logic [31:0] PWM_BASE  = 32'h4003_0000;
    localparam logic [31:0] UART_BASE = 32'h4004_0000;

    localparam logic [2:0] SEL_GPIO = 3'd0;
    localparam logic [2:0] SEL_UART = 3'd1;
    localparam logic [2:0] SEL_ADC  = 3'd2;
    localparam logic [2:0] SEL_PWM  = 3'd3;
    localparam logic [2:0] SEL_NONE = 3'd7;

    // ------------------------------------------------------------------
    // Reloj y reset
    // ------------------------------------------------------------------
    logic clk = 1'b0;
    logic rst = 1'b1;
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------
    // Senales del maestro
    // ------------------------------------------------------------------
    logic [31:0] s_axi_awaddr  = '0;
    logic        s_axi_awvalid = 1'b0;
    logic        s_axi_awready;

    logic [31:0] s_axi_wdata   = '0;
    logic [3:0]  s_axi_wstrb   = '0;
    logic        s_axi_wvalid  = 1'b0;
    logic        s_axi_wready;

    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready  = 1'b0;

    logic [31:0] s_axi_araddr  = '0;
    logic        s_axi_arvalid = 1'b0;
    logic        s_axi_arready = 1'b0;   // en este TB lo maneja el TB (hace de mux)
    logic        s_axi_rvalid  = 1'b0;
    logic        s_axi_rready  = 1'b0;

    logic [2:0]  rd_sel;
    logic        rd_busy;

    // ------------------------------------------------------------------
    // Senales hacia/desde los perifericos
    // ------------------------------------------------------------------
    // GPIO
    logic [31:0] s_gpio_awaddr;  logic s_gpio_awvalid, s_gpio_awready;
    logic [31:0] s_gpio_wdata;   logic [3:0] s_gpio_wstrb;  logic s_gpio_wvalid, s_gpio_wready;
    logic [1:0]  s_gpio_bresp;   logic s_gpio_bvalid, s_gpio_bready;
    logic        gpio_wr_en;     logic [7:0] gpio_wr_addr;  logic [31:0] gpio_wr_data;
    logic [3:0]  gpio_wr_strb;   logic [7:0] gpio_rd_addr;  logic [31:0] gpio_rd_data;
    // UART
    logic [31:0] s_uart_awaddr;  logic s_uart_awvalid, s_uart_awready;
    logic [31:0] s_uart_wdata;   logic [3:0] s_uart_wstrb;  logic s_uart_wvalid, s_uart_wready;
    logic [1:0]  s_uart_bresp;   logic s_uart_bvalid, s_uart_bready;
    logic        uart_wr_en;     logic [7:0] uart_wr_addr;  logic [31:0] uart_wr_data;
    logic [3:0]  uart_wr_strb;   logic [7:0] uart_rd_addr;  logic [31:0] uart_rd_data;
    // ADC
    logic [31:0] s_adc_awaddr;   logic s_adc_awvalid, s_adc_awready;
    logic [31:0] s_adc_wdata;    logic [3:0] s_adc_wstrb;   logic s_adc_wvalid, s_adc_wready;
    logic [1:0]  s_adc_bresp;    logic s_adc_bvalid, s_adc_bready;
    logic        adc_wr_en;      logic [7:0] adc_wr_addr;   logic [31:0] adc_wr_data;
    logic [3:0]  adc_wr_strb;    logic [7:0] adc_rd_addr;   logic [31:0] adc_rd_data;
    // PWM
    logic [31:0] s_pwm_awaddr;   logic s_pwm_awvalid, s_pwm_awready;
    logic [31:0] s_pwm_wdata;    logic [3:0] s_pwm_wstrb;   logic s_pwm_wvalid, s_pwm_wready;
    logic [1:0]  s_pwm_bresp;    logic s_pwm_bvalid, s_pwm_bready;
    logic        pwm_wr_en;      logic [7:0] pwm_wr_addr;   logic [31:0] pwm_wr_data;
    logic [3:0]  pwm_wr_strb;    logic [7:0] pwm_rd_addr;   logic [31:0] pwm_rd_data;

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    traductor_direcciones u_dut (
        .clk(clk), .rst(rst),

        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_gpio_awaddr(s_gpio_awaddr), .s_gpio_awvalid(s_gpio_awvalid), .s_gpio_awready(s_gpio_awready),
        .s_uart_awaddr(s_uart_awaddr), .s_uart_awvalid(s_uart_awvalid), .s_uart_awready(s_uart_awready),
        .s_adc_awaddr (s_adc_awaddr),  .s_adc_awvalid (s_adc_awvalid),  .s_adc_awready (s_adc_awready),
        .s_pwm_awaddr (s_pwm_awaddr),  .s_pwm_awvalid (s_pwm_awvalid),  .s_pwm_awready (s_pwm_awready),

        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_gpio_wdata(s_gpio_wdata), .s_gpio_wstrb(s_gpio_wstrb), .s_gpio_wvalid(s_gpio_wvalid), .s_gpio_wready(s_gpio_wready),
        .s_uart_wdata(s_uart_wdata), .s_uart_wstrb(s_uart_wstrb), .s_uart_wvalid(s_uart_wvalid), .s_uart_wready(s_uart_wready),
        .s_adc_wdata (s_adc_wdata),  .s_adc_wstrb (s_adc_wstrb),  .s_adc_wvalid (s_adc_wvalid),  .s_adc_wready (s_adc_wready),
        .s_pwm_wdata (s_pwm_wdata),  .s_pwm_wstrb (s_pwm_wstrb),  .s_pwm_wvalid (s_pwm_wvalid),  .s_pwm_wready (s_pwm_wready),

        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_gpio_bresp(s_gpio_bresp), .s_gpio_bvalid(s_gpio_bvalid), .s_gpio_bready(s_gpio_bready),
        .s_uart_bresp(s_uart_bresp), .s_uart_bvalid(s_uart_bvalid), .s_uart_bready(s_uart_bready),
        .s_adc_bresp (s_adc_bresp),  .s_adc_bvalid (s_adc_bvalid),  .s_adc_bready (s_adc_bready),
        .s_pwm_bresp (s_pwm_bresp),  .s_pwm_bvalid (s_pwm_bvalid),  .s_pwm_bready (s_pwm_bready),

        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .rd_sel(rd_sel), .rd_busy(rd_busy)
    );

    // ------------------------------------------------------------------
    // Periferico GPIO
    // ------------------------------------------------------------------
    AXI_LITE_INTERFACE u_if_gpio (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_gpio_awaddr), .s_axi_awvalid(s_gpio_awvalid), .s_axi_awready(s_gpio_awready),
        .s_axi_wdata(s_gpio_wdata), .s_axi_wstrb(s_gpio_wstrb), .s_axi_wvalid(s_gpio_wvalid), .s_axi_wready(s_gpio_wready),
        .s_axi_bresp(s_gpio_bresp), .s_axi_bvalid(s_gpio_bvalid), .s_axi_bready(s_gpio_bready),
        .s_axi_araddr(32'h0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b0),
        .wr_en(gpio_wr_en), .wr_addr(gpio_wr_addr), .wr_data(gpio_wr_data), .wr_strb(gpio_wr_strb),
        .rd_addr(gpio_rd_addr), .rd_data(gpio_rd_data)
    );
    tb_banco_regs u_bank_gpio (
        .clk(clk), .rst(rst), .wr_en(gpio_wr_en), .wr_addr(gpio_wr_addr), .wr_data(gpio_wr_data),
        .wr_strb(gpio_wr_strb), .rd_addr(gpio_rd_addr), .rd_data(gpio_rd_data)
    );

    // ------------------------------------------------------------------
    // Periferico UART
    // ------------------------------------------------------------------
    AXI_LITE_INTERFACE u_if_uart (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_uart_awaddr), .s_axi_awvalid(s_uart_awvalid), .s_axi_awready(s_uart_awready),
        .s_axi_wdata(s_uart_wdata), .s_axi_wstrb(s_uart_wstrb), .s_axi_wvalid(s_uart_wvalid), .s_axi_wready(s_uart_wready),
        .s_axi_bresp(s_uart_bresp), .s_axi_bvalid(s_uart_bvalid), .s_axi_bready(s_uart_bready),
        .s_axi_araddr(32'h0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b0),
        .wr_en(uart_wr_en), .wr_addr(uart_wr_addr), .wr_data(uart_wr_data), .wr_strb(uart_wr_strb),
        .rd_addr(uart_rd_addr), .rd_data(uart_rd_data)
    );
    tb_banco_regs u_bank_uart (
        .clk(clk), .rst(rst), .wr_en(uart_wr_en), .wr_addr(uart_wr_addr), .wr_data(uart_wr_data),
        .wr_strb(uart_wr_strb), .rd_addr(uart_rd_addr), .rd_data(uart_rd_data)
    );

    // ------------------------------------------------------------------
    // Periferico ADC
    // ------------------------------------------------------------------
    AXI_LITE_INTERFACE u_if_adc (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_adc_awaddr), .s_axi_awvalid(s_adc_awvalid), .s_axi_awready(s_adc_awready),
        .s_axi_wdata(s_adc_wdata), .s_axi_wstrb(s_adc_wstrb), .s_axi_wvalid(s_adc_wvalid), .s_axi_wready(s_adc_wready),
        .s_axi_bresp(s_adc_bresp), .s_axi_bvalid(s_adc_bvalid), .s_axi_bready(s_adc_bready),
        .s_axi_araddr(32'h0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b0),
        .wr_en(adc_wr_en), .wr_addr(adc_wr_addr), .wr_data(adc_wr_data), .wr_strb(adc_wr_strb),
        .rd_addr(adc_rd_addr), .rd_data(adc_rd_data)
    );
    tb_banco_regs u_bank_adc (
        .clk(clk), .rst(rst), .wr_en(adc_wr_en), .wr_addr(adc_wr_addr), .wr_data(adc_wr_data),
        .wr_strb(adc_wr_strb), .rd_addr(adc_rd_addr), .rd_data(adc_rd_data)
    );

    // ------------------------------------------------------------------
    // Periferico PWM
    // ------------------------------------------------------------------
    AXI_LITE_INTERFACE u_if_pwm (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_pwm_awaddr), .s_axi_awvalid(s_pwm_awvalid), .s_axi_awready(s_pwm_awready),
        .s_axi_wdata(s_pwm_wdata), .s_axi_wstrb(s_pwm_wstrb), .s_axi_wvalid(s_pwm_wvalid), .s_axi_wready(s_pwm_wready),
        .s_axi_bresp(s_pwm_bresp), .s_axi_bvalid(s_pwm_bvalid), .s_axi_bready(s_pwm_bready),
        .s_axi_araddr(32'h0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b0),
        .wr_en(pwm_wr_en), .wr_addr(pwm_wr_addr), .wr_data(pwm_wr_data), .wr_strb(pwm_wr_strb),
        .rd_addr(pwm_rd_addr), .rd_data(pwm_rd_data)
    );
    tb_banco_regs u_bank_pwm (
        .clk(clk), .rst(rst), .wr_en(pwm_wr_en), .wr_addr(pwm_wr_addr), .wr_data(pwm_wr_data),
        .wr_strb(pwm_wr_strb), .rd_addr(pwm_rd_addr), .rd_data(pwm_rd_data)
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
        $display(" PRUEBA TERMINADA: tb_traductor_direcciones");
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

    // Monitor: ningun periferico debe activarse durante una escritura no mapeada
    bit mon_unmapped = 1'b0;
    bit spurious     = 1'b0;
    always @(posedge clk) begin
        if (mon_unmapped && (s_gpio_awvalid || s_uart_awvalid || s_adc_awvalid || s_pwm_awvalid ||
                             s_gpio_wvalid  || s_uart_wvalid  || s_adc_wvalid  || s_pwm_wvalid))
            spurious <= 1'b1;
    end

    // ======================================================================
    // Modelo de referencia y funciones auxiliares
    // ======================================================================
    logic [31:0] exp_mem [4][64];

    function automatic logic [31:0] base(input int p);
        case (p)
            0: return GPIO_BASE;
            1: return UART_BASE;
            2: return ADC_BASE;
            default: return PWM_BASE;
        endcase
    endfunction

    function automatic string nombre(input int p);
        case (p)
            0: return "GPIO";
            1: return "UART";
            2: return "ADC";
            default: return "PWM";
        endcase
    endfunction

    function automatic logic [31:0] get_mem(input int p, input int idx);
        case (p)
            0: return u_bank_gpio.mem[idx];
            1: return u_bank_uart.mem[idx];
            2: return u_bank_adc.mem[idx];
            default: return u_bank_pwm.mem[idx];
        endcase
    endfunction

    function automatic logic [31:0] merge(input logic [31:0] old_v, input logic [31:0] new_v,
                                          input logic [3:0] strb);
        logic [31:0] r;
        r = old_v;
        for (int b = 0; b < 4; b++)
            if (strb[b]) r[8*b +: 8] = new_v[8*b +: 8];
        return r;
    endfunction

    function automatic logic [31:0] dato(input int p, input int k);
        return 32'hC0DE_0000 + (p << 12) + (k << 4) + p + 1;
    endfunction

    // ======================================================================
    // Maestro AXI-Lite
    // ======================================================================
    task automatic aw_phase(input logic [31:0] addr, input int dly);
        repeat (dly) @(negedge clk);
        @(negedge clk);
        s_axi_awaddr  = addr;
        s_axi_awvalid = 1'b1;
        #1;
        while (!s_axi_awready) begin
            @(negedge clk);
            #1;
        end
        @(negedge clk);                    // el handshake ocurrio en el posedge previo
        s_axi_awvalid = 1'b0;
        s_axi_awaddr  = 32'hFFFF_FFFF;     // el traductor debe haber registrado la seleccion
    endtask

    task automatic w_phase(input logic [31:0] data, input logic [3:0] strb, input int dly);
        repeat (dly) @(negedge clk);
        @(negedge clk);
        s_axi_wdata  = data;
        s_axi_wstrb  = strb;
        s_axi_wvalid = 1'b1;
        #1;
        while (!s_axi_wready) begin
            @(negedge clk);
            #1;
        end
        @(negedge clk);
        s_axi_wvalid = 1'b0;
        s_axi_wdata  = 32'hFFFF_FFFF;
        s_axi_wstrb  = 4'h0;
    endtask

    task automatic axi_write(input  logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb,
                             input  int aw_dly, input int w_dly, input int b_dly,
                             output logic [1:0] resp, output bit b_hold_ok);
        fork
            aw_phase(addr, aw_dly);
            w_phase(data, strb, w_dly);
        join
        s_axi_bready = 1'b0;
        b_hold_ok    = 1'b1;
        if (b_dly > 0) begin
            repeat (b_dly) @(negedge clk);
            #1;
            b_hold_ok = s_axi_bvalid;      // bvalid debe seguir arriba sin bready
        end
        s_axi_bready = 1'b1;
        #1;
        while (!s_axi_bvalid) begin
            @(negedge clk);
            #1;
        end
        resp = s_axi_bresp;
        @(negedge clk);                    // handshake B en el posedge previo
        s_axi_bready = 1'b0;
    endtask

    // Verifica que los 4 bancos coincidan con el modelo en la palabra idx
    task automatic check_banks(input string ctx, input int idx);
        bit ok;
        ok = 1'b1;
        for (int q = 0; q < 4; q++)
            ok = ok && (get_mem(q, idx) === exp_mem[q][idx]);
        check(ok, $sformatf("%s: GPIO=%h UART=%h ADC=%h PWM=%h (esperado %h %h %h %h)", ctx,
              get_mem(0, idx), get_mem(1, idx), get_mem(2, idx), get_mem(3, idx),
              exp_mem[0][idx], exp_mem[1][idx], exp_mem[2][idx], exp_mem[3][idx]));
    endtask

    // Escritura a un periferico + chequeo completo
    task automatic write_per(input int p, input int off, input logic [31:0] data, input logic [3:0] strb,
                             input int awd, input int wd, input int bd, input string tag);
        logic [1:0] resp;
        bit         hold;
        int         idx;
        idx = (off >> 2) & 63;
        axi_write(base(p) + off, data, strb, awd, wd, bd, resp, hold);
        exp_mem[p][idx] = merge(exp_mem[p][idx], data, strb);
        repeat (3) @(negedge clk);
        check(resp == 2'b00, $sformatf("%s [%s off=0x%0h]: bresp = OKAY", tag, nombre(p), off));
        if (bd > 0)
            check(hold, $sformatf("%s [%s]: bvalid se mantiene sin bready", tag, nombre(p)));
        check_banks($sformatf("%s [%s off=0x%0h] dato=%h strb=%b solo el periferico destino cambia",
                              tag, nombre(p), off, data, strb), idx);
    endtask

    // Escritura a direccion no mapeada
    task automatic write_unmapped(input logic [31:0] addr, input string tag);
        logic [1:0] resp;
        bit         hold;
        mon_unmapped = 1'b1;
        spurious     = 1'b0;
        axi_write(addr, 32'hDEAD_BEEF, 4'hF, 0, 0, 0, resp, hold);
        repeat (3) @(negedge clk);
        mon_unmapped = 1'b0;
        check(resp == 2'b11, $sformatf("%s [addr=%h]: bresp = DECERR (obtenido %b)", tag, addr, resp));
        check(!spurious,     $sformatf("%s [addr=%h]: ningun periferico recibio awvalid/wvalid", tag, addr));
        for (int i = 0; i < 4; i++) check_banks($sformatf("%s [addr=%h]: bancos intactos", tag, addr), i);
    endtask

    // Prueba de la seleccion de lectura
    task automatic test_rd_sel(input logic [31:0] addr, input logic [2:0] exp_sel, input string tag);
        @(negedge clk);
        s_axi_araddr  = addr;
        s_axi_arvalid = 1'b1;
        s_axi_arready = 1'b0;
        #1;
        check(rd_sel === exp_sel && rd_busy === 1'b0,
              $sformatf("%s: rd_sel=%0d (esperado %0d) y rd_busy=0 antes de AR", tag, rd_sel, exp_sel));
        @(negedge clk);
        s_axi_arready = 1'b1;              // handshake AR en el posedge siguiente
        @(negedge clk);
        s_axi_arvalid = 1'b0;
        s_axi_arready = 1'b0;
        s_axi_araddr  = 32'hFFFF_FFFF;     // el maestro cambia/quita la direccion
        #1;
        check(rd_sel === exp_sel && rd_busy === 1'b1,
              $sformatf("%s: tras AR rd_sel se mantiene en %0d y rd_busy=1", tag, exp_sel));
        s_axi_rvalid = 1'b1;
        s_axi_rready = 1'b1;               // handshake R en el posedge siguiente
        @(negedge clk);
        s_axi_rvalid = 1'b0;
        s_axi_rready = 1'b0;
        #1;
        check(rd_busy === 1'b0, $sformatf("%s: tras R rd_busy vuelve a 0", tag));
    endtask

    // ======================================================================
    // Secuencia principal
    // ======================================================================
    int k;

    initial begin
        for (int p = 0; p < 4; p++)
            for (int i = 0; i < 64; i++)
                exp_mem[p][i] = '0;

        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        $display("");
        $display("---- Prueba 0: estado despues del reset ----");
        check(s_axi_bvalid === 1'b0, "bvalid = 0 en reposo");
        check(!(s_gpio_awvalid || s_uart_awvalid || s_adc_awvalid || s_pwm_awvalid),
              "ningun awvalid hacia perifericos en reposo");
        check(rd_busy === 1'b0, "rd_busy = 0 en reposo");

        $display("");
        $display("---- Prueba 1: escritura a cada periferico ----");
        for (int p = 0; p < 4; p++) begin
            write_per(p, 32'h00, dato(p, 0), 4'hF, 0, 0, 0, "Escritura");
            write_per(p, 32'h04, dato(p, 1), 4'hF, 0, 0, 0, "Escritura");
            write_per(p, 32'h08, dato(p, 2), 4'hF, 0, 0, 0, "Escritura");
            write_per(p, 32'h3C, dato(p, 3), 4'hF, 0, 0, 0, "Escritura");
        end

        $display("");
        $display("---- Prueba 2: strobes parciales ----");
        for (int p = 0; p < 4; p++) begin
            write_per(p, 32'h10, 32'hFFFF_FFFF, 4'hF,  0, 0, 0, "Strobe base");
            write_per(p, 32'h10, 32'h1234_5678, 4'b0101, 0, 0, 0, "Strobe 0101");
            write_per(p, 32'h10, 32'hAABB_CCDD, 4'b1000, 0, 0, 0, "Strobe 1000");
        end

        $display("");
        $display("---- Prueba 3: orden de canales (W antes que AW / AW antes que W) ----");
        for (int p = 0; p < 4; p++) begin
            write_per(p, 32'h14, dato(p, 4), 4'hF, 4, 0, 0, "W primero, AW retrasado");
            write_per(p, 32'h18, dato(p, 5), 4'hF, 0, 4, 0, "AW primero, W retrasado");
        end

        $display("");
        $display("---- Prueba 4: contrapresion en el canal B ----");
        for (int p = 0; p < 4; p++)
            write_per(p, 32'h1C, dato(p, 6), 4'hF, 0, 0, 5, "bready retrasado");

        $display("");
        $display("---- Prueba 5: rafaga de escrituras consecutivas (periferico alternado) ----");
        for (k = 0; k < 12; k++) begin
            logic [1:0] resp_b;
            bit         hold_b;
            int         pb;
            pb = k % 4;
            axi_write(base(pb) + 32'h40 + 4*k, 32'hB000_0000 + k, 4'hF, 0, 0, 0, resp_b, hold_b);
            exp_mem[pb][16 + k] = 32'hB000_0000 + k;
            check(resp_b == 2'b00, $sformatf("Rafaga #%0d [%s]: bresp = OKAY", k, nombre(pb)));
        end
        repeat (3) @(negedge clk);
        for (k = 0; k < 12; k++)
            check_banks($sformatf("Rafaga #%0d verificada", k), 16 + k);

        $display("");
        $display("---- Prueba 6: direcciones no mapeadas (DECERR) ----");
        write_unmapped(32'h5000_0000, "No mapeada");
        write_unmapped(32'h4000_0000, "Region LEDs/sin periferico");
        write_unmapped(32'h4005_0000, "Justo despues de UART");
        write_unmapped(32'h0000_0000, "Direccion 0");
        write_per(3, 32'h20, 32'h600D_F00D, 4'hF, 0, 0, 0, "Recuperacion tras DECERR");

        $display("");
        $display("---- Prueba 7: seleccion de lectura (rd_sel / rd_busy) ----");
        test_rd_sel(GPIO_BASE + 32'h04, SEL_GPIO, "Lectura GPIO");
        test_rd_sel(UART_BASE + 32'h04, SEL_UART, "Lectura UART");
        test_rd_sel(ADC_BASE  + 32'h04, SEL_ADC,  "Lectura ADC");
        test_rd_sel(PWM_BASE  + 32'h04, SEL_PWM,  "Lectura PWM");
        test_rd_sel(32'h5000_0000,      SEL_NONE, "Lectura no mapeada");

        repeat (5) @(negedge clk);
        reporte_final();
        $finish;
    end

endmodule
