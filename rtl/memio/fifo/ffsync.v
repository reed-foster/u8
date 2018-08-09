// ffsync.v - Reed Foster
// 2 flip-flop synchronizer for asynchronous FIFO

module ffsync
    #( // parameters
        WIDTH = 9 // bitwidth to synchronize (must be fifoaddrwidth + 1)
    )( // ports
        input [WIDTH-1:0] signal,
        input clock, reset,
        output reg [WIDTH-1:0] signal_sync
    );

    // architecture

    // signal --> meta --> signal_sync
    // (clk)   ^        ^

    // first reg
    reg [WIDTH-1:0] meta;
    always_ff @(posedge clock) begin
        if (reset)
            meta <= 0;
        else
            meta <= signal;
    end

    always_ff @(posedge clock) begin
        if (reset)
            signal_sync <= 0;
        else
            signal_sync <= meta;
    end

endmodule
