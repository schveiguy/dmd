module core.internal.gc.impl.sdc.gc;

import core.gc.gcinterface;
static import core.memory;
import core.stdc.string : memcpy, memset, memmove;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;

// define all the extern(C) functions we need from libdmalloc

extern(C) nothrow {
        void onOutOfMemoryError(void* pretend_sideffect = null, string file = __FILE__, size_t line = __LINE__) @trusted nothrow @nogc;

        // hooks from sdc
        void __sd_gc_druntime_qalloc(BlkInfo *result, size_t size, uint bits, void *finalizer);
        //BlkInfo __sd_gc_druntime_qalloc(size_t size, uint bits, void *finalizer);
        void __sd_gc_init();
        void __sd_gc_collect();
        void *__sd_gc_realloc(void *ptr, size_t size);
        @nogc void *__sd_gc_free(void *ptr);
        @nogc BlkInfo __sd_gc_druntime_allocInfo(void *ptr);
        void __sd_gc_setBlockFinalizer(typeof(&_destroyBlockCtx) fn);
        void rt_finalize2(void* p, bool det, bool resetMemory) nothrow;
}

enum TYPEINFO_IN_BLOCK = cast(void*)1;

extern(C) void _destroyBlockCtx(void *ptr, size_t size, void *context)
{
    import core.stdc.stdio;

    //printf("here, ptr = %p, size = %ld, context = %p\n", ptr, size, context);
    // if typeinfo is cast(void*)1, then the TypeInfo is inside the block (i.e.
    // this is an object).
    if(context == TYPEINFO_IN_BLOCK)
    {
        //printf("finalizing class\n");
        rt_finalize2(ptr, false, false);
    }
    else
    {
        // context is a typeinfo pointer, which can be used to destroy the
        // elements in the block.
        auto ti = cast(TypeInfo)context;
        auto elemSize = ti.tsize;
        if(elemSize == 0)
        {
            // call the destructor on the pointer, and be done
            ti.destroy(ptr);
        }
        else
        {
            // if an array, ensure the size is a multiple of the type size.
            assert(size % elemSize == 0);
            while(size > 0)
            {
                ti.destroy(ptr);
                ptr += elemSize;
                size -= elemSize;
            }
        }
    }
}

private pragma(crt_constructor) void gc_conservative_ctor()
{
    _d_register_sdc_gc();
}

extern(C) void _d_register_sdc_gc()
{
    // HACK: this is going to set up the ThreadCache in SDC for the main thread.
    __sd_gc_init();
    __sd_gc_setBlockFinalizer(&_destroyBlockCtx);
    import core.gc.registry;
    registerGCFactory("sdc", &initialize);
}

// since all the real work is done in the SDC library, the class is just a
// shim, and can just be initialized at compile time.
private __gshared SnazzyGC instance = new SnazzyGC;

private GC initialize()
{
    import core.stdc.stdio;
    printf("using SDC GC!\n");
    return instance;
}

final class SnazzyGC : GC
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
        __sd_gc_collect();
    }

    /**
     *
     */
    void collectNoStack() nothrow
    {
        // just do the same thing for now? Not sure why this exists.
        __sd_gc_collect();
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
        auto blkinfo = __sd_gc_druntime_allocInfo(p);
        return blkinfo.attr;
    }

    /**
     *
     */
    uint setAttr(void* p, uint mask) nothrow
    {
        // SDC GC does not support setting attributes after allocation
        return getAttr(p);
    }

    /**
     *
     */
    uint clrAttr(void* p, uint mask) nothrow
    {
        // SDC GC does not support setting attributes after allocation
        return getAttr(p);
    }

    /**
     *
     */
    void* malloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if(!size)
            return null;
        // TODO: deal with finalizer/typeinfo
        BlkInfo blkinfo = qalloc(size, bits, ti);
        return blkinfo.base;
    }

    /*
     *
     */
    BlkInfo qalloc(size_t size, uint bits, const scope TypeInfo ti) nothrow
    {
        import core.stdc.stdio;
        /*if(ti !is null)
            printf("here %s\n", ti.toString().ptr);
        else
            printf("here null typeinfo\n");*/
        if(!size)
            return BlkInfo.init;
        // TODO: deal with finalizer/typeinfo
        //auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        BlkInfo blkinfo;
        // need to check if ti is a class
        void *ctx = null;
        if(auto cti = cast(TypeInfo_Class)ti)
        {
            //printf("allocating class\n");
            ctx = TYPEINFO_IN_BLOCK;
        }
        else if(auto sti = cast(TypeInfo_Struct)ti)
        {
            if(sti.xdtor)
            {
                //printf("allocating struct with finalizer\n");
                ctx = cast(void*)sti;
            }
            else {
                //printf("allocating struct\n");
            }
        }
        // else, no typeinfo needed

        __sd_gc_druntime_qalloc(&blkinfo, size, bits, ctx);
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
        //auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        BlkInfo blkinfo;
        // need to check if ti is a class
        bool isObject = (cast(TypeInfo_Class)ti) !is null;
        __sd_gc_druntime_qalloc(&blkinfo, size, bits, isObject ? TYPEINFO_IN_BLOCK : cast(void *)ti);
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
        auto blkinfo = __sd_gc_druntime_allocInfo(p);
        return blkinfo.base;
    }

    /**
     * Determine the allocated size of pointer p.  If p is an interior pointer
     * or not a gc allocated pointer, return 0.
     */
    size_t sizeOf(void* p) nothrow @nogc
    {
        auto blkinfo = __sd_gc_druntime_allocInfo(p);
        return blkinfo.size;
    }

    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    BlkInfo query(void* p) nothrow
    {
        return __sd_gc_druntime_allocInfo(p);
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
