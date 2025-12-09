`timescale 1ns / 1ps


module tb_counter_top ();

    localparam US = 1_000, MS = 1_000_000, SEC = 1_000_000_000;
    integer BIT_PERIOD = 104160;

    logic clk, rst;
    logic i_mode, i_enable, i_clear;
    logic rx, tx;
    logic [3:0] fnd_com;
    logic [7:0] fnd_data;
    int count = 0;
    int cs;

    counter_top dut (
        .clk     (clk),
        .rst     (rst),
        .i_mode  (i_mode),
        .i_enable(i_enable),
        .i_clear (i_clear),
        .rx      (rx),
        .tx      (tx),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data)
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        rx = 1;
        i_mode = 0;
        i_enable = 0;
        i_clear = 0;
        #10;
        rst = 0;
        #10;
        //button input test
        #(101 * MS);
        // press_button(i_enable);
        // #(101 * MS);
        // press_button(i_mode);
        // press_button(i_enable);
        // #(101 * MS);
        // #(101 * MS);
        // press_button(i_clear);
        // #(101 * MS);
        // $stop;
        // //button random input test
        // random_button_task(15);
        // #10;

        //uart random input test
        send_uart("r");
        #(101 * MS);
        send_uart("m");
        send_uart("r");
        #(101 * MS);
        #(101 * MS);
        send_uart("c");
        #(101 * MS);
        $stop;
        //UART random input test
        random_uart_task(10);
        #10;
        $stop;
    end


    //ref는 SystemVerilog의 태스크(task)나 함수(function)에서 인자를 전달하는 방식 중 하나로
    // **참조에 의한 전달(pass by reference)**을 의미합니다.
    //ref가 없다면 pass by value
    //ref를 사용하기 위해서는 automatic 사용해야한다 

    //automatic은  ref 인자 사용 가능: ref 인자는 외부 변수의 직접 참조를 전달하므로,
    // 이 참조가 여러 동시 호출에서 충돌하지 않도록 automatic 태스크에서만 허용됩니다.

    //to recognize button_debouncer
    task automatic press_button(ref logic button);

        button = 1;
        #(4 * US);
        button = 0;
    endtask  //press_button

    //randomize button press task
    task random_button_task(int run_count);

        repeat (run_count) begin
            cs = $unsigned($random) % 3;
            case (cs)
                0: press_button(i_clear);
                1: press_button(i_mode);
                2: press_button(i_enable);
            endcase
            #(100 * MS);
            count++;
            $display("%d : cs = %d", count, cs);
        end

    endtask  //random_button_task

    // task tx -> rx send_uart
    task send_uart(input [7:0] send_data);
        integer i;
        begin
            // start bit
            rx = 0;
            #(BIT_PERIOD);  // uart 9600bps bit time
            // data bit
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BIT_PERIOD);  // uart 9600bps bit time 
            end
            // stopbit
            rx = 1;
            #(BIT_PERIOD);  // uart 9600bps bit time
        end
    endtask

    //randomize send uart task
    task random_uart_task(int run_count);

        repeat (run_count) begin
            cs = $unsigned($random) % 3;
            case (cs)
                0: send_uart("c");
                1: send_uart("m");
                2: send_uart("r");
            endcase
            #(100 * MS);
            count++;
            $display("%d : cs = %d", count, cs);
        end

    endtask  //random uart task
endmodule
