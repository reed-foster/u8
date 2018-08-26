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
        output [WIDTH-1:0] pointer, // gray-coded pointer (equivalent to "address", just gray-coded)
        output status // full (MODE = 0; enqueue) or empty (MODE = 1; dequeue)
    );

    // architecture

    wire [WIDTH-1:0] binary;
    wire [WIDTH-1:0] oppbinary;
    wire [WIDTH-1:0] graynext;
    reg [WIDTH-1:0] gray;

    // update counter
    always_ff @(posedge clock) begin
        if (reset)
            gray <= 0;
        else if (inc && !status)
            gray <= graynext;
    end

    // compact gray to binary conversion
    genvar i;
    generate for (i = 0; i < WIDTH; i++)
    begin
        assign binary[i] = ^(gray >> i);
        assign oppbinary[i] = ^(oppclockptr >> i);
    end
    endgenerate
    // binary to gray conversion (simultaneously incrementing)
    assign graynext = ((binary + 1) >> 1) ^ (binary + 1);

    // assign outputs
    assign pointer = gray;

    // since the msb of gray-code is equivalent to the msb of binary code
    // we don't need to do a gray2binary conversion of oppclockptr
    // XOR with MODE: if msbs are the same (their xor is 0) and module is instantiated in dequeue-mode (MODE = 1), then we want to check when fifo is empty
    assign status = (oppbinary[WIDTH-2:0] == binary[WIDTH-2:0]) & (oppbinary[WIDTH-1] ^ gray[WIDTH-1] ^ MODE);

endmodule
