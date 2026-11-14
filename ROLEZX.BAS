' ************************************************************
'  ROLEZX v25 - Reloj analogico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  CAMBIOS v25 (tamano y arranque sobre v24):
'
'   * BINARIO MAS PEQUENO: se elimina por completo la libreria
'     de PRINT (aprox. 1.6 KB, ~25% del binario). Los cinco
'     PRINT se sustituyen por putRom (copia del caracter ROM a
'     la celda de atributo) y POKE directo de atributos. Las
'     cadenas van como arrays de UByte: la inicializacion de
'     arrays ya esta incluida, asi que no se anade ninguna
'     libreria nueva.
'   * ARRANQUE MAS RAPIDO (velocidad percibida): bigChar y el
'     relleno de la ventana de fecha pasan de PLOT/DRAW (una
'     llamada ROM por pixel) a POKE directo sobre la bitmap.
'     ROLEZX y la fecha se pintan en ~1 ms en vez de ~70 ms.
'     Verificado por simulacion (scripts/verify_poke.py) que el
'     resultado en pantalla es bit a bit identico al original.
'   * SIN CAMBIOS DE LOGICA NI DE ASPECTO: esfera, tabla de
'     senos, fusion de las 12, tic-tac, espera con HALT,
'     deteccion de tecla y orden de pintado de v24.
'
'  Historia: v23 arranco ~1 s mas rapido girando el seno en vez
'  de llamar a SIN/COS; v22 una sola tabla de senos (ax fuera
'  del binario con AT) y color sin clash (PAPER 1 + INK 6 en
'  toda la esfera, agujas en XOR). v24 reordeno el pintado para
'  que el reloj se construya desde el primer instante. v25
'  mantiene todo eso y ademas recorta tamano y arranque.
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

#define TITLE_LEN 14       ' "ROLEZX by Guti"

' ------------------------------------------------------------
' Direccion del byte de bitmap que contiene el pixel (x, y),
' y en coords hardware (0 = arriba). Usada por bigChar y
' drawDate para escribir pixeles sin pasar por PLOT.
' ------------------------------------------------------------
FUNCTION scrAddr(y as UByte, x as UByte) as UInteger
  RETURN 16384 + (CAST(UInteger, y >> 6) << 11) + (CAST(UInteger, y BAND 7) << 8) + (CAST(UInteger, (y >> 3) BAND 7) << 5) + CAST(UInteger, x >> 3)
END FUNCTION

' Duplica cada bit de un nibble: exn(n) -> 8 bits con cada bit
' repetido dos veces. Permite escalar un byte de caracter a 2x
' con dos lecturas a la tabla en vez de 4 PLOT por pixel.
DIM exn(15) as UByte = {0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF}

' ------------------------------------------------------------
' putRom: copia un caracter ROM (1x) a la celda de atributo
' (fila r, columna c). Solo toca la bitmap, no los atributos:
' los atributos de cada celda ya los pone CLS, el POKE del fondo
' azul o el POKE de la barra. Sustituye a PRINT AT r,c;CHR$ ch
' para no arrastrar la libreria de PRINT (~1.6 KB).
' ------------------------------------------------------------
SUB putRom(r as UByte, c as UByte, ch as UByte)
  DIM k as UByte
  DIM kk as UInteger
  DIM src as UInteger
  DIM base as UInteger
  src = 15360 + CAST(UInteger, ch) * 8
  base = 16384 + (CAST(UInteger, r >> 3) << 11) + (CAST(UInteger, r BAND 7) << 5) + c
  FOR k = 0 TO 7
    kk = CAST(UInteger, k) << 8
    POKE base + kk, PEEK(src + k)
  NEXT k
END SUB

' ------------------------------------------------------------
' bigChar: caracter ROM escalado 2x (16x16 px) por POKE directo
' a la bitmap. opv = 0 anyade pixeles (OR, esfera/ROLEZX);
' opv = 1 los invierte (XOR, recorta el digito de la fecha).
' x debe ser multiplo de 8 (todas las llamadas lo cumplen).
' ------------------------------------------------------------
SUB bigChar(x as UByte, yt as UByte, ch as UByte, opv as UByte)
  DIM r as UByte
  DIM b as UByte
  DIM yh as UByte
  DIM src as UInteger
  DIM a0 as UInteger
  DIM a1 as UInteger
  DIM lo as UByte
  DIM ro as UByte
  src = 15360 + CAST(UInteger, ch) * 8
  FOR r = 0 TO 7
    b = PEEK(src + r)
    IF b <> 0 THEN
      yh = yt + r + r
      a0 = scrAddr(yh, x)         ' fila superior del bloque 2x2
      a1 = scrAddr(yh + 1, x)     ' fila inferior (scrAddr ya da el salto de celda)
      lo = exn(b >> 4)
      ro = exn(b BAND 0x0F)
      IF opv = 0 THEN
        POKE a0,     PEEK(a0)     BOR lo
        POKE a0 + 1, PEEK(a0 + 1) BOR ro
        POKE a1,     PEEK(a1)     BOR lo
        POKE a1 + 1, PEEK(a1 + 1) BOR ro
      ELSE
        POKE a0,     PEEK(a0)     BXOR lo
        POKE a0 + 1, PEEK(a0 + 1) BXOR ro
        POKE a1,     PEEK(a1)     BXOR lo
        POKE a1 + 1, PEEK(a1 + 1) BXOR ro
      END IF
    END IF
  NEXT r
END SUB

' ------------------------------------------------------------
' Ventana de fecha a las 3 (estilo Datejust). Se rellena con
' pixeles amarillos (POKE OR sobre la bitmap; la ventana ya es
' azul por el POKE del fondo) y el digito se recorta con XOR:
' apaga esos pixeles y deja ver el azul. No toca atributos.
' ------------------------------------------------------------
SUB drawDate(n as UByte)
  DIM yr as UByte
  DIM ab as UInteger
  ' Relleno: x 150..185 (36 px), y 99..116 -> hardware 75..92.
  ' Byte 18 (cols 150-151) mascara 0x03; bytes 19..22 todo 0xFF;
  ' byte 23 (cols 184-185) mascara 0xC0.
  FOR yr = 75 TO 92
    ab = scrAddr(yr, 150)
    POKE ab,     PEEK(ab)     BOR 0x03
    POKE ab + 1, 0xFF
    POKE ab + 2, 0xFF
    POKE ab + 3, 0xFF
    POKE ab + 4, 0xFF
    POKE ab + 5, PEEK(ab + 5) BOR 0xC0
  NEXT yr
  IF n < 10 THEN
    bigChar(160, 76, 48 + n, 1)
  ELSE
    bigChar(152, 76, 48 + n / 10, 1)
    bigChar(168, 76, 48 + n MOD 10, 1)
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

  ' ROLEZX centrado en el eje del reloj (OR: anyade pixeles amarillos)
  bigChar(80, 44, 82, 0)  : bigChar(96, 44, 79, 0)  : bigChar(112, 44, 76, 0)
  bigChar(128, 44, 69, 0) : bigChar(144, 44, 90, 0) : bigChar(160, 44, 88, 0)

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
' AT 49152 mapea la tabla fuera del binario (se rellena al
' arrancar); si tu Boriel rechaza DIM ... AT para arrays,
' quita " AT 49152" y todo sigue funcionando (solo crece).
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

' Textos como arrays de UByte (evita la libreria de strings y la
' de PRINT). Codigos ASCII de cada caracter.
DIM tTitle(13) as UByte = {82, 79, 76, 69, 90, 88, 32, 98, 121, 32, 71, 117, 116, 105}  ' "ROLEZX by Guti"
DIM tOyster(15) as UByte = {79, 89, 83, 84, 69, 82, 32, 80, 69, 82, 80, 69, 84, 85, 65, 76}  ' "OYSTER PERPETUAL"
DIM tDate(7)   as UByte = {68, 65, 84, 69, 74, 85, 83, 84}  ' "DATEJUST"

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

  ' ------------------------------------------------------------
  ' ARRANQUE EN ORDEN DE "LO QUE SE VE ANTES" (v24): cada paso
  ' pinta algo mientras el siguiente calcula. Orden: barra ->
  ' textos del dial -> fondo azul -> aros -> marcas -> fecha ->
  ' tabla de agujas -> agujas.
  ' ------------------------------------------------------------

  ' Barra inferior azul con titulo centrado (FLASH). Atributo
  ' 0xCF = BRIGHT 1, FLASH 1, PAPER 1, INK 7. POKE directo (sin
  ' PRINT): la bitmap de la fila ya esta a 0 tras CLS.
  FOR k = 0 TO 31 : POKE 23200 + k, 207 : NEXT k    ' 22528 + 21*32
  FOR k = 0 TO TITLE_LEN - 1 : putRom(21, 9 + k, tTitle(k)) : NEXT k

  ' Textos del dial ANTES de los circulos y el fondo azul: sus
  ' celdas quedan dentro de la zona azul y el POKE del fondo les
  ' pondra el atributo 0x4E (azul + amarillo) despues.
  FOR k = 0 TO 15 : putRom(8, 8 + k, tOyster(k)) : NEXT k
  FOR k = 0 TO 7  : putRom(13, 12 + k, tDate(k)) : NEXT k

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
FOR k = 0 TO TITLE_LEN - 1 : putRom(0, 8 + k, tTitle(k)) : NEXT k
