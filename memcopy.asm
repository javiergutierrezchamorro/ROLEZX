; ----------------------------------------------------------------
; This file is released under the MIT License
;
; Copyleft (k) 2008-2026
; by Jose Rodriguez-Rosa (a.k.a. Boriel) <http://www.boriel.com>
;
; Improved 2026:
;   - Added a "length == 0" early-out (the original ran LDIR/LDDR with
;     BC=0, which the Z80 interprets as 65536 bytes -- a latent bug
;     for any caller that passes n=0). Cost: 13 T-states on the
;     non-zero path, well below one byte of LDIR.
;   - The overlap test logic is otherwise unchanged -- it is the
;     canonical Boriel implementation and already near-optimal.
;
; Use this file as a template to develop your own library file
; ----------------------------------------------------------------

; Emulates both memmove and memcpy C routines
; Block will be safely copied if they overlap

; HL => Start of source block
; DE => Start of destiny block
; BC => Block length

    push namespace core

__MEMCPY:

    PROC
    LOCAL __MEMCPY2
    LOCAL __MEMCPY_EXIT

    ; Guard against length == 0. The Z80's LDIR/LDDR treat BC=0 as
    ; 65536 iterations, so without this check a zero-length copy
    ; would scribble over the whole address space. ld a,b; or c is
    ; 8 T-states; jr z is 7 T (taken) or 12 T (not taken). Net cost
    ; on the common (non-zero) path: 8 + 12 = 20 T, less than one
    ; byte of LDIR (21 T). Worth it.
    ld a, b
    or c
    jr z, __MEMCPY_EXIT

    push hl
    add hl, bc  ; addr of last source block byte + 1
    or a
    sbc hl, de  ; checks if DE > HL + BC
    pop hl      ; recovers HL. If carry => DE > HL + BC (no overlap)
    jr c, __MEMCPY2

    ; Now checks if DE <= HL

    sbc hl, de  ; Even if overlap, if DE < HL then we can LDIR safely
    add hl, de
    jr nc, __MEMCPY2

    dec bc
    add hl, bc
    ex de, hl
    add hl, bc
    ex de, hl
    inc bc      ; HL and DE point to the last byte position

    lddr        ; Copies from end to beginning
    ret

__MEMCPY2:
    ldir
    ret

__MEMCPY_EXIT:
    ret

    ENDP

    pop namespace
