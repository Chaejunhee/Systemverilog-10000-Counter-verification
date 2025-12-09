`timescale 1ns / 1ps

interface uart_interface;

    logic clk;
    logic rst;
    logic rx;
    logic tx;

endinterface

class transaction;
    rand bit [7:0] data_8bit;
    logic          rx;
    logic          tx;

    task display(string name_s);
        $display("%t, [%s] operate", $time, name_s);
    endtask  //display

    task send_display();
        $display("rx start | Data Genrated : %d", data_8bit);
    endtask  //display

    task receive_display();
        $display("tx finish | Data Received : %d", data_8bit);
    endtask
endclass  //transaction

class generator;

    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_event;

    int total_count;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            total_count++;
            trans = new();
            assert (trans.randomize())
            else $error("[GEN] randomize() error!!");
            trans.send_display();
            gen2drv_mbox.put(trans);
            trans.display("GEN");
            @(gen_next_event);

        end
    endtask  //run

endclass  //generator

class driver;

    localparam BIT_PERIOD = 104166;

    virtual uart_interface uart_if;
    transaction trans;
    event gen_next_event;
    event mon_next_event;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) drv2scb_mbox;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) drv2scb_mbox,
                 virtual uart_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.drv2scb_mbox = drv2scb_mbox;
        this.uart_if = uart_if;

    endfunction  //new()

    // task tx -> rx send_uart
    task send_uart(input [7:0] send_data);
        integer i;
        begin
            // start bit
            uart_if.rx = 0;
            #(BIT_PERIOD);  // uart 9600bps bit time
            // data bit
            for (i = 0; i < 8; i = i + 1) begin
                uart_if.rx = send_data[i];
                #(BIT_PERIOD);  // uart 9600bps bit time 
            end
            // stopbit
            uart_if.rx = 1;
            #(BIT_PERIOD);  // uart 9600bps bit time
        end
    endtask

    task reset();
        uart_if.clk = 0;
        uart_if.rst = 1;
        uart_if.rx  = 1;
        repeat (2) @(posedge uart_if.clk);
        uart_if.rst = 0;
        repeat (2) @(posedge uart_if.clk);
        $display("[DRV] reset done!");
    endtask  //reset

    task run();
        forever begin
            #1;
            gen2drv_mbox.get(trans);
            drv2scb_mbox.put(trans);
            send_uart(trans.data_8bit);
            trans.display("DRV");



        end
    endtask  //run

endclass  //driver

class monitor;

    localparam BIT_PERIOD = 104166;

    virtual uart_interface uart_if;
    mailbox #(transaction) mon2scb_mbox;
    transaction trans;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if = uart_if;

    endfunction  //new()

    task receive_uart();
        integer bit_count;
        begin
            // $display("receive_uart start");
            trans.data_8bit = 0;
            @(negedge uart_if.tx);
            // middle of start bit
            #(BIT_PERIOD / 2);
            // start bit pass/fail
            if (uart_if.tx) begin
                // fail
                $display("Fail Start bit");
            end
            // data bit pass/fail
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                #(BIT_PERIOD);
                trans.data_8bit[bit_count] = uart_if.tx;
            end
        end
    endtask

    task run();
        forever begin
            #1;
            trans = new();
            receive_uart();
            trans.display("MON");
            mon2scb_mbox.put(trans);

        end
    endtask  //run

endclass  //monitor

class scoreboard;

    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;

    transaction trans;  //from monitor
    transaction pc_send_data;  //from driver

    event gen_next_event;

    int pass_count;
    int fail_count;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) drv2scb_mbox, event gen_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.drv2scb_mbox   = drv2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run();
        forever begin
            #1;
            mon2scb_mbox.get(trans);
            drv2scb_mbox.get(pc_send_data);
            trans.display("SCB");
            trans.receive_display();

            if (trans.data_8bit == pc_send_data.data_8bit) begin
                pass_count++;
                $display("Data matched | send_data = %d, receive_data = %d",
                         pc_send_data.data_8bit, trans.data_8bit);
            end else begin
                fail_count++;
                $display("Data mismatched | send_data = %d, receive_data = %d",
                         pc_send_data.data_8bit, trans.data_8bit);
            end
            ->gen_next_event;
        end
    endtask  //run

endclass  //scoreboard

class environment;

    transaction            trans;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;
    event                  gen_next_event;
    event                  mon_next_event;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    function new(virtual uart_interface uart_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        drv2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, drv2scb_mbox, uart_if);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(mon2scb_mbox, drv2scb_mbox, gen_next_event);
    endfunction  //new()

    task reset();
        drv.reset();
        #10;
    endtask  //reset

    task report();
        $display("========================================================");
        $display("===================== Test Report ======================");
        $display("========================================================");
        $display("==                  Total Test : %3d                  ==",
                 gen.total_count);
        $display("==                  Pass Test  : %3d                  ==",
                 scb.pass_count);
        $display("==                  Fail Test  : %3d                  ==",
                 scb.fail_count);
        $display("========================================================");
        $display("================= Test bench is finish =================");
        $display("========================================================");
    endtask  //report

    task run();
        fork
            gen.run(1000);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        report();
        $stop;
    endtask  //run

endclass  //environment


module tb_uart_top ();

    uart_interface uart_if_tb ();
    environment env;

    uart_top dut (
        .clk(uart_if_tb.clk),
        .rst(uart_if_tb.rst),
        .rx (uart_if_tb.rx),
        .tx (uart_if_tb.tx)
    );


    always #5 uart_if_tb.clk = ~uart_if_tb.clk;

    initial begin
        env = new(uart_if_tb);
        env.reset();
        env.run();
        #100;
        $stop;
    end

endmodule
