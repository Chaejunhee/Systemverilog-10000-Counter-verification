`timescale 1ns / 1ps

module uart_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic       tx,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    logic w_b_tick;
    logic w_r_done;
    logic [7:0] w_r_data, w_rx_fifo_rdata, w_tx_fifo_rdata;
    logic w_rx_empty, w_tx_fifo_full, w_tx_fifo_empty, w_tx_busy;

    assign rx_data = w_rx_fifo_rdata;
    assign rx_done = ~w_rx_empty;
    
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~w_tx_fifo_empty),
        .tx_data(w_tx_fifo_rdata),
        .b_tick(w_b_tick),
        .tx_busy(w_tx_busy),
        .tx(tx)
    );
    fifo U_FIFO_TX (
        .clk  (clk),
        .rst  (rst),
        .wr   (~w_rx_empty),
        .rd   (~w_tx_busy),
        .wdata(w_rx_fifo_rdata),
        .rdata(w_tx_fifo_rdata),
        .full (w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );

    fifo U_FIFO_RX (
        .clk  (clk),
        .rst  (rst),
        .wr   (w_r_done),
        .rd   (~w_tx_fifo_full),
        .wdata(w_r_data),
        .rdata(w_rx_fifo_rdata),
        .full (),
        .empty(w_rx_empty)
    );
    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(w_r_data),
        .rx_done(w_r_done)
    );

    baud_tick_generator U_B_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

endmodule
