#include "Vsdram.h"

#include <stdlib.h> // for rand

#include "tb.h" // template for testbenches

#define CPUCKPERIOD 3
#define RAMCKPERIOD 2

class SDRAM_TB : public TESTBENCH<Vsdram>
{
public:
    // override virtual functions
    void eval(void) { m_core->eval(); }
    void tick(void)
    {
        m_tickcount++;
        eval();
        if (m_tickcount % CPUCKPERIOD == 0)
            m_core->pclock ^= 1;
        if (m_tickcount % RAMCKPERIOD == 0)
            m_core->ramclock ^= 1;
        eval();
        if (m_trace)
        {
            m_trace->dump(m_tickcount);
            m_trace->flush();
        }
    }
    void initializeinputs(void)
    {
        m_core->ramclock = 0;
        m_core->pclock = 0;
        m_core->fulladdress = 0;
        m_core->d_in = 0;
        m_core->readreq = 0;
        m_core->writereq = 0;
        m_core->read = 0;
        m_core->write = 0;
        m_core->data_from_ram = 0;
    }
    void reset(void)
    {
        initializeinputs();
        tick();
        eval();
    }

    void to_rising_edge(CData *clk)
    {
        while (*clk != 0) { tick(); }
        while (*clk != 1) { tick(); }
    }

    void next_rising_edge(CData *pck, CData *rck)
    {
        bool found = false;
        while (!found)
        {
            while (*pck != 0 && *rck != 0) { tick(); } // wait until 1 clock is 0
            int pck_i = *pck;
            int rck_i = *rck;
            tick();
            if (pck_i == 0 && *pck == 1) // rising edge pclock
                found = true;
            if (rck_i == 0 && *rck == 1) // risign edge rclock
                found = true;
        }
    }

    void no_stim_trace(void)
    {
        tick();
        while (m_core->udqm != 0) { tick(); } // initialize
        m_core->readreq = 1;
        to_rising_edge(&(m_core->pclock));
        m_core->readreq = 0;
        for (int i = 0; i < 16535; i++) { tick(); }
    }
};

// main method
int main(int argc, char **argv, char **env)
{
    Verilated::commandArgs(argc, argv);
    SDRAM_TB *tb = new SDRAM_TB();
    tb->opentrace("sdram_trace.vcd");
    tb->no_stim_trace();
    exit(0);
}
