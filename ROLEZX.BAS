' ************************************************************
'  ROLEZX v15.7 - Reloj analógico estilo Rolex Datejust
'  Máximo rendimiento + salida por tecla
' ************************************************************

#define cx      128
#define cy      96
#define rHora   42
#define rMin    68
#define rSec    80

#define T0      36540
#define DIA0    7
#define DIASMES 30
#define PM0     0

SUB bigChar(x as UByte, yt as UByte, ch as UByte)
  DIM r as UByte
  DIM c as UByte
  DIM b as UByte
  DIM m as UByte
  DIM px as UByte
  DIM py as UByte
  DIM adr as UInteger
  adr = 15360 + CAST(UInteger, ch) * 8
  FOR r = 0 TO 7
    b = PEEK(adr + r)
    IF b THEN
      m = 128
      px = x
      py = 191 - yt - r - r
      FOR c = 0 TO 7
        IF b BAND m THEN
          PLOT px, py : PLOT px + 1, py
          PLOT px, py - 1 : PLOT px + 1, py - 1
        END IF
        m = m >> 1
        px = px + 2
      NEXT c
    END IF
  NEXT r
END SUB

SUB drawDate(n as UByte)
  OVER 0 : INVERSE 1
  PRINT AT 11,19; "    "; AT 12,19; "    ";
  IF n < 10 THEN
    bigChar(160, 88, 48 + n)
  ELSE
    bigChar(152, 88, 48 + n / 10)
    bigChar(168, 88, 48 + n MOD 10)
  END IF
  INVERSE 0 : OVER 1
END SUB

SUB drawFace()
  DIM n as UByte
  DIM q as Byte
  DIM r as UByte
  DIM a as Float
  DIM b as Float
  DIM s as Float
  DIM c as Float

  BORDER 0 : PAPER 0 : INK 6 : BRIGHT 1 : OVER 0 : INVERSE 0 : CLS

  CIRCLE cx, cy, 94
  CIRCLE cx, cy, 89

  FOR n = 0 TO 59
    a = n * (PI / 30.0)
    s = SIN(a) : c = COS(a)
    PLOT cx + 0.5 + 89 * s, cy + 0.5 + 89 * c
    DRAW 5 * s, 5 * c

    IF n MOD 5 = 0 THEN
      r = 74
      IF n THEN
        FOR q = -1 TO 1
          a = q * 0.02
          b = s + a * c
          a = c - a * s
          PLOT cx + 0.5 + 61 * b, cy + 0.5 + 61 * a
          DRAW 11 * b, 11 * a
        NEXT q
      END IF
    ELSE
      r = 78
    END IF
    PLOT cx + 0.5 + r * s, cy + 0.5 + r * c
    DRAW (84 - r) * s, (84 - r) * c
  NEXT n

  ' Corona
  PLOT cx - 8, cy + 62 : DRAW 0, 5
  PLOT cx - 4, cy + 62 : DRAW 0, 7
  PLOT cx    , cy + 62 : DRAW 0, 9
  PLOT cx + 4, cy + 62 : DRAW 0, 7
  PLOT cx + 8, cy + 62 : DRAW 0, 5
  PLOT cx - 8, cy + 62 : DRAW 16, 0

  bigChar(80, 53, 82) : bigChar(96, 53, 79) : bigChar(112, 53, 76)
  bigChar(128, 53, 69) : bigChar(144, 53, 90) : bigChar(160, 53, 88)
  PRINT AT 9, 8; "OYSTER PERPETUAL"
  PRINT AT 14, 12; "DATEJUST"

  PLOT 151, 87 : DRAW 33, 0 : DRAW 0, 17 : DRAW -33, 0 : DRAW 0, -17
  CIRCLE cx, cy, 3
END SUB

' Tablas de agujas
DIM hx(299) as Byte
DIM hy(299) as Byte
DIM mx(299) as Byte
DIM my(299) as Byte
DIM sx(299) as Byte
DIM sy(299) as Byte

DIM i as UByte
DIM ang as Float
DIM sn as Float
DIM cs as Float
DIM x as Integer
DIM y as Integer

FOR i = 0 TO 74
  ang = i * (PI / 150.0)
  sn = SIN(ang) : cs = COS(ang)

  x = CAST(Integer, rHora * sn + 0.5) : y = CAST(Integer, rHora * cs + 0.5)
  hx(i)     = x  : hy(i)     = y
  hx(i + 75)  = y  : hy(i + 75)  = -x
  hx(i + 150) = -x : hy(i + 150) = -y
  hx(i + 225) = -y : hy(i + 225) = x

  x = CAST(Integer, rMin * sn + 0.5) : y = CAST(Integer, rMin * cs + 0.5)
  mx(i)     = x  : my(i)     = y
  mx(i + 75)  = y  : my(i + 75)  = -x
  mx(i + 150) = -x : my(i + 150) = -y
  mx(i + 225) = -y : my(i + 225) = x

  x = CAST(Integer, rSec * sn + 0.5) : y = CAST(Integer, rSec * cs + 0.5)
  sx(i)     = x  : sy(i)     = y
  sx(i + 75)  = y  : sy(i + 75)  = -x
  sx(i + 150) = -x : sy(i + 150) = -y
  sx(i + 225) = -y : sy(i + 225) = x
NEXT i

' Estado del reloj
DIM t   as UInteger = T0
DIM si  as UInteger = (t MOD 60) * 5
DIM mi  as UInteger = (t MOD 3600) / 12
DIM hi  as UInteger = t / 144
DIM m12 as UByte    = (t MOD 144) / 12
DIM pm  as UByte    = PM0
DIM dia as UByte    = DIA0
DIM oi  as UInteger
DIM acc as UInteger = 0
DIM nb  as UByte
DIM pl  as UByte
DIM d   as UByte

drawFace()
drawDate(dia)

' Asegurar modo XOR para las agujas
OVER 1

PLOT cx, cy : DRAW hx(hi), hy(hi)
PLOT cx, cy : DRAW mx(mi), my(mi)
PLOT cx, cy : DRAW sx(si), sy(si)

pl = PEEK(23672)
ASM
  ei
END ASM

DO
  ASM
    halt
  END ASM

  ' Salida por tecla (rápida y más robusta)
  IF ((IN 254) BAND 31) <> 31 OR ((IN 253) BAND 31) <> 31 THEN EXIT DO

  nb = PEEK(23672)
  d  = nb - pl
  pl = nb
  acc = acc + d

  WHILE acc >= 10
    acc = acc - 10

    oi = si
    si = si + 1
    IF si = 300 THEN si = 0
    PLOT cx, cy : DRAW sx(si), sy(si)
    PLOT cx, cy : DRAW sx(oi), sy(oi)

    IF si = 0 THEN
      oi = mi
      mi = mi + 1
      IF mi = 300 THEN mi = 0
      PLOT cx, cy : DRAW mx(mi), my(mi)
      PLOT cx, cy : DRAW mx(oi), my(oi)

      m12 = m12 + 1
      IF m12 = 12 THEN
        m12 = 0
        oi = hi
        hi = hi + 1
        IF hi = 300 THEN
          hi = 0
          pm = 1 - pm
          IF pm = 0 THEN
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
        END IF
        PLOT cx, cy : DRAW hx(hi), hy(hi)
        PLOT cx, cy : DRAW hx(oi), hy(oi)
      END IF
    END IF
  END WHILE
LOOP

' Restauración
BORDER 7
PAPER 7
INK 0
BRIGHT 0
OVER 0
INVERSE 0
CLS
PRINT AT 0, 8; "ROLEZX by Guti"