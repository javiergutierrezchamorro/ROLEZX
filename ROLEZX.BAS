' ************************************************************
'  ROLEZX v17.2 - Reloj analógico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  Novedades v17.0:
'   * Tic-tac audible en cada paso del segundero (BEEP alternante)
'   * Segundero a velocidad real: 10 frames por paso (0,2 s),
'     300 pasos = 60 s exactos (antes 5 frames y giraba al doble)
'   * Fecha por fin visible: el digito NO se dibuja con INK 0
'     (cada PLOT cambia la tinta de la CELDA 8x8 entera y eso
'     volvia negras las celdas, tapando el fondo amarillo con
'     bloques solidos). Ahora se dibuja enmascarando con OVER 1:
'     apaga los pixeles del fondo y quedan en papel negro sobre
'     amarillo, sin tocar atributos. Ventana centrada en el eje
'     del reloj y digitos completos, sin recortes
'   * v17.2: textos del dial centrados en el eje del reloj
'     (antes caian 7 px a la derecha del centro) e impresos
'     ANTES de dibujar la esfera: PRINT borra el fondo de sus
'     celdas, y al imprimirlos despues machacaban la base del
'     ROLEZX y el circulo interior. El ROLEZX grande sube
'     (yt 44) y se centra para dejarles sitio limpio
'   * Simplificado y optimizado:
'     - Tablas de agujas unificadas en 2 arrays 2D (un solo bucle)
'     - Contador de pasos en vez de si MOD 60 en el bucle principal
'     - Salida por tecla con una sola lectura: IN 254 con A8-A15 a 0
'       selecciona TODAS las semifilas del teclado (el IN 253 leia
'       un puerto flotante y podia provocar salidas aleatorias)
' ************************************************************

#define cx      128
#define cy      108
#define rOuter  72
#define rHora   33
#define rMin    52
#define rSec    63

#define T0      36540
#define DIA0    7
#define DIASMES 30
#define PM0     0

' 50 Hz -> 1 frame = 20 ms. Paso del segundero = 10 frames = 0,2 s
#define UMBRAL  10

#define TITLE   "ROLEZX by Guti"

' ------------------------------------------------------------
' Caracter ROM escalado 2x (16x16 px) sin tocar atributos
' ------------------------------------------------------------
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

' ------------------------------------------------------------
' Ventana de fecha a las 3 (estilo Datejust)
' Interior x 151-184, y 100-115 = 34x16 px centrado en cy
' IMPORTANTE: el digito se dibuja con OVER 1 (XOR). Eso APAGA
' los pixeles del fondo amarillo y quedan en papel (negro) sin
' cambiar el atributo de las celdas. Si se dibujara con INK 0,
' el PLOT pondria tinta 0 en las celdas enteras y el fondo
' amarillo desapareceria en bloques negros solidos.
' ------------------------------------------------------------
SUB drawDate(n as UByte)
  DIM yy as UByte
  OVER 0
  ' Fondo amarillo (pixeles ON, tinta 6)
  INK 6
  FOR yy = 100 TO 115
    PLOT 151, yy : DRAW 33, 0
  NEXT yy
  ' Digitos en negro = mascara XOR sobre el amarillo
  ' (yt = 76 deja el glifo justo en y 100-115)
  OVER 1
  IF n < 10 THEN
    bigChar(160, 76, 48 + n)
  ELSE
    bigChar(152, 76, 48 + n / 10)
    bigChar(168, 76, 48 + n MOD 10)
  END IF
  ' Contorno de la ventana
  OVER 0
  PLOT 150, 99 : DRAW 35, 0
  DRAW 0, 17 : DRAW -35, 0 : DRAW 0, -17
  OVER 1
END SUB

' ------------------------------------------------------------
' Esfera completa
' ------------------------------------------------------------
SUB drawFace()
  DIM n as UByte
  DIM q as Byte
  DIM r as UByte
  DIM a as Float
  DIM b as Float
  DIM s as Float
  DIM c as Float

  BORDER 0 : PAPER 0 : INK 6 : BRIGHT 1 : OVER 0 : INVERSE 0 : CLS

  ' Textos del dial PRIMERO: PRINT borra el fondo de sus celdas,
  ' asi que se imprimen antes de dibujar circulos, marcas y letras
  ' (que solo anaden pixeles y no machacan nada).
  ' Centrados en cx: 16 chars -> col 8, 8 chars -> col 12 (x = 127.5)
  PRINT AT 8, 8; "OYSTER PERPETUAL"
  PRINT AT 13, 12; "DATEJUST"

  CIRCLE cx, cy, rOuter
  CIRCLE cx, cy, rOuter - 5

  FOR n = 0 TO 59
    a = n * (PI / 30.0)
    s = SIN(a) : c = COS(a)
    PLOT cx + 0.5 + (rOuter - 2) * s, cy + 0.5 + (rOuter - 2) * c
    DRAW 4 * s, 4 * c

    IF n MOD 5 = 0 THEN
      r = 54
      IF n THEN
        FOR q = -1 TO 1
          a = q * 0.02
          b = s + a * c
          a = c - a * s
          PLOT cx + 0.5 + 44 * b, cy + 0.5 + 44 * a
          DRAW 8 * b, 8 * a
        NEXT q
      END IF
    ELSE
      r = 58
    END IF
    PLOT cx + 0.5 + r * s, cy + 0.5 + r * c
    DRAW (rOuter - 8 - r) * s, (rOuter - 8 - r) * c
  NEXT n

  ' Corona
  PLOT cx - 6, cy + 46 : DRAW 0, 4
  PLOT cx - 3, cy + 46 : DRAW 0, 5
  PLOT cx    , cy + 46 : DRAW 0, 7
  PLOT cx + 3, cy + 46 : DRAW 0, 5
  PLOT cx + 6, cy + 46 : DRAW 0, 4
  PLOT cx - 6, cy + 46 : DRAW 12, 0

  ' ROLEZX (subido a yt 44 y centrado: 6 letras x 16 px desde cx-48;
  ' queda entre la corona y el texto, sin tocar las marcas)
  bigChar(80, 44, 82) : bigChar(96, 44, 79) : bigChar(112, 44, 76)
  bigChar(128, 44, 69) : bigChar(144, 44, 90) : bigChar(160, 44, 88)

  CIRCLE cx, cy, 3

  ' Barra cyan inferior
  PAPER 5 : INK 0
  PRINT AT 21,0; "                                ";
  PRINT AT 21,9; TITLE
  PAPER 0 : INK 6
END SUB

' ------------------------------------------------------------
' Tablas de agujas 2D: 0 = hora, 1 = minuto, 2 = segundo
' 300 pasos/vuelta. Un solo bucle genera los 4 cuadrantes.
' ------------------------------------------------------------
DIM ax(2, 299) as Byte
DIM ay(2, 299) as Byte

DIM i   as UByte
DIM h   as UByte
DIM ang as Float
DIM sn  as Float
DIM cs  as Float
DIM x   as Integer
DIM y   as Integer
DIM rr(2) as UByte

rr(0) = rHora : rr(1) = rMin : rr(2) = rSec

FOR i = 0 TO 74
  ang = i * (PI / 150.0)
  sn = SIN(ang) : cs = COS(ang)
  FOR h = 0 TO 2
    x = CAST(Integer, rr(h) * sn + 0.5)
    y = CAST(Integer, rr(h) * cs + 0.5)
    ax(h, i)     = x  : ay(h, i)     = y
    ax(h, i + 75)  = y  : ay(h, i + 75)  = -x
    ax(h, i + 150) = -x : ay(h, i + 150) = -y
    ax(h, i + 225) = -y : ay(h, i + 225) = x
  NEXT h
NEXT i

' ------------------------------------------------------------
' Estado del reloj
' ------------------------------------------------------------
DIM t   as UInteger = T0
DIM si  as UInteger = (t MOD 60) * 5
DIM mi  as UInteger = (t MOD 3600) / 12
DIM hi  as UInteger = t / 144
DIM sc  as UByte    = si MOD 60
DIM m12 as UByte    = (t MOD 144) / 12
DIM pm  as UByte    = PM0
DIM dia as UByte    = DIA0
DIM oi  as UInteger
DIM acc as UInteger = 0
DIM nb  as UByte
DIM pl  as UByte
DIM d   as UByte
DIM toc as UByte    = 0

drawFace()
drawDate(dia)

' Agujas en modo XOR
OVER 1

PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
PLOT cx, cy : DRAW ax(1, mi), ay(1, mi)
PLOT cx, cy : DRAW ax(2, si), ay(2, si)

pl = PEEK(23672)
ASM
  ei
END ASM

DO
  ASM
    halt
  END ASM

  ' Salir con cualquier tecla
  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  nb = PEEK(23672)
  d = nb - pl
  pl = nb
  acc = acc + d

  ' Un paso cada 10 frames (0,2 s): 300 pasos = 60 s exactos
  WHILE acc >= UMBRAL
    acc = acc - UMBRAL

    ' --- Segundero ---
    oi = si
    si = si + 1
    IF si = 300 THEN si = 0
    PLOT cx, cy : DRAW ax(2, si), ay(2, si)
    PLOT cx, cy : DRAW ax(2, oi), ay(2, oi)

    ' --- Tic-tac: tono alterno en cada paso ---
    IF toc THEN
      BEEP 0.008, 28
      toc = 0
    ELSE
      BEEP 0.008, 40
      toc = 1
    END IF

    ' --- Minutero cada 60 pasos (12 s) ---
    sc = sc + 1
    IF sc = 60 THEN
      sc = 0
      oi = mi
      mi = mi + 1
      IF mi = 300 THEN mi = 0
      PLOT cx, cy : DRAW ax(1, mi), ay(1, mi)
      PLOT cx, cy : DRAW ax(1, oi), ay(1, oi)

      ' --- Horario cada 12 pasos del minutero (12 min) ---
      m12 = m12 + 1
      IF m12 = 12 THEN
        m12 = 0
        oi = hi
        hi = hi + 1
        IF hi = 300 THEN
          hi = 0
          pm = 1 - pm
          ' Medianoche: avanza el dia
          IF pm = 0 THEN
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
        END IF
        PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
        PLOT cx, cy : DRAW ax(0, oi), ay(0, oi)
      END IF
    END IF
  END WHILE
LOOP

' ------------------------------------------------------------
' Restauracion
' ------------------------------------------------------------
BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS
PRINT AT 0, 8; TITLE