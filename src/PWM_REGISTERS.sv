module PWM_REGISTERS (

    input logic clk,
    input logic rst,

    // Interfaz de escritura
    input logic        wr_en,
    input logic [7:0]  wr_addr,
    input logic [31:0] wr_data,
    input logic [3:0]  wr_strb,

    // Interfaz de lectura
    input  logic [7:0]  rd_addr,
    output logic [31:0] rd_data,

    // Salidas de configuración
    output logic enable,
    output logic [1:0] freq_sel,
    output logic running,

    output logic signed [15:0] duty_ref

);

    // --------------------------------------------
    // Registros internos de 32 bits
    // --------------------------------------------

    logic [31:0] control_reg;
    logic [31:0] reference_reg;

    // --------------------------------------------
    // Extracción de señales
    // --------------------------------------------

    assign enable   = control_reg[0];
    assign freq_sel = control_reg[2:1];

    assign duty_ref = reference_reg[15:0];

    // running representa que el PWM está habilitado
    // y que la frecuencia seleccionada es válida.

    assign running = enable && (freq_sel != 2'b11);

    // --------------------------------------------
    // Escritura de registros
    // --------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            control_reg   <= 32'h00000000;
            reference_reg <= 32'h00000000;

        end

        else if (wr_en) begin

            case (wr_addr)

                // Registro de control: 0x00
                8'h00: begin

                    if (wr_strb[0]) begin

                        control_reg[0]   <= wr_data[0];
                        control_reg[2:1] <= wr_data[2:1];

                    end

                end

                // Registro de referencia: 0x04
                8'h04: begin

                    if (wr_strb[0]) begin

                        reference_reg[7:0] <= wr_data[7:0];

                    end

                    if (wr_strb[1]) begin

                        reference_reg[15:8] <= wr_data[15:8];

                    end

                end

                default: begin

                end

            endcase

        end

    end

    // --------------------------------------------
    // Lectura de registros
    // --------------------------------------------

    always_comb begin

        rd_data = 32'h00000000;

        case (rd_addr)

            8'h00: begin

                rd_data = control_reg;

                // Bit 3: running, solo lectura
                rd_data[3] = running;

            end

            8'h04: begin

                rd_data = reference_reg;

            end

            default: begin

                rd_data = 32'h00000000;

            end

        endcase

    end

endmodule