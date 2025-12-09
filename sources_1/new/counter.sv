`timescale 1ns / 1ps

module counter_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       i_mode,
    input  logic       i_enable,
    input  logic       i_clear,
    input  logic       rx,
    output logic       tx,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data
);
    logic [13:0] w_counter;
    logic w_enable, w_clear, w_mode;
    logic w_cu_enable, w_cu_clear, w_cu_mode;
    logic [7:0] w_rx_data;
    logic w_rx_done;

    fnd_controller U_FND_CNTL (
        .clk(clk),
        .rst(rst),
        .counter(w_counter),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );
    Datapath_10000 U_DP (
        .clk(clk),
        .rst(rst),
        .i_mode(w_cu_mode),
        .i_enable(w_cu_enable),
        .i_clear(w_cu_clear),
        .counter(w_counter)
    );
    counter_control_unit U_CU (
        .clk(clk),
        .rst(rst),
        .i_enable(w_enable),
        .i_clear(w_clear),
        .i_mode(w_mode),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .o_enable(w_cu_enable),
        .o_clear(w_cu_clear),
        .o_mode(w_cu_mode)
    );


    uart_top U_UART_TOP (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );


    button_debounce U_BTN_L (
        .clk(clk),
        .rst(rst),
        .i_button(i_clear),
        .o_button(w_clear)
    );
    button_debounce U_BTN_R (
        .clk(clk),
        .rst(rst),
        .i_button(i_enable),
        .o_button(w_enable)
    );
    button_debounce U_BTN_U (
        .clk(clk),
        .rst(rst),
        .i_button(i_mode),
        .o_button(w_mode)
    );


endmodule

module Datapath_10000 (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_mode,
    input  logic        i_enable,
    input  logic        i_clear,
    output logic [13:0] counter

);
    logic w_tick;

    tick_generator_10hz U_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .i_enable(i_enable),
        .i_clear(i_clear),
        .o_tick(w_tick)
    );
    counter_10000 U_COUNTER_10000 (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick),
        .mode(i_mode),
        .i_clear(i_clear),
        .counter(counter)
    );

endmodule

module tick_generator_10hz (
    input  logic clk,
    input  logic rst,
    input  logic i_enable,
    input  logic i_clear,
    output logic o_tick
);

    localparam F_COUNT = 100_000_000 / 50_000_000;  //50Mhz for dp verifi
    // localparam F_COUNT = 100_000_000/10; //10hz normal

    logic [$clog2(F_COUNT)-1:0] r_count;

    always_ff @(posedge clk, posedge rst) begin
        if (rst || i_clear) begin
            o_tick  <= 0;
            r_count <= 0;
        end else if (i_enable == 1) begin
            if (r_count == F_COUNT - 1) begin
                r_count <= 0;
                o_tick  <= 1;
            end else begin
                r_count <= r_count + 1;
                o_tick  <= 0;
            end
        end else begin
            r_count <= r_count;
            o_tick  <= 0;
        end
    end

endmodule

module counter_10000 (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_tick,
    input  logic        mode,
    input  logic        i_clear,
    output logic [13:0] counter
);
    logic [13:0] counter_reg;

    assign counter = counter_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst || i_clear) begin
            counter_reg <= 0;
        end else begin
            if (mode == 1'b1) begin
                if (i_tick) begin
                    if (counter_reg == 10000 - 1) begin
                        counter_reg <= 0;
                    end else begin
                        counter_reg <= counter_reg + 1;
                    end
                end
            end else begin
                if (i_tick) begin
                    if (counter_reg == 0) begin
                        counter_reg <= 10000 - 1;
                    end else begin
                        counter_reg <= counter_reg - 1;
                    end
                end
            end
        end
    end

endmodule

