// tb.h - Reed Foster
// Template for Verilator testbenches

#include <verilated.h>
#include <verilated_vcd_c.h>

#include <stdio.h>
#include <stdint.h>

#include <assert.h>

// it is expected that all virtual methods are overridden if they are to be used
template <class Vmodule> class TESTBENCH
{
public:
    Vmodule *m_core;
    VerilatedVcdC *m_trace;
    uint64_t m_tickcount;

    TESTBENCH(void) : m_tickcount(0l)
    {
        Verilated::traceEverOn(true);
        m_core = new Vmodule;
        initializeinputs();
    }

    ~TESTBENCH(void)
    {
        delete m_core;
        m_core = NULL;
    }

    void opentrace(const char *vcdname)
    {
        if (!m_trace)
        {
            m_trace = new VerilatedVcdC;
            m_core->trace(m_trace, 99);
            m_trace->open(vcdname);
        }
    }

    void close(void)
    {
        if (m_trace)
        {
            m_trace->close();
            m_trace = NULL;
        }
    }

    virtual void initializeinputs(void) {}

    virtual void eval(void) { m_core->eval(); }

    virtual void tick(void)
    {
        m_tickcount++;
        if (m_trace)
        {
            m_trace->dump(10*m_tickcount);
            m_trace->flush();
        }
    }

    virtual	void reset(void) { initializeinputs(); }

    bool done(void) { return (Verilated::gotFinish()); }
};
