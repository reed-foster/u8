// asyncfifo.v - Reed Foster
// FIFO with support for asynchronous read and write clocks

module asyncfifo
    #( // parameters
        parameter ADDRWIDTH = 8,
        parameter WIDTH = 8
    )( // ports
        input deq_clock, enq_clock,
        input dequeue, enqueue,
        input reset,
        input [WIDTH - 1:0] data_in,
        output [WIDTH - 1:0] data_out,
        output full, empty
    );

    // architecture

    wire empty_t, full_t;
    assign full = full_t;
    assign empty = empty_t;

    // synchronizer and pointer/address wires
    wire [ADDRWIDTH:0] enqueue_ptr_sync, dequeue_ptr_sync;
    wire [ADDRWIDTH:0] enqueue_ptr, dequeue_ptr;

    // ram
    localparam DEPTH = 2 ** ADDRWIDTH;
    reg [WIDTH-1:0] memory [DEPTH-1:0];
    // dequeue
    always_ff @(posedge deq_clock)
    begin
        if (reset) // don't need to clear ram
            data_out <= 0;
        else if (dequeue && !empty_t)
            data_out <= memory[dequeue_ptr[ADDRWIDTH-1:0]];
    end
    // enqueue
    always_ff @(posedge enq_clock)
    begin
        if (!reset && enqueue && !full_t)
            memory[enqueue_ptr[ADDRWIDTH-1:0]] <= data_in;
    end

    // Pointer/Address counters and status
    ptrstatus #(.WIDTH(ADDRWIDTH + 1), .MODE(0)) enq_ptrstatus
        (
            .inc            (enqueue),
            .clock          (enq_clock),
            .reset          (reset),
            .oppclockptr    (dequeue_ptr_sync),
            .pointer        (enqueue_ptr),
            .status         (full_t)
        );
    ptrstatus #(.WIDTH(ADDRWIDTH + 1), .MODE(1)) deq_ptrstatus
        (
            .inc            (dequeue),
            .clock          (deq_clock),
            .reset          (reset),
            .oppclockptr    (enqueue_ptr_sync),
            .pointer        (dequeue_ptr),
            .status         (empty_t)
        );

    // synchronizers
    ffsync #(.WIDTH(ADDRWIDTH + 1)) enq2deq
        (
            .signal         (enqueue_ptr),
            .clock          (deq_clock),
            .reset          (reset),
            .signal_sync    (enqueue_ptr_sync)
        );
    ffsync #(.WIDTH(ADDRWIDTH + 1)) deq2enq
        (
            .signal         (dequeue_ptr),
            .clock          (enq_clock),
            .reset          (reset),
            .signal_sync    (dequeue_ptr_sync)
        );
endmodule
