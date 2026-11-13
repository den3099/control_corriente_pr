module AXI_LITE_INTERFACE (

    input logic clk,
    input logic rst,

    // Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // Write Response Channel
    output logic [1:0] s_axi_bresp,
    output logic       s_axi_bvalid,
    input  logic       s_axi_bready,

    // Read Address Channel
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // Read Data Channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Interfaz con PWM_REGISTERS
    output logic        wr_en,
    output logic [7:0]  wr_addr,
    output logic [31:0] wr_data,
    output logic [3:0]  wr_strb,

    output logic [7:0]  rd_addr,
    input  logic [31:0] rd_data

);

    // --------------------------------------------
    // Estados de escritura
    // --------------------------------------------

    typedef enum logic {

        IDLE,
        WRITE_RESPONSE

    } write_state_t;

    write_state_t state;

    // --------------------------------------------
    // Registros temporales
    // --------------------------------------------

    logic [31:0] awaddr_reg;
    logic [31:0] wdata_reg;
    logic [3:0]  wstrb_reg;

    logic addr_received;
    logic data_received;

    // --------------------------------------------
    // Handshake
    // --------------------------------------------

    logic aw_handshake;
    logic w_handshake;

    assign aw_handshake = s_axi_awvalid && s_axi_awready;
    assign w_handshake  = s_axi_wvalid  && s_axi_wready;

    // --------------------------------------------
    // Señales de salida
    // --------------------------------------------

    always_comb begin

        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;

        s_axi_bvalid = (state == WRITE_RESPONSE);

        s_axi_bresp = 2'b00;

        if (state == IDLE) begin

            s_axi_awready = !addr_received;
            s_axi_wready  = !data_received;

        end

    end

    // --------------------------------------------
    // Máquina de estados de escritura
    // --------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            state <= IDLE;

            awaddr_reg <= '0;
            wdata_reg  <= '0;
            wstrb_reg  <= '0;

            addr_received <= 1'b0;
            data_received <= 1'b0;

            wr_en   <= 1'b0;
            wr_addr <= '0;
            wr_data <= '0;
            wr_strb <= '0;

        end

        else begin

            wr_en <= 1'b0;

            case (state)

                IDLE: begin

                    if (aw_handshake) begin

                        awaddr_reg <= s_axi_awaddr;
                        addr_received <= 1'b1;

                    end

                    if (w_handshake) begin

                        wdata_reg <= s_axi_wdata;
                        wstrb_reg <= s_axi_wstrb;

                        data_received <= 1'b1;

                    end

                    if ((addr_received || aw_handshake) &&
                        (data_received || w_handshake)) begin

                        wr_addr <= aw_handshake ?
                                   s_axi_awaddr[7:0] :
                                   awaddr_reg[7:0];

                        wr_data <= w_handshake ?
                                   s_axi_wdata :
                                   wdata_reg;

                        wr_strb <= w_handshake ?
                                   s_axi_wstrb :
                                   wstrb_reg;

                        wr_en <= 1'b1;

                        addr_received <= 1'b0;
                        data_received <= 1'b0;

                        state <= WRITE_RESPONSE;

                    end

                end

                WRITE_RESPONSE: begin

                    if (s_axi_bready) begin

                        state <= IDLE;

                    end

                end

            endcase

        end

    end

    // --------------------------------------------
    // Lectura AXI
    // --------------------------------------------

    assign rd_addr = s_axi_araddr[7:0];

    assign s_axi_arready = !s_axi_rvalid;

    assign s_axi_rresp = 2'b00;

    always_ff @(posedge clk) begin

        if (rst) begin

            s_axi_rdata  <= '0;
            s_axi_rvalid <= 1'b0;

        end

        else begin

            if (s_axi_arvalid && s_axi_arready) begin

                s_axi_rdata <= rd_data;
                s_axi_rvalid <= 1'b1;

            end

            else if (s_axi_rvalid && s_axi_rready) begin

                s_axi_rvalid <= 1'b0;

            end

        end

    end

endmodule