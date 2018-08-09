// tb.h - Reed Foster
// Template for Verilator testbenches

#include <stdio.h>
#include <stdint.h>

#include <assert.h>

template <class Vmodule> class TESTBENCH
{
public:
    Vmodule *m_core;
    uint64_t m_tickcount;

    TESTBENCH(void) : m_tickcount(0l)
    {
        m_core = new Vmodule;
        m_core->clock = 0;
        eval(); // Get our initial values set properly.
    }

    ~TESTBENCH(void)
    {
        delete m_core;
        m_core = NULL;
    }

    virtual void eval(void) { m_core->eval(); }

    virtual void tick(void)
    {
        m_tickcount++;
        // Make sure we have our evaluations straight before the top
        // of the clock.  This is necessary since some of the
        // connection modules may have made changes, for which some
        // logic depends.  This forces that logic to be recalculated
        // before the top of the clock.
        eval();
        m_core->clock = 1;
        eval();
        m_core->clock = 0;
        eval();
    }

    virtual	void reset(void)
    {
        m_core->reset = 1;
        tick();
        m_core->reset = 0;
    }

    unsigned long tickcount(void) { return m_tickcount; }
    bool done(void) { return (Verilated::gotFinish()); }
};
