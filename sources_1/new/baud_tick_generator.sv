`timescale 1ns / 1ps


module baud_tick_generator (
    input  logic clk,
    input  logic rst,
    output logic b_tick
);

    parameter BAUDRATE = 9600 * 16;
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;

    logic [$clog2(BAUD_COUNT)-1:0] counter_reg;
    logic b_tick_reg;

    assign b_tick = b_tick_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick_reg  <= 0;
        end else begin
            if (counter_reg == BAUD_COUNT - 1) begin
                counter_reg <= 0;
                b_tick_reg  <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                b_tick_reg  <= 1'b0;
            end
        end
    end


endmodule
