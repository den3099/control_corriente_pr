module PWM_FREQUENCY_GENERATOR (

    input logic clk,
    input logic rst,

    input logic enable,
    input logic [1:0] freq_sel,

    output logic [13:0] carrier,
    output logic [13:0] max_count

);

    logic direction_up;

    // --------------------------------------------
    // Selección de frecuencia
    // --------------------------------------------

    always_comb begin

        case (freq_sel)

            2'b00: max_count = 14'd10000;

            2'b01: max_count = 14'd5000;

            2'b10: max_count = 14'd2500;

            default: max_count = 14'd0;

        endcase

    end

    // --------------------------------------------
    // Contador triangular up/down
    // --------------------------------------------

    always_ff @(posedge clk) begin

        if (rst || !enable || (max_count == 0)) begin

            carrier <= 14'd0;

            direction_up <= 1'b1;

        end

        else begin

            if (direction_up) begin

                if (carrier == max_count) begin

                    direction_up <= 1'b0;

                    carrier <= carrier - 1'b1;

                end

                else begin

                    carrier <= carrier + 1'b1;

                end

            end

            else begin

                if (carrier == 0) begin

                    direction_up <= 1'b1;

                    carrier <= carrier + 1'b1;

                end

                else begin

                    carrier <= carrier - 1'b1;

                end

            end

        end

    end

endmodule