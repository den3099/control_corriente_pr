module DEAD_TIME_GENERATOR #(

    parameter integer DEAD_TIME_CYCLES = 50

)(

    input logic clk,
    input logic rst,

    input logic enable,

    input logic raw_pwm_A,
    input logic raw_pwm_B,

    output logic pwm_AH,
    output logic pwm_AL,

    output logic pwm_BH,
    output logic pwm_BL

);

    // --------------------------------------------
    // Señales internas para ambas ramas
    // --------------------------------------------

    logic [1:0] raw_pwm;
    logic [1:0] raw_previous;

    logic [1:0] next_state;
    logic [1:0] blanking;

    localparam integer DT_WIDTH =
        (DEAD_TIME_CYCLES <= 1) ? 1 : $clog2(DEAD_TIME_CYCLES);

    logic [DT_WIDTH-1:0] counter [0:1];

    // --------------------------------------------
    // Asociación de señales
    // --------------------------------------------

    assign raw_pwm[0] = raw_pwm_A;
    assign raw_pwm[1] = raw_pwm_B;

    // --------------------------------------------
    // Control independiente de cada rama
    // --------------------------------------------

    genvar i;

    generate

        for (i = 0; i < 2; i = i + 1) begin : DEAD_TIME_BRANCH

            always_ff @(posedge clk) begin

                if (rst || !enable) begin

                    raw_previous[i] <= raw_pwm[i];

                    next_state[i] <= raw_pwm[i];

                    blanking[i] <= 1'b0;

                    counter[i] <= '0;

                end

                else begin

                    raw_previous[i] <= raw_pwm[i];

                    // Detección de cambio
                    if (raw_pwm[i] != raw_previous[i]) begin

                        next_state[i] <= raw_pwm[i];

                        blanking[i] <= 1'b1;

                        counter[i] <= '0;

                    end

                    // Conteo del tiempo muerto
                    else if (blanking[i]) begin

                        if (counter[i] >= DEAD_TIME_CYCLES - 1) begin

                            blanking[i] <= 1'b0;

                            counter[i] <= '0;

                        end

                        else begin

                            counter[i] <= counter[i] + 1'b1;

                        end

                    end

                end

            end

        end

    endgenerate

    // --------------------------------------------
    // Salidas de la rama A
    // --------------------------------------------

    always_comb begin

        pwm_AH = 1'b0;
        pwm_AL = 1'b0;

        if (enable && !rst && !blanking[0]) begin

            pwm_AH = next_state[0];

            pwm_AL = !next_state[0];

        end

    end

    // --------------------------------------------
    // Salidas de la rama B
    // --------------------------------------------

    always_comb begin

        pwm_BH = 1'b0;
        pwm_BL = 1'b0;

        if (enable && !rst && !blanking[1]) begin

            pwm_BH = next_state[1];

            pwm_BL = !next_state[1];

        end

    end

endmodule