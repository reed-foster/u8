// sdram.v - Reed Foster
// SDRAM controller (for use with cache controller; hence the odd interface)

module sdram
    #( // parameters
        parameter CLOCKPERIOD = 6, // period in ns; CAS latency = 2 requires ckperiod >= 12; otherwise ckperiod >=6
        parameter CASLATENCY = 3
    )( // ports
        // processor interface
        input ramclock, // clock for controller; same frequency as SDRAM
        input pclock, // processor clock; same frequency as cache and processor (used for read/write to fifos)
        input [23:0] fulladdress, // 2 bits for bank address, 13 for row, and 9 for column
        input [16:0] d_in, // data from cache
        output [16:0] d_out, // data to cache
        input readreq, writereq,
        input read, write, // asserted when actually reading from or writing to fifos
        output readready, writeready, // alias for !readfifo.empty and !writefifo.full

        // sdram interface (minus clock)
        output cke,
        output udqm, ldqm,
        output [1:0] ba,
        output cs, ras, cas, we,
        output [12:0] addr,
        output [15:0] data_to_ram,
        input [15:0] data_from_ram,
        output data_tristate // 1 if data_to_ram should be written to inout, 0 if data_from_ram should be read
    );

    // Timing Characteristics (in ns)
    localparam TRC = 60; // row cycle time (same bank)
    localparam TRFC = 60; // refresh cycle time
    localparam TRCD = 18; // ras# to cas# delay (same bank)
    localparam TRP = 18; // precharge to refresh/row activate (same bank)
    localparam TRRD = 12; // row activate to row activate (different bank)
    localparam TMRD = 12; // mode register set
    localparam TRAS = 42; // row activate to precharge (same bank)
    localparam TWR = 12; // write recovery time

    ////////////////////////////////
    // TIMER
    ////////////////////////////////
    // Timer defaults (convert ns to ticks)
    localparam TIMERDEF_init_startup = 200000 / CLOCKPERIOD; // countdown for 200us
    localparam TIMERDEF_init_precharge_setmode = TRP / CLOCKPERIOD; // default = 3
    localparam TIMERDEF_init_setmode_refresh0 = TMRD / CLOCKPERIOD; // default = 2
    localparam TIMERDEF_init_refresh0_refresh1 = TRP / CLOCKPERIOD; // default = 3
    localparam TIMERDEF_init_refresh1_exit = TRC / CLOCKPERIOD; // default = 10
    localparam TIMERDEF_refresh_wait = TRC / CLOCKPERIOD; // default = 10
    localparam TIMERDEF_bankactivate = TRCD / CLOCKPERIOD; // default = 3
    localparam TIMERDEF_read_cas_latency = CASLATENCY - 1; // -1 because one cycle of latency is counted in READ state
    localparam TIMERDEF_read_wait = 509;
    localparam TIMERDEF_write_wait = 511;
    localparam TIMERDEF_idle = 10;

    // timer
    reg [17:0] timer = TIMERDEF_init_startup; // only need to use 16 bits, but verilog doesn't know that the minimum value for CLOCKPERIOD is 6
    // update timer
    always_ff @(posedge clock)
    begin
        case (state)
            // init
            INITWAIT0:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_init_precharge_setmode;
            INITWAIT1:      ;
            INITPRECHARGE:  ;
            INITWAIT2:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_init_setmode_refresh0;
            INITSETMODE:    ;
            INITWAIT3:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_init_refresh0_refresh1;
            INITREFRESH0:   ;
            INITWAIT4:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_init_refresh1_exit;
            INITREFRESH1:   ;
            INITWAIT5:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_idle;
            // idle
            IDLE:           timer <= (timer > 0) ? timer - 1 : TIMERDEF_refresh_wait;
            // read
            READBANKACT:    timer <= TIMERDEF_bankactivate;
            READWAIT0:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_read_cas_latency;
            READ:           timer <= timer - 1; // only one clock cycle occurs here
            READWAIT1:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_read_wait;
            READWAIT2:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_idle;
            READBURSTHALT:  ;
            READPRECHARGE:  ;
            READWAIT3:      ;
            READWAIT4:      ;
            // write
            WRITEBANKACT:   timer <= TIMERDEF_bankactivate;
            WRITEWAIT0:     timer <= (timer > 0) ? timer - 1 : TIMERDEF_write_wait;
            WRITE:          ;
            WRITEWAIT1:     timer <= (timer > 0) ? timer - 1 : TIMERDEF_idle;
            WRITEBURSTHALT: ;
            WRITEPRECHARGE: ;
            WRITEWAIT2:     ;
            // refresh
            REFRESH:        timer <= TIMERDEF_refresh_wait; // reset timer to be sure
            REFRESHWAIT:    timer <= (timer > 0) ? timer - 1 : TIMERDEF_idle;
        endcase
    end

    /////////////////////////////////////////////////
    // FSM
    /////////////////////////////////////////////////
    // FSM states
    localparam STATEWIDTH = $clog2(30);
    localparam INITWAIT0 = 0, INITWAIT1 = 1, INITPRECHARGE = 2, INITWAIT2 = 3, INITSETMODE = 4, INITWAIT3 = 5, INITREFRESH0 = 6, INITWAIT4 = 7, INITREFRESH1 = 8, INITWAIT5 = 9;
    localparam IDLE = 10;
    localparam READBANKACT = 11, READWAIT0 = 12, READ = 13, READWAIT1 = 14, READWAIT2 = 15, READBURSTHALT = 16, READPRECHARGE = 17, READWAIT3 = 18, READWAIT4 = 19;
    localparam WRITEBANKACT = 20, WRITEWAIT0 = 21, WRITE = 22, WRITEWAIT1 = 23, WRITEBURSTHALT = 24, WRITEPRECHARGE = 25, WRITEWAIT2 = 26;
    localparam REFRESH = 27, REFRESHWAIT = 28;
    // update FSM on rising clock edge
    reg [STATEWIDTH-1:0] state = INITWAIT0;
    reg [STATEWIDTH-1:0] nextstate;
    always_ff @(posedge clock)
    begin
        state <= nextstate;
    end
    // state transision logic
    always_comb
    begin
        case (state)
            INITWAIT0:      nextstate = (timer == 0) ? INITWAIT1 : state;
            INITWAIT1:      nextstate = INITPRECHARGE;
            INITPRECHARGE:  nextstate = INITWAIT2;
            INITWAIT2:      nextstate = (timer == 0) ? INITSETMODE : state;
            INITSETMODE:    nextstate = INITWAIT3;
            INITWAIT3:      nextstate = (timer == 0) ? INITREFRESH0 : state;
            INITREFRESH0:   nextstate = INITWAIT4;
            INITWAIT4:      nextstate = (timer == 0) ? INITREFRESH1 : state;
            INITREFRESH1:   nextstate = INITWAIT5;
            INITWAIT5:      nextstate = (timer == 0) ? IDLE : state;
            IDLE:
            begin
                // TODO implement logic
            end
            READBANKACT:    nextstate = READWAIT0;
            READWAIT0:      nextstate = (timer == 0) ? READ : state;
            READ:           nextstate = READWAIT1;
            READWAIT1:      nextstate = (timer == 0) ? READWAIT2 : state;
            READWAIT2:      nextstate = (timer == 0) ? READBURSTHALT : state;
            READBURSTHALT:  nextstate = READPRECHARGE;
            READPRECHARGE:  nextstate = READWAIT3;
            READWAIT3:      nextstate = READWAIT4;
            READWAIT4:      nextstate = IDLE;
            WRITEBANKACT:   nextstate = WRITEWAIT0;
            WRITEWAIT0:     nextstate = (timer == 0) ? WRITE : state;
            WRITE:          nextstate = WRITEWAIT1;
            WRITEWAIT1:     nextstate = (timer == 0) ? WRITEBURSTHALT : state;
            WRITEBURSTHALT: nextstate = WRITEPRECHARGE;
            WRITEPRECHARGE: nextstate = WRITEWAIT2;
            WRITEWAIT2:     nextstate = IDLE;
            REFRESH:        nextstate = REFRESHWAIT;
            REFRESHWAIT:    nextstate = (timer == 0) ? IDLE : state;
        endcase
    end

    ///////////////////////////
    // FIFOs
    ///////////////////////////
    wire getnextrequest;
    wire requestqueueempty;
    wire [24:0] nextrequest;
    wire readactive, writeactive;
    assign getnextrequest = (state == IDLE) && (!requestqueueempty);
    // fifo instances
    asyncfifo #(.ADDRWIDTH(2), .WIDTH(25)) requestqueue
        (
            .deq_clock  (ramclock),
            .enq_clock  (pclock),
            .dequeue    (getnextrequest),
            .enqueue    (readreq | writereq),
            .reset      (0),
            .data_in    ({writereq, fulladdress}),
            .data_out   (nextrequest),
            .full       (0),
            .empty      (requestqueueempty)
        );
    asyncfifo #(.ADDRWIDTH(9), .WIDTH(16)) readqueue
        (
            .deq_clock  (pclock),
            .enq_clock  (ramclock),
            .dequeue    (read),
            .enqueue    (readactive),
            .reset      (0),
            .data_in    (),
            .data_out   (),
            .full       (),
            .empty      ()
        );
    asyncfifo #(.ADDRWIDTH(9), .WIDTH(16)) writequeue
        (
            .deq_clock  (ramclock),
            .enq_clock  (pclock),
            .dequeue    (writeactive),
            .enqueue    (write),
            .reset      (0),
            .data_in    (),
            .data_out   (),
            .full       (),
            .empty      ()
        );
endmodule;
