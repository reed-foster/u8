// cache.v - Reed Foster
// cache memory and controller

module cache
    #( // parameters
        parameter OFFSETWIDTH = 5, // 32-bytes of data per line
        parameter INDEXWIDTH = 11, // 2048 lines
    )( // ports
        // processor interface
        input store, // enable storing of data
        input load, // enable loading of data
        input [23:0] fulladdress, // 2 bits for bank address, 13 for row, and 9 for column
        input [7:0] d_in,
        output [7:0] d_out,
        input clock,
        output new_dout,

        // sdram controller interface
        // address is connected to SDRAM component in supercomponent
        output [15:0] data_to_ram, // data from cache
        input [15:0] data_from_ram, // data to cache
        output readreq, writereq,
        output read, write, // asserted when actually reading from or writing to fifos
        input readready, writeready, // alias for !readfifo.empty and !writefifo.full
    );

    // architecture
    // bitwidth constants
    localparam LINESIZEBYTES = 2 ** OFFSETWIDTH;
    localparam TAGWIDTH = 24 - INDEXWIDTH - OFFSETWIDTH;
    localparam LINEWIDTH = 1 + TAGWIDTH + 8 * LINESIZEBYTES;
    localparam NUMLINES = 2 ** INDEXWIDTH;

    // addresses
    wire [INDEXWIDTH-1:0] index;
    wire [TAGWIDTH-1:0] tag;
    wire [OFFSETWIDTH-1:0] offset;
    assign index = fulladdress[23:24-INDEXWIDTH];
    assign tag = fulladdress[23-INDEXWIDTH:OFFSETWIDTH];
    assign offset = fulladdress[OFFSETWIDTH-1:0];

    // memory
    reg [LINEWIDTH-1:0] memory [NUMLINES-1:0];
    always_comb
    begin
        if (load && hit)
        begin
            d_out = memory[index][8*(offset+1):8*offset];
        else
            d_out = 0;
        end
    end

    // hit logic
    wire hit;
    always_comb
    begin
        if ((load || store) && // only assert hit if we're performing a load or store
            memory[index][LINEWIDTH-1] && // valid bit is set
            (memory[index][LINEWIDTH-2:LINEWIDTH-1-TAGWIDTH] == tag)) // tags match
            hit = 1;
        else
            hit = 0;
        end
    end

    // states
    // DEFAULT: default mode of operation, 0 ck read/write latency for hits
    // READREQ: sends read request to SDRAM controller
    // WRITEREQ: sends write request to SDRAM controller
    // READLINE: stores data to RAM from cache line (in case of eviction)
    // WRITELINE: loads data from RAM to cache line. can't accept additional requests (not an issue for singlescalar execution)
    //
    // always do read req first, then write req
    // after write req, wait until writeready is asserted to evict line
    // at the same time, wait until readready is asserted to shift SDRAM controller fifo data in.
    // store the first value in a register attatched to d_out.
    // once data is shifted in, attach tag and valid bit, then write to cache memory.

endmodule;
