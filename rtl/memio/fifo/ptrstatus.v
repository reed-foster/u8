// ptrstatus.v - Reed Foster
// Binary/gray counter and status flags for use with asyncfifo.v
// *should not be instantiated by any module other than asyncfifo.v

module ptrstatus
    #( // parameters
        parameter WIDTH = 9, // must be instantiated with (fifoaddrwidth + 1)
        parameter MODE = 0 // 0 for enqueue (write), 1 for dequeue (read)

    )( // ports
        input inc, // enable count
        input clock, reset,
        input [WIDTH-1:0] oppclockptr, // gray-coded pointer of opposite clock domain
        output [WIDTH-2:0] address, // binary-coded address
        output [WIDTH-1:0] pointer, // gray-coded pointer (equivalent to "address", just gray-coded)
        output status // full (MODE = 0; enqueue) or empty (MODE = 1; dequeue)
    );

    // architecture

    // address/pointer temp
    reg [WIDTH-1:0] binary;
    reg [WIDTH-1:0] gray;

    // update counter
    always_ff @(posedge clock) begin
        if (reset)
            binary <= 0;
        else if (inc && !status)
            binary <= binary + 1;
    end

    // compact binary to gray conversion, equivalent to {counter[msb], counter[msb-1] ^ counter[msb], ... , counter[1] ^ counter[0]}
    assign gray = (binary >> 1) ^ binary;

    // assign outputs
    assign address = binary[WIDTH-2:0];
    assign pointer = gray;

    // since the msb of gray-code is equivalent to the msb of binary code
    // we don't need to do a gray2binary conversion of oppclockptr
    // XOR with MODE: if msbs are the same (their xor is 0) and module is instantiated in dequeue-mode (MODE = 1), then we want to check when fifo is empty
    assign status = (oppclockptr[WIDTH-2:0] == gray[WIDTH-2:0]) & (oppclockptr[WIDTH-1] ^ gray[WIDTH-1] ^ MODE);

endmodule
