' ************************************************************
'  ROLEZX v18.1 - Reloj analógico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  CAMBIOS v18 (corrección + simplificación + optimización):
'
'   * CORREGIDO EL SALTO DEL SEGUNDO 60: si, mi y hi ya NO son
'     contadores con incremento y wrap propio (si = si + 1 :
'     IF si = 300 THEN si = 0). Ahora se DERIVAN en cada paso de
'     un contador maestro `pasos` (ULong, 1 paso = 0.2 s) con
'     divisiones de 32 bits. Con el esquema antiguo, el primer
'     valor que alcanzaba 300 quedaba truncado a 8 bits en el
'     binario de algunas versiones del compilador y el wrap
'     nunca se detectaba: 300 mod 256 = 44 pasos = segundo 8.8,
'     exactamente el salto observado. Con el nuevo esquema el
'     valor 300 jamás se almacena en una variable: el índice se
'     CALCULA cada paso, así que el truncamiento es imposible.
'   * Delta de FRAMES explícitamente modular:
'     d = (nb - pl) BAND 255. Funciona sea cual sea la promoción
'     de tipos que aplique el compilador a la resta de UByte.
'   * SIMPLIFICADO: fuera t, sc y m12. El minutero y el horario
'     se mueven cuando su índice derivado cambia; medianoche y
'     fusión triple se detectan con el mismo criterio que antes.
'   * HORA INICIAL EXACTA: antes hi = t / 144 truncaba la parte
'     decimal (hasta 2.4 min de error); ahora todo sale del
'     contador maestro sin perder nada.
'
'  CAMBIOS v18.1 (todo el ASM fuera):
'
'   * SIN UNA SOLA INSTRUCCIÓN ASM: retirados el beeper en
'     ensamblador y los bloques ei/halt. El tic-tac vuelve al
'     BEEP de la ROM (0.008 s, tono alterno) y la sincronía de
'     refresco se hace con el propio FRAMES: el bucle gira
'     libre y solo actúa cuando FRAMES (23672) salta. Como la
'     ULA lo incrementa al comenzar el VBLANK, el dibujo sigue
'     alineado al refresco igual que con halt. (El BEEP de la
'     ROM hace DI unos 8 ms, pero la ULA mantiene la INT
'     pendiente hasta atenderla: no se pierde ningún tick y el
'     delta de FRAMES compensa solo.)
'   * CORREGIDO EL ERROR DE COMPILACIÓN: en la v18 quedó
'     `DIM pm ... = PM0` sin su `#define PM0 0` (borrado al
'     simplificar), de ahí el "Undeclared variable PM0" en el
'     modo estricto. Ahora: DIM pm as UByte = 0.
'   * SE CONSERVA INTACTO: esfera, ventana de fecha enmascarada
'     con OVER 1, reparación de la fusión triple de las 12
'     (rep/hp de v17.4), dibujado de la aguja nueva antes de
'     borrar la vieja y salida por teclado con IN 254.
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
' El dígito se dibuja con OVER 1 (XOR): apaga los pixeles del
' fondo amarillo sin cambiar los atributos de las celdas.
' ------------------------------------------------------------
SUB drawDate(n as UByte)
  DIM yy as UByte
  OVER 0
  INK 6
  FOR yy = 100 TO 115
    PLOT 151, yy : DRAW 33, 0
  NEXT yy
  OVER 1
  IF n < 10 THEN
    bigChar(160, 76, 48 + n)
  ELSE
    bigChar(152, 76, 48 + n / 10)
    bigChar(168, 76, 48 + n MOD 10)
  END IF
  OVER 0
  PLOT 150, 99 : DRAW 35, 0
  DRAW 0, 17 : DRAW -35, 0 : DRAW 0, -17
  OVER 1
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
  PAPER 5 : INK 0
  PRINT AT 21,0; "                                ";
  PRINT AT 21,9; TITLE
  PAPER 0 : INK 6

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

    IF n MOD 5 = 0 THEN
      r = 54
      IF n THEN
        ' Batón triple (en el 12 se omite: chocaría con la corona)
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
    ax(h, i)       =  x  : ay(h, i)       =  y
    ax(h, i + 75)  =  y  : ay(h, i + 75)  = -x
    ax(h, i + 150) = -x  : ay(h, i + 150) = -y
    ax(h, i + 225) = -y  : ay(h, i + 225) =  x
  NEXT h
NEXT i

' ------------------------------------------------------------
' Estado del reloj: UN contador maestro de pasos.
'   1 paso = 0.2 s (5 pasos/s).  300 pasos = 1 vuelta (60 s)
'   segundero: si = pasos MOD 300
'   minutero : 1 paso suyo cada 60 pasos (12 s)
'   horario  : 1 paso suyo cada 720 pasos (144 s = 2.4 min)
'   12 h = 216000 pasos -> pm cambia; 24 h = 432000 -> cambia el día
' ------------------------------------------------------------
DIM pasos as ULong = CAST(ULong, T0) * 5
DIM si as UInteger = CAST(UInteger, pasos MOD 300)
DIM mi as UInteger = CAST(UInteger, (pasos / 60) MOD 300)
DIM hi as UInteger = CAST(UInteger, (pasos / 720) MOD 300)
DIM oi as UInteger
DIM om as UInteger
DIM oh as UInteger
DIM pm  as UByte = 0
DIM dia as UByte = CAST(UByte, DIA0)
DIM acc as UInteger = 0
DIM nb  as UByte
DIM pl  as UByte
DIM d   as UByte
DIM toc as UByte = 0
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
  ' Salir con cualquier tecla (A8-A15 a 0 = todas las semifilas)
  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  ' Sin halt ni ASM: el bucle gira libre y solo acumula cuando
  ' FRAMES (23672) salta; si no ha saltado (d = 0) esta vuelta
  ' no hace nada. La ULA incrementa FRAMES al comenzar el
  ' VBLANK, así que el dibujo sigue sincronizado con el
  ' refresco de pantalla igual que con halt
  nb = PEEK(23672)
  ' Delta modular explícito: correcto aunque el compilador
  ' promocione la resta a 16 bits con signo
  d = (nb - pl) BAND 255
  pl = nb
  acc = acc + d

  ' Un paso cada 10 frames (0.2 s): 300 pasos = 60 s exactos
  WHILE acc >= UMBRAL
    acc = acc - UMBRAL

    pasos = pasos + 1

    ' --- Segundero: dibujar la nueva ANTES de borrar la vieja,
    '     así nunca hay un frame con el dial sin aguja ---
    oi = si
    si = CAST(UInteger, pasos MOD 300)
    PLOT cx, cy : DRAW ax(2, si), ay(2, si)
    PLOT cx, cy : DRAW ax(2, oi), ay(2, oi)

    ' --- Reparación de la fusión triple de las 12: el borrado
    '     del segundero acaba de apagar la línea fundida
    '     (horario+minutero); se reenciende ---
    IF rep THEN
      PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
      rep = 0
    END IF

    ' --- Tic-tac: tono alterno en cada paso (BEEP de la ROM) ---
    IF toc THEN
      BEEP 0.008, 28
      toc = 0
    ELSE
      BEEP 0.008, 40
      toc = 1
    END IF

    ' --- Minutero: cambia cada 60 pasos (12 s) ---
    om = mi
    mi = CAST(UInteger, (pasos / 60) MOD 300)
    IF mi <> om THEN
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

      ' --- Horario: cambia cada 720 pasos (144 s) ---
      oh = hi
      hi = CAST(UInteger, (pasos / 720) MOD 300)
      IF hi <> oh THEN
        IF hi = 0 THEN
          ' Medianoche y mediodía: cambia pm
          pm = 1 - pm
          IF pm = 0 THEN
            ' Medianoche: avanza el día
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
        END IF
        PLOT cx, cy : DRAW ax(0, hi), ay(0, hi)
        PLOT cx, cy : DRAW ax(0, oh), ay(0, oh)
        ' Fusión triple en las 12 en punto (12:00 / 00:00):
        ' activar la reparación (rep) y el borrado parcial (hp)
        IF hi = 0 AND si = 0 AND mi = 0 THEN
          rep = 1
          hp = 1
        END IF
      END IF
    END IF
  END WHILE
LOOP

' ------------------------------------------------------------
' Restauración
' ------------------------------------------------------------
BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS
PRINT AT 0, 8; TITLE
