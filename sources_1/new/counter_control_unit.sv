`timescale 1ns / 1ps

module counter_control_unit (
    input  logic       clk,
    input  logic       rst,
    input  logic       i_enable,
    input  logic       i_clear,
    input  logic       i_mode,
    input  logic [7:0] rx_data,
    input  logic       rx_done,
    output logic       o_enable,
    output logic       o_clear,
    output logic       o_mode
);


    localparam RUN = 1'b0, STOP = 1'b1;
    localparam MODE_UP = 1'b0, MODE_DOWN = 1'b1;
    localparam IDLE = 1'b0, CLEAR = 1'b1;


    logic enable_reg, enable_next;
    logic mode_reg, mode_next;
    logic clear_reg, clear_next;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            enable_reg <= RUN;
            mode_reg   <= MODE_UP;
            clear_reg  <= IDLE;
        end else begin
            enable_reg <= enable_next;
            mode_reg   <= mode_next;
            clear_reg  <= clear_next;
        end
    end

    always_comb begin
        enable_next = enable_reg;
        mode_next   = mode_reg;
        clear_next  = clear_reg;

        if (rx_done) begin
            case (rx_data)
                "r": begin
                    o_enable = ~o_enable;
                    enable_next = ~enable_reg;
                end
                "c": begin
                    o_clear = ~o_clear;
                    clear_next = ~clear_reg;
                end
                "m": begin
                    o_mode = ~o_mode;
                    mode_next = ~mode_reg;
                end
            endcase
        end

        case (enable_reg)
            RUN: begin
                o_enable = 1;
                if (i_enable) begin
                    enable_next = STOP;
                end
            end
            STOP: begin
                o_enable = 0;
                if (i_enable) begin
                    enable_next = RUN;
                end
            end
        endcase

        case (mode_reg)
            MODE_UP: begin
                o_mode = 1;
                if (i_mode) begin
                    mode_next = MODE_DOWN;
                end
            end
            MODE_DOWN: begin
                o_mode = 0;
                if (i_mode) begin
                    mode_next = MODE_UP;
                end
            end
        endcase

        case (clear_reg)
            IDLE: begin
                o_clear = 0;
                if (i_clear) begin
                    clear_next = CLEAR;
                end
            end
            CLEAR: begin
                o_clear = 1;
                clear_next = IDLE;
            end
        endcase
    end

endmodule
