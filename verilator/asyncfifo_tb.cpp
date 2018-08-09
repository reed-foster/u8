#include "Vasyncfifo.h"
#include <verilated.h>

#include <stdlib.h> // for rand
#include <algorithm> // for std::max

#include "tb.h" // template for testbenches

#define DEQCKPERIOD 3 // number of base clock periods in one deq_clock period
#define ENQCKPERIOD 2 // same as DEQCKPERIOD but for enq_clock

class ASYNCFIFO_TB : public TESTBENCH<Vasyncfifo>
{
public:
    // override virtual functions
    void eval(void) { m_core->eval(); }
    void tick(void)
    {
        m_tickcount++;
        eval();
        if (m_tickcount % DEQCKPERIOD == 0)
            m_core->deq_clock ^= 1;
        if (m_tickcount % ENQCKPERIOD == 0)
            m_core ->enq_clock ^= 1;
        eval();
    }
    void initializeinputs(void)
    {
        m_tickcount = 0;
        m_core->deq_clock = 0;
        m_core->enq_clock = 0;
        m_core->dequeue = 0;
        m_core->enqueue = 0;
        m_core->data_in = 0;
        m_core->reset = 0;
    }
    void reset(void)
    {
        initializeinputs();
        m_core->reset = 1;
        for (int i = 0; i < 2 * std::max(DEQCKPERIOD, ENQCKPERIOD); i++) { tick(); } // toggle baseclock 2 * maxperiod in order to ensure >= 1 rising edge on both clocks
        m_core->reset = 0;
        eval();
    }

    void to_rising_edge(CData *clk) // reference to clock port
    {
        if (*clk == 1)
            while (*clk != 0) { tick(); }
        while (*clk != 1) { tick(); }
    }

    // test methods
    void test_standard(void) // fills and empties fifo, ensuring data is preserved
    {
        reset();
        int count = 256;

        // generate some test values
        int testvals[count];
        for (int i = 0; i < count; i++) { testvals[i] = rand() % 256; } // 0 to 255 for 8-bit values

        // fill FIFO
        m_core->enqueue = 1;
        for (int val : testvals)
        {
            m_core->data_in = val;
            to_rising_edge(&(m_core->enq_clock));
        }

        // empty FIFO
        m_core->enqueue = 0;
        m_core->dequeue = 1;
        for (int i = 0; i < count; i++)
        {
            to_rising_edge(&(m_core->deq_clock));
            assert(m_core->data_out == testvals[i]);
        }
        printf("test_standard() success!\n");
    }

    void test_full() // fills fifo, attempts to write a byte 3 times, reads back entire fifo ensuring that the byte was not successfully queued
    {
        reset();

        // fill FIFO
        m_core->enqueue = 1;
        m_core->data_in = 0xff;
        while (m_core->full != 1) { to_rising_edge(&(m_core->enq_clock)); }

        //attempt to write 0x01 3 times
        m_core->data_in = 0x01;
        for (int i = 0; i < 3; i++) { to_rising_edge(&(m_core->enq_clock)); }

        // empty fifo, ensuring 0x01 was not written
        m_core->enqueue = 0;
        m_core->dequeue = 1;
        while (m_core->empty != 1)
        {
            to_rising_edge(&(m_core->deq_clock));
            assert(m_core->data_out == 0xff);
        }
        printf("test_full() success!\n");
    }

    void test_empty() // fills and empties fifo, attempts to dequeue 3 times, ensuring that data_out and fifo__DOT__deq_addr don't change
    {
        reset();

        // fill FIFO
        m_core->enqueue = 1;
        int i = 0;
        while (m_core->full != 1)
        {
            m_core->data_in = i;
            to_rising_edge(&(m_core->enq_clock));
            i++;
        }

        // empty FIFO
        m_core->enqueue = 0;
        m_core->dequeue = 1;
        while (m_core->empty != 1) { to_rising_edge(&(m_core->deq_clock)); }

        // attempt to dequeue from empty fifo
        int dataout, deqaddr;
        for (int i = 0; i < 3; i++)
        {
            dataout = m_core->data_out;
            deqaddr = m_core->asyncfifo__DOT__deq_ptrstatus__DOT__binary;
            to_rising_edge(&(m_core->deq_clock));
            assert(dataout == m_core->data_out);
            assert(deqaddr == m_core->asyncfifo__DOT__deq_ptrstatus__DOT__binary);
        }
        printf("test_empty() success!\n");
    }
};

// main method
int main(int argc, char **argv, char **env)
{
    Verilated::commandArgs(argc, argv);
    ASYNCFIFO_TB *tb = new ASYNCFIFO_TB();
    tb->test_standard();
    tb->test_full();
    tb->test_empty();
    exit(0);
}
