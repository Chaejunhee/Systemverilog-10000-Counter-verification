`timescale 1ns / 1ps
interface dp_interface;

    logic        clk;
    logic        rst;
    logic        i_mode;
    logic        i_enable;
    logic        i_clear;
    logic [13:0] counter;

endinterface  //dp_interface 

class transaction;
    rand bit        i_mode;
    rand bit        i_enable;
    rand bit        i_clear;
    logic    [13:0] counter;


    constraint input_dist {
        i_enable dist {
            0 :/ 20,
            1 :/ 80
        };
        i_mode dist {
            0 :/ 30,
            1 :/ 70
        };
        i_clear dist {
            0 :/ 99,
            1 :/ 1
        };
    }

    task display(string name_s);
        $display(
            "[%t] [%s] | i_enable = %d, i_mode = %d, i_clear = %d, counter = %d",
            $time, name_s, i_enable, i_mode, i_clear, counter);
    endtask  //display

endclass  //transaction

class generator;

    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_event;

    int total_count;
    int enable_count, mode_count, clear_count;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            total_count++;
            trans = new();

            assert (trans.randomize())
            else $error("[GEN] randomize() error!!");
            gen2drv_mbox.put(trans);
            gen2scb_mbox.put(trans);
            if (trans.i_enable) begin
                enable_count++;
            end
            if (trans.i_mode) begin
                mode_count++;
            end
            if (trans.i_clear) begin
                clear_count++;
            end
            trans.display("GEN");
            @(gen_next_event);

        end
    endtask  //run

endclass  //generator

class driver;

    virtual dp_interface dp_if;
    mailbox #(transaction) gen2drv_mbox;

    transaction trans;
    event mon_next_event;

    function new(mailbox#(transaction) gen2drv_mbox, virtual dp_interface dp_if,
                 event mon_next_event);
        this.gen2drv_mbox = gen2drv_mbox;
        this.dp_if = dp_if;
        this.mon_next_event = mon_next_event;
    endfunction  //new()

    task reset();
        dp_if.clk      = 0;
        dp_if.rst      = 1;
        dp_if.i_enable = 0;
        dp_if.i_mode   = 1;
        dp_if.i_clear  = 0;
        repeat (2) @(posedge dp_if.clk);
        dp_if.rst = 0;
        @(posedge dp_if.clk);
        $display("[DRV] reset done!");
    endtask  //reset


    task run();
        forever begin
            gen2drv_mbox.get(trans);
            trans.display("DRV");
            repeat (2) @(posedge dp_if.clk);
            dp_if.i_enable = trans.i_enable;
            dp_if.i_mode   = trans.i_mode;
            dp_if.i_clear  = trans.i_clear;
            if (trans.i_clear == 1'b1) begin
                #20;
                dp_if.i_clear = 0;
            end
            ->mon_next_event;
            repeat (2) @(posedge dp_if.clk);
        end
    endtask  //run

endclass  //driver

class monitor;

    virtual dp_interface dp_if;
    mailbox #(transaction) mon2scb_mbox;
    event mon_next_event;
    transaction trans;
    integer i;

    function new(mailbox#(transaction) mon2scb_mbox, virtual dp_interface dp_if,
                 event mon_next_event);
        this.mon2scb_mbox = mon2scb_mbox;
        this.dp_if = dp_if;
        this.mon_next_event = mon_next_event;
    endfunction  //new()

    task run();
        forever begin
            trans = new();
            @(mon_next_event);
            for (i = 0; i < 10; i++) begin
                repeat (2) @(posedge dp_if.clk);
                trans.i_enable = dp_if.i_enable;
                trans.i_mode   = dp_if.i_mode;
                trans.i_clear  = dp_if.i_clear;
                trans.counter  = dp_if.counter;
                trans.display("MON");
                mon2scb_mbox.put(trans);
            end
        end
    endtask  //run
endclass  //monitor

class scoreboard;

    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;
    transaction trans;
    transaction gen_tr;
    event gen_next_event;

    integer i = 0;

    int pass_count, fail_count;


    //for queueing
    logic [13:0] counter_queue[$:50];

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    int enable_flag = 1;
    int mode_flag    = 1;
    int clear_flag = 1;

    logic [13:0] counter_temp[2];

    task verification();
        //report process 작성
        counter_temp[0] = counter_queue.pop_front();
        counter_temp[1] = counter_queue.pop_front();

        //clear verifi
        if (gen_tr.i_clear) begin
            if (counter_temp[0] == 0) begin
                clear_flag = 1;
            end else begin
                clear_flag = 0;
            end
        end

        for (i = 0; i < 9; i++) begin

            //enable verifi
            if (gen_tr.i_enable) begin
                if (counter_temp[0] != counter_temp[1]) begin
                    enable_flag = 1;
                end else begin
                    enable_flag = 0;
                    break;
                end
            end else begin
                if (counter_temp[0] == counter_temp[1]) begin
                    enable_flag = 1;
                end else begin
                    enable_flag = 0;
                    break;
                end
            end

            //mode verifi
            if (gen_tr.i_enable) begin
                if (gen_tr.i_mode) begin
                    if (counter_temp[0] == 9999 && counter_temp[1] == 0) begin
                        mode_flag = 1;
                    end else if (counter_temp[0] < counter_temp[1]) begin
                        mode_flag = 1;
                    end else begin
                        mode_flag = 0;
                        break;
                    end
                end else begin
                    if (counter_temp[0] == 0 && counter_temp[1] == 9999) begin
                        mode_flag = 1;
                    end else if (counter_temp[0] > counter_temp[1]) begin
                        mode_flag = 1;
                    end else begin
                        mode_flag = 0;
                        break;
                    end
                end
            end else begin
                mode_flag = 1;
            end

            $display("%d %d", counter_temp[0], counter_temp[1]);
            counter_temp[0] = counter_temp[1];
            counter_temp[1] = counter_queue.pop_front();
        end

        if (clear_flag) begin
            $display("clear pass!");
        end else begin
            $display("clear fail!");
        end
        if (enable_flag) begin
            $display("enable pass!");
        end else begin
            $display("enable fail!");
        end
        if (mode_flag) begin
            $display("mode pass!");
        end else begin
            $display("mode fail!");
        end

        if (clear_flag & enable_flag & mode_flag) begin
            pass_count++;
        end else begin
            fail_count++;
        end
    endtask  //report

    task run();
        forever begin
            gen2scb_mbox.get(gen_tr);
            for (i = 0; i < 10; i++) begin
                mon2scb_mbox.get(trans);
                trans.display("SCB");
                counter_queue.push_back(trans.counter);
            end
            verification();
            // counter_queue.delete();
            ->gen_next_event;

        end
    endtask  //run
endclass  //scoreboard

class environment;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;
    event mon_next_event;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    function new(virtual dp_interface dp_if_tb);
        gen2drv_mbox = new();
        gen2scb_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_event);
        drv = new(gen2drv_mbox, dp_if_tb, mon_next_event);
        mon = new(mon2scb_mbox, dp_if_tb, mon_next_event);
        scb = new(mon2scb_mbox, gen2scb_mbox, gen_next_event);

    endfunction  //new()

    task report();
        $display("========================================================");
        $display("===================== Test Report ======================");
        $display("========================================================");
        $display("==                  Total Test   : %3d                ==",
                 gen.total_count);
        $display("==                  Pass Test    : %3d                ==",
                 scb.pass_count);
        $display("==                  Fail Test    : %3d                ==",
                 scb.fail_count);
        $display("==                  enable count : %3d                ==",
                 gen.enable_count);
        $display("==                  mode   count : %3d                ==",
                 gen.mode_count);
        $display("==                  clear  count : %3d                ==",
                 gen.clear_count);
        $display("========================================================");
        $display("================= Test bench is finish =================");
        $display("========================================================");
    endtask  //report

    task reset();
        drv.reset();
        #10;
    endtask  //reset

    task run();
        fork
            gen.run(500);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        report();
        #10;
        $display("finish");

        $stop;
    endtask  //run
endclass  //environment


module tb_cu_dp_systemverilog ();

    dp_interface dp_if_tb ();

    environment env;
    Datapath_10000 dut0 (
        .clk     (dp_if_tb.clk),
        .rst     (dp_if_tb.rst),
        .i_mode  (dp_if_tb.i_mode),
        .i_enable(dp_if_tb.i_enable),
        .i_clear (dp_if_tb.i_clear),
        .counter (dp_if_tb.counter)
    );



    always #5 dp_if_tb.clk = ~dp_if_tb.clk;

    initial begin
        env = new(dp_if_tb);
        env.reset();
        env.run();


    end
endmodule
