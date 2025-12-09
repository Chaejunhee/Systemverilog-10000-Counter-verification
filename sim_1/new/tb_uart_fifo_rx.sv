`timescale 1ns / 1ps

interface rx_interface;
    logic       clk;
    logic       rst;
    logic       rx;
    logic [7:0] rx_data;
    logic       rx_done;
endinterface


class transaction;
    rand logic       rx;
    rand logic [7:0] rx_data;
    logic            rx_done;
    logic      [7:0] expected_data;

    task display(string name_s);
        $display("%t, [%s] : rx = %d, rx_data = %b, rx_done= %d", $time,
                 name_s, rx, rx_data, rx_done);
    endtask
endclass


class generator;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;

    // event를 받기 위해 생성
    event gen_next_event;
    int total_count = 0;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run(int count);
        repeat (count) begin
            total_count++;
            trans = new();
            assert (trans.randomize())
            else $error("[GEN] trans.randomize() error !!! ");

            gen2drv_mbox.put(trans);

            trans.display("GEN");
            // Receive event
            @(gen_next_event);
        end
    endtask
endclass


class driver;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) drv2scb_mbox;

    virtual rx_interface rx_if;
    parameter BIT_PERIOD = 104160;
    logic [7:0] send_data;
    logic [7:0] expected_data;

    int k = 0;


    event mon_next_event;

    function new(mailbox#(transaction) gen2drv_mbox, virtual rx_interface rx_if,
                 event mon_next_event, mailbox#(transaction) drv2scb_mbox);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.rx_if          = rx_if;
        this.mon_next_event = mon_next_event;
        this.drv2scb_mbox   = drv2scb_mbox;
    endfunction

    task reset();
        rx_if.clk   = 0;
        rx_if.rst   = 1;
        rx_if.rx    = 1;
        rx_if.rx_data = 0;
        rx_if.rx_done = 0;


        repeat (2) @(posedge rx_if.clk);
        rx_if.rst = 0;
        repeat (2) @(posedge rx_if.clk);
        $display("[DRV] reset done!");
    endtask

    task run();
        forever begin
            #1 gen2drv_mbox.get(trans);
            trans.expected_data = trans.rx_data;

            #1 drv2scb_mbox.put(trans);

            rx_if.rx      = trans.rx;  // 외부 인자가 우항
            rx_if.rx_data = trans.rx_data;
            rx_if.rx_done = trans.rx_done;
            send(rx_if.rx_data);
            trans.display("DRV");
            //#2;
            ->mon_next_event;
            @(posedge rx_if.clk);
        end
    endtask

    task send(input [7:0] send_data);
        begin
            rx_if.rx = 1'b0;
            #(BIT_PERIOD);

            // Data Bits (LSB first)
            for (k = 0; k < 8; k = k + 1) begin
                rx_if.rx = send_data[k];
                #(BIT_PERIOD);
            end

            // Stop Bit
            rx_if.rx = 1'b1;
            #(BIT_PERIOD);
        end
    endtask
endclass


class monitor;
    transaction trans;
    virtual rx_interface rx_if;
    mailbox #(transaction) mon2scb_mbox;

    event mon_next_event;

    function new(mailbox#(transaction) mon2scb_mbox, virtual rx_interface rx_if,
                 event mon_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.rx_if          = rx_if;
        this.mon_next_event = mon_next_event;
    endfunction

    task run();
        forever begin
            @(mon_next_event);
            trans = new;
            @(posedge rx_if.clk);
            trans.rx      = rx_if.rx;
            //trans.b_tick  = rx_if.b_tick;
            trans.rx_data = rx_if.rx_data;
            trans.rx_done = rx_if.rx_done;

            trans.display("MON");
            mon2scb_mbox.put(trans);
            @(posedge rx_if.clk);
        end
    endtask
endclass


class scoreboard;
    transaction trans;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;


    event gen_next_event;

    logic [7:0] expected_data;

    int pass_count = 0, fail_count = 0;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event,
                 mailbox#(transaction) drv2scb_mbox);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
        this.drv2scb_mbox   = drv2scb_mbox;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(trans);
            drv2scb_mbox.get(tr);

            trans.display("SCB");

            if (trans.rx_data == tr.expected_data) begin
                pass_count++;
                $display(
                    "[SCB] data matched! rdata : %b == expected_data : %b | rx_done : %d",
                    trans.rx_data, tr.expected_data, trans.rx_done);
            end else begin
                fail_count++;
                $display(
                    "[SCB] data mis-matched... rdata : %b != expected_data : %b | rx_done : %d",
                    trans.rx_data, tr.expected_data, trans.rx_done);
            end

            ->gen_next_event;
        end
    endtask
endclass


class environment;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;

    event gen_next_event;
    event mon_next_event;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    function new(virtual rx_interface rx_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        drv2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, rx_if, mon_next_event, drv2scb_mbox);

        mon = new(mon2scb_mbox, rx_if, mon_next_event);
        scb = new(mon2scb_mbox, gen_next_event, drv2scb_mbox);
    endfunction


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
    endtask

    task run();
        drv.reset();
        fork
            gen.run(50);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        report();
        $stop;
    endtask
endclass


module tb_uart_rx ();
    environment env;
    rx_interface rx_if ();

    logic b_tick;

    uart_rx dut (
        .clk    (rx_if.clk),
        .rst    (rx_if.rst),
        .b_tick (b_tick),
        .rx     (rx_if.rx),
        .rx_data(rx_if.rx_data),
        .rx_done(rx_if.rx_done)
    );

    baud_tick_generator U_BAUD_TICK (
        .clk   (rx_if.clk),
        .rst   (rx_if.rst),
        .b_tick(b_tick)
    );

    always #5 rx_if.clk = ~rx_if.clk;

    initial begin
        rx_if.clk = 0;

        env = new(rx_if);
        env.run();
    end
endmodule
