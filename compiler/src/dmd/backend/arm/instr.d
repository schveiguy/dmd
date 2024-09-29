/**
 * AArch64 instruction encodings
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/arm/instr.d, backend/cod3.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_arm_insrt.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/arm/instr.d
 */

module dmd.backend.arm.instr;

import core.stdc.stdio;

nothrow:
@safe:

enum Extend
{
    UXTB,
    UXTH,
    UXTW,
    LSL,
    UXTX = LSL,
    SXTB,
    SXTH,
    SXTW,
    SXTX,
}

/************************
 * AArch64 instructions
 */
struct INSTR
{
  pure nothrow:

    enum uint nop = 0xD503201F;

    alias reg_t = ubyte;

    /************************************ Reserved ***********************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#reserved                  */

    enum int udf = 0; // https://www.scs.stanford.edu/~zyedidia/arm64/udf_perm_undef.html


    /************************************ SME encodings *******************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#sme                        */


    /************************************ SVE encodings *******************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#sve                        */

    /* SVE integer unary operations (predicated)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#sve_int_pred_un
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#sve_int_un_pred_arit_0
     */
    static uint sve_int_un_pred_arit_0(uint size, uint opc, uint Pg, reg_t Zn, reg_t Zd)
    {
        return (4    << 24) |
               (size << 22) |
               (2    << 19) |
               (opc  << 16) |
               (5    << 13) |
               (Pg   << 10) |
               (Zn   <<  5) |
                Zd;
    }

    /************************************ Data Processing -- Immediate ****************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpimm                      */

    /* Add offset to PC
     * ADR/ADRP Xd,label
     * https://www.scs.stanford.edu/~zyedidia/arm64/adr.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/adrp.html
     */
    static uint adr(uint op, uint imm, ubyte Rd)
    {
        uint immlo = imm & 3;
        uint immhi = imm >> 2;
        return (op    << 31) |
               (immlo << 29) |
               (0x10  << 24) |
               (immhi <<  5) |
                Rd;
    }

    /* Add/subtract (immediate)
     * ADD/ADDS/SUB/SUBS Rd,Rn,#imm{, shift}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_imm
     */
    static uint addsub_imm(uint sf, uint op, uint S, uint sh, uint imm12, ubyte Rn, ubyte Rd)
    {
        assert(imm12 < 0x1000);
        return (sf     << 31) |
               (op     << 30) |
               (S      << 29) |
               (0x22   << 23) |
               (sh     << 22) |
               (imm12  << 10) |
               (Rn     <<  5) |
                Rd;
    }

    /* Add/subtract (immdiate, with tags)
     */

    /* Min/max (immdiate)
     */

    /* Logical (immediate)
     * AND/ORR/EOR/ANDS Rd,Rn,#imm
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_imm
     */
    static uint log_imm(uint sf, uint opc, uint N, uint immr, uint imms, ubyte Rn, ubyte Rd)
    {
        return (sf   << 31) |
               (opc  << 29) |
               (0x24 << 23) |
               (N    << 22) |
               (immr << 16) |
               (imms << 10) |
               (Rn   <<  5) |
                Rd;
    }

    /* Move wide (immediate)
     * MOVN/MOVZ/MOVK Rd, #imm{, LSL #shift}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#movewide
     */
     static uint movewide(uint sf, uint opc, uint hw, uint imm16, uint Rd)
     {
        return (sf    << 31) |
               (opc   << 29) |
               (0x25  << 23) |
               (hw    << 21) |
               (imm16 <<  5) |
                Rd;
     }

    /* Bitfield
     * SBFM/BFM/UBFM
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpimm
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#bitfield
     */
    static uint bitfield(uint sf, uint opc, uint N, uint immr, uint imms, reg_t Rn, reg_t Rd)
    {
        return (sf   << 31) |
               (opc  << 29) |
               (0x26 << 23) |
               (N    << 22) |
               (immr << 16) |
               (imms << 10) |
               (Rn   <<  5) |
                Rd;
    }

    /* Extract
     * EXTR
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpimm
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#extract
     */
    static uint extract(uint sf, uint op21, uint N, uint o0, reg_t Rm, uint imms, reg_t Rn, reg_t Rd)
    {
        return (sf   << 31) |
               (op21 << 29) |
               (0x27 << 23) |
               (N    << 22) |
               (o0   << 21) |
               (Rm   << 16) |
               (imms << 10) |
               (Rn   <<  5) |
                Rd;
    }

    /****************************** Branches, Exception Generating and System instructions **************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#control                          */

    /* System register move
     * MSR/MRS
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#systemmove
     */
    static uint systemmove(uint L, uint sysreg, ubyte Rt)
    {
        return (0x354 << 22) | (L << 21) | (1 << 20) | (sysreg << 5) | Rt;
    }

    enum tpidr_el0 = 0x5E82;

    /* Unconditional branch (register)
     * BLR
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#branch_reg
     */
    static uint branch_reg(uint opc, uint op2, uint op3, ubyte Rn, uint op4)
    {
        return (0x6B << 25) | (opc << 21) | (op2 << 16) | (op3 << 10) | (Rn << 5) | op4;
    }

    /* Unconditional branch (immediate)
     * B/BL
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#branch_imm
     */
    static uint branch_imm(uint op, uint imm26)
    {
        return (op << 31) | (5 << 26) | imm26;
    }

    /* Compare and branch (immediate)
     * CBZ/CBNZ
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#compbranch
     */
    static uint compbranch(uint sf, uint op, uint imm19, ubyte Rt)
    {
        return (sf << 31) | (0x1A << 25) | (op << 24) | (imm19 << 5) | Rt;
    }

    /* Test and branch (immediate)
     * TBZ/TBNZ
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#testbranch
     */
    static uint testbranch(uint b5, uint op, uint b40, uint imm14, ubyte Rt)
    {
        return (b5 << 31) | (0x1B << 25) | (op << 24) | (b40 << 19) | (imm14 << 5) | Rt;
    }


    /****************************** Data Processing -- Register **********************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpreg                     */

    /* Data-processing (1 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_1src
     */
    static uint dp_1src(uint sf, uint S, uint opcode2, uint opcode, ubyte Rn, ubyte Rd)
    {
        return (sf      << 31) |
               (1       << 30) |
               (S       << 29) |
               (0xD6    << 21) |
               (opcode2 << 16) |
               (opcode  << 10) |
               (Rn      <<  5) |
                Rd;
    }

    /* Data-processing (2 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_2src
     */
    static uint dp_2src(uint sf, uint S, uint Rm, uint opcode, ubyte Rn, ubyte Rd)
    {
        return (sf     << 31) |
               (0      << 30) |
               (S      << 29) |
               (0xD6   << 21) |
               (Rm     << 16) |
               (opcode << 10) |
               (Rn     <<  5) |
                Rd;
    }

    /* Logical (shifted register)
     * AND/BIC/ORR/ORN/EOR/ANDS/BICS Rd, Rn, Rm, {shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_shift
     */
    static uint log_shift(uint sf, uint opc, uint shift, uint N, ubyte Rm, uint imm6, ubyte Rn, ubyte Rd)
    {
        return (sf    << 31) |
               (opc   << 29) |
               (0xA   << 24) |
               (shift << 22) |
               (N     << 21) |
               (Rm    << 16) |
               (imm6  << 10) |
               (Rn    <<  5) |
                Rd;
    }

    /* Add/Subtract (shifted register)
     * ADD/ADDS/SUB/SUBS
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_shift
     */
    static uint addsub_shift(uint sf, uint op, uint S, uint shift, ubyte Rm, uint imm6, ubyte Rn, ubyte Rd)
    {
        assert(shift < 4);
        assert(imm6 < 64);
        return (sf    << 31) |
               (op    << 30) |
               (S     << 29) |
               (0xB   << 24) |
               (shift << 22) |
               (0     << 21) |
               (Rm    << 16) |
               (imm6  << 10) |
               (Rn    <<  5) |
                Rd;
    }

    /* Add/subtract (extended register)
     * ADD/ADDS/SUB/SUBS Rd, Rn, Rm, {shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_ext
     */
    static uint addsub_ext(uint sf, uint op, uint S, uint opt, ubyte Rm, uint option, uint imm3, ubyte Rn, ubyte Rd)
    {
        assert(imm3 < 8);
        return (sf   << 31) |
               (op   << 30) |
               (S    << 29) |
               (0xB  << 24) |
               (opt  << 22) |
               (1    << 21) |
               (Rm   << 16) |
               (option << 13) |
               (imm3 << 10) |
               (Rn   <<  5) |
                Rd;
    }

    /* Add/subtract (with carry)
     * ADC/ADCS/SBC/SBCS Rd, Rn, Rm
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_carry
     */
    static uint addsub_carry(uint sf, uint op, uint S, ubyte Rm, ubyte Rn, ubyte Rd)
    {
        return (sf   << 31) |
               (op   << 30) |
               (S    << 29) |
               (0xD0 << 24) |
               (Rm   << 16) |
               (Rn   <<  5) |
                Rd;
    }

    /* Add/subtract (checked pointer)
     * ADDPT/SUBPT
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_pt
     */
    static uint addsub_pt(uint sf, uint op, uint S, ubyte Rm, uint imm3, ubyte Rn, ubyte Rd)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD0 << 21) | (Rm << 16) | (1 << 13) | (imm3 << 10) | (Rn << 5) | Rd;
    }

    /* Rotate right into flags
     * RMIF
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#rmif
     */
    static uint rmif(uint sf, uint op, uint S, uint imm6, ubyte Rn, uint o2, uint mask)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xC0 << 21) | (imm6 << 15) | (1 << 10) | (Rn << 5) | (o2 << 4) | mask;
    }

    /* Evaluate into flags
     * SETF8/SETF16
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#setf
     */
    static uint setf(uint sf, uint op, uint S, uint opcode2, uint sz, ubyte Rn, uint o3, uint mask)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD0 << 21) | (opcode2 << 15) | (sz << 14) | (2 << 10) | (Rn << 5) | (o3 << 4) | mask;
    }

    /* Conditional compare (register)
     * CCMN/CCMP
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condcmp_reg
     */
    static uint condcmp_reg(uint sf, uint op, uint S, ubyte Rm, uint cond, uint o2, ubyte Rn, uint o3, uint nzcv)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD2 << 21) | (Rm << 16) | (cond << 12) | (o2 << 10) | (Rn << 5) | (o3 << 4) | nzcv;
    }

    /* Conditional compare (immediate)
     * CCMN/CCMP
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condcmp_imm
     */
    static uint condcmp_imm(uint sf, uint op, uint S, uint imm5, uint cond, uint o2, ubyte Rn, uint o3, uint nzcv)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD2 << 21) | (imm5 << 16) | (cond << 12) | (1 << 11) | (o2 << 10) | (Rn << 5) | (o3 << 4) | nzcv;
    }

    /* Conditional select
     * CSEL/CSINC/CSINV/CSNEG
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condsel
     */
    static uint condsel(uint sf, uint op, uint S, ubyte Rm, uint cond, uint o2, ubyte Rn, ubyte Rd)
    {
        assert(cond < 16);
        return (sf << 31) | (op << 30) | (S << 29) | (0xD4 << 21) | (Rm << 16) | (cond << 12) | (o2 << 10) | (Rn << 5) | Rd;
    }

    /* Data-processing (3 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_3src
     */
    static uint dp_3src(uint sf, uint op54, uint op31, uint Rm, uint o0, ubyte Ra, ubyte Rn, ubyte Rd)
    {
        uint ins = (sf   << 31) |
                   (op54 << 29) |
                   (0x1B << 24) |
                   (op31 << 21) |
                   (Rm   << 16) |
                   (o0   << 15) |
                   (Ra   << 10) |
                   (Rn   <<  5) |
                    Rd;
        return ins;
    }


    /****************************** Data Processing -- Scalar Floating-Point and Advanced SIMD **/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#simd_dp                  */

    /* Floating-point data-processing (1 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#floatdp1
     */
    static uint floatdp1(uint M, uint S, uint ftype, uint opcode, uint Rn, uint Rd)
    {
        assert(Rn < 32 && Rd < 32); // remember to convert R32-63 to 0-31
        return (M << 31) | (S << 29) | (0x1E << 24) | (ftype << 22) | (1 << 21) | (0x10 << 10) | (Rn << 5) | Rd;
    }

    // FMOV Rd, Rn  https://www.scs.stanford.edu/~zyedidia/arm64/fmov_float.html
    static uint fmov(uint ftype, uint Rn, uint Rd) { return floatdp1(0,0,ftype,0,Rn,Rd); }


    /****************************** Loads and Stores ********************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst                     */

    /* Compare and swap pair
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#comswappr
     */
    static uint comswappr(uint sz, uint L, ubyte Rs, uint o0, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return (sz << 30) | (0x10 << 23) | (L << 22) | (1 << 21) | (Rs << 16) | (o0 << 15) | (Rt2 << 10) | (Rn << 5) | Rt;
    }

    /* Advanced SIMD load/store multiple structures
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#asisdlse
     */
    static uint asisdlse(uint Q, uint L, uint opcode, uint size, ubyte Rn, ubyte Rt)
    {
        return (Q << 30) | (0x18 << 23) | (L << 22) | (opcode << 12) | (size << 10) | (Rn << 5) | Rt;
    }

    /* Load/store register pair
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_post
     */
    static uint ldstpair(uint opc, uint VR, uint opc2, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        assert(imm7 < 0x80);
        return (opc  << 30) |
               (5    << 27) |
               (VR   << 26) |
               (opc2 << 23) |
               (L    << 22) |
               (imm7 << 15) |
               (Rt2  << 10) |
               (Rn   <<  5) |
                Rt;
    }


    /* Load/store register (immediate post-indexed)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_immpost
     */
    static uint ldst_immpost(uint size, uint VR, uint opc, uint imm9, ubyte Rn, ubyte Rt)
    {
        return (size << 30) |
               (7    << 27) |
               (VR   << 26) |
               (opc  << 22) |
               (imm9 << 12) |
               (Rn   <<  5) |
                Rt;
    }

    /* Load/store register (register offset)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     */
    static uint ldst_regoff(uint size, uint VR, uint opc, ubyte Rm, uint option, uint S, ubyte Rn, ubyte Rt)
    {
        return (size   << 30) |
               (7      << 27) |
               (VR     << 26) |
               (opc    << 22) |
               (1      << 21) |
               (Rm     << 16) |
               (option << 13) |
               (S      << 12) |
               (1      << 11) |
               (Rn     <<  5) |
                Rt;
    }

    /* Load/store register (unsigned immediate)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_pos
     */
    static uint ldst_pos(uint size, uint VR, uint opc, uint imm12, ubyte Rn, ubyte Rt)
    {
        return (size  << 30) |
               (7     << 27) |
               (VR    << 26) |
               (1     << 24) |
               (opc   << 22) |
               (imm12 << 10) |
               (Rn    <<  5) |
                Rt;
    }

    /* =============================================================================== */
    /* =============================================================================== */

    /* SBFM Rd,Rn,#immr,#imms
     * https://www.scs.stanford.edu/~zyedidia/arm64/sbfm.html
     */
    static uint sbfm(uint sf, uint N, uint immr, uint imms, reg_t Rn, reg_t Rd)
    {
        return bitfield(sf, 0, N, immr, imms, Rn, Rd);
    }

    /* ASR Rd,Rn,#shift
     * https://www.scs.stanford.edu/~zyedidia/arm64/asr_sbfm.html
     */
    static uint asr_sbfm(uint sf, uint immr, reg_t Rn, reg_t Rd)
    {
        return sbfm(sf, sf, immr, sf ? 63 : 31, Rn, Rd);
    }

    /* SBFIZ Rd,Rn,#lsb,#width
     * https://www.scs.stanford.edu/~zyedidia/arm64/sbfiz_sbfm.html
     */
    static uint sbfiz_sbfm(uint sf, uint lsb, uint width, reg_t Rn, reg_t Rd)
    {
        return sbfm(sf, sf, -lsb & (sf ? 0x3F : 0x1F), width - 1, Rn, Rd);
    }

    /* SBFX Rd,Rn,#lsb,#width
     * https://www.scs.stanford.edu/~zyedidia/arm64/sbfx_sbfm.html
     */
    static uint sbfx_sbfm(uint sf, uint lsb, uint width, reg_t Rn, reg_t Rd)
    {
        return sbfm(sf, sf, lsb, lsb + width - 1, Rn, Rd);
    }

    /* SXTB Rd,Wn
     * https://www.scs.stanford.edu/~zyedidia/arm64/sxtw_sbfm.html
     */
    static uint sxtb_sbfm(uint sf, reg_t Rn, reg_t Rd)
    {
        return sbfm(sf, sf, 0, 7, Rn, Rd);
    }

    /* SXTH Rd,Wn
     * https://www.scs.stanford.edu/~zyedidia/arm64/sxth_sbfm.html
     */
    static uint sxth_sbfm(uint sf, reg_t Rn, reg_t Rd)
    {
        return sbfm(sf, sf, 0, 15, Rn, Rd);
    }

    /* SXTW Xd,Wn
     * https://www.scs.stanford.edu/~zyedidia/arm64/sxtw_sbfm.html
     */
    static uint sxtw_sbfm(reg_t Rn, reg_t Rd)
    {
        return sbfm(1, 1, 0, 31, Rn, Rd);
    }


    /********* Branches, Exception Generating and System Instructions **********/

    /* BR Xn
     * https://www.scs.stanford.edu/~zyedidia/arm64/br.html
     */
    static uint br(ubyte Rn)
    {
        return branch_reg(0, 0x1F, 0, Rn, 0);
    }

    /* BLR Xn
     * https://www.scs.stanford.edu/~zyedidia/arm64/blr.html
     */
    static uint blr(ubyte Rn)
    {
        return branch_reg(1, 0x1F, 0, Rn, 0);
    }

    /* RET Xn
     * https://www.scs.stanford.edu/~zyedidia/arm64/ret.html
     */
    static ret(ubyte Rn = 30)
    {
        return branch_reg(2, 0x1F, 0, Rn, 0);
    }

    static assert(ret() == 0xd65f03c0);


    /****************************** Data Processing -- Register **********************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpreg                     */


    /* MADD
     * https://www.scs.stanford.edu/~zyedidia/arm64/madd.html
     */
    static uint madd(uint sf, ubyte Rm, ubyte Ra, ubyte Rn, ubyte Rd)
    {
        uint op54   = 0;
        uint op31   = 0;
        uint o0     = 0;
        return dp_3src(sf, op54, op31, Rm, o0, Ra, Rn, Rd);
    }

    /* MSUB Rd, Rn, Rm, Ra
     * https://www.scs.stanford.edu/~zyedidia/arm64/msub.html
     */
    static uint msub(uint sf, ubyte Rm, ubyte Ra, ubyte Rn, ubyte Rd)
    {
        uint op54   = 0;
        uint op31   = 0;
        uint o0     = 1;
        return dp_3src(sf, op54, op31, Rm, o0, Ra, Rn, Rd);
    }

    /* SDIV/UDIV Rd, Rn, Rm
     * http://www.scs.stanford.edu/~zyedidia/arm64/sdiv.html
     * http://www.scs.stanford.edu/~zyedidia/arm64/udiv.html
     */
    static uint sdiv_udiv(uint sf, bool uns, ubyte Rm, ubyte Rn, ubyte Rd)
    {
        uint S = 0;
        uint opcode = 2 + (uns ^ 1);
        return dp_2src(sf, S, Rm, opcode, Rn, Rd);
    }

    /* SUBS Rd, Rn, #imm{, shift }
     * https://www.scs.stanford.edu/~zyedidia/arm64/subs_addsub_imm.html
     */
    static uint subs_imm(uint sf, ubyte sh, uint imm12, ubyte Rn, ubyte Rd)
    {
        return addsub_imm(sf, 1, 1, sh, imm12, Rn, Rd);
    }

    /* CMP Rn, #imm{, shift}
     * http://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_imm.html
     */
    static uint cmp_imm(uint sf, ubyte sh, uint imm12, ubyte Rn)
    {
        return subs_imm(sf, sh, imm12, Rn, 31);
    }

    /* SUBS Rd, Rn, Rm, shift, #imm6
     * http://www.scs.stanford.edu/~zyedidia/arm64/subs_addsub_shift.html
     */
    static uint subs_shift(uint sf, ubyte Rm, uint shift, uint imm6, ubyte Rn, ubyte Rd)
    {
        return addsub_shift(sf, 1, 1, shift, Rm, imm6, Rn, Rd);
    }

    /* CMP Rn, Rm, shift, #imm6
     * http://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_shift.html
     */
    static uint cmp_shift(uint sf, ubyte Rm, uint shift, uint imm6, ubyte Rn)
    {
        return addsub_shift(sf, 1, 1, shift, Rm, imm6, Rn, 0x1F);
    }

    /* NEG/NEGS Rd,Rm,shift #imm6
     * http://www.scs.stanford.edu/~zyedidia/arm64/neg_sub_addsub_shift.html
     * http://www.scs.stanford.edu/~zyedidia/arm64/negs_subs_addsub_shift.html
     */
    static uint neg_sub_addsub_shift(uint sf, uint S, uint shift, reg_t Rm, uint imm6, reg_t Rd)
    {
        return addsub_shift(sf, 1, S, shift, Rm, imm6, 0x1F, Rd);
    }

    /* SUBS Rd, Rn, Rm, extend, #imm3
     * http://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_ext.html
     */
    static uint subs_ext(uint sf, ubyte Rm, uint option, uint imm3, ubyte Rn, ubyte Rd)
    {
        return addsub_ext(sf, 1, 1, 0, Rm, option, imm3, Rn, Rd);
    }

    /* CMP Rn, Rm, extend, #imm3
     * http://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_ext.html
     */
    static uint cmp_ext(uint sf, ubyte Rm, uint option, uint imm3, ubyte Rn)
    {
        return addsub_ext(sf, 1, 1, 0, Rm, option, imm3, Rn, 0x1F);
    }

    /* ORR Rd, Rn, Rm{, shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/orr_log_shift.html
     */
    static uint orr_shifted_register(uint sf, uint shift, ubyte Rm, uint imm6, ubyte Rn, ubyte Rd)
    {
        uint opc = 1;
        uint N = 0;
        return log_shift(sf, opc, shift, N, Rm, imm6, Rn, Rd);
    }

    /* MOV Rd, Rn, Rm{, shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/mov_orr_log_shift.html
     */
    static uint mov_register(uint sf, ubyte Rm, ubyte Rd)
    {
        return orr_shifted_register(sf, 0, Rm, 0, 31, Rd);
    }

    /* CSINC Rd, Rn, Rm, <cond>?
     * https://www.scs.stanford.edu/~zyedidia/arm64/csinc.html
     */
    static uint csinc(uint sf, ubyte Rm, uint cond, ubyte Rn, ubyte Rd)
    {
        return condsel(sf, 0, 0, Rm, cond, 1, Rn, Rd);
    }

    /* Loads and Stores */

    /* Load/store no-allocate pair (offset)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstnapair_offs
     */
    static uint ldstnapair_offs(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 0, L, imm7, Rt2, Rn, Rt);
    }

    /* Load/store register pair (post-indexed)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_post
     */
    static uint ldstpair_post(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 1, L, imm7, Rt2, Rn, Rt);
    }

    /* Load/store register pair (offset)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_off
     */
    static uint ldstpair_off(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 2, L, imm7, Rt2, Rn, Rt);
    }

    /* Load/store register pair (pre-indexed)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_pre
     */
    static uint ldstpair_pre(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 3, L, imm7, Rt2, Rn, Rt);
    }

    /* STRB (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_pos
     * https://www.scs.stanford.edu/~zyedidia/arm64/strb_imm.html
     */
    static uint strb_imm(ubyte Rt, ubyte Rn, ulong offset)
    {
        // STRB Rt,[Xn,#offset]
        uint size = 0;
        uint imm12 = offset & 0xFFF;
        return ldst_pos(0, 0, 0, imm12, Rn, Rt);
    }

    /* STRH (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_pos
     * https://www.scs.stanford.edu/~zyedidia/arm64/strh_imm.html
     */
    static uint strh_imm(ubyte Rt, ubyte Rn, ulong offset)
    {
        // STRH Rt,[Xn,#offset]
        uint size = 1;
        uint imm12 = offset & 0xFFF;
        return ldst_pos(0, 0, 0, imm12, Rn, Rt);
    }

    /* STR (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/str_imm_gen.html
     */
    static uint str_imm_gen(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // STR Rt,[Xn,#offset]
        uint size = 2 + is64;
        uint imm12 = (cast(uint)offset >> (is64 ? 3 : 2)) & 0xFFF;
        return ldst_pos(size, 0, 0, imm12, Rn, Rt);
    }

    /* LDRB(immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrb_imm_gen.html
     */
    static uint ldrb_imm(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // ldrb Rt,[Xn,#offset]
        uint size = 0;
        uint imm12 = cast(uint)offset & 0xFFF;
        return ldst_pos(size, 0, 1, imm12, Rn, Rt);
    }

    /* LDRSB(immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrsb_imm_gen.html
     */
    static uint ldrsb_imm(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // ldrsb Rt,[Xn,#offset]
        uint size = 0;
        uint imm12 = cast(uint)offset & 0xFFF;
        return ldst_pos(size, 0, 2 + is64, imm12, Rn, Rt);
    }

    /* LDRH(immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrh_imm_gen.html
     */
    static uint ldrh_imm(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // ldrb Rt,[Xn,#offset]
        uint size = 1;
        uint imm12 = cast(uint)offset & 0xFFF;
        return ldst_pos(size, 0, 1, imm12, Rn, Rt);
    }

    /* LDRSH(immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrsh_imm_gen.html
     */
    static uint ldrsh_imm(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // ldrsh Rt,[Xn,#offset]
        uint size = 1;
        uint imm12 = cast(uint)offset & 0xFFF;
        return ldst_pos(size, 0, 2 + is64, imm12, Rn, Rt);
    }

    /* LDR (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldr_imm_gen.html
     */
    static uint ldr_imm_gen(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // ldr Rt,[Rn,#offset]
        uint size = 2 + is64;
        uint imm12 = (cast(uint)offset >> (is64 ? 3 : 2)) & 0xFFF;
        return ldst_pos(size, 0, 1, imm12, Rn, Rt);
    }

    /* STRB (register)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/strb_reg.html
     */
    static uint strb_reg(reg_t Rindex,uint extend,uint S,reg_t Xbase,reg_t Rt)
    {
        // STRB Rt,Xbase,Rindex,extend S
        return ldst_regoff(0, 0, 0, Rindex, extend, S, Xbase, Rt);
    }

    /* STRH (register)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/strh_reg.html
     */
    static uint strh_reg(reg_t Rindex,uint extend,uint S,reg_t Xbase,reg_t Rt)
    {
        // STRH Rt,Xbase,Rindex,extend S
        return ldst_regoff(0, 1, 0, Rindex, extend, S, Xbase, Rt);
    }

    /* STR (register)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/str_reg_gen.html
     */
    static uint str_reg_gen(uint sz,reg_t Rindex,uint extend,uint S,reg_t Rbase,reg_t Rt)
    {
        // STR Rt,Rbase,Rindex,extend S
        return ldst_regoff(2 | sz, 0, 0, Rindex, extend, S, Rbase, Rt);
    }

    /* LDRB (register) Extended register
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrb_reg.html
     */
    static uint ldrb_reg(uint sz,reg_t Rindex,uint extend,uint S,reg_t Rbase,reg_t Rt)
    {
        // LDRB Rt,Rbase,Rindex,extend S
        return ldst_regoff(0, 0, 1, Rindex, extend, S, Rbase, Rt);
    }

    /* LDRSB (register) Extended register
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrsb_reg.html
     */
    static uint ldrsb_reg(uint sz,reg_t Rindex,uint extend,uint S,reg_t Rbase,reg_t Rt)
    {
        // LDRB Rt,Rbase,Rindex,extend S
        return ldst_regoff(0, 0, 2 + (sz == 8), Rindex, extend, S, Rbase, Rt);
    }

    /* LDRH (register) Extended register
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrh_reg.html
     */
    static uint ldrh_reg(uint sz,reg_t Rindex,uint extend,uint S,reg_t Rbase,reg_t Rt)
    {
        // LDRH Rt,Rbase,Rindex,extend S
        return ldst_regoff(1, 0, 1, Rindex, extend, S, Rbase, Rt);
    }

    /* LDRSH (register) Extended register
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldrsh_reg.html
     */
    static uint ldrsh_reg(uint sz,reg_t Rindex,uint extend,uint S,reg_t Rbase,reg_t Rt)
    {
        // LDRSH Rt,Rbase,Rindex,extend S
        return ldst_regoff(1, 0, 2 + (sz == 8), Rindex, extend, S, Rbase, Rt);
    }

    /* LDR (register)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_regoff
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldr_reg_gen.html
     */
    static uint ldr_reg_gen(uint sz,reg_t Rindex,uint extend,uint S,reg_t Rbase,reg_t Rt)
    {
        // LDR Rt,Rbase,Rindex,extend S
        return ldst_regoff(2 | sz, 0, 1, Rindex, extend, S, Rbase, Rt);
    }
}

/**********************
 * Encode bit mask
 * Params:
 *      bitmask = mask to encode
 *      N = set to N bit
 *      immr = set to immr value
 *      imms = set to imms value
 * Returns:
 *      true = success
 *      false = failure
 * References:
 *      * https://www.scs.stanford.edu/~zyedidia/arm64/shared_pseudocode.html#impl-aarch64.DecodeBitMasks.5
 */
bool encodeNImmrImms(ulong value, out uint N, out uint immr, out uint imms)
{
    if (value == 0 || value == ~0L)
        return false;

    /* `size` is the number of bits in the pattern
     */
    uint size = 64;
    if ((value ^ (value >> 32)) & 0xFFFF_FFFF)
        size = 64;
    else
    {
        value &= 0xFFFF_FFFF;
        if (value == 0 || value == 0xFFFF_FFFF)
            return false;
        if ((value ^ (value >> 16)) & 0xFFFF)
            size = 32;
        else
        {
            value &= 0xFFFF;
            if ((value ^ (value >> 8)) & 0xFF)
                size = 16;
            else
            {
                value &= 0xFF;
                if ((value ^ (value >> 4)) & 0xF)
                    size = 8;
                else
                {
                    value &= 0xF;
                    if ((value ^ (value >> 2)) & 3)
                        size = 4;
                    else
                    {
                        value &= 3;
                        size = 2;
                    }
                }
            }
        }
    }

    /* `value` is now the pattern that is `size` bits in length
     */

    static uint popcount(ulong x)
    {
        uint n = 0;
        while (x)
        {
            n += cast(uint)x & 1;
            x >>= 1;
        }
        return n;
    }

    uint numOnes = popcount(value);

    /* Is n a right-justified run of 1's?
     */
    static bool isRunRJ(ulong n) { return ((n + 1) & n) == 0; }

    uint rotation;  // how much value has been rotated left
    ulong leftMostBit = 1L << (size - 1);

    /* Case 000111 */
    if (isRunRJ(value))
    {
        rotation = 0;
    }
    /* Case 011100 */
    else if (!(value & 1))
    {
        do
        {
            value >>= 1;
            ++rotation;
        } while (!(value & 1));
    }
    /* Case 100011 */
    else
    {
        do
        {
            value = (value << 1) | 1;
            --rotation;
        } while (value & leftMostBit);
        if (size != 64)  // avoid undefined behavior for <<64
            value &= (1L << size) - 1UL;
        rotation += size;
    }
    if (!isRunRJ(value))        // if embedded 0s in pattern
        return false;

    immr = ((size - rotation) & (size - 1)) & 0x3F;
    imms = ((~(size - 1) << 1) | (numOnes - 1)) & 0x3F;
    N = size == 64;
    return true;
}

unittest
{
    uint N,immr,imms;
    assert(encodeNImmrImms(0x5555_5555_5555_5555,N,immr,imms));
    assert(N == 0 && immr == 0 && imms == 0x3C);

    assert(encodeNImmrImms(0xFFFF,N,immr,imms));
    assert(N == 1 && immr == 0 && imms == 0xF);

    assert(encodeNImmrImms(0xFF,N,immr,imms));
    assert(N == 1 && immr == 0 && imms == 0x7);
}

/******************************
 * Extract field from instruction in manner lifted from spec.
 * Params:
 *      opcode = opcode to extract field
 *      end = leftmost bit number 31..0
 *      start = rightmost bit number 31..0
 * Returns:
 *      extracted field
 */
public
uint field(uint opcode, uint end, uint start) pure
{
    assert(end < 32 && start < 32 && start <= end);
    //printf("%08x\n", (cast(uint)((cast(ulong)1 << (end + 1)) - 1) & opcode) >> start);
    return (cast(uint)((1UL << (end + 1)) - 1) & opcode) >> start; // UL prevents <<32 undefined behavior
}

unittest
{
    assert(field(0xFFFF_FFFF, 31, 31) == 1);
    assert(field(0xFFFF_FFFF, 31, 0) == 0xFFFF_FFFF);
    assert(field(0x0000_FFCF,  7, 4) == 0x0000_000C);
}

/******************************
 * Set field in instruction in manner lifted from spec.
 * Params:
 *      opcode = opcode to set field in
 *      end = leftmost bit number 31..0
 *      start = rightmost bit number 31..0
 *      value = new field value
 */
public
uint setField(uint ins, uint end, uint start, uint value) pure
{
    assert(end < 32 && start < 32 && start <= end);
    uint width = end - start + 1;
    uint mask = cast(uint)((1UL << width) - 1); // UL prevents <<32 undefined behavior
    uint shmask = mask << start;
    //printf("value: %08x end:%d start:%d width: %d mask: %08x shmask: %08x\n", value, end, start, width, mask, shmask);
    assert(value <= shmask);
    ins = (ins & ~shmask) | (value << start);
    //printf("ins: x%08x\n", ins);
    return ins;
}

unittest
{
    //printf("ins %08x\n", setField(0xFFFF_FFF1, 31, 31, 0));
    assert(setField(0xFFFF_FFF1, 31, 31,           0) == 0x7FFF_FFF1);
    assert(setField(0xFFF3_FFFF, 31, 31,           1) == 0xFFF3_FFFF);
    assert(setField(0x8000_FFCF,  7,  4,         0xD) == 0x8000_FFDF);
    assert(setField(0x8000_FFCF,  0,  0,           0) == 0x8000_FFCE);
    assert(setField(0x8000_FFCF,  0,  0,           1) == 0x8000_FFCF);
    assert(setField(0xFFFF_FFFF, 31,  0, 0x1234_5678) == 0x1234_5678);
}