// usbfifo.v - Reed Foster
// tester for interface to FT2232HL asynchronous fifo

// could make the interface a synch <-> asynch interface using a fifo

module usbfifo
    ( // ports
        // FT2232H interface
        input rxf, // low when data is available to read
        input txe, // low when data can be written to fifo
        output rd, // active low
        output wr, // active low
        inout [7:0] data_tristate,

        input clock // internal logic must be synchronous
    );

    // architecture
    reg datavalid = 0;
    reg [7:0] data;

    assign data_tristate = (state == TXDATA || state == TXWRLO) ? data : 8'bZ;
    assign rd = (state == RXRDLO || state == RXDATA) ? 0 : 1;
    assign wr = (state == TXWRLO || state == TXWAIT) ? 0 : 1;

    //////////////////////////////
    // timer
    //////////////////////////////
    localparam TIMERDEF = 2;
    reg [1:0] timer = TIMERDEF;
    // update timer
    always @ (posedge clock)
    begin
        if (state == WAIT) // only count down if we're waiting
            timer <= (timer > 0) ? timer - 1 : TIMERDEF;
    end

    //////////////////////////////
    // FSM
    //////////////////////////////
    localparam STATEWIDTH = 3;
    localparam IDLE = 0;
    localparam TXDATA = 1, TXWRLO = 2, TXWAIT = 3, TXWRHI = 4;
    localparam RXRDLO = 5, RXDATA = 6;
    localparam WAIT = 7;
    reg [STATEWIDTH-1:0] state = IDLE;
    reg [STATEWIDTH-1:0] nextstate;
    always @ (posedge clock)
    begin
        state <= nextstate;
    end
    always @ ( * )
    begin
        case (state)
            IDLE:   nextstate = (txe == 0 && datavalid == 1) ? TXDATA : (rxf == 0) ? RXRDLO : state;
            TXDATA: nextstate = TXWRLO;
            TXWRLO: nextstate = TXWAIT;
            TXWAIT: nextstate = TXWRHI;
            TXWRHI: nextstate = WAIT;
            RXRDLO: nextstate = RXDATA;
            RXDATA: nextstate = WAIT;
            WAIT:   nextstate = (timer == 0) ? IDLE : state;
        endcase
    end

    always @ (posedge clock)
    begin
        if (state == RXDATA)
        begin
            datavalid <= 1;
            data <= data_tristate;
        end
        if (state == TXDATA)
            datavalid <= 0;
    end

endmodule
