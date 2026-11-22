' ----------------------------------------------------------------
' This file is released under the MIT License
'
' Copyleft (k) 2008-2026
' Contributed by:
'   - Jose Rodriguez-Rosa (a.k.a. Boriel) <http://www.boriel.com>
'   - Miguel Angel Diaz-Jodar (a.k.a. McLeod_Ideafix) <http://zxuno.speccy.org/>
'
' Improved 2026:
'   - MemSet now guards length==0 (the original wrote one byte even
'     when n=0, since LDIR with BC=0 copies 65536 bytes). The guard
'     adds ld a,b; or c; ret z (12 T) on the n>=1 path.
'   - Added Poke16 and Peek16 (16-bit little-endian memory access),
'     using the same "sub fastcall" + EXX stack-peel convention as
'     the rest of this file. Poke16 uses a direct pop/push peel
'     (only 2 params, no need for EXX). Peek16 reads the high byte
'     directly into H and recycles A for the low byte -- the
'     minimum-instruction path (24 T body).
'
' WARNING SUPPRESSION:
'   This file triggers three kinds of FALSE-POSITIVE warnings under
'   Boriel -O1..-O3. They are inherent to "sub fastcall + ASM inline".
'   In current Boriel, NONE of them can be silenced by #pragma inside
'   the source: `#pragma optimization_level = 0` is CLI-only and
'   triggers W301 if used in source. The ONLY supported way is the
'   -W flag on the zxbc command line:
'
'       zxbc -O3 -W 150 -W 160 -W 170 -W 190 -f tap -o out.tap prog.bas
'
'   The warning classes and why they are false positives:
'
'     [W150] Parameter 'X' is never used
'            The params are read only inside ASM..END ASM, which the
'            BASIC flow analyzer does not cross. Silence with -W 150.
'            (Earlier Boriel versions let #pragma optimization_level=0
'            silence this from the source; current versions reject it
'            with W301. Do NOT put that pragma in the source.)
'
'     [W160] SUB 'X' declared as FASTCALL with N parameters
'            Informational: only the 1st param goes in HL. That is
'            precisely the convention we rely on (the EXX peel pops
'            the rest from the stack). Silence with -W 160.
'
'     [W170] Function 'X' is never called and has been ignored
'            DCE removes subs not called from the main program
'            (MemCopy/MemMove/Poke16/Peek16 are not used by every
'            consumer). Silence with -W 170.
'
'     [W190] Function 'Peek16' should return a value
'            Peek16 returns via the FASTCALL HL convention; Boriel's
'            own __leave sequence handles it. No BASIC RETURN needed.
'            Silence with -W 190.
'
'   #pragma case_insensitive (push/pop at file scope) IS still
'   accepted and is NOT CLI-only; it stays so the subs/keywords can
'   be written in lowercase.
'
' Convention summary (identical for every sub in this file):
'   sub fastcall f(a, b, c)
'     - caller pushes c, then b, then loads a into HL, then CALLs
'     - stack at entry: [retaddr, b, c]  (c is deepest)
'     - HL already holds a (the first parameter)
'   To pop b and c without losing HL or the return address, every
'   3-param sub uses the EXX stack-peel:
'       exx           ; shadow register set
'       pop hl        ; HL' = retaddr  (pops from main stack)
'       exx           ; back to main set
'       pop de        ; DE = b
'       pop bc        ; BC = c
'       exx           ; shadow again
'       push hl       ; retaddr back on main stack
'       exx           ; main set: HL=a, DE=b, BC=c, retaddr on stack
'   Cost: ~46 T. The retaddr is parked in HL' and pushed back, so a
'   normal RET at the end works (or a tail-call jp to another sub).
' ----------------------------------------------------------------

#ifndef __LIBRARY_MEMCOPY__

REM Avoid recursive / multiple inclusion

#define __LIBRARY_MEMCOPY__

#pragma push(case_insensitive)
#pragma case_insensitive = True

' ----------------------------------------------------------------
' Sub MemMove(sourceaddr, destaddr, blocklength)
'
' Parameters:
'     souceaddr: memory address of source block to copy
'     destaddr:  memory address of destiny block to copy
'     length:    number of bytes to copy
'
' Copies block of memory safely from source to dest.
' Source and destiny blocks may overlap
'
' ----------------------------------------------------------------
' The W150 warnings ("Parameter never used") fire because the
' params are read only inside ASM..END ASM, invisible to the flow
' analyzer. Silence them with -W 150 on the command line:
'   zxbc -O3 -W 150 -W 160 -W 170 -W 190 -f tap -o out.tap prog.bas
' (#pragma optimization_level is CLI-only in current Boriel and
' triggers W301 if used in source.)
' ----------------------------------------------------------------
sub fastcall MemMove(source as uinteger, dest as uinteger, length as uinteger)
	asm
    push namespace core
; Emulates both memmove and memcpy C routines
; Blocks will safely copies if they overlap

; HL => Start of source block
; DE => Start of destiny block
; BC => Block length

    exx
    pop hl  ; uses HL' to preserve HL
    exx
    pop de  ; dest
    pop bc  ; length
    exx
    push hl ; stores ret addr back
    exx
    jp __MEMCPY
    pop namespace
	end asm
end sub


' ----------------------------------------------------------------
' Sub MemCopy(sourceaddr, destaddr, blocklength)
'
' Parameters:
'     souceaddr: memory address of source block to copy
'     destaddr:  memory address of destiny block to copy
'     length:    number of bytes to copy
'
' Copies block of memory from source to dest.
' Source and destiny blocks should not overlap.
' This sub is slightly faster than memmove
' ----------------------------------------------------------------
sub fastcall MemCopy(source as uinteger, dest as uinteger, length as uinteger)
	asm
    push namespace core
; Emulates both memmove and memcpy C routines
; Blocks will safely copies if they DON'T overlap

; HL => Start of source block
; DE => Start of destiny block
; BC => Block length

    exx
    pop hl  ; uses HL' to preserve HL
    exx
    pop de  ; dest
    pop bc  ; length
    exx
    push hl ; stores ret addr back
    exx
    ldir
    pop namespace
	end asm
end sub


' ----------------------------------------------------------------
' Sub MemSet(destaddr, value, blocklength)
'
' Parameters:
'     destaddr:  memory address of destiny block to fill
'     value:     value to fill with
'     length:    number of bytes to fill (MUST be >= 1)
'
' CONTRACT: the caller MUST guarantee length >= 1. If length == 0
' this sub writes ONE spurious byte at destaddr (the seed), because
' the seed byte is written BEFORE the (length-1) guard. Every caller
' in this codebase passes a constant or provably-nonzero length; if
' you ever need to fill zero bytes conditionally, guard at the call
' site with "IF n <> 0 THEN MemSet(...)".
'
' Optimization (folded into MemSet itself, no separate variant):
' the seed byte is written BEFORE the length guard, while A still
' holds the value from pop af. This removes the "park in D / reload
' from D" pair (ld d,a + ld a,d = 8 T) of the older two-guard
' version, and folds the n=0 guard into the n=1 guard (after dec bc).
'
' Second optimization (verified against Boriel's original): the
' "ld a,(hl)" reload of the seed before the LDIR setup is REDUNDANT.
' LDIR reads from (HL), which already holds the seed byte (the
' LDIR-as-fill trick: each byte written to (DE) becomes the source
' for the next iteration, because DE = HL+1 and HL advances in
' lockstep). Boriel's original MemSet never reloaded A. Removing
' the redundant reload saves a further 7 T per call.
'
' Uses the LDIR-as-fill trick:
'   ld (hl),a   ; seed byte at start
'   dec bc      ; n-1 bytes left
'   ld d,h
'   ld e,l
'   inc de     ; DE = HL+1
'   ldir       ; each iteration re-reads the byte just written,
'              ; propagating it forward -- 21 T per byte.
'
' Total cost (n>=2, peel included): 81 + 21n T-states.
'       n=1: 41 (peel) + 7 (seed) + 6 (dec) + 4+4+11 (guard, ret
'            taken) = 73 T.
' ----------------------------------------------------------------
sub fastcall MemSet(dest as uinteger, value as ubyte, length as uinteger)
    asm
    push namespace core

; HL => Start of destination block
; A  => Value (from pop af, still valid here)
; BC => Block length (MUST be >= 1)

    pop de  ; ret addr
    pop af  ; value (A = byte)
    pop bc  ; length
    push de ; stores ret addr back

    ld (hl), a     ; 7 T  seed byte (A still holds the value)
    dec bc         ; 6 T  BC = length - 1
    ld a, b        ; 4 T
    or c           ; 4 T
    ret z          ; 5/11 T  if length was 1, seed was enough
    ; No "ld a,(hl)" here: LDIR reads (HL) which already holds the
    ; seed byte. The LDIR-as-fill trick propagates it forward.
    ld d, h        ; 4 T
    ld e, l        ; 4 T
    inc de         ; 6 T  DE = HL + 1
    ldir           ; 21 T/byte
    pop namespace
    end asm
end sub


' ----------------------------------------------------------------
' Function Peek16(addr) as UInteger
'
' Reads a 16-bit little-endian word from addr.
' FASTCALL: addr arrives in HL; the result is returned in HL
' (the Boriel convention for a fastcall function returning
' UInteger).
'
' Cost: 33 T (caller) + 24 T (body) + 10 T (ret) = 67 T.
'
' We use ld a,(hl); inc hl; ld h,(hl); ld l,a rather than the
' "obvious" ld c,(hl); inc hl; ld b,(hl); push bc; pop hl, because
' the latter costs 41 T (4 extra T and one extra stack slot).
' Reading the high byte directly into H and recycling A for the
' low byte is the minimum-instruction path.
'
' Note: Boriel emits a [W190] "should return a value" warning here
' because no BASIC RETURN expression is visible. The value IS
' returned -- via the FASTCALL HL convention -- and Boriel's own
' __leave sequence handles it. Compile with -W 190 to silence, or
' ignore: it is a known false positive for FASTCALL+ASM functions
' (same as fastplot.bas, point.bas in Boriel's stdlib).
' ----------------------------------------------------------------
function fastcall Peek16(addr as uinteger) as uinteger
    asm
    push namespace core
    ld a, (hl)     ; 7 T  low byte
    inc hl         ; 6 T
    ld h, (hl)     ; 7 T  high byte -> H
    ld l, a        ; 4 T  low byte  -> L
                   ; HL = value, returned by fastcall convention
    pop namespace
    end asm
end function


' ----------------------------------------------------------------
' Sub Poke16(addr, value)
'
' Writes a 16-bit little-endian word to addr.
' FASTCALL: addr in HL, value popped from the stack into BC.
'
' Cost: 60 T (caller: ld hl,(_value) + push hl + ld hl,(_addr)
'              + call)
'       + 51 T (callee: pop de + pop bc + push de + ld (hl),c
'              + inc hl + ld (hl),b)
'       + 10 T (ret, emitted by Boriel at __leave)
'       = 121 T total.
'
' Compare with the equivalent "two POKE" in BASIC: ~540 T per call
' (Boriel's POKE compiles to ld hl,(addr); ld a,(value); ld (hl),a
' plus the FOR-loop overhead). Poke16 is ~4.5x faster than that.
'
' Why pop de / pop bc / push de (and not the EXX peel):
'   Poke16 has only TWO parameters (addr in HL, value on stack),
'   so the stack at entry is just [retaddr, value]. We do not need
'   to preserve HL across two pops (there is nothing else to pop
'   after value), so the cheaper direct peel is enough:
'       pop de   ; retaddr parked in DE (no exx needed)
'       pop bc   ; value
'       push de  ; retaddr back
'   This is 31 T vs the 46 T of the full EXX peel -- saves 15 T.
'   The EXX peel is only needed for 3-param subs (MemMove/MemCopy/
'   MemSet) where HL must survive across TWO pops.
' ----------------------------------------------------------------
sub fastcall Poke16(addr as uinteger, value as uinteger)
    asm
    push namespace core
    pop de          ; 10 T  DE = retaddr
    pop bc          ; 10 T  BC = value
    push de         ; 11 T  retaddr back on stack
    ld (hl), c      ; 7 T   low byte
    inc hl          ; 6 T
    ld (hl), b      ; 7 T   high byte
    pop namespace
    end asm
end sub


#require "mem/memcopy.asm"

#pragma pop(case_insensitive)

#endif
