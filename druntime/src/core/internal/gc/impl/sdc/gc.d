module core.internal.gc.impl.sdc.gc;

import core.gc.gcinterface;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;

// define all the extern(C) functions we need from libdmalloc

extern(C) {
        void onOutOfMemoryError(void* pretend_sideffect = null, string file = __FILE__, size_t line = __LINE__) @trusted nothrow @nogc;

        // hooks from sdc
        void *__sd_gc_druntime_qalloc(size_t size, uint bits, void *finalizer);
        void *__sd_gc_realloc(void *ptr, size_t size);
        void *__sd_gc_free(void *ptr);
}

private pragma(crt_constructor) void gc_conservative_ctor()
{
    _d_register_sdc_gc();
}

extern(C) void _d_register_sdc_gc()
{
    import core.gc.registry;
    registerGCFactory("sdc", &initialize);
}

private GC initialize()
{
    import core.lifetime : emplace;

    // REVIEW: this is allocating the GC using the GC if we hook malloc...
    auto gc = cast(ConservativeGC) cstdlib.malloc(__traits(classInstanceSize, ConservativeGC));
    if (!gc)
        onOutOfMemoryError();

    return emplace(gc);
}


class SnazzyGC : GC
{
    void enable()
    {
        // TODO: add once there is a hook
    }

    /**
     *
     */
    void disable()
    {
        // TODO: add once there is a hook
    }

    /**
     *
     */
    void collect() nothrow
    {
        // TODO: add once there is a hook
    }

    /**
     *
     */
    void collectNoStack() nothrow
    {
        // TODO: add once there is a hook
    }

    /**
     * minimize free space usage
     */
    void minimize() nothrow
    {
        // TODO: add once there is a hook
    }

    /**
     *
     */
    uint getAttr(void* p) nothrow
    {
        // TODO: add once there is a hook
        return 0;
    }

    /**
     *
     */
    uint setAttr(void* p, uint mask) nothrow
    {
        // TODO: add once there is a hook
        return 0;
    }

    /**
     *
     */
    uint clrAttr(void* p, uint mask) nothrow
    {
        // TODO: add once there is a hook
        return 0;
    }

    /**
     *
     */
    void* malloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if(!size)
            return null;
        // TODO: deal with finalizer/typeinfo
        auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        if(blkinfo.base && !(bits & BlkAttr.NO_SCAN))
        {
            // set the data not allocated to all 0
            memset(blkinfo.base + size, 0, blkinfo.size - size);
        }
        return blkinfo.base;
    }

    /*
     *
     */
    BlkInfo qalloc(size_t size, uint bits, const scope TypeInfo ti) nothrow
    {
        if(!size)
            return BlkInfo.init;
        // TODO: deal with finalizer/typeinfo
        auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        if(blkinfo.base && !(bits & BlkAttr.NO_SCAN))
        {
            // set the data not allocated to all 0
            memset(blkinfo.base + size, 0, blkinfo.size - size);
        }
        return blkinfo;
    }

    /*
     *
     */
    void* calloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if(!size)
            return null;
        // TODO: deal with finalizer/typeinfo
        auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        if(blkinfo.base)
        {
            if(!(bits & BlkAttr.NO_SCAN))
            {
                // set the data to all 0
                memset(blkinfo.base, 0, blkinfo.size);
            }
            else
            {
                // only need to zero out the block that was asked for.
                memset(blkinfo.base, 0, size);
            }
        }
        return blkinfo.base;
    }

    /*
     *
     */
    void* realloc(void* p, size_t size, uint bits, const TypeInfo ti) nothrow
    {
        // TODO: deal with bits and typeinfo
        return __sd_gc_realloc(p, size);
    }

    /**
     * Attempt to in-place enlarge the memory block pointed to by p by at least
     * minsize bytes, up to a maximum of maxsize additional bytes.
     * This does not attempt to move the memory block (like realloc() does).
     *
     * Returns:
     *  0 if could not extend p,
     *  total size of entire memory block if successful.
     */
    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti) nothrow
    {
        // TODO: add once there is a hook
        return 0;
    }

    /**
     *
     */
    size_t reserve(size_t size) nothrow
    {
        // TODO: add once there is a hook
        return 0;
    }

    /**
     *
     */
    void free(void* p) nothrow @nogc
    {
        // Note: p is not supposed to be freed if it is an interior pointer,
        // but it is freed in SDC in this case.
        __sd_gc_free(p);
    }

    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    void* addrOf(void* p) nothrow @nogc
    {
        // TODO: add once there is a hook
        return null;
    }

    /**
     * Determine the allocated size of pointer p.  If p is an interior pointer
     * or not a gc allocated pointer, return 0.
     */
    size_t sizeOf(void* p) nothrow @nogc
    {
        // TODO: add once there is a hook
        return 0;
    }

    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    BlkInfo query(void* p) nothrow
    {
        // TODO: add once there is a hook
        return BlkInfo();
    }

    /**
     * Retrieve statistics about garbage collection.
     * Useful for debugging and tuning.
     */
    core.memory.GC.Stats stats() @safe nothrow @nogc
    {
        // TODO: add once there is a hook
        return core.memory.GC.Stats();
    }

    /**
     * Retrieve profile statistics about garbage collection.
     * Useful for debugging and tuning.
     */
    core.memory.GC.ProfileStats profileStats() @safe nothrow @nogc
    {
        // TODO: add once there is a hook
        return core.memory.GC.ProfileStats();
    }

    /**
     * add p to list of roots
     */
    void addRoot(void* p) nothrow @nogc
    {
        // TODO: add once there is a hook
    }

    /**
     * remove p from list of roots
     */
    void removeRoot(void* p) nothrow @nogc
    {
        // TODO: add once there is a hook
    }

    /**
     *
     */
    @property RootIterator rootIter() @nogc
    {
        // TODO: add once there is a hook
        return null;
    }

    /**
     * add range to scan for roots
     */
    void addRange(void* p, size_t sz, const TypeInfo ti) nothrow @nogc
    {
        // TODO: add once there is a hook
    }

    /**
     * remove range
     */
    void removeRange(void* p) nothrow @nogc
    {
        // TODO: add once there is a hook
    }

    /**
     *
     */
    @property RangeIterator rangeIter() @nogc
    {
        // TODO: add once there is a hook
        return null;
    }

    /**
     * run finalizers
     */
    void runFinalizers(const scope void[] segment) nothrow
    {
        // TODO: add once there is a hook
    }

    /*
     *
     */
    bool inFinalizer() nothrow @nogc @safe
    {
        // TODO: add once there is a hook
        return false;
    }

    /**
     * Returns the number of bytes allocated for the current thread
     * since program start. It is the same as
     * GC.stats().allocatedInCurrentThread, but faster.
     */
    ulong allocatedInCurrentThread() nothrow
    {
        // TODO: add once there is a hook
        return 0;
    }
}
