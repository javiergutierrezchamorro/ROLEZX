' ************************************************************
'  ROLEZX v30 - Reloj analogico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  Optimizaciones v30:
'   - Tabla agujas 450 bytes (solo x,y positivos)
'   - Indices 0..74 unificados
'   - Variables temporales reducidas (old)
'   - bigChar sin IF b<>0 + direccion unica
'   - Hora inicial 10:09:00 correcta (si=0, mi=11, hi=63)
'   - Fixed del arranque declaradas locales al bloque
'   - Tic-tac por frames calibrado
'
'  Compilar: zxbc -O3 -W 150 -W 160 -W 170 -W 190 -f tap -o rolezx.tap rolezx.bas
' ************************************************************

#include once "memcopy.bas"

#define cx      128
#define cy      108
#define rOuter  72
#define rHora   33
#define rMin    52
#define rSec    63
#define DIA0    7
#define DIASMES 30

FUNCTION scrAddr(y as UByte, x as UByte) as UInteger
  RETURN 16384 + (CAST(UInteger, y SHR 6) SHL 11) + (CAST(UInteger, y BAND 7) SHL 8) + (CAST(UInteger, (y SHR 3) BAND 7) SHL 5) + CAST(UInteger, x SHR 3)
END FUNCTION

DIM exn(15) as UByte = {0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF}

SUB putRom(r as UByte, c as UByte, ch as UByte)
  DIM src as UInteger = 15360 + CAST(UInteger, ch) * 8
  DIM base as UInteger = 16384 + (CAST(UInteger, r SHR 3) SHL 11) + (CAST(UInteger, r BAND 7) SHL 5) + c
  POKE base,        PEEK(src)
  POKE base + 256,  PEEK(src + 1)
  POKE base + 512,  PEEK(src + 2)
  POKE base + 768,  PEEK(src + 3)
  POKE base + 1024, PEEK(src + 4)
  POKE base + 1280, PEEK(src + 5)
  POKE base + 1536, PEEK(src + 6)
  POKE base + 1792, PEEK(src + 7)
END SUB

SUB bigChar(x as UByte, yt as UByte, ch as UByte, opv as UByte)
  DIM r as UByte
  DIM b as UByte
  DIM src as UInteger = 15360 + CAST(UInteger, ch) * 8
  DIM a0 as UInteger
  DIM m as UInteger
  FOR r = 0 TO 7
    b = PEEK(src + r)
    a0 = scrAddr(yt + r + r, x)
    m = CAST(UInteger, exn(b SHR 4)) + (CAST(UInteger, exn(b BAND 0x0F)) SHL 8)
    IF opv = 0 THEN
      POKE uinteger a0, PEEK(uinteger, a0) BOR m
      POKE uinteger a0 + 256, PEEK(uinteger, a0 + 256) BOR m
    ELSE
      POKE uinteger a0, PEEK(uinteger, a0) BXOR m
      POKE uinteger a0 + 256, PEEK(uinteger, a0 + 256) BXOR m
    END IF
  NEXT r
END SUB

SUB drawDate(n as UByte)
  DIM yr as UByte
  DIM abMid as UInteger
  FOR yr = 75 TO 92
    abMid = scrAddr(yr, 152)
    POKE abMid - 1, PEEK(abMid - 1) BOR 0x03
    POKE long abMid, -1
    POKE abMid + 4, PEEK(abMid + 4) BOR 0xC0
  NEXT yr
  IF n < 10 THEN
    bigChar(160, 76, 48 + n, 1)
  ELSE
    bigChar(152, 76, 48 + n / 10, 1)
    bigChar(168, 76, 48 + n MOD 10, 1)
  END IF
END SUB

SUB drawFace()
  DIM n as UByte
  DIM q as Byte
  DIM r as UByte
  DIM a as Fixed
  DIM b as Fixed
  DIM s as Fixed = 0
  DIM c as Fixed = 1
  DIM sa as Fixed = SIN(PI / 30.0)
  DIM ca as Fixed = COS(PI / 30.0)

  FOR n = 0 TO 59
    PLOT cx + 0.5 + (rOuter - 2) * s, cy + 0.5 + (rOuter - 2) * c
    DRAW 4 * s, 4 * c

    r = 58
    IF n MOD 5 = 0 THEN
      r = 54
      IF n <> 0 THEN
        FOR q = -1 TO 1
          a = q * 0.02
          b = s + a * c
          a = c - a * s
          PLOT cx + 0.5 + 44 * b, cy + 0.5 + 44 * a
          DRAW 8 * b, 8 * a
        NEXT q
      END IF
    END IF
    PLOT cx + 0.5 + r * s, cy + 0.5 + r * c
    DRAW (rOuter - 8 - r) * s, (rOuter - 8 - r) * c
    a = s * ca + c * sa
    c = c * ca - s * sa
    s = a
  NEXT n

  ' Corona
  PLOT cx - 6, cy + 46 : DRAW 0, 4
  PLOT cx - 3, cy + 46 : DRAW 0, 5
  PLOT cx    , cy + 46 : DRAW 0, 7
  PLOT cx + 3, cy + 46 : DRAW 0, 5
  PLOT cx + 6, cy + 46 : DRAW 0, 4
  PLOT cx - 6, cy + 46 : DRAW 12, 0

  ' ROLEZX
  bigChar(80, 44, 82, 0)  : bigChar(96, 44, 79, 0)  : bigChar(112, 44, 76, 0)
  bigChar(128, 44, 69, 0) : bigChar(144, 44, 90, 0) : bigChar(160, 44, 88, 0)

  CIRCLE cx, cy, 3
END SUB

' Tabla agujas 450 bytes: xH,yH, xM,yM, xS,yS  (75 cada uno)
DIM ax(449) as Byte AT 49152

DIM i as UByte
DIM h as UByte

DIM aw(16) as UByte = {3, 5, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 7, 7, 6, 4, 2}
DIM ad as UInteger = 22592

DIM tTitle(13) as UByte = {82, 79, 76, 69, 90, 88, 32, 98, 121, 32, 71, 117, 116, 105}
DIM tOyster(15) as UByte = {79, 89, 83, 84, 69, 82, 32, 80, 69, 82, 80, 69, 84, 85, 65, 76}
DIM tDate(7) as UByte = {68, 65, 84, 69, 74, 85, 83, 84}

' 10:09:00 exacto con 75 pasos/vuelta
' Hora:   10h * (75/12) + 9min * (75/12/60) ≈ 62.5 + 0.94 ≈ 63
' Minuto: 9 * (75/60) = 11.25 ≈ 11
' Segundo: 0
DIM si as UByte = 0
DIM mi as UByte = 11
DIM hi as UByte = 63

DIM km as UByte = 0
DIM kh as UByte = 0
DIM old as UByte
DIM dia as UByte = DIA0
DIM frames as UByte = 0
DIM toc as UByte = 20
DIM beepLeft as UByte = 0

  BORDER 0 : PAPER 0 : INK 6 : BRIGHT 1 : OVER 0 : INVERSE 0 : CLS

  MemSet(23200, 207, 32)
  FOR i = 0 TO 13 : putRom(21, 9 + i, tTitle(i)) : NEXT i
  FOR i = 0 TO 15 : putRom(8, 8 + i, tOyster(i)) : NEXT i
  FOR i = 0 TO 7  : putRom(13, 12 + i, tDate(i)) : NEXT i

  FOR h = 0 TO 16
    MemSet(ad + 16 - aw(h), 78, CAST(UInteger, aw(h)) * 2)
    ad = ad + 32
  NEXT h

  PAPER 8
  CIRCLE cx, cy, rOuter
  CIRCLE cx, cy, rOuter - 5
  drawFace()
  drawDate(dia)

  ' Tabla de agujas (variables Fixed locales al bloque)
  DIM sn as Fixed = 0
  DIM cs as Fixed = 1
  DIM sd as Fixed = SIN(PI / 150.0)
  DIM cd as Fixed = COS(PI / 150.0)
  DIM ang as Fixed

  FOR i = 0 TO 74
    ax(i)       = CAST(Byte, rHora * sn + 0.5)
    ax(i + 75)  = CAST(Byte, rHora * cs + 0.5)
    ax(i + 150) = CAST(Byte, rMin  * sn + 0.5)
    ax(i + 225) = CAST(Byte, rMin  * cs + 0.5)
    ax(i + 300) = CAST(Byte, rSec  * sn + 0.5)
    ax(i + 375) = CAST(Byte, rSec  * cs + 0.5)
    ang = sn * cd + cs * sd
    cs  = cs * cd - sn * sd
    sn  = ang
  NEXT i

  OVER 1
  PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
  PLOT cx, cy : DRAW ax(mi + 150), ax(mi + 225)
  PLOT cx, cy : DRAW ax(si + 300), ax(si + 375)

DO
  ASM
  halt
  END ASM

  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  frames = frames + 1

  IF beepLeft <> 0 THEN
    beepLeft = beepLeft - 1
    IF beepLeft = 0 THEN OUT 254, 0
  END IF

  IF (frames BAND 7) = 0 THEN
    ' Segundos
    old = si
    si = si + 1
    IF si = 75 THEN si = 0
    PLOT cx, cy : DRAW ax(si + 300), ax(si + 375)
    PLOT cx, cy : DRAW ax(old + 300), ax(old + 375)

    ' Minutos
    km = km + 1
    IF km = 60 THEN
      km = 0
      old = mi
      mi = mi + 1
      IF mi = 75 THEN mi = 0

      kh = kh + 1
      IF kh = 12 THEN
        kh = 0
        old = hi
        hi = hi + 1
        IF hi = 75 THEN
          hi = 0
          IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
          drawDate(dia)
        END IF
        PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
        PLOT cx, cy : DRAW ax(old), ax(old + 75)
      END IF

      PLOT cx, cy : DRAW ax(mi + 150), ax(mi + 225)
      PLOT cx, cy : DRAW ax(old + 150), ax(old + 225)
    END IF

    ' Tic-tac (1 frame / 2 frames)
    OUT 254, 16
    IF toc = 20 THEN
      beepLeft = 1 : toc = 45
    ELSE
      beepLeft = 2 : toc = 20
    END IF
  END IF
LOOP

BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS
