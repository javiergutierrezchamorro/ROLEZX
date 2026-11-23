' ************************************************************
'  ROLEZX v28 - Reloj analogico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  CAMBIOS v28 (sobre v27):
'
'   * TODOS los Float de calculo geometrico pasan a Fixed
'     (tabla de agujas + drawFace). Fixed 16.16 es mas que
'     suficiente para radios <= 72 y 75/60 pasos de rotacion.
'     El arranque se acelera de forma notable (operaciones
'     aritmeticas mucho mas baratas que la FP de la ROM).
'
'   * Se mantienen SIN/COS de la ROM solo para obtener el
'     paso angular inicial (se convierten inmediatamente a
'     Fixed). El resto de la rotacion iterativa es Fixed puro.
'
'   * Redondeo simplificado a + 0.5 (con Fixed es preciso).
'
'   * Resto de optimizaciones de v26/v27 intactas (MemSet,
'     POKE long, POKE uinteger, putRom desenrollado, etc.).
'
'  Compilar con:  zxbc -O3 -W 150 -W 160 -W 170 -W 190 -f tap -o rolezx.tap rolezx.bas
' ************************************************************

#include once "memcopy.bas"

#define cx      128
#define cy      108
#define rOuter  72
#define rHora   33
#define rMin    52
#define rSec    63

#define T0      36540      ' s desde medianoche -> arranque 10:09:00
#define DIA0    7
#define DIASMES 30

#define UMBRAL  10
#define TITLE_LEN 14

FUNCTION scrAddr(y as UByte, x as UByte) as UInteger
  RETURN 16384 + (CAST(UInteger, y SHR 6) SHL 11) + (CAST(UInteger, y BAND 7) SHL 8) + (CAST(UInteger, (y SHR 3) BAND 7) SHL 5) + CAST(UInteger, x SHR 3)
END FUNCTION

DIM exn(15) as UByte = {0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF}

SUB putRom(r as UByte, c as UByte, ch as UByte)
  DIM src as UInteger
  DIM base as UInteger
  src = 15360 + CAST(UInteger, ch) * 8
  base = 16384 + (CAST(UInteger, r SHR 3) SHL 11) + (CAST(UInteger, r BAND 7) SHL 5) + c
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
  DIM yh as UByte
  DIM src as UInteger
  DIM a0 as UInteger
  DIM a1 as UInteger
  DIM lo as UByte
  DIM ro as UByte
  DIM m as UInteger
  src = 15360 + CAST(UInteger, ch) * 8
  FOR r = 0 TO 7
    b = PEEK(src + r)
    IF b <> 0 THEN
      yh = yt + r + r
      a0 = scrAddr(yh, x)
      a1 = scrAddr(yh + 1, x)
      lo = exn(b SHR 4)
      ro = exn(b BAND 0x0F)
      m = CAST(UInteger, lo) + (CAST(UInteger, ro) SHL 8)
      IF opv = 0 THEN
        POKE uinteger a0, PEEK(uinteger, a0) BOR m
        POKE uinteger a1, PEEK(uinteger, a1) BOR m
      ELSE
        POKE uinteger a0, PEEK(uinteger, a0) BXOR m
        POKE uinteger a1, PEEK(uinteger, a1) BXOR m
      END IF
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
  DIM s as Fixed
  DIM c as Fixed
  DIM sa as Fixed
  DIM ca as Fixed

  ' Paso de 6 grados (PI/30) → Fixed
  sa = SIN(PI / 30.0)
  ca = COS(PI / 30.0)
  s = 0
  c = 1

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

DIM ax(1124) as Byte AT 49152

DIM i   as UByte
DIM h   as UByte
DIM off as UInteger
DIM ang as Fixed
DIM sn  as Fixed
DIM cs  as Fixed
DIM sd  as Fixed
DIM cd  as Fixed
DIM x   as Byte
DIM y   as Byte
DIM rr(2) as UByte = {rHora, rMin, rSec}

DIM aw(16) as UByte = {3, 5, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 7, 7, 6, 4, 2}
DIM ad  as UInteger = 22592

DIM tTitle(13) as UByte = {82, 79, 76, 69, 90, 88, 32, 98, 121, 32, 71, 117, 116, 105}
DIM tOyster(15) as UByte = {79, 89, 83, 84, 69, 82, 32, 80, 69, 82, 80, 69, 84, 85, 65, 76}
DIM tDate(7)   as UByte = {68, 65, 84, 69, 74, 85, 83, 84}

DIM si as UInteger = CAST(UInteger, (T0 MOD 60) * 5 + 750)
DIM mi as UInteger = CAST(UInteger, ((T0 - T0 MOD 12) / 12) MOD 300 + 375)
DIM hi as UInteger = CAST(UInteger, ((T0 - T0 MOD 144) / 144) MOD 300)
DIM km as UByte = CAST(UByte, (T0 MOD 12) * 5)
DIM kh as UByte = CAST(UByte, ((T0 - T0 MOD 12) / 12) MOD 12)
DIM oi as UInteger
DIM om as UInteger
DIM oh as UInteger
DIM pm  as UByte = 0
DIM dia as UByte = DIA0
DIM acc as UByte = 0
DIM nb  as UByte
DIM pl  as UByte
DIM d   as UByte
DIM k   as UByte
DIM toc as UByte = 20
DIM rep as UByte = 0
DIM hp  as UByte = 0


  BORDER 0 : PAPER 0 : INK 6 : BRIGHT 1 : OVER 0 : INVERSE 0 : CLS

  MemSet(23200, 207, 32)
  FOR k = 0 TO TITLE_LEN - 1 : putRom(21, 9 + k, tTitle(k)) : NEXT k

  FOR k = 0 TO 15 : putRom(8, 8 + k, tOyster(k)) : NEXT k
  FOR k = 0 TO 7  : putRom(13, 12 + k, tDate(k)) : NEXT k

FOR h = 0 TO 16
  MemSet(ad + 16 - aw(h), 78, CAST(UInteger, aw(h)) * 2)
  ad = ad + 32
NEXT h

PAPER 8

CIRCLE cx, cy, rOuter
CIRCLE cx, cy, rOuter - 5

drawFace()
drawDate(dia)

' Tabla de agujas (Fixed)
sd = SIN(PI / 150.0)
cd = COS(PI / 150.0)
sn = 0
cs = 1

FOR i = 0 TO 74
  off = CAST(UInteger, i)
  FOR h = 0 TO 2
    x = CAST(Byte, rr(h) * sn + 0.5)
    y = CAST(Byte, rr(h) * cs + 0.5)
    ax(off)       =  x : ax(off + 75)  =  y
    ax(off + 150) = -x : ax(off + 225) = -y
    ax(off + 300) =  x
    off = off + 375
  NEXT h
  ang = sn * cd + cs * sd
  cs  = cs * cd - sn * sd
  sn  = ang
NEXT i

OVER 1

PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
PLOT cx, cy : DRAW ax(mi), ax(mi + 75)
PLOT cx, cy : DRAW ax(si), ax(si + 75)

pl = PEEK(23672)

DO
  ASM
  halt
  END ASM

  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  nb = PEEK(23672)
  d = nb - pl
  pl = nb
  acc = acc + d

  WHILE acc >= UMBRAL
    acc = acc - UMBRAL

    oi = si
    si = si + 1
    IF si = 1050 THEN si = 750
    PLOT cx, cy : DRAW ax(si), ax(si + 75)
    PLOT cx, cy : DRAW ax(oi), ax(oi + 75)

    IF rep <> 0 THEN
      PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
      rep = 0
    END IF

    km = km + 1
    IF km = 60 THEN
      km = 0
      om = mi
      mi = mi + 1
      IF mi = 675 THEN mi = 375
      PLOT cx, cy : DRAW ax(mi), ax(mi + 75)
      IF hp = 1 AND om = hi + 375 THEN
        PLOT cx + ax(hi), cy + ax(hi + 75) + 1
        DRAW ax(om) - ax(hi), ax(om + 75) - ax(hi + 75) - 1
        hp = 0
      ELSE
        PLOT cx, cy : DRAW ax(om), ax(om + 75)
      END IF

      kh = kh + 1
      IF kh = 12 THEN
        kh = 0
        oh = hi
        hi = hi + 1
        IF hi = 300 THEN
          hi = 0
          pm = 1 - pm
          IF pm = 0 THEN
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
          rep = 1 : hp = 1
        END IF
        PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
        PLOT cx, cy : DRAW ax(oh), ax(oh + 75)
      END IF
    END IF

    OUT 254, 16
    FOR k = 1 TO toc : NEXT k
    OUT 254, 0
    toc = 65 - toc
  END WHILE
LOOP

BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS