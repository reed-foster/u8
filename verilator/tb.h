// tb.h - Reed Foster
// Template for Verilator testbenches

#include <stdio.h>
#include <stdint.h>

#include <assert.h>

// it is expected that all virtual methods are overridden if they are to be used
template <class Vmodule> class TESTBENCH
{
public:
    Vmodule *m_core;
    uint64_t m_tickcount;

    TESTBENCH(void) : m_tickcount(0l)
    {
        m_core = new Vmodule;
        initializeinputs();
    }

    ~TESTBENCH(void)
    {
        delete m_core;
        m_core = NULL;
    }

    virtual void initializeinputs(void) {}

    virtual void eval(void) { m_core->eval(); }

    virtual void tick(void) { m_tickcount++; }

    virtual	void reset(void) { initializeinputs(); }

    bool done(void) { return (Verilated::gotFinish()); }
};
