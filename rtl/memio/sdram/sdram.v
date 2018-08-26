// sdram.v - Reed Foster
// SDRAM controller (for use with cache controller; hence the odd interface)

// TODO improve full/empty logic on fifos to prevent attempting to write garbage data to/from ram

module sdram
    #( // parameters
        parameter CLOCKPERIOD = 6, // period in ns; CAS latency = 2 requires ckperiod >= 12; otherwise ckperiod >=6
        parameter CASLATENCY = 3
    )( // ports
        // processor interface
        input ramclock, // clock for controller; same frequency as SDRAM
        input pclock, // processor clock; same frequency as cache and processor (used for read/write to fifos)
        input [23:0] fulladdress, // 2 bits for bank address, 13 for row, and 9 for column
        input [15:0] d_in, // data from cache
        output [15:0] d_out, // data to cache
        input readreq, writereq,
        input read, write, // asserted when actually reading from or writing to fifos
        output readready, writeready, // alias for !readfifo.empty and !writefifo.full

        // sdram interface
        // clock to sdram is implemented by oddr2 in topmodule
        // clock out to sdram should be out of phase by 180deg (probably)
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
    localparam TRCD = 18; // ras# to cas# delay (same bank)
    localparam TRP = 18; // precharge to refresh/row activate (same bank)
    localparam TMRD = 12; // mode register set
    localparam TREFI = 7800; // average refresh interval

    ////////////////////////////////
    // TIMER
    ////////////////////////////////
    // Timer defaults (convert ns to ticks)
    localparam TICK_TRC = TRC / CLOCKPERIOD;
    localparam TICK_TRCD = TRCD / CLOCKPERIOD;
    localparam TICK_TRP = TRP / CLOCKPERIOD;
    localparam TICK_TMRD = TMRD / CLOCKPERIOD;
    localparam TICK_TREFI = TREFI / CLOCKPERIOD;
    localparam TIMERDEF_init_startup            = 200000 / CLOCKPERIOD - 2; // countdown for 200us
    localparam TIMERDEF_init_precharge_setmode  = TICK_TRP > 2  ? TICK_TRP - 2 : 0; // default = 3 - 2
    localparam TIMERDEF_init_setmode_refresh0   = TICK_TMRD > 2 ? TICK_TMRD - 2 : 0; // default = 2 - 2
    localparam TIMERDEF_init_refresh0_refresh1  = TICK_TRP > 2 ? TICK_TRP - 2 : 0; // default = 3 - 2
    localparam TIMERDEF_init_refresh1_exit      = TICK_TRC > 2 ? TICK_TRC - 2 : 0; // default = 10 - 2
    localparam TIMERDEF_refresh_wait            = TICK_TRC > 2 ? TICK_TRC - 2 : 0; // default = 10 - 2
    localparam TIMERDEF_bankactivate            = TICK_TRCD > 2 ? TICK_TRCD - 2 : 0; // default = 3 - 2
    localparam TIMERDEF_read_cas_latency = CASLATENCY - 1; // -1 because one cycle of latency is counted in READ state
    localparam TIMERDEF_read_wait = 512 - 4;
    localparam TIMERDEF_write_wait = 512 - 2;
    localparam TIMERDEF_idle = TICK_TREFI / 2; // arbitrary
    // timer
    reg [17:0] timer = TIMERDEF_init_startup; // only need to use 16 bits, but verilog doesn't know that the minimum value for CLOCKPERIOD is 6
    // update timer
    always_ff @(posedge ramclock)
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
            IDLE:
            begin
                if (!requestqueueempty)
                    timer <= TIMERDEF_bankactivate;
                else
                    timer <= (timer > 0) ? timer - 1 : TIMERDEF_refresh_wait;
            end
            // read
            READBANKACT:    timer <= TIMERDEF_bankactivate;
            READWAIT0:      timer <= (timer > 0) ? timer - 1 : TIMERDEF_read_cas_latency;
            READ:           timer <= timer - 1;
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
    always_ff @(posedge ramclock)
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
                if (!requestqueueempty)
                begin
                    if (nextrequest[24]) // msb holds request mode (1 for write, 0 for read)
                        nextstate = WRITEBANKACT;
                    else
                        nextstate = READBANKACT;
                end
                else
                    nextstate = (timer == 0) ? REFRESH : state;
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


    ///////////////////////////////////////////////////////
    // FIFOs
    ///////////////////////////////////////////////////////
    // request queue
    wire getnextrequest;
    wire requestqueueempty;
    wire [24:0] nextrequest;
    assign getnextrequest = (state == IDLE) && (!requestqueueempty);
    // read/write queues
    wire [15:0] readqueue_in, writequeue_out;
    assign readqueue_in = d_in_iob; // attach fifo i/o to iobs
    assign d_out_iob = writequeue_out;
    wire readactive, writeactive;
    assign readactive = (state == READWAIT2 || state == READBURSTHALT || state == READPRECHARGE || state == READWAIT3) ? 1 : 0;
    assign writeactive = (state == WRITE || state == WRITEWAIT1) ? 1 : 0;
    wire readready_n, writeready_n;
    assign readready = !readready_n;
    assign writeready = !writeready_n;
    // writequeue empty logic
    wire write_empty;
    // dummy signals
    wire reqfull, readfull;
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
            .full       (reqfull),
            .empty      (requestqueueempty)
        );
    asyncfifo #(.ADDRWIDTH(9), .WIDTH(16)) readqueue
        (
            .deq_clock  (pclock),
            .enq_clock  (ramclock),
            .dequeue    (read),
            .enqueue    (readactive),
            .reset      (0),
            .data_in    (readqueue_in),
            .data_out   (d_out),
            .full       (readfull),
            .empty      (readready_n)
        );
    asyncfifo #(.ADDRWIDTH(9), .WIDTH(16)) writequeue
        (
            .deq_clock  (ramclock),
            .enq_clock  (pclock),
            .dequeue    (writeactive),
            .enqueue    (write),
            .reset      (0),
            .data_in    (d_in),
            .data_out   (writequeue_out),
            .full       (writeready_n),
            .empty      (writeempty)
        );


    ///////////////////////////////////////////////
    // SDRAM control
    ///////////////////////////////////////////////
    // commands {cs, ras, cas, we}
    localparam [3:0] cmd_deselect   = 4'hf;
    localparam [3:0] cmd_nop        = 4'h7;
    localparam [3:0] cmd_read       = 4'h5; // A10 must be low
    localparam [3:0] cmd_write      = 4'h4; // A10 must be low
    localparam [3:0] cmd_bankact    = 4'h3;
    localparam [3:0] cmd_precharge  = 4'h2; // A10 must be high
    localparam [3:0] cmd_refresh    = 4'h1;
    localparam [3:0] cmd_setmode    = 4'h0; // A10 must be low
    localparam [3:0] cmd_haltburst  = 4'h6;
    // control vector (msb->lsb): {address[12:0], udqm, ldqm, ba, cs, ras, cas, we}
    reg [20:0] controlvec;
    // dqms must be high during initialization
    localparam CTLVECDEF_init_deselect  = {13'b0, 2'b11, 2'b0, cmd_deselect};
    localparam CTLVECDEF_init_setmode   = {{6'b0, CASLATENCY[2:0], 4'b0111}, 2'b11, 2'b0, cmd_setmode}; // [2:0] to ensure CASLATENCY truncated to 3 bits
    localparam CTLVECDEF_init_refresh   = {13'b0, 2'b11, 2'b0, cmd_refresh};
    localparam CTLVECDEF_init_precharge = {{2'b0, 1'b1, 10'b0}, 2'b11, 2'b0, cmd_precharge};
    // dqms can be held low during non-initialization commands
    localparam CTLVECDEF_deselect       = {13'b0, 2'b0, 2'b0, cmd_deselect};
    localparam CTLVECDEF_bursthalt      = {13'b0, 2'b0, 2'b0, cmd_haltburst};
    localparam CTLVECDEF_precharge      = {{2'b0, 1'b1, 10'b0}, 2'b0, 2'b0, cmd_precharge};
    localparam CTLVECDEF_refresh        = {13'b0, 2'b0, 2'b0, cmd_refresh};
    // update controlvector
    always_comb
    begin
        case(state)
            INITWAIT0:      controlvec = {13'b0, 2'b11, 2'b0, cmd_deselect};
            INITWAIT1:      controlvec = CTLVECDEF_init_deselect;
            INITPRECHARGE:  controlvec = CTLVECDEF_init_precharge;
            INITWAIT2:      controlvec = CTLVECDEF_init_deselect;
            INITSETMODE:    controlvec = CTLVECDEF_init_setmode;
            INITWAIT3:      controlvec = CTLVECDEF_init_deselect;
            INITREFRESH0:   controlvec = CTLVECDEF_init_refresh;
            INITWAIT4:      controlvec = CTLVECDEF_init_deselect;
            INITREFRESH1:   controlvec = CTLVECDEF_init_refresh;
            INITWAIT5:      controlvec = CTLVECDEF_init_deselect;
            IDLE:           controlvec = CTLVECDEF_deselect;
            READBANKACT:    controlvec = {nextrequest[21:9], 2'b0, nextrequest[23:22], cmd_bankact};
            READWAIT0:      controlvec = CTLVECDEF_deselect;
            READ:           controlvec = {{4'b0, nextrequest[8:0]}, 2'b0, nextrequest[23:22], cmd_read};
            READWAIT1:      controlvec = CTLVECDEF_deselect;
            READWAIT2:      controlvec = CTLVECDEF_deselect;
            READBURSTHALT:  controlvec = CTLVECDEF_bursthalt;
            READPRECHARGE:  controlvec = CTLVECDEF_precharge;
            READWAIT3:      controlvec = CTLVECDEF_deselect;
            READWAIT4:      controlvec = CTLVECDEF_deselect;
            WRITEBANKACT:   controlvec = {nextrequest[21:9], 2'b0, nextrequest[23:22], cmd_bankact};
            WRITEWAIT0:     controlvec = CTLVECDEF_deselect;
            WRITE:          controlvec = {{4'b0, nextrequest[8:0]}, 2'b0, nextrequest[23:22], cmd_write};
            WRITEWAIT1:     controlvec = CTLVECDEF_deselect;
            WRITEBURSTHALT: controlvec = CTLVECDEF_bursthalt;
            WRITEPRECHARGE: controlvec = CTLVECDEF_precharge;
            WRITEWAIT2:     controlvec = CTLVECDEF_deselect;
            REFRESH:        controlvec = CTLVECDEF_refresh;
            REFRESHWAIT:    controlvec = CTLVECDEF_deselect;
            default:        controlvec = CTLVECDEF_deselect;
        endcase
    end


    /////////////////////////////////////////////
    // IOBs
    /////////////////////////////////////////////
    (* IOB = "TRUE" *)
    reg cke_iob;
    (* IOB = "TRUE" *)
    reg [1:0] ba_iob, dqm_iob;
    (* IOB = "TRUE" *)
    reg [3:0] cmd_iob;
    (* IOB = "TRUE" *)
    reg [12:0] addr_iob;
    (* IOB = "TRUE" *)
    reg [15:0] d_in_iob, d_out_iob;
    // assign controlvec to iobs (din/dout are directly connected to fifos)
    always_comb
    begin
        cke_iob = (state == INITWAIT0 || (writeactive && writeempty)) ? 1'b0 : 1'b1;
        ba_iob = controlvec[5:4];
        dqm_iob = controlvec[7:6];
        cmd_iob = controlvec[3:0];
        addr_iob = controlvec[20:8];
    end
    // assign i/o to iob regs
    assign cke = cke_iob;
    assign ldqm = dqm_iob[0];
    assign udqm = dqm_iob[1];
    assign ba = ba_iob;
    assign we = cmd_iob[0];
    assign cas = cmd_iob[1];
    assign ras = cmd_iob[2];
    assign cs = cmd_iob[3];
    assign addr = addr_iob;
    assign data_to_ram = d_out_iob;
    assign d_in_iob = data_from_ram;
endmodule;
