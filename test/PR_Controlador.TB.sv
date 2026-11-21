`timescale 1ns/1ps

module PWM_CONTROLLER_TB;

    // ============================================================
    // Reloj y DUT
    // Reloj de 100 MHz: periodo = 10 ns
    // rst EXTERNO activo en bajo: 0 = reset, 1 = funcionamiento
    // ============================================================
    logic clk = 1'b0;
    logic rst = 1'b0;

    always #5 clk = ~clk;

    logic [31:0] s_axi_awaddr = '0;
    logic s_axi_awvalid = 1'b0;
    wire  s_axi_awready;

    logic [31:0] s_axi_wdata = '0;
    logic [3:0]  s_axi_wstrb = '0;
    logic s_axi_wvalid = 1'b0;
    wire  s_axi_wready;

    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    logic s_axi_bready = 1'b0;

    logic [31:0] s_axi_araddr = '0;
    logic s_axi_arvalid = 1'b0;
    wire s_axi_arready;

    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    logic s_axi_rready = 1'b0;

    logic [2:0] s_axi_awprot = 3'b000;
    logic [2:0] s_axi_arprot = 3'b000;

    wire pwm_AH, pwm_AL, pwm_BH, pwm_BL;

    PWM_CONTROLLER DUT (
        .clk(clk), .rst(rst),

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

        .pwm_AH(pwm_AH), .pwm_AL(pwm_AL),
        .pwm_BH(pwm_BH), .pwm_BL(pwm_BL),

        .s_axi_awprot(s_axi_awprot),
        .s_axi_arprot(s_axi_arprot)
    );

    // ============================================================
    // DUT independiente para probar el dead time de forma aislada
    // Este bloque usa reset activo en alto, como el submodulo RTL.
    // ============================================================
    logic dt_rst = 1'b1;
    logic dt_enable = 1'b0;
    logic dt_raw_A = 1'b0;
    logic dt_raw_B = 1'b0;
    wire dt_AH, dt_AL, dt_BH, dt_BL;

    DEAD_TIME_GENERATOR #(.DEAD_TIME_CYCLES(50)) DT_UNIT (
        .clk(clk), .rst(dt_rst), .enable(dt_enable),
        .raw_pwm_A(dt_raw_A), .raw_pwm_B(dt_raw_B),
        .pwm_AH(dt_AH), .pwm_AL(dt_AL),
        .pwm_BH(dt_BH), .pwm_BL(dt_BL)
    );

    // ============================================================
    // Contadores de resultados
    // ============================================================
    integer tests_passed = 0;
    integer tests_failed = 0;

    task automatic check(input bit condition, input string test_name);
        begin
            if (condition) begin
                tests_passed = tests_passed + 1;
                $display("[OK] %s", test_name);
            end
            else begin
                tests_failed = tests_failed + 1;
                $display("[ERROR] %s", test_name);
            end
        end
    endtask

    task automatic check_equal(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name
    );
        begin
            if (actual === expected) begin
                tests_passed = tests_passed + 1;
                $display("[OK] %s = %08h", test_name, actual);
            end
            else begin
                tests_failed = tests_failed + 1;
                $display("[ERROR] %s | esperado=%08h obtenido=%08h",
                         test_name, expected, actual);
            end
        end
    endtask

    // ============================================================
    // AXI-Lite: tareas de escritura
    // channel_order:
    // 0 = AW y W simultaneos
    // 1 = AW primero, W despues
    // 2 = W primero, AW despues
    // ============================================================
    task automatic send_aw(input logic [31:0] address);
        integer timeout_count;
        begin
            @(negedge clk);
            s_axi_awaddr  = address;
            s_axi_awvalid = 1'b1;
            timeout_count = 0;
            do begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100)
                    $fatal(1, "TIMEOUT esperando handshake AW");
            end while (s_axi_awready !== 1'b1);
            @(negedge clk);
            s_axi_awvalid = 1'b0;
        end
    endtask

    task automatic send_w(
        input logic [31:0] data,
        input logic [3:0] strobe
    );
        integer timeout_count;
        begin
            @(negedge clk);
            s_axi_wdata  = data;
            s_axi_wstrb  = strobe;
            s_axi_wvalid = 1'b1;
            timeout_count = 0;
            do begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100)
                    $fatal(1, "TIMEOUT esperando handshake W");
            end while (s_axi_wready !== 1'b1);
            @(negedge clk);
            s_axi_wvalid = 1'b0;
        end
    endtask

    task automatic axi_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] strobe,
        input integer channel_order
    );
        integer timeout_count;
        begin
            case (channel_order)
                1: begin
                    send_aw(address);
                    repeat (2) @(posedge clk);
                    send_w(data, strobe);
                end
                2: begin
                    send_w(data, strobe);
                    repeat (2) @(posedge clk);
                    send_aw(address);
                end
                default: begin
                    fork
                        send_aw(address);
                        send_w(data, strobe);
                    join
                end
            endcase

            // Mantener BREADY bajo hasta comprobar BVALID y BRESP.
            timeout_count = 0;
            while (s_axi_bvalid !== 1'b1) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100)
                    $fatal(1, "TIMEOUT esperando BVALID");
            end

            check(s_axi_bresp == 2'b00, "BRESP = OKAY");

            @(negedge clk);
            s_axi_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;

            // Dar tiempo al registro para capturar wr_en registrado.
            repeat (2) @(posedge clk);
        end
    endtask

    // ============================================================
    // AXI-Lite: lectura con backpressure opcional
    // ============================================================
    task automatic axi_read(
        input logic [31:0] address,
        output logic [31:0] data
    );
        integer timeout_count;
        begin
            @(negedge clk);
            s_axi_araddr  = address;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b0;

            timeout_count = 0;
            do begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100)
                    $fatal(1, "TIMEOUT esperando handshake AR");
            end while (s_axi_arready !== 1'b1);

            @(negedge clk);
            s_axi_arvalid = 1'b0;

            timeout_count = 0;
            while (s_axi_rvalid !== 1'b1) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100)
                    $fatal(1, "TIMEOUT esperando RVALID");
            end

            data = s_axi_rdata;
            check(s_axi_rresp == 2'b00, "RRESP = OKAY");

            // Mantener RVALID mientras RREADY=0 y comprobar estabilidad.
            repeat (3) begin
                @(posedge clk);
                #1;
                check(s_axi_rvalid === 1'b1, "RVALID se mantiene con RREADY=0");
                check(s_axi_rdata === data, "RDATA estable durante backpressure");
            end

            @(negedge clk);
            s_axi_rready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axi_rready = 1'b0;
        end
    endtask

    task automatic expect_read(
        input logic [31:0] address,
        input logic [31:0] expected,
        input string name
    );
        logic [31:0] value;
        begin
            axi_read(address, value);
            check_equal(value, expected, name);
        end
    endtask

    // ============================================================
    // Comprobaciones continuas de seguridad
    // ============================================================
    always @(negedge clk) begin
        if (rst === 1'b1) begin
            if ((pwm_AH && pwm_AL) || (pwm_BH && pwm_BL)) begin
                tests_failed = tests_failed + 1;
                $display("[ERROR] Solapamiento en salidas complementarias del DUT");
            end
        end

        if (dt_enable && !dt_rst) begin
            if ((dt_AH && dt_AL) || (dt_BH && dt_BL)) begin
                tests_failed = tests_failed + 1;
                $display("[ERROR] Solapamiento en DEAD_TIME_GENERATOR");
            end
        end
    end

    // ============================================================
    // Medicion del periodo de la portadora PWM
    // duty=0 hace que raw_pwm_A tenga transiciones una vez por ciclo.
    // El periodo esperado es 2*max_count*10 ns.
    // ============================================================
    task automatic measure_pwm_period(
        input logic [1:0] frequency,
        input integer max_count_expected,
        input string name
    );
        time t1, t2;
        time expected_period;
        logic [31:0] ctrl_value;
        begin
            // Deshabilitar antes de cambiar freq_sel.
            axi_write(32'h00000000, {29'd0, frequency, 1'b0}, 4'b0001, 0);
            axi_write(32'h00000004, 32'h00000000, 4'b0011, 0);
            axi_write(32'h00000000, {29'd0, frequency, 1'b1}, 4'b0001, 0);

            repeat (5) @(posedge clk);
            check(DUT.max_count == max_count_expected,
                  $sformatf("%s: max_count correcto", name));

            // Esperar dos flancos ascendentes de raw_pwm_A.
            @(posedge DUT.raw_pwm_A);
            t1 = $time;
            @(posedge DUT.raw_pwm_A);
            t2 = $time;

            expected_period = 2 * max_count_expected * 10;
            check((t2 - t1) == expected_period,
                  $sformatf("%s: periodo medido=%0t ns esperado=%0t ns",
                            name, (t2-t1), expected_period));

            ctrl_value = 32'h00000000;
            axi_write(32'h00000000, ctrl_value, 4'b0001, 0);
        end
    endtask

    ///Extra
    // Diagnostico de escrituras hacia PWM_REGISTERS
    always @(posedge clk) begin
        if (DUT.wr_en) begin
            $display(
                "[DEBUG WRITE] t=%0t addr=%h data=%h strb=%b",
                $time,
                DUT.wr_addr,
                DUT.wr_data,
                DUT.wr_strb
            );
        end
    end
    // Diagnostico de flancos PWM
    always @(posedge DUT.raw_pwm_A) begin
        $display(
            "[DEBUG PWM] t=%0t | carrier=%0d | max_count=%0d | threshold_A=%0d | duty_ref=%0d | raw_A=%b",
            $time,
            DUT.carrier,
            DUT.max_count,
            DUT.MODULATOR.threshold_a,
            DUT.duty_ref,
            DUT.raw_pwm_A
        );
    end

    // ============================================================
    // Testbench principal
    // ============================================================
    logic [31:0] read_value;
    integer i;
    integer dead_cycles;

    initial begin
        $timeformat(-9, 0, " ns", 10);

        $display("");
        $display("==================================================");
        $display(" PWM_CONTROLLER - TESTBENCH INTEGRAL");
        $display(" Clock = 100 MHz | Tclk = 10 ns");
        $display(" Reset externo activo en bajo");
        $display("==================================================");

        // ---------------- RESET ----------------
        rst = 1'b0;
        s_axi_bready = 1'b0;
        s_axi_rready = 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b1;
        repeat (3) @(posedge clk);

        axi_read(32'h00, read_value);
        check_equal(read_value, 32'h00000000, "Reset CTRL");
        axi_read(32'h04, read_value);
        check_equal(read_value, 32'h00000000, "Reset DUTY_REF");

        check((pwm_AH|pwm_AL|pwm_BH|pwm_BL) == 1'b0,
              "Salidas puente H apagadas despues del reset");

        // ---------------- AXI: escritura/lectura ----------------
        $display("\n--- AXI-LITE Y REGISTROS ---");

        axi_write(32'h00, 32'h00000002, 4'b0001, 0);
        expect_read(32'h00, 32'h00000002, "CTRL frecuencia 10 kHz");

        axi_write(32'h00, 32'h00000004, 4'b0001, 1);
        expect_read(32'h00, 32'h00000004, "CTRL frecuencia 20 kHz, AW primero");

        axi_write(32'h00, 32'h00000000, 4'b0001, 2);
        expect_read(32'h00, 32'h00000000, "CTRL 5 kHz, W primero");

        axi_write(32'h04, 32'h00001234, 4'b0011, 0);
        expect_read(32'h04, 32'h00001234, "DUTY_REF 1234");

        axi_write(32'h04, 32'h0000AAAA, 4'b0011, 0);
        axi_write(32'h04, 32'h00000056, 4'b0001, 0);
        expect_read(32'h04, 32'h0000AA56, "WSTRB solo byte bajo");

        axi_write(32'h00000004, 32'h0000BB00, 4'b0010, 0);
        $display("[TB CHECK] Escritura byte alto enviada: data=%08h strb=%b",
         32'h0000BB00, 4'b0010);
        expect_read(32'h04, 32'h0000BB56, "WSTRB solo byte alto");

        // Strobe cero: no debe modificar el registro.
        axi_write(32'h04, 32'h00001234, 4'b0000, 0);
        expect_read(32'h04, 32'h0000BB56, "WSTRB cero no modifica DUTY_REF");

        // Direccion no implementada debe leer cero y no alterar registros.
        axi_write(32'h08, 32'hFFFFFFFF, 4'b1111, 0);
        expect_read(32'h08, 32'h00000000, "Lectura direccion no implementada");
        expect_read(32'h04, 32'h0000BB56, "Direccion no valida no altera DUTY_REF");

        // ---------------- ENABLE / RUNNING ----------------
        $display("\n--- CONTROL ENABLE / RUNNING ---");

        axi_write(32'h00, 32'h00000001, 4'b0001, 0);
        expect_read(32'h00, 32'h00000009, "ENABLE y RUNNING activos");

        axi_write(32'h00, 32'h00000007, 4'b0001, 0);
        expect_read(32'h00, 32'h00000007, "Frecuencia invalida no activa RUNNING");

        check(DUT.max_count == 0, "Frecuencia 11 produce max_count cero");
        check((pwm_AH|pwm_AL|pwm_BH|pwm_BL) == 1'b0,
              "Frecuencia invalida apaga salidas");

        // ---------------- FRECUENCIAS ----------------
        $display("\n--- FRECUENCIA PWM ---");
        measure_pwm_period(2'b00, 10000, "5 kHz");
        measure_pwm_period(2'b01, 5000,  "10 kHz");
        measure_pwm_period(2'b10, 2500,  "20 kHz");

        // ---------------- MODULADOR ----------------
        $display("\n--- MODULADOR UNIPOLAR ---");

        // Seleccionar 5 kHz, duty cero y habilitar.
        axi_write(32'h00, 32'h00000000, 4'b0001, 0);
        axi_write(32'h04, 32'h00000000, 4'b0011, 0);
        axi_write(32'h00, 32'h00000001, 4'b0001, 0);
        repeat (3) @(posedge clk);

        check(DUT.max_count == 10000, "Modulador configurado a 5 kHz");
        check(DUT.raw_pwm_A === 1'b1 && DUT.raw_pwm_B === 1'b1,
              "Duty cero: A y B comienzan en estado alto");

        // Referencia positiva maxima: A casi 100%, B casi 0%.
        axi_write(32'h04, 32'h00007FFF, 4'b0011, 0);
        repeat (2) @(posedge clk);
        check(DUT.raw_pwm_A === 1'b1, "Duty +32767: rama A alta en carrier bajo");
        check(DUT.raw_pwm_B === 1'b0, "Duty +32767: rama B baja en carrier bajo");

        // Referencia negativa maxima: A casi 0%, B casi 100%.
        axi_write(32'h04, 32'h00008000, 4'b0011, 0);
        repeat (2) @(posedge clk);
        check(DUT.raw_pwm_A === 1'b0, "Duty -32768: rama A baja en carrier bajo");
        check(DUT.raw_pwm_B === 1'b1, "Duty -32768: rama B alta en carrier bajo");

        // Duty cero: ambos comparadores tienen umbral de 50%.
        axi_write(32'h04, 32'h00000000, 4'b0011, 0);
        repeat (2) @(posedge clk);
        check(DUT.raw_pwm_A === 1'b1 && DUT.raw_pwm_B === 1'b1,
              "Duty cero: ambas referencias simetricas");

        // Deshabilitar debe forzar raw PWM a cero y las cuatro salidas a cero.
        axi_write(32'h00, 32'h00000000, 4'b0001, 0);
        repeat (3) @(posedge clk);
        check(DUT.raw_pwm_A === 1'b0 && DUT.raw_pwm_B === 1'b0,
              "Disable fuerza raw PWM a cero");
        check((pwm_AH|pwm_AL|pwm_BH|pwm_BL) == 1'b0,
              "Disable apaga las cuatro salidas");

        // ---------------- DEAD TIME AISLADO ----------------
        $display("\n--- DEAD TIME GENERATOR: PRUEBA AISLADA ---");

        dt_rst = 1'b1;
        dt_enable = 1'b0;
        dt_raw_A = 1'b0;
        dt_raw_B = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        dt_rst = 1'b0;
        dt_enable = 1'b1;
        repeat (3) @(posedge clk);

        check(dt_AH === 1'b0 && dt_AL === 1'b1,
              "Estado inicial rama A complementario");
        check(dt_BH === 1'b0 && dt_BL === 1'b1,
              "Estado inicial rama B complementario");

        // Cambio A: ambas salidas deben quedar apagadas durante 50 ciclos.
        @(negedge clk);
        dt_raw_A = 1'b1;
        @(posedge clk);
        #1;
        check(dt_AH === 1'b0 && dt_AL === 1'b0,
              "Cambio A inicia blanking: ambas salidas apagadas");

        dead_cycles = 0;
        while ((dt_AH === 1'b0) && (dt_AL === 1'b0) &&
               (dead_cycles < 60)) begin
            @(posedge clk);
            #1;
            dead_cycles = dead_cycles + 1;
        end

        check(dead_cycles == 50,
              $sformatf("Dead time rama A = %0d ciclos (esperado 50)", dead_cycles));
        check(dt_AH === 1'b1 && dt_AL === 1'b0,
              "Rama A conmuta al estado solicitado despues del dead time");

        // Cambio de vuelta en A.
        @(negedge clk);
        dt_raw_A = 1'b0;
        @(posedge clk);
        #1;
        check(dt_AH === 1'b0 && dt_AL === 1'b0,
              "Segundo cambio A inicia blanking");
        repeat (50) @(posedge clk);
        #1;
        check(dt_AH === 1'b0 && dt_AL === 1'b1,
              "Rama A vuelve al estado complementario");

        // Verificar también rama B.
        @(negedge clk);
        dt_raw_B = 1'b1;
        @(posedge clk);
        #1;
        check(dt_BH === 1'b0 && dt_BL === 1'b0,
              "Cambio B inicia blanking");
        repeat (50) @(posedge clk);
        #1;
        check(dt_BH === 1'b1 && dt_BL === 1'b0,
              "Rama B conmuta despues de 50 ciclos");

        // Reset/disable del generador de dead time.
        dt_enable = 1'b0;
        #1;
        check((dt_AH|dt_AL|dt_BH|dt_BL) == 1'b0,
              "Disable del dead time apaga todas las salidas");

        // ---------------- RESET DURANTE OPERACION ----------------
        $display("\n--- RESET DURANTE OPERACION ---");

        axi_write(32'h04, 32'h000055AA, 4'b0011, 0);
        axi_write(32'h00, 32'h00000001, 4'b0001, 0);
        repeat (5) @(posedge clk);

        @(negedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b1;
        repeat (3) @(posedge clk);

        axi_read(32'h00, read_value);
        check_equal(read_value, 32'h00000000, "Reset operativo CTRL");
        axi_read(32'h04, read_value);
        check_equal(read_value, 32'h00000000, "Reset operativo DUTY_REF");
        check((pwm_AH|pwm_AL|pwm_BH|pwm_BL) == 1'b0,
              "Reset operativo apaga salidas");

        // ---------------- RESULTADO ----------------
        $display("");
        $display("==================================================");
        $display(" RESULTADO FINAL");
        $display(" Pruebas aprobadas: %0d", tests_passed);
        $display(" Pruebas fallidas : %0d", tests_failed);
        $display("==================================================");

        if (tests_failed == 0) begin
            $display(" TODAS LAS PRUEBAS COMPLETADAS SIN ERRORES");
            $finish;
        end
        else begin
            $fatal(1, "TESTBENCH FALLIDO: revisar errores anteriores");
        end
    end

    // Watchdog global
    initial begin
        #5000000;
        $fatal(1, "WATCHDOG: el testbench excedio el tiempo limite");
    end

endmodule
