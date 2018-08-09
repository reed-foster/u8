// fifo.v - Reed Foster
// Parametrized Synchronous FIFO

module fifo
    #( // parameters
        parameter ADDRWIDTH = 8,
        parameter WIDTH = 8,
        parameter REGISTERDOUT = 1 // 1 registers data_out, 0 bypasses the register
    )( // ports
        input clock, reset,
        input dequeue, enqueue,
        input [WIDTH-1:0] data_in,
        output reg [WIDTH-1:0] data_out,
        output full, empty
    );

    // architecture

    localparam DEPTH = 2 ** ADDRWIDTH;

    // extra bit to detect rollover count
    // if [width-1:0] bits are equal, and the msbs are different, fifo is full
    // if lsbs are equal and msbs are the same, fifo is empty
    reg [ADDRWIDTH:0] deq_addr, enq_addr;
    wire full_t, empty_t;

    // ram
    reg [WIDTH-1:0] memory [DEPTH-1:0];
    // dequeue
    if (REGISTERDOUT)
    begin
        always_ff @(posedge clock)
        begin
            if (reset) // don't need to clear ram
                data_out <= 0;
            else if (dequeue && !empty_t)
                data_out <= memory[deq_addr[ADDRWIDTH-1:0]];
        end
    end
    else
        assign data_out = memory[deq_addr[ADDRWIDTH-1:0]];
    // enqueue
    always_ff @(posedge clock)
    begin
        if (!reset && enqueue && !full_t)
            memory[enq_addr[ADDRWIDTH-1:0]] <= data_in;
    end

    // read_ptr
    always_ff @(posedge clock)
    begin
        if (reset)
            deq_addr <= 0;
        else if (dequeue && !empty_t)
            deq_addr <= deq_addr + 1;
    end

    // write
    always_ff @(posedge clock)
    begin
        if (reset)
            enq_addr <= 0;
        else if (enqueue && !full_t)
            enq_addr <= enq_addr + 1;
    end

    assign full_t = (deq_addr[ADDRWIDTH-1:0] == enq_addr[ADDRWIDTH-1:0]) && (deq_addr[ADDRWIDTH] != enq_addr[ADDRWIDTH]);
    assign empty_t = (deq_addr[ADDRWIDTH-1:0] == enq_addr[ADDRWIDTH-1:0]) && (deq_addr[ADDRWIDTH] == enq_addr[ADDRWIDTH]);
    assign full = full_t;
    assign empty = empty_t;

endmodule
