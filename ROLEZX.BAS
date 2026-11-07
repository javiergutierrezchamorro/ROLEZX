' ************************************************************
'  ROLEZX v12 - Reloj analogico estilo Rolex Datejust
'  Boriel ZX BASIC:
'    zxbc ROLEZX.BAS -O 3 --array-base 0 --string-base 0 --explicit
'
'  v12: esfera a pantalla completa (radio 94 sobre 192 de alto), agujas
'       mas largas, ROLEZX y la fecha en tamano doble (fuente de la ROM
'       ampliada x2).
'  v11: tablas de agujas en Byte (la mitad de memoria, indexado mas
'       rapido) y un solo contador de pasos en vez de dos.
'
'  Cambios respecto a v9:
'   * CORREGIDO: PLOT/DRAW tienen el eje Y hacia ARRIBA, pero la
'     esfera y las agujas usaban "cy - r*COS": todo salia reflejado
'     (las 12 abajo, agujas girando al reves). Ahora es cy + r*COS.
'   * CORREGIDO: la fecha (PRINT AT, fila desde ARRIBA) caia en la
'     fila 11 y el marco (PLOT, Y desde ABAJO) en la fila 12.
'     Ahora ambos estan en la fila 12.
'   * Sin Float/Long/INT en el bucle: el tiempo son contadores
'     enteros y las agujas salen de tablas precalculadas (300
'     posiciones = 1.2 grados). Cero trigonometria en marcha.
'   * HALT en el bucle: la CPU descansa hasta la siguiente
'     interrupcion (FRAMES) y solo se dibuja cuando hay cambio.
'   * Fecha sin POKE de atributos: ventana en INVERSE, con los
'     mismos atributos que toda la esfera.
'   * Esfera: un solo SIN/COS por marca, batones incluidos (antes
'     8 llamadas SIN/COS por marca).
' ************************************************************

#define cx      128
#define cy      96
#define rHora   42
#define rMin    68
#define rSec    80

' Hora inicial en segundos dentro de las 12 h: 10*3600 + 9*60 = 36540 (10:09:00)
#define T0      36540
' Dia inicial, dias del mes (para el cambio a medianoche) y 0=AM / 1=PM
#define DIA0    7
#define DIASMES 30
#define PM0     0

' Aguja desde el centro con desplazamiento (dx,dy), en modo XOR
' (OVER 1): dibujarla dos veces en el mismo sitio la borra
SUB hand(dx as Integer, dy as Integer)
  PLOT cx, cy
  DRAW dx, dy
END SUB

' Caracter de la ROM ampliado x2 (16x16). x = columna en pixeles,
' yt = fila superior en pixeles contada desde ARRIBA (como PRINT).
' Respeta INVERSE: con INVERSE 1 "borra" los pixeles (negativo).
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
          PLOT px, py: PLOT px + 1, py
          PLOT px, py - 1: PLOT px + 1, py - 1
        END IF
        m = m >> 1
        px = px + 2
      NEXT c
    END IF
  NEXT r
END SUB

' Ventana de fecha a las 3: 4x2 celdas (cols 19-22, filas 11-12) en
' INVERSE, con la cifra en tamano doble en negativo. Mismos atributos
' que el resto: sin color clash.
SUB drawDate(n as UByte)
  OVER 0: INVERSE 1
  PRINT AT 11, 19; "    "; AT 12, 19; "    ";
  IF n < 10 THEN
    bigChar(160, 88, 48 + n)
  ELSE
    bigChar(152, 88, 48 + n / 10)
    bigChar(168, 88, 48 + n MOD 10)
  END IF
  INVERSE 0: OVER 1
END SUB

' --- Esfera estilo Datejust, toda en tinta 6 brillante ---
' OJO: en PLOT/DRAW la Y crece hacia ARRIBA -> cy + r*COS
SUB drawFace()
  DIM n as UByte
  DIM q as Byte
  DIM r as UByte
  DIM a as Float
  DIM b as Float
  DIM s as Float
  DIM c as Float
  BORDER 0: PAPER 0: INK 6: BRIGHT 1: OVER 0: INVERSE 0: CLS
  ' Bisel exterior (casi 192 de alto)
  CIRCLE cx, cy, 94
  CIRCLE cx, cy, 89
  ' Muescas del bisel, pista de minutos y batones de hora, en un solo
  ' bucle: un SIN/COS por marca. Los batones (tres lineas, +-0.02 rad)
  ' usan sin(a+d)=s+d*c, cos(a+d)=c-d*s, sin llamar otra vez a SIN/COS.
  FOR n = 0 TO 59
    a = n * (PI / 30.0)
    s = SIN(a): c = COS(a)
    PLOT cx + 0.5 + 89 * s, cy + 0.5 + 89 * c
    DRAW 5 * s, 5 * c
    IF n MOD 5 = 0 THEN
      r = 74
      IF n > 0 THEN              ' las 12 llevan la corona
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
  ' Corona de cinco picos a las 12
  PLOT cx - 8, cy + 62: DRAW 0, 5
  PLOT cx - 4, cy + 62: DRAW 0, 7
  PLOT cx, cy + 62: DRAW 0, 9
  PLOT cx + 4, cy + 62: DRAW 0, 7
  PLOT cx + 8, cy + 62: DRAW 0, 5
  PLOT cx - 8, cy + 62: DRAW 16, 0
  ' Rotulos. ROLEZX en tamano doble; el resto con la fuente normal
  ' (PRINT AT: fila desde ARRIBA)
  bigChar(80, 53, 82)    ' R
  bigChar(96, 53, 79)    ' O
  bigChar(112, 53, 76)   ' L
  bigChar(128, 53, 69)   ' E
  bigChar(144, 53, 90)   ' Z
  bigChar(160, 53, 88)   ' X
  PRINT AT 9, 8; "OYSTER PERPETUAL"
  PRINT AT 14, 12; "DATEJUST"
  ' Marco de la ventana de fecha (x 151..184, Y de PLOT 87..104)
  PLOT 151, 87: DRAW 33, 0: DRAW 0, 17: DRAW -33, 0: DRAW 0, -17
  ' Eje central
  CIRCLE cx, cy, 3
END SUB

' --- Tablas de agujas: 300 posiciones (1.2 grados) ---
' Se calcula solo el primer cuadrante (75 posiciones) y se refleja.
' Indice 0 = las 12, crece en sentido horario. Byte con signo: -80..80.
DIM hx(299) as Byte
DIM hy(299) as Byte
DIM mx(299) as Byte
DIM my(299) as Byte
DIM sx(299) as Byte
DIM sy(299) as Byte

DIM i as UInteger
DIM ang as Float
DIM sn as Float
DIM cs as Float
DIM x as Integer
DIM y as Integer

FOR i = 0 TO 74
  ang = i * (PI / 150.0)
  sn = SIN(ang): cs = COS(ang)

  x = CAST(Integer, rHora * sn + 0.5): y = CAST(Integer, rHora * cs + 0.5)
  hx(i) = x:        hy(i) = y
  hx(i + 75) = y:   hy(i + 75) = -x
  hx(i + 150) = -x: hy(i + 150) = -y
  hx(i + 225) = -y: hy(i + 225) = x

  x = CAST(Integer, rMin * sn + 0.5): y = CAST(Integer, rMin * cs + 0.5)
  mx(i) = x:        my(i) = y
  mx(i + 75) = y:   my(i + 75) = -x
  mx(i + 150) = -x: my(i + 150) = -y
  mx(i + 225) = -y: my(i + 225) = x

  x = CAST(Integer, rSec * sn + 0.5): y = CAST(Integer, rSec * cs + 0.5)
  sx(i) = x:        sy(i) = y
  sx(i + 75) = y:   sy(i + 75) = -x
  sx(i + 150) = -x: sy(i + 150) = -y
  sx(i + 225) = -y: sy(i + 225) = x
NEXT i

' --- Estado del reloj: solo contadores enteros ---
'  si: posicion del segundero (0..299, 5 pasos por segundo)
'  mi: posicion del minutero  (0..299, avanza cada 12 s)
'  hi: posicion de la hora    (0..299, avanza cada 144 s)
DIM t as UInteger = T0
DIM si as UInteger = (t MOD 60) * 5
DIM mi as UInteger = (t MOD 3600) / 12
DIM hi as UInteger = t / 144
DIM sc as UByte = (t MOD 12) * 5       ' pasos del segundero dentro del paso del minutero (0..59)
DIM m12 as UByte = (t MOD 144) / 12    ' pasos del minutero dentro del paso de la hora
DIM pm as UByte = PM0
DIM dia as UByte = DIA0
DIM oi as UInteger
DIM acc as UInteger = 0
DIM nb as UByte
DIM pl as UByte
DIM d as UByte

drawFace()
drawDate(dia)              ' deja OVER 1 activo: desde aqui todo es XOR
hand(hx(hi), hy(hi))
hand(mx(mi), my(mi))
hand(sx(si), sy(si))

pl = PEEK(23672)           ' byte bajo de FRAMES, justo antes de arrancar
ASM
  ei                       ; HALT necesita interrupciones activas
END ASM

' --- Bucle principal ---
' d = nb - pl se trunca a 8 bits: da los frames transcurridos aunque
' FRAMES de la vuelta. Cada 10 frames (0.2 s) avanza el segundero.
DO
  ASM
    halt
  END ASM
  nb = PEEK(23672)
  d = nb - pl
  pl = nb
  acc = acc + d

  IF acc >= 10 THEN
    acc = acc - 10

    ' Segundero: dibuja la nueva posicion y borra la anterior
    oi = si
    si = si + 1
    IF si = 300 THEN si = 0
    hand(sx(si), sy(si))
    hand(sx(oi), sy(oi))

    ' Minutero: un paso (1.2 grados) cada 12 s = 60 pasos del segundero
    sc = sc + 1
    IF sc = 60 THEN
      sc = 0
      oi = mi
      mi = mi + 1
      IF mi = 300 THEN mi = 0
      hand(mx(mi), my(mi))
      hand(mx(oi), my(oi))
      m12 = m12 + 1

      ' Horario: un paso (1.2 grados) cada 144 s
      IF m12 = 12 THEN
        m12 = 0
        oi = hi
        hi = hi + 1
        IF hi = 300 THEN
          hi = 0
          pm = 1 - pm
          ' Medianoche: cambia el dia
          IF pm = 0 THEN
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
        END IF
        hand(hx(hi), hy(hi))
        hand(hx(oi), hy(oi))
      END IF
    END IF
  END IF
LOOP
