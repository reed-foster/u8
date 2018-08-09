#include "Vfifo.h"
#include <verilated.h>

#include <stdlib.h> // for rand

#include "tb.h" // template for testbenches

class FIFO_TB : public TESTBENCH<Vfifo>
{
public:
    // override virtual functions
    void eval(void) { m_core->eval(); }
    void tick(void)
    {
        for (int i = 0; i < 2; i++)
        {
            m_tickcount++;
            eval();
            m_core->clock ^= 1;
            eval();
        }
    }
    void initializeinputs(void)
    {
        m_core->clock = 0;
        m_core->dequeue = 0;
        m_core->enqueue = 0;
        m_core->data_in = 0;
        m_core->reset = 0;
    }
    void reset(void)
    {
        initializeinputs();
        tick();
        m_core->reset = 0;
        eval();
    }

    // test functions

    void test_standard(int count) // tests standard operation; no blocked enqueues/dequeues
    {
        reset();
        count = count > 256 ? 256 : count; // default addrwidth is 256, don't want to do more than that

        // generate some test values
        int testvals[count];
        for (int i = 0; i < count; i++) { testvals[i] = rand() % 256; } // 0 to 255 for 8-bit values

        // enqueue test values
        m_core->enqueue = 1;
        for (int val : testvals)
        {
            assert(m_core->full != 1);
            m_core->data_in = val;
            tick();
        }

        // dequeue test values
        m_core->enqueue = 0;
        m_core->dequeue = 1;
        for (int i = 0; i < count; i++)
        {
            tick();
            assert(m_core->data_out == testvals[i]);
            assert((m_core->empty != 1) ^ (i == count - 1));
        }
        printf("test_standard() success!\n");
    }

    void test_full() // fills fifo, attempts to write a byte 3 times, reads back entire fifo ensuring that the byte was not successfully queued
    {
        reset();

        // fill FIFO
        m_core->enqueue = 1;
        m_core->data_in = 0xff;
        while (m_core->full != 1) { tick(); }

        //attempt to write 0x01 3 times
        m_core->data_in = 0x01;
        tick();
        tick();
        tick();

        // empty fifo, ensuring 0x01 was not written
        m_core->enqueue = 0;
        m_core->dequeue = 1;
        while (m_core->empty != 1)
        {
            tick();
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
            tick();
            i++;
        }

        // empty FIFO
        m_core->enqueue = 0;
        m_core->dequeue = 1;
        while (m_core->empty != 1) { tick(); }

        // attempt to dequeue from empty fifo
        int dataout, deqaddr;
        for (int i = 0; i < 3; i++)
        {
            dataout = m_core->data_out;
            deqaddr = m_core->fifo__DOT__deq_addr;
            tick();
            assert(dataout == m_core->data_out);
            assert(deqaddr == m_core->fifo__DOT__deq_addr);
        }
        printf("test_empty() success!\n");
    }
};

// main method
int main(int argc, char **argv, char **env)
{
    Verilated::commandArgs(argc, argv);
    FIFO_TB *tb = new FIFO_TB();
    tb->test_standard(256);
    tb->test_full();
    tb->test_empty();
    exit(0);
}
