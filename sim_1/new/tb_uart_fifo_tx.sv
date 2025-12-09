`timescale 1ns / 1ps

interface tf_interface;
    logic       clk;
    logic       rst;
    //logic fifo_empty;
    logic [7:0] fifo_wdata;
    logic       wr;
    logic       tx;
    //logic tx_busy;
endinterface  //tx_interface

class transaction;
    logic wr;
    rand logic [7:0] fifo_wdata;
    logic tx;
    logic [7:0] receive_data;

    task display(string name_s);
        $display("%t, [%s] tx_data = %d, wr = %d", $time, name_s, fifo_wdata,
                 wr);
    endtask  //display
endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_event;

    int total_count = 0;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;

    endfunction  //new()

    task run(int count);
        repeat (count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            total_count++;
            tr.display("GEN");
            @(gen_next_event);
        end
    endtask  //run



endclass  //generator

class driver;

    virtual tf_interface tx_if;
    mailbox #(transaction) gen2drv_mbox;
    transaction tr;
    event mon_next_event;

    function new(virtual tf_interface tx_if, mailbox#(transaction) gen2drv_mbox,
                 event mon_next_event);
        this.mon_next_event = mon_next_event;
        this.tx_if = tx_if;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction  //new()

    task reset();
        tx_if.clk = 0;
        tx_if.rst = 1;
        tx_if.fifo_wdata = 8'h00;
        tx_if.wr = 0;
        repeat (2) @(posedge tx_if.clk);
        tx_if.rst = 0;
        repeat (2) @(posedge tx_if.clk);
        $display("[DRV] reset done!");
    endtask  //reset

    task run();
        forever begin
            gen2drv_mbox.get(tr);

            tx_if.fifo_wdata = tr.fifo_wdata;
            #10;
            tx_if.wr = 1;
            #10;
            tx_if.wr = 0;
            tr.display("DRV");
            ->mon_next_event;
        end
    endtask  //run
endclass  //driverlass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual tf_interface tx_if;
    event mon_next_event;

    logic [7:0] receive_data;
    integer bit_count = 0;

    parameter BIT_PERIOD = 104166;

    function new(mailbox#(transaction) mon2scb_mbox, virtual tf_interface tx_if,
                 event mon_next_event);
        this.mon2scb_mbox = mon2scb_mbox;
        this.tx_if = tx_if;
        this.mon_next_event = mon_next_event;
    endfunction  //new()

    task receive_uart();
        begin
            //$display("%t receive_uart start", $time);
            receive_data = 0;
            @(negedge tx_if.tx);
            // middle of start bit
            #(BIT_PERIOD / 2);
            // start bit pass/fail
            if (tx_if.tx) begin
                // fail
                $display("Fail Start bit");
            end
            // data bit pass/fail
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                #(BIT_PERIOD);
                receive_data[bit_count] = tx_if.tx;
            end
            //$display("receive_uart start2");
            // check stop bit
            #(BIT_PERIOD);
            if (!tx_if.tx) begin
                $display("Fail STOP bit");
            end
            #(BIT_PERIOD / 2);
            // pass/fail tx data
            tr.receive_data = receive_data;

        end
    endtask

    task run();
        forever begin
            @(mon_next_event);
            tr = new();
            receive_uart();
            tr.fifo_wdata = tx_if.fifo_wdata;
            tr.display("MON");
            mon2scb_mbox.put(tr);

        end
    endtask  //automatic
endclass  //monitor

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;
    int pass_count = 0;
    int fail_count = 0;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()


    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("SCB");
            // scoreboard
            // queue, decision
            if (tr.fifo_wdata == tr.receive_data) begin
                $display(
                    "Pass, Data matched : fifo_wdata = %2x, received data %2x",
                    tr.fifo_wdata, tr.receive_data);
                pass_count = pass_count + 1;
            end else begin
                $display(
                    "Fail, Data mismatch: fifo_wdata = %2x, received data %2x",
                    tr.fifo_wdata, tr.receive_data);
                fail_count = fail_count + 1;
            end

            ->gen_next_event;
        end
    endtask  //run

endclass  //scoreboard


class environment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;
    event mon_next_event;


    function new(virtual tf_interface tx_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(tx_if, gen2drv_mbox, mon_next_event);
        mon = new(mon2scb_mbox, tx_if, mon_next_event);
        scb = new(mon2scb_mbox, gen_next_event);
    endfunction  //new()

    task report();
        $display("========================================================");
        $display("===================== Test Result ======================");
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
        drv.reset();
        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #100;
        report();
        $stop;
    endtask  //run
endclass  //environment


module tb_uart_fifo_tx ();

    tf_interface tx_if_tb ();

    environment       env;
    logic             w_b_tick;
    logic             fifo_empty;
    logic       [7:0] tx_data;
    logic             tx_busy;

    uart_tx DUT_TX (
        .clk     (tx_if_tb.clk),
        .rst     (tx_if_tb.rst),
        .tx_start(~fifo_empty),
        .tx_data (tx_data),
        .b_tick  (w_b_tick),
        .tx_busy (tx_busy),
        .tx      (tx_if_tb.tx)
    );

    baud_tick_generator DUT_TICK_GEN (
        .clk   (tx_if_tb.clk),
        .rst   (tx_if_tb.rst),
        .b_tick(w_b_tick)
    );

    fifo DUT_FIFO_TX (
        .clk  (tx_if_tb.clk),
        .rst  (tx_if_tb.rst),
        .wr   (tx_if_tb.wr),
        .rd   (~tx_busy),
        .wdata(tx_if_tb.fifo_wdata),
        .rdata(tx_data),
        .full (),
        .empty(fifo_empty)
    );

    always #5 tx_if_tb.clk = ~tx_if_tb.clk;

    initial begin
        env = new(tx_if_tb);
        env.run();

    end

endmodule
