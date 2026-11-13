module UNIPOLAR_MODULATOR (

    input logic enable,

    input logic signed [15:0] duty_ref,

    input logic [13:0] carrier,
    input logic [13:0] max_count,

    output logic raw_pwm_A,
    output logic raw_pwm_B

);

    // --------------------------------------------
    // Extensión de la referencia
    // --------------------------------------------

    logic signed [17:0] duty_extended;

    logic signed [17:0] numerator_a_signed;
    logic signed [17:0] numerator_b_signed;

    logic [16:0] numerator_a;
    logic [16:0] numerator_b;

    // --------------------------------------------
    // Variables para escalamiento
    // --------------------------------------------

    logic [30:0] max_count_extended;

    logic [30:0] numerator_a_extended;
    logic [30:0] numerator_b_extended;

    logic [30:0] product_a;
    logic [30:0] product_b;

    logic [14:0] threshold_a;
    logic [14:0] threshold_b;

    // --------------------------------------------
    // Extensión de la referencia Q1.15
    // --------------------------------------------

    always_comb begin

        duty_extended = {
            {2{duty_ref[15]}},
            duty_ref
        };

        // Numeradores para las referencias unipolares

        numerator_a_signed = 18'sd32768 + duty_extended;

        numerator_b_signed = 18'sd32768 - duty_extended;

        numerator_a = numerator_a_signed[16:0];

        numerator_b = numerator_b_signed[16:0];

    end

    // --------------------------------------------
    // Conversión a escala de la portadora
    // --------------------------------------------

    always_comb begin

        max_count_extended = {17'd0, max_count};

        numerator_a_extended = {14'd0, numerator_a};

        numerator_b_extended = {14'd0, numerator_b};

        product_a = max_count_extended * numerator_a_extended;

        product_b = max_count_extended * numerator_b_extended;

        // División entre 65536 mediante desplazamiento

        threshold_a = product_a[30:16];

        threshold_b = product_b[30:16];

    end

    // --------------------------------------------
    // Comparadores PWM
    // --------------------------------------------

    always_comb begin

        raw_pwm_A = 1'b0;
        raw_pwm_B = 1'b0;

        if (enable && (max_count != 0)) begin

            raw_pwm_A = ({1'b0, carrier} < threshold_a);

            raw_pwm_B = ({1'b0, carrier} < threshold_b);

        end

    end

endmodule