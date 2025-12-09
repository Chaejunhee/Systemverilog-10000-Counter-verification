`timescale 1ns / 1ps

module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    input  logic       b_tick,
    output logic       tx_busy,
    output logic       tx
);

    localparam [1:0] IDLE = 2'b00, TX_START = 2'b01, TX_DATA = 2'b10, TX_STOP= 2'b11;

    logic [1:0] state_reg, state_next;
    logic tx_busy_reg, tx_busy_next;
    logic tx_reg, tx_next;
    logic [7:0] data_buf_reg, data_buf_next;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx_busy = tx_busy_reg;
    assign tx = tx_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            tx_busy_reg    <= 1'b0;
            tx_reg         <= 1'b1;
            data_buf_reg   <= 8'h00;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg    <= 3'b000;
        end else begin
            state_reg      <= state_next;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end

    always_comb  begin
        //initialize
        state_next      = state_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    b_tick_cnt_next = 0;
                    data_buf_next = tx_data;
                    state_next = TX_START;
                end
            end
            TX_START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        state_next      = TX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 0;
                            state_next = TX_STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
