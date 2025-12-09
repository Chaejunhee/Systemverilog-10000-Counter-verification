`timescale 1ns / 1ps

module button_debounce (
    input  logic clk,
    input  logic rst,
    input  logic i_button,
    output logic o_button
);
    localparam  [2:0] IDLE = 3'b000,A=3'b001,B=3'b010,C=3'b011,D=3'b100;

    logic w_clk_1Mhz;

    logic flag_reg, flag_next;
    logic [2:0] state_next, state_reg;
    logic o_btn_reg, o_btn_next;
    logic o_btn_buf;

    assign o_button = (~o_btn_buf & o_btn_reg);

    clk_div_1Mhz U_CLK_1MHZ (
        .clk(clk),
        .rst(rst),
        .clk_1Mhz(w_clk_1Mhz)
    );

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            o_btn_buf <= 0;
        end else begin
            o_btn_buf <= o_btn_reg;
        end
    end

    always_ff @(posedge w_clk_1Mhz, posedge rst) begin
        if (rst) begin
            state_reg <= IDLE;
            flag_reg  <= 1'b0;
            o_btn_reg <= 1'b0;
        end else begin
            state_reg <= state_next;
            flag_reg  <= flag_next;
            o_btn_reg <= o_btn_next;
            // o_btn_buf <= o_btn_reg;
        end
    end



    always_comb begin
        state_next = state_reg;
        flag_next  = flag_reg;
        o_btn_next = 1'b0;
        case (state_reg)
            IDLE: begin
                flag_next = 0;  //moore output
                if (i_button) begin  //mealy output
                    state_next = A;
                end else begin
                    state_next = state_reg;
                end
            end
            A: begin
                flag_next = 0;
                if (i_button) begin
                    state_next = B;
                end else begin
                    state_next = IDLE;
                end
            end
            B: begin
                flag_next = 0;
                if (i_button) begin
                    state_next = C;
                end else begin
                    state_next = IDLE;
                end
            end
            C: begin
                flag_next = 0;
                if (i_button) begin
                    o_btn_next = 1'b1;
                    state_next = D;
                end else begin
                    state_next = IDLE;
                end
            end
            D: begin
                flag_next = 1;
                if (i_button) begin
                    state_next = state_reg;
                end else begin
                    state_next = IDLE;
                end
            end
        endcase
    end

endmodule


module clk_div_1Mhz (
    input  logic clk,
    input  logic rst,
    output logic clk_1Mhz
);

    reg o_clk_reg;
    reg [$clog2(100)-1:0] r_count;

    assign clk_1Mhz = o_clk_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            o_clk_reg <= 0;
            r_count   <= 0;
        end else begin
            if (r_count == 100 - 1) begin
                o_clk_reg <= 1;
                r_count   <= 0;
            end else begin
                r_count <= r_count + 1;
                if (r_count == 100 / 2 - 1) begin
                    o_clk_reg <= 0;
                end
            end
        end

    end

endmodule
