' ************************************************************
'  ROLEZX v24 - Reloj analogico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  CAMBIOS v24 (velocidad percibida sobre v23):
'
'   * LA ESFERA APARECE ANTES DE CALCULAR: el programa ya no hace
'     primero todos los calculos y despues pinta. Ahora pinta en
'     este orden: textos -> fondo azul (solo POKE, instantaneo) ->
'     aros -> marcas y corona -> ROLEZX -> fecha, y al final genera
'     la tabla de agujas y dibuja las agujas. El tiempo total es el
'     mismo, pero se ve construirse el reloj desde el primer
'     instante en vez de esperar con la pantalla vacia.
'   * Para poder pintar el fondo azul al principio, PAPER 8
'     (transparente) se activa antes de los aros y las marcas: asi
'     PLOT/DRAW/CIRCLE no pisan el azul. Todos los DIM van juntos
'     antes del codigo; sin cambios de logica ni de aspecto final.
'
'  CAMBIOS v23 (arranque, tamano y color sobre v22):
'
'   * ARRANQUE ~1 s MAS RAPIDO: v22 llamaba a SIN y COS 270 veces
'     (60 en la esfera + 75 en la tabla, por 2). La ROM tarda
'     varios ms en cada una. Ahora se calcula solo el paso
'     angular (4 llamadas) y cada seno/coseno se obtiene girando
'     el anterior: sen(t+d) = sen*cos(d) + cos*sen(d),
'     cos(t+d) = cos*cos(d) - sen*sen(d). Son 4 multiplicaciones
'     en coma flotante en vez de 2 llamadas trigonometricas. El
'     error acumulado en 75 pasos es ~1e-8: irrelevante. Para que
'     los valores justo en x.5 (r*sen(30 grados) = 31.5, 16.5...)
'     redondeen siempre igual y las agujas sean simetricas, el
'     redondeo suma 0.5001 en vez de 0.5.
'   * TABLA FUERA DEL BINARIO: ax se declara AT 49152. Boriel
'     guarda los DIM sin inicializar como bytes a cero dentro del
'     binario (1125 bytes). Con AT solo se mapea la memoria, no
'     se reserva ni se emite nada. La tabla se rellena entera al
'     arrancar, asi que no importa lo que haya en esa zona. Si tu
'     version de Boriel rechaza DIM ... AT para arrays, quita
'     " AT 49152" y todo sigue funcionando (solo crece el binario).
'   * Se quitan el marco negro de la ventana de la fecha y las
'     franjas arcoiris de la barra: vuelven la ventana azul de v22
'     y la barra original. Menos codigo y menos datos.
'
'  CAMBIOS v22 (tamano, velocidad y color sobre v21):
'
'   * UNA SOLA TABLA DE SENOS: ay(k) = ax(k + 75) (el coseno es
'     el seno adelantado un cuarto de vuelta = 75 pasos). Se
'     elimina ay (900 bytes) y ax pasa de 900 a 1125: cada aguja
'     ocupa un bloque de 375 (300 + 75 de solape para que
'     k + 75 nunca se salga de su bloque).
'       hora   : ax(0..374)     minuto : ax(375..749)
'       segundo: ax(750..1124)
'     La generacion hace 5 escrituras por aguja en vez de 8 y ya
'     no multiplica en 16 bits (off se acumula sumando 375).
'   * INDICES CON SU DESPLAZAMIENTO YA INCLUIDO: mi va de 375 a
'     674 y si de 750 a 1049, asi el bucle caliente hace ax(si)
'     en vez de ax(600 + si) (una suma de 16 bits menos por
'     acceso y menos bytes por cada uno).
'   * x, y e i pasan a Byte/UByte; rr() se inicializa en la
'     declaracion (3 asignaciones menos).
'   * COLOR SIN CLASH: esfera con papel azul (PAPER 1) e ink
'     amarillo (INK 6) en TODAS las celdas. Como el ink es el
'     mismo en toda la esfera, las agujas (XOR) nunca cambian de
'     color al cruzar de una celda a otra. El azul solo es
'     fondo: se pinta una vez con POKE a los atributos.
'   * PAPER 8 (transparente) tras pintar el fondo: PLOT, DRAW y
'     CIRCLE de Boriel reescriben el atributo COMPLETO de la
'     celda con los colores actuales; con papel transparente
'     solo reescriben ink 6 / bright 1, que ya son los de la
'     celda, y el azul no se pierde.
'   * Verificado y SIN CAMBIOS: espera con HALT, acc UByte, logica
'     de fusion de las 12 (rep/hp), contadores derivados de T0.
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
  DIM y0 as UByte
  DIM adr as UInteger
  adr = 15360 + CAST(UInteger, ch) * 8
  y0 = 191 - yt
  FOR r = 0 TO 7
    b = PEEK(adr + r)
    IF b <> 0 THEN
      m = 128
      px = x
      py = y0 - r - r
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
' La ventana se rellena con pixeles de ink (amarillo) sobre el
' papel azul de la esfera; el digito se dibuja con OVER 1 (XOR):
' apaga esos pixeles y deja ver el azul, sin tocar atributos.
' Deja OVER 1 e INK 6 al salir (el bucle principal dibuja asi).
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
  DIM sa as Float
  DIM ca as Float

  ' Seno y coseno de cada marca girando el anterior (paso = 6 grados)
  sa = SIN(PI / 30.0) : ca = COS(PI / 30.0)
  s = 0 : c = 1

  FOR n = 0 TO 59
    PLOT cx + 0.5 + (rOuter - 2) * s, cy + 0.5 + (rOuter - 2) * c
    DRAW 4 * s, 4 * c

    r = 58
    IF n MOD 5 = 0 THEN
      r = 54
      IF n <> 0 THEN
        ' Baton triple (en el 12 se omite: chocaria con la corona)
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
    a = s * ca + c * sa : c = c * ca - s * sa : s = a
  NEXT n

  ' Corona (logo a las 12, entre el texto y el indice de las 12)
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
' Tabla de senos aplanada (ay(k) = ax(k + 75)): 300 pasos por
' vuelta, bloques de 375 (los ultimos 75 repiten los primeros).
'   hora:    ax(0..374)
'   minuto:  ax(375..749)
'   segundo: ax(750..1124)
' Por cada paso i (0..74) y aguja: x = r*sen, y = r*cos y
'   ax(off) = x   ax(off+75) = y   ax(off+150) = -x
'   ax(off+225) = -y   ax(off+300) = x
' off es UInteger: off + 300 se evalua siempre en 16 bits.
' ------------------------------------------------------------
DIM ax(1124) as Byte AT 49152

DIM i   as UByte
DIM h   as UByte
DIM off as UInteger
DIM ang as Float
DIM sn  as Float
DIM cs  as Float
DIM sd  as Float
DIM cd  as Float
DIM x   as Byte
DIM y   as Byte
DIM rr(2) as UByte = {rHora, rMin, rSec}

' Anchos (en celdas, a cada lado de la columna 16) de la zona azul
' en las filas 2..18: celdas que caen enteras dentro de rOuter
DIM aw(16) as UByte = {3, 5, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 7, 7, 6, 4, 2}
DIM ad  as UInteger = 22592     ' atributos de la fila 2 (22528 + 2 * 32)

' ------------------------------------------------------------
' Estado del reloj (todo sale de T0 en compilacion)
'   1 paso = 0.2 s (5 pasos/s).  300 pasos = 1 vuelta (60 s)
'   si: segundero 750..1049, un paso por paso
'   mi: minutero  375..674, un paso cada 60 pasos (km cuenta 0..59)
'   hi: horario   0..299, un paso cada 12 del minutero (kh 0..11)
'   hi envuelve cada 12 h -> cambia pm; pm vuelve a 0 -> nuevo dia
' ------------------------------------------------------------
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

  ' Barra inferior: PRINT borra el fondo de sus celdas, asi que
  ' va antes que cualquier dibujo de la esfera
  PAPER 1 : INK 7 : FLASH 1
  PRINT AT 21,0; "                                ";
  PRINT AT 21,9; FLASH 1; TITLE
  PAPER 0 : INK 6: FLASH 0

' ------------------------------------------------------------
' ARRANQUE EN ORDEN DE "LO QUE SE VE ANTES": cada paso pinta algo
' mientras el siguiente calcula, asi la espera no es una pantalla
' vacia. Orden: textos -> fondo azul -> aros -> marcas -> fecha ->
' tabla de agujas (solo hace falta para las agujas) -> agujas.
' ------------------------------------------------------------

' Textos del dial ANTES de los circulos y marcas (PRINT machaca
' el fondo de sus celdas; los dibujos solo anaden pixeles)
PRINT AT 8, 8; "OYSTER PERPETUAL"
PRINT AT 13, 12; "DATEJUST"

' Fondo azul de la esfera: atributo 78 = BRIGHT 1, PAPER 1, INK 6.
' El ink es el mismo en todas las celdas (6): las agujas no cambian
' de color al cruzar celdas, asi que no hay color clash.
FOR h = 0 TO 16
  FOR k = 16 - aw(h) TO 15 + aw(h)
    POKE ad + k, 78
  NEXT k
  ad = ad + 32
NEXT h

' Papel transparente: PLOT/DRAW/CIRCLE ya no reescriben el fondo
PAPER 8

CIRCLE cx, cy, rOuter
CIRCLE cx, cy, rOuter - 5

drawFace()
drawDate(dia)

' Tabla de agujas (ver descripcion junto a los DIM).
' Seno y coseno del paso (1.2 grados); cada vuelta del bucle gira (sn, cs)
sd = SIN(PI / 150.0) : cd = COS(PI / 150.0)
sn = 0 : cs = 1

FOR i = 0 TO 74
  off = CAST(UInteger, i)
  FOR h = 0 TO 2
    x = CAST(Byte, rr(h) * sn + 0.5001)
    y = CAST(Byte, rr(h) * cs + 0.5001)
    ax(off)       =  x : ax(off + 75)  =  y
    ax(off + 150) = -x : ax(off + 225) = -y
    ax(off + 300) =  x
    off = off + 375
  NEXT h
  ang = sn * cd + cs * sd : cs = cs * cd - sn * sd : sn = ang
NEXT i


' Agujas en modo XOR (las 3 siempre, igual que en marcha)
OVER 1

PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
PLOT cx, cy : DRAW ax(mi), ax(mi + 75)
PLOT cx, cy : DRAW ax(si), ax(si + 75)

pl = PEEK(23672)

DO
  ' Espera 1 frame dormido en HALT; despierta con la INT del ULA.
  ' (PAUSE 1 haria lo mismo, pero la ROM ademas recorre el
  ' teclado en cada frame del PAUSE: HALT cuesta 4 T-states.)
  ASM
  halt
  END ASM

  ' Salir con cualquier tecla (A8-A15 a 0 = todas las semifilas)
  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  ' Delta de FRAMES (UByte, envuelve solo): compensa frames
  ' perdidos si un paso dura mas de un frame
  nb = PEEK(23672)
  d = nb - pl
  pl = nb
  acc = acc + d

  ' Un paso cada 10 frames (0.2 s): 300 pasos = 60 s exactos
  WHILE acc >= UMBRAL
    acc = acc - UMBRAL

    ' --- Segundero: dibujar la nueva ANTES de borrar la vieja,
    '     asi nunca hay un frame con el dial sin aguja ---
    oi = si
    si = si + 1
    IF si = 1050 THEN si = 750
    PLOT cx, cy : DRAW ax(si), ax(si + 75)
    PLOT cx, cy : DRAW ax(oi), ax(oi + 75)

    ' --- Reparacion de la fusion triple de las 12: el borrado
    '     del segundero acaba de apagar la linea fundida
    '     (horario+minutero); se reenciende ---
    IF rep <> 0 THEN
      PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
      rep = 0
    END IF

    ' --- Minutero: cambia cada 60 pasos (12 s) ---
    km = km + 1
    IF km = 60 THEN
      km = 0
      om = mi
      mi = mi + 1
      IF mi = 675 THEN mi = 375
      PLOT cx, cy : DRAW ax(mi), ax(mi + 75)
      IF hp = 1 AND om = hi + 375 THEN
        ' El minutero se separa del horario tras la fusion de
        ' las 12: borrar SOLO su tramo exterior (r34..52).
        ' El tramo r0..33 queda encendido: es el horario.
        ' Se empieza en y(hi)+1 para no tocar su punta
        PLOT cx + ax(hi), cy + ax(hi + 75) + 1
        DRAW ax(om) - ax(hi), ax(om + 75) - ax(hi + 75) - 1
        hp = 0
      ELSE
        PLOT cx, cy : DRAW ax(om), ax(om + 75)
      END IF

      ' --- Horario: cambia cada 12 pasos del minutero (144 s) ---
      kh = kh + 1
      IF kh = 12 THEN
        kh = 0
        oh = hi
        hi = hi + 1
        IF hi = 300 THEN
          ' Medianoche y mediodia: cambia pm
          hi = 0
          pm = 1 - pm
          IF pm = 0 THEN
            ' Medianoche: avanza el dia
            IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
            drawDate(dia)
          END IF
          ' Fusion triple en las 12 en punto (si = 750 y mi = 375
          ' siempre en este instante): reparacion y borrado parcial
          rep = 1 : hp = 1
        END IF
        PLOT cx, cy : DRAW ax(hi), ax(hi + 75)
        PLOT cx, cy : DRAW ax(oh), ax(oh + 75)
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
' Restauracion
' ------------------------------------------------------------
BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS
PRINT AT 0, 8; TITLE
