module core.internal.gc.impl.sdc.gc;

import core.gc.gcinterface;
static import core.memory;
import core.stdc.string : memcpy, memset, memmove;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;

// define all the extern(C) functions we need from libdmalloc

extern(C) nothrow {
        void onOutOfMemoryError(void* pretend_sideffect = null, string file = __FILE__, size_t line = __LINE__) @trusted nothrow @nogc;

        // hooks from sdc
        void __sd_gc_druntime_qalloc(BlkInfo *result, size_t size, uint bits, const(void)*finalizer);
        //BlkInfo __sd_gc_druntime_qalloc(size_t size, uint bits, void *finalizer);
        void __sd_gc_init();
        void __sd_gc_collect();
        void *__sd_gc_realloc(void *ptr, size_t size);
        @nogc void *__sd_gc_free(void *ptr);
        @nogc BlkInfo __sd_gc_druntime_allocInfo(void *ptr);
        size_t __sd_getArrayUsed(void *ptr, size_t pdData, bool atomic) @nogc;
        bool __sd_setArrayUsed(void *ptr, size_t pdData, size_t newUsed, size_t existingUsed, bool atomic) @nogc;
        void __sd_getArrayMetadata(void *ptr, void** base, size_t* size, size_t* flags) @nogc;
        void __sd_gc_add_roots_ptr(void *ptr, size_t len) @nogc;
        void __sd_gc_remove_roots(void *ptr) @nogc;

        void rt_finalize2(void* p, bool det, bool resetMemory) nothrow;
}

enum TYPEINFO_IN_BLOCK = cast(void*)1;

extern(C) void __sd_run_finalizer(void *ptr, size_t size, void *context)
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
            // just in case, make sure we don't wrap past 0
            while(size >= elemSize)
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
    import core.gc.registry;
    registerGCFactory("sdc", &initialize);
}

alias ThreadScanFn = extern(C) void function(void *context, void *start, void *end) nothrow;

// copied from core.thread.threadbase
alias ScanAllThreadsFn = void delegate(void*, void*) nothrow;
extern (C) void thread_scanAll(scope ScanAllThreadsFn scan) nothrow;

extern(C) void thread_scanAll_C(void *context, ThreadScanFn scanFn)
{
    static struct Scanner
    {
        ThreadScanFn scanFn;
        void *context;
        void doScan(void *start, void *end) nothrow {
            scanFn(context, start, end);
        }
    }

    auto scanner = Scanner(scanFn, context);
    thread_scanAll(&scanner.doScan);
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
    void *malloc(size_t size, uint bits, const void *context, immutable size_t *pointerbitmap) nothrow
    {
        if(!size)
            return null;
        BlkInfo blkinfo;
        __sd_gc_druntime_qalloc(&blkinfo, size, bits, context);
        return blkinfo.base;
    }

    /*
     *
     */
    BlkInfo qalloc(size_t size, uint bits, const scope TypeInfo ti) nothrow
    {
        import core.stdc.stdio;
        //printf("here, bits are %x\n", bits);
        if(!size)
            return BlkInfo.init;
        // TODO: deal with finalizer/typeinfo
        //auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        BlkInfo blkinfo;
        // need to check if ti is a class

        // establish the context pointer. If no finalizer is present, then pass null.
        // if finalize is set,
        //   if it's a class, then the finalizer will be in the block directly.
        //   if it's a struct, then the typeinfo will be used to finalize.
        void *ctx = null;
        if (bits & BlkAttr.FINALIZE)
            ctx = (bits & BlkAttr.STRUCTFINAL) ? cast(void*)ti : TYPEINFO_IN_BLOCK;

        __sd_gc_druntime_qalloc(&blkinfo, size, bits, ctx);
        return blkinfo;
    }

    /*
     *
     */
    void* calloc(size_t size, uint bits, const void* context, immutable size_t* pointerBitmap) nothrow
    {
        if(!size)
            return null;
        //auto blkinfo = __sd_gc_druntime_qalloc(size, bits, null);
        BlkInfo blkinfo;

        // TODO: need to hook SDC's zero alloc function
        __sd_gc_druntime_qalloc(&blkinfo, size, bits, context);
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
    void* realloc(void* p, size_t size, uint bits, immutable size_t *ptrBitmap) nothrow
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
    size_t extend(void* p, size_t minsize, size_t maxsize) nothrow
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
        __sd_gc_add_roots_ptr(p, 0);
    }

    /**
     * remove p from list of roots
     */
    void removeRoot(void* p) nothrow @nogc
    {
        __sd_gc_remove_roots(p);
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
        __sd_gc_add_roots_ptr(p, sz);
    }

    /**
     * remove range
     */
    void removeRange(void* p) nothrow @nogc
    {
        __sd_gc_remove_roots(p);
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

    /**
     * Get array metadata for a specific pointer. Note that the resulting
     * metadata will point at the block start, not the pointer.
     */
    ArrayMetadata getArrayMetadata(void *ptr) @nogc nothrow @trusted
    {
        void *base;
        size_t size;
        size_t flags;
        __sd_getArrayMetadata(ptr, &base, &size, &flags);
        return ArrayMetadata(base, size, flags);
    }

    /**
     * Set the array used data size. You must use a metadata struct that you
     * got from the same GC instance. If existingUsed is ~0, then this
     * overrides any used value already stored. If it's any other value, the
     * call only succeeds if the existing used value matches.
     *
     * The return value indicates success or failure.
     * Generally called via the ArrayMetadata method.
     */
    bool setArrayUsed(ref ArrayMetadata metadata, size_t newUsed, size_t existingUsed = ~0UL, bool atomic = false) nothrow @nogc @trusted
    {
        return __sd_setArrayUsed(metadata.base, metadata._gc_private_flags, newUsed, existingUsed, atomic) ? true : false;
    }

    /**
     * get the array used data size. You must use a metadata struct that you
     * got from the same GC instance.
     * Generally called via the ArrayMetadata method.
     */
    size_t getArrayUsed(ref ArrayMetadata metadata, bool atomic = false) nothrow @nogc @trusted
    {
        return __sd_getArrayUsed(metadata.base, metadata._gc_private_flags, atomic);
    }
}
