module core.internal.gc.impl.sdc.gc;

import core.gc.gcinterface;
static import core.memory;
import core.stdc.string : memcpy, memset, memmove;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;

// BIG NOTE: SDC uses ALL the block for appending, by just removing the flag
// saying the block is appendable, for the last byte. However, this currently
// allows cross-block pointers, where you slice past the end of an array, now
// you are pointing at the next block. To circumvent this, whenever we allocate
// an *appendable* block, we request 1 extra byte, and whenever we deal with
// arrays, we always assume that there is one more byte than the size we have.
// Note that this is ONLY done with appendable blocks, and not ones that aren't
// appendable. We must account for this when reading and writing used sizes.
// HOWEVER, this does not happen for slabs with finalizers, because slabs with
// finalizers store the finalizers at the end of the slab slot along with the
// used space. We cheat and use the bits to determine this when allocating and
// getting the block info.

private int sizeAdjustment(size_t size, uint bits) pure nothrow @nogc @safe
{
    if(bits & BlkAttr.APPENDABLE)
    {
        // if it will be a large block, then we have to always add 1 byte, regardless of the context
        if(size >= 14336)
            return 1;
        // if there is a context pointer, we don't need to add a buffer byte
        if(!(bits & BlkAttr.FINALIZE))
            return 1;
    }
    // no size adjustment needed.
    return 0;
}

// define all the extern(C) functions we need from libdmalloc

extern(C) nothrow {
        void onOutOfMemoryError(void* pretend_sideffect = null, string file = __FILE__, size_t line = __LINE__) @trusted nothrow @nogc;

        // hooks from sdc
        void* __sd_gc_alloc_finalizer(size_t size, void *finalizer);
        void* __sd_gc_alloc_finalizer_no_pointers(size_t size, void *finalizer);
        void* __sd_gc_alloc(size_t size);
        void* __sd_gc_alloc_no_pointers(size_t size);
        void __sd_gc_init();
        void __sd_gc_collect();
        void *__sd_gc_realloc(void *ptr, size_t size);
        void *__sd_gc_free(void *ptr) @nogc;
        bool __sd_gc_fetch_alloc_info(void *ptr, void** base, size_t* size, size_t* gcPrivateData, BlkAttr* flags) @nogc;
        size_t __sd_gc_get_array_used(void *ptr, size_t pdData) @nogc;
        bool __sd_gc_set_array_used(void *ptr, size_t pdData, size_t newUsed, size_t existingUsed) @nogc;
        void __sd_gc_add_roots(void[] range) @nogc;
        void __sd_gc_remove_roots(void *ptr) @nogc;

        // hook to druntime finalization.
        void rt_finalize2(void* p, bool det, bool resetMemory) nothrow;
}

enum TYPEINFO_IN_BLOCK = cast(void*)1;

extern(C) void __sd_gc_finalize(void *ptr, size_t size, void *context)
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
        auto blkinfo = query(p);
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
        // TODO, NO_SCAN is not supported, all blocks are scanned, but sdc
        // does support non-pointer allocations, just not through the C api.
        void* ctx = (context is null && (bits & BlkAttr.FINALIZE)) ?
            TYPEINFO_IN_BLOCK : cast(void*)context;
        if(ctx)
            bits |= BlkAttr.FINALIZE;
        size += sizeAdjustment(size, bits);
        if(ctx || (bits & BlkAttr.APPENDABLE))
	{
		if(bits & BlkAttr.NO_SCAN)
			return __sd_gc_alloc_finalizer_no_pointers(size, ctx);
		else
			return __sd_gc_alloc_finalizer(size, ctx);
	}
        else
	{
		if(bits & BlkAttr.NO_SCAN)
			return __sd_gc_alloc_no_pointers(size);
		else
			return __sd_gc_alloc(size);
	}
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
        BlkInfo blkinfo;
        auto ctx = (bits & BlkAttr.STRUCTFINAL) ? cast(void*)ti : null;

        auto ptr = malloc(size, bits, ctx, null);
        if(!ptr)
            return BlkInfo.init;
        size_t context;
        __sd_gc_fetch_alloc_info(ptr, &blkinfo.base, &blkinfo.size, &context, cast(BlkAttr*)&blkinfo.attr);
        blkinfo.size -= sizeAdjustment(blkinfo.size, blkinfo.attr);
        return blkinfo;
    }

    /*
     *
     */
    void* calloc(size_t size, uint bits, const void* context, immutable size_t* pointerBitmap) nothrow
    {
        if(!size)
            return null;

        // TODO: need to hook SDC's zero alloc function
        auto ptr = malloc(size, bits, context, pointerBitmap);
        if(ptr)
        {
            // zero out the allocated data.
            memset(ptr, 0, size);
        }
        return ptr;
    }

    /*
     *
     */
    void* realloc(void* p, size_t size, uint bits, immutable size_t *ptrBitmap) nothrow
    {
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
        auto blkinfo = query(p);
        return blkinfo.base;
    }

    /**
     * Determine the allocated size of pointer p.  If p is an interior pointer
     * or not a gc allocated pointer, return 0.
     */
    size_t sizeOf(void* p) nothrow @nogc
    {
        auto blkinfo = query(p);
        return blkinfo.size;
    }

    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    BlkInfo query(void* p) nothrow
    {
        BlkInfo result;
        size_t context;
        if (__sd_gc_fetch_alloc_info(p, &result.base, &result.size, &context, cast(BlkAttr*)&result.attr))
        {
            // determine if we need a size adjustment
            result.size -= sizeAdjustment(result.size, result.attr);
            return result;
        }
        return BlkInfo.init;
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
        __sd_gc_add_roots(p[0 .. 0]);
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
        __sd_gc_add_roots(p[0 .. sz]);
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
        size_t flags; // page descriptor
        BlkAttr attrs;
        if(!__sd_gc_fetch_alloc_info(ptr, &base, &size, &flags, &attrs))
            return ArrayMetadata.init;

        // If attrs is not appendable, then this has no metadata and can't be
        // appended.
        if(!(attrs & BlkAttr.APPENDABLE))
            // not appendable
            return ArrayMetadata.init;
        size -= sizeAdjustment(size, attrs);
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
    bool setArrayUsed(ref ArrayMetadata metadata, size_t newUsed, size_t existingUsed = size_t.max, bool atomic = false) nothrow @nogc @trusted
    {
        // if the size is not even, then we have the buffer byte involved
        int addone = metadata.size & 1;
        if(existingUsed < size_t.max)
            existingUsed += addone;
        return __sd_gc_set_array_used(metadata.base, metadata._gc_private_flags, newUsed + addone, existingUsed);
    }

    /**
     * get the array used data size. You must use a metadata struct that you
     * got from the same GC instance.
     * Generally called via the ArrayMetadata method.
     */
    size_t getArrayUsed(ref ArrayMetadata metadata, bool atomic = false) nothrow @nogc @trusted
    {
        // if the size is not even, then we have the buffer byte involved
        int addone = metadata.size & 1;
        auto result = __sd_gc_get_array_used(metadata.base, metadata._gc_private_flags);
        // defend against wrapping.
        if(result) result -= addone;
        return result;
    }
}
