' ************************************************************
'  ROLEZX v20 - Reloj analógico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  CAMBIOS v20 (revisión a fondo + simplificación):
'
'   * ERROR CORREGIDO EN LAS TABLAS DE AGUJAS: `i` era UByte, así
'     que `i + 225` se evaluaba en 8 bits (para i >= 31 daba
'     256..299 -> 0..43). El 4º cuadrante (índices 225..299) quedaba
'     a medias (256..299 = 0,0) y además machacaba los índices
'     0..43 del 1º cuadrante: de ahí el salto hacia el segundo 8.8
'     (paso 44). Ahora `i` es UInteger.
'   * SIN CONTADOR MAESTRO ULong: segundero, minutero y horario son
'     contadores UInteger con su propio wrap (sin divisiones de
'     32 bits ni MOD en el bucle). Los valores iniciales salen de
'     T0 en tiempo de compilación.
'   * TIC-TAC SIN BEEP: el BEEP de la ROM deja las interrupciones
'     desactivadas durante el tono; si el INT del ULA (pulso de
'     32 T) cae ahí se pierde un frame y el reloj se atrasa. Ahora
'     es un pulso OUT 254 sin DI, de ancho alterno (toc).
'   * Condiciones explícitas (<> 0) para el modo estricto.
'   * drawDate: ventana de fecha en un solo bucle (el marco 1 px
'     era del mismo color que el relleno).
'   * Fusión de las 12: se arma directamente al envolver el
'     horario (siempre coincide con si = 0 y mi = 0).
' ************************************************************

#define cx      128
#define cy      108
#define rOuter  72
#define rHora   33
#define rMin    52
#define rSec    63

#define T0      36540      ' s desde medianoche -> arranque 10:09:00
#define DIA0    7
#define DIASMES 30

' 50 Hz -> 1 frame = 20 ms. Paso del segundero = 10 frames = 0.2 s
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
    IF b <> 0 THEN
      m = 128
      px = x
      py = 191 - yt - r - r
      FOR c = 0 TO 7
        IF (b BAND m) <> 0 THEN
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
' El dígito se dibuja con OVER 1 (XOR): apaga los pixeles del
' fondo amarillo sin cambiar los atributos de las celdas.
' ------------------------------------------------------------
SUB drawDate(n as UByte)
  DIM yy as UByte
  OVER 0
  INK 6
  FOR yy = 99 TO 116
    PLOT 150, yy : DRAW 35, 0
  NEXT yy
  OVER 1
  IF n < 10 THEN
    bigChar(160, 76, 48 + n)
  ELSE
    bigChar(152, 76, 48 + n / 10)
    bigChar(168, 76, 48 + n MOD 10)
  END IF
END SUB

' ------------------------------------------------------------
' Esfera completa (se ejecuta una sola vez)
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

  ' Barra inferior: PRINT borra el fondo de sus celdas, así que
  ' va antes que cualquier dibujo de la esfera
  PAPER 1 : INK 7 : FLASH 1
  PRINT AT 21,0; "                                ";
  PRINT AT 21,9; FLASH 1; TITLE
  PAPER 0 : INK 6: FLASH 0

  ' Textos del dial ANTES de los círculos y marcas (PRINT machaca
  ' el fondo de sus celdas; los dibujos solo añaden pixeles)
  PRINT AT 8, 8; "OYSTER PERPETUAL"
  PRINT AT 13, 12; "DATEJUST"

  CIRCLE cx, cy, rOuter
  CIRCLE cx, cy, rOuter - 5

  FOR n = 0 TO 59
    a = n * (PI / 30.0)
    s = SIN(a) : c = COS(a)
    PLOT cx + 0.5 + (rOuter - 2) * s, cy + 0.5 + (rOuter - 2) * c
    DRAW 4 * s, 4 * c

    r = 58
    IF n MOD 5 = 0 THEN
      r = 54
      IF n <> 0 THEN
        ' Batón triple (en el 12 se omite: chocaría con la corona)
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
  NEXT n

  ' Corona (logo a las 6, bajo el nombre)
  PLOT cx - 6, cy + 46 : DRAW 0, 4
  PLOT cx - 3, cy + 46 : DRAW 0, 5
  PLOT cx    , cy + 46 : DRAW 0, 7
  PLOT cx + 3, cy + 46 : DRAW 0, 5
  PLOT cx + 6, cy + 46 : DRAW 0, 4
  PLOT cx - 6, cy + 46 : DRAW 12, 0

  ' ROLEZX centrado en el eje del reloj
  bigChar(80, 44, 82) : bigChar(96, 44, 79) : bigChar(112, 44, 76)
  bigChar(128, 44, 69) : bigChar(144, 44, 90) : bigChar(160, 44, 88)

  CIRCLE cx, cy, 3
END SUB

' ------------------------------------------------------------
' Tablas de agujas 2D: 0 = hora, 1 = minuto, 2 = segundo
' 300 pasos/vuelta. Un solo bucle genera los 4 cuadrantes.
' OJO: `i` debe ser UInteger (i + 225 llega a 299).
' ------------------------------------------------------------
DIM ax(2, 299) as Byte
DIM ay(2, 299) as Byte

DIM i   as UInteger
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
    ax(h, i)       =  x  : ay(h, i)       =  y
    ax(h, i + 75)  =  y  : ay(h, i + 75)  = -x
    ax(h, i + 150) = -x  : ay(h, i + 150) = -y
    ax(h, i + 225) = -y  : ay(h, i + 225) =  x
  NEXT h
NEXT i

' ------------------------------------------------------------
' Estado del reloj (todo sale de T0 en compilación)
'   1 paso = 0.2 s (5 pasos/s).  300 pasos = 1 vuelta (60 s)
'   si: segundero 0..299, un paso cada paso
'   mi: minutero  0..299, un paso cada 60 pasos (km cuenta 0..59)
'   hi: horario   0..299, un paso cada 12 del minutero (kh 0..11)
'   hi envuelve cada 12 h -> cambia pm; pm vuelve a 0 -> nuevo día
' ------------------------------------------------------------
DIM si as UInteger = CAST(UInteger, (T0 MOD 60) * 5)
DIM mi as UInteger = CAST(UInteger, ((T0 - T0 MOD 12) / 12) MOD 300)
DIM hi as UInteger = CAST(UInteger, ((T0 - T0 MOD 144) / 144) MOD 300)
DIM km as UByte = CAST(UByte, (T0 MOD 12) * 5)
DIM kh as UByte = CAST(UByte, ((T0 - T0 MOD 12) / 12) MOD 12)
DIM oi as UInteger
DIM om as UInteger
DIM oh as UInteger
DIM pm  as UByte = 0
DIM dia as UByte = DIA0
DIM acc as UInteger = 0
DIM nb  as UByte
DIM pl  as UByte
DIM d   as UByte
DIM k   as UByte
DIM toc as UByte = 20
DIM rep as UByte = 0
DIM hp  as UByte = 0

drawFace()
drawDate(dia)

' Agujas en modo XOR (las 3 siempre, igual que en marcha)
OVER 1

PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
PLOT cx, cy : DRAW ax(1, mi), ay(1, mi)
PLOT cx, cy : DRAW ax(2, si), ay(2, si)

pl = PEEK(23672)

DO
  ' Espera 1 frame dormido en HALT (PAUSE); sale antes si hay
  ' una tecla pulsada. El despertar ocurre con la INT del ULA
  PAUSE 1

  ' Salir con cualquier tecla (A8-A15 a 0 = todas las semifilas)
  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  ' Delta de FRAMES (UByte, envuelve solo): compensa frames
  ' perdidos si un paso dura más de un frame
  nb = PEEK(23672)
  d = nb - pl
  pl = nb
  acc = acc + d

  ' Un paso cada 10 frames (0.2 s): 300 pasos = 60 s exactos
  WHILE acc >= UMBRAL
    acc = acc - UMBRAL

    ' --- Segundero: dibujar la nueva ANTES de borrar la vieja,
    '     así nunca hay un frame con el dial sin aguja ---
    oi = si
    si = si + 1
    IF si = 300 THEN si = 0
    PLOT cx, cy : DRAW ax(2, si), ay(2, si)
    PLOT cx, cy : DRAW ax(2, oi), ay(2, oi)

    ' --- Reparación de la fusión triple de las 12: el borrado
    '     del segundero acaba de apagar la línea fundida
    '     (horario+minutero); se reenciende ---
    IF rep <> 0 THEN
      PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
      rep = 0
    END IF

    ' --- Minutero: cambia cada 60 pasos (12 s) ---
    km = km + 1
    IF km = 60 THEN
      km = 0
      om = mi
      mi = mi + 1
      IF mi = 300 THEN mi = 0
      PLOT cx, cy : DRAW ax(1, mi), ay(1, mi)
      IF hp = 1 AND om = hi THEN
        ' El minutero se separa del horario tras la fusión de
        ' las 12: borrar SOLO su tramo exterior (r34..52).
        ' El tramo r0..33 queda encendido: es el horario.
        ' Se empieza en ay(0,om)+1 para no tocar su punta
        PLOT cx + ax(0, om), cy + ay(0, om) + 1
        DRAW ax(1, om) - ax(0, om), ay(1, om) - ay(0, om) - 1
        hp = 0
      ELSE
        PLOT cx, cy : DRAW ax(1, om), ay(1, om)
      END IF

      ' --- Horario: cambia cada 12 pasos del minutero (144 s) ---
      kh = kh + 1
      IF kh = 12 THEN
        kh = 0
        oh = hi
        hi = hi + 1
        IF hi = 300 THEN
          ' Medianoche y mediodía: cambia pm
          hi = 0
          pm = 1 - pm
          IF pm = 0 THEN
            ' Medianoche: avanza el día
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
          ' Fusión triple en las 12 en punto (si = 0 y mi = 0
          ' siempre en este instante): reparación y borrado parcial
          rep = 1 : hp = 1
        END IF
        PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
        PLOT cx, cy : DRAW ax(0, oh), ay(0, oh)
      END IF
    END IF

    ' --- Tic-tac: pulso de altavoz SIN DI, ancho alterno 20/45
    '     (con el BEEP de la ROM las interrupciones quedan
    '     desactivadas y se pueden perder frames) ---
    OUT 254, 16
    FOR k = 1 TO toc : NEXT k
    OUT 254, 0
    toc = 65 - toc
  END WHILE
LOOP

' ------------------------------------------------------------
' Restauración
' ------------------------------------------------------------
BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS
PRINT AT 0, 8; TITLE
