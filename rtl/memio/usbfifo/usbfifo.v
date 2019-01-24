// usbfifo.v - Reed Foster
// tester for interface to FT2232HL asynchronous fifo

// could make the interface a synch <-> asynch interface using a fifo

module usbfifo
    #( // parameters

    )( // ports
        // FT2232H interface
        input rxf, // low when data is available to read
        input txe, // low when data can be written to fifo
        output rd, // active low
        output wr, // active low
        input [7:0] rx_data,
        output [7:0] tx_data,

        input clock // internal logic must be synchronous
    );

    // architecture

    // increment received word by 1
    reg [7:0] word;
    assign tx_data = word + 8'b1;
    // synchronize rxf and txe signals
    reg s_rxf = 1; // active low
    reg s_txe = 1; // active low
    assign rd = s_rxf;
    assign wr = s_txe;

    // trd (read -> data) is < 14ns so 50MHz clock is fine
    // tdw (data -> write) is > 5ns; 50MHz is definitely fine
    always_ff @(posedge clock)
    begin
        s_rxf <= rxf;
        s_txe <= txe;
    end

    always_ff @(negedge clock)
    begin
        if (s_rxf == 0) // s_rxf must've been low for half a clock period
            word <= rx_data;
    end

endmodule;
