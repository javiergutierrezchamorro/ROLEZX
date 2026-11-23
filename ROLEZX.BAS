' ************************************************************
'  ROLEZX v33 - Reloj analogico estilo Rolex Datejust
'  (Boriel ZX BASIC para ZX Spectrum 48K, 50 Hz)
' ************************************************************
'  v33 - PEEK/POKE tipado y CONST (mismo comportamiento, menos codigo):
'   - ax() fuera: la tabla se accede con PEEK/POKE tipados. ax(t)
'     llamaba al runtime generico __ARRAY (lee tabla de dimensiones,
'     resta LBOUND y multiplica con __FMUL16: cientos de T por
'     acceso); PEEK(Byte, AXTAB + t) son 4 instrucciones inline.
'     El tick (2 drawHand) queda sin llamadas __ARRAY y la
'     construccion de tabla tambien (6 x 75 POKEs directos).
'   - Constantes migradas a CONST tipado (CONST x As Tipo = valor):
'     el optimizador las pliega igual que #define (binario byte a
'     byte identico, verificado). OJO: SIN tipo, CONST dispara W100.
'   - tmp as Integer fuera del build de tabla: CAST(Byte, INT())
'     directo; INT() se fusiona inline a coste cero.
'   - Compilar con -O4: 48 bytes menos que -O3 (solo eliminacion de
'     cargas muertas, diff verificado instruccion a instruccion)
'   - FASTCALL NO USAR: roto en zxbc 1.18.7 (el llamador pasa el
'     parametro en registros pero el cuerpo lo lee de la pila)
'   - Total: 4981 -> 4860 bytes de TAP, 0 warnings
'
'  v32 - Constantes simbolicas para la tabla de agujas ax():
'   - NPOS (75): entradas por bloque (x o y) de la tabla; los
'     indices recorren 0..NPOS-1 (bucle de construccion y
'     si/mi/hi) y envuelven en NPOS
'   - OFF_HORA / OFF_MIN / OFF_SEC (0 / 150 / 300): bloque x de
'     cada aguja; su bloque y esta a NPOS entradas (OFF_* + NPOS)
'   - El optimizador plega las constantes: binario identico
'
'  v31 - Corregidos los 3 W120 (bug real) + optimizacion:
'   - drawHand: offset UByte -> UInteger. Con UByte el literal 300
'     se truncaba a 44: la aguja de segundos leia filas equivocadas
'     de la tabla. Ademas pos+offset+75 desbordaba en 8 bits y el
'     minutero se descuadraba desde el indice 31 (sin aviso).
'   - Salida por tecla: basta IN 254 (puerto 00FE activa las 8
'     semi-filas a la vez -> cualquier tecla). IN 253/251/247 tienen
'     A0=1: la ULA no responde y devuelven el bus flotante.
'   - bigChar: bucle unico (solo se usa al iniciar / cambiar fecha)
'   - fillMem propio: fuera memcopy.bas y sus W150/W160/W170
'     -> 0 warnings SIN supresiones -W
'
'  Compilar: zxbc -O4 -f tap -o rolezx.tap rolezx.bas
'
'  Optimizaciones v30 + cambios 4.1 / 5.x + limpieza Boriel:
'   - Tabla agujas 450 bytes (solo x,y positivos)
'   - Indices 0..74 unificados
'   - Unificado trazado de agujas (SUB drawHand)
'   - bigChar: scrAddr + IF fuera del bucle
'   - Constantes simbólicas para literales de pantalla
'   - Hora con acumulador tipo Bresenham (coherente)
'   - Reloj automático: aguja de segundos salta ~1/8 s
'   - Salida por tecla mejorada
'   - km/kh eliminados
'   - * 8 → SHL 3
'   - POKE/PEEK tipados
'   - CAST(Fixed, SIN/COS) + variable intermedia Integer
' ************************************************************

CONST cx          As UByte   = 128
CONST cy          As UByte   = 108
CONST rOuter      As UByte   = 72
CONST rHora       As UByte   = 33
CONST rMin        As UByte   = 52
CONST rSec        As UByte   = 63
CONST DIA0        As UByte   = 7
CONST DIASMES     As UByte   = 30

CONST DATE_X      As UByte   = 152
CONST DATE_Y      As UByte   = 76
CONST DATE_WIN_Y0 As UByte   = 75
CONST DATE_WIN_Y1 As UByte   = 92
CONST TITLE_ROW   As UByte   = 21
CONST TITLE_COL   As UByte   = 9
CONST OYSTER_ROW  As UByte   = 8
CONST OYSTER_COL  As UByte   = 8
CONST DATEJ_ROW   As UByte   = 13
CONST DATEJ_COL   As UByte   = 12
CONST BRAND_Y     As UByte   = 44
CONST BRAND_X0    As UByte   = 80

' Tabla de agujas ax(): 6 bloques de NPOS entradas (x,y de hora,
' min y seg). OFF_* apunta al primer elemento del bloque x de cada
' aguja; su bloque y esta a continuacion (OFF_* + NPOS).
' AXTAB: direccion de la tabla (0xC000). Se accede con PEEK/POKE
' tipados en vez de array: ax(t) llama al runtime generico __ARRAY
' (tabla de dimensiones + __FMUL16, cientos de T por acceso);
' PEEK(Byte, AXTAB + t) son 4 instrucciones inline sin llamada.
CONST NPOS        As UByte   = 75
CONST OFF_HORA    As UInteger = 0
CONST OFF_MIN     As UInteger = 150
CONST OFF_SEC     As UInteger = 300
CONST AXTAB       As UInteger = 49152

FUNCTION scrAddr(y as UByte, x as UByte) as UInteger
  RETURN 16384 + (CAST(UInteger, y SHR 6) SHL 11) + (CAST(UInteger, y BAND 7) SHL 8) + (CAST(UInteger, (y SHR 3) BAND 7) SHL 5) + CAST(UInteger, x SHR 3)
END FUNCTION

DIM exn(15) as UByte = {0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF}

' La tabla de agujas (450 bytes con signo) vive en 0xC000 (AXTAB).
' Ya no se declara como array: sin descriptor y sin __ARRAY.

' Relleno de n bytes con v desde la direccion a (sustituye a MemSet
' de memcopy.bas, que dispara W150/W160/W170). Es codigo de
' inicializacion: un bucle de POKEs es mas que suficiente.
SUB fillMem(a as UInteger, v as UByte, n as UByte)
  DIM j as UByte
  FOR j = 1 TO n
    POKE a, v
    a = a + 1
  NEXT j
END SUB

SUB putRom(r as UByte, c as UByte, ch as UByte)
  DIM src as UInteger = 15360 + (CAST(UInteger, ch) SHL 3)
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
  DIM src as UInteger = 15360 + (CAST(UInteger, ch) SHL 3)
  DIM a0 as UInteger
  DIM m as UInteger

  ' Un solo bucle con la operacion dentro: bigChar solo se ejecuta
  ' al inicializar y al cambiar la fecha (no es codigo caliente)
  FOR r = 0 TO 7
    b  = PEEK(src + r)
    a0 = scrAddr(yt + (r SHL 1), x)
    m  = CAST(UInteger, exn(b SHR 4)) + (CAST(UInteger, exn(b BAND 0x0F)) SHL 8)
    IF opv = 0 THEN
      POKE uinteger a0,       PEEK(uinteger, a0)       BOR m
      POKE uinteger a0 + 256, PEEK(uinteger, a0 + 256) BOR m
    ELSE
      POKE uinteger a0,       PEEK(uinteger, a0)       BXOR m
      POKE uinteger a0 + 256, PEEK(uinteger, a0 + 256) BXOR m
    END IF
  NEXT r
END SUB

SUB drawDate(n as UByte)
  DIM yr as UByte
  DIM a as UInteger
  FOR yr = DATE_WIN_Y0 TO DATE_WIN_Y1
    a = scrAddr(yr, DATE_X)
    POKE a - 1, PEEK(a - 1) BOR 3
    POKE long a, -1
    POKE a + 4, PEEK(a + 4) BOR 192
  NEXT yr
  IF n < 10 THEN
    bigChar(DATE_X + 8, DATE_Y, 48 + n, 1)
  ELSE
    bigChar(DATE_X,     DATE_Y, 48 + n / 10, 1)
    bigChar(DATE_X + 16, DATE_Y, 48 + n MOD 10, 1)
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
  DIM sa as Fixed = CAST(Fixed, SIN(PI / 30.0))
  DIM ca as Fixed = CAST(Fixed, COS(PI / 30.0))

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

  PLOT cx - 6, cy + 46 : DRAW 0, 4
  PLOT cx - 3, cy + 46 : DRAW 0, 5
  PLOT cx    , cy + 46 : DRAW 0, 7
  PLOT cx + 3, cy + 46 : DRAW 0, 5
  PLOT cx + 6, cy + 46 : DRAW 0, 4
  PLOT cx - 6, cy + 46 : DRAW 12, 0

  bigChar(BRAND_X0,      BRAND_Y, 82, 0)
  bigChar(BRAND_X0 + 16, BRAND_Y, 79, 0)
  bigChar(BRAND_X0 + 32, BRAND_Y, 76, 0)
  bigChar(BRAND_X0 + 48, BRAND_Y, 69, 0)
  bigChar(BRAND_X0 + 64, BRAND_Y, 90, 0)
  bigChar(BRAND_X0 + 80, BRAND_Y, 88, 0)

  CIRCLE cx, cy, 3
END SUB

' v33: PEEK/POKE tipado en vez de ax(): 2 llamadas a __ARRAY menos
' por invocacion (el runtime generico hace lectura de tabla de
' dimensiones, resta de LBOUND y __FMUL16 por acceso; el PEEK son
' 4 instrucciones inline). drawHand se llama 2 veces por tick.
' FASTCALL estaria genial (param en registros) pero esta ROTO en
' zxbc 1.18.7: el llamador usa la convencion de registros y el
' cuerpo sigue leyendo la pila -> valor corrupto. No usar.
SUB drawHand(pos as UByte, offset as UInteger)
  DIM t as UInteger
  t = pos + offset
  PLOT cx, cy
  DRAW PEEK(Byte, AXTAB + t), PEEK(Byte, AXTAB + t + NPOS)
END SUB

DIM tTitle(13) as UByte = {82, 79, 76, 69, 90, 88, 32, 98, 121, 32, 71, 117, 116, 105}
DIM tOyster(15) as UByte = {79, 89, 83, 84, 69, 82, 32, 80, 69, 82, 80, 69, 84, 85, 65, 76}
DIM tDate(7) as UByte = {68, 65, 84, 69, 74, 85, 83, 84}

DIM si as UByte = 0
DIM mi as UByte = 11
DIM hi as UByte = 63

DIM dia as UByte = DIA0
DIM frames as UByte = 0
DIM beepLeft as UByte = 0

DIM hourAcc as UByte = 0
DIM secSteps as UByte = 0

  BORDER 0 : PAPER 0 : INK 6 : BRIGHT 1 : OVER 0 : INVERSE 0 : CLS

  fillMem(23200, 207, 32)
  DIM i as UByte
  FOR i = 0 TO 13 : putRom(TITLE_ROW, TITLE_COL + i, tTitle(i)) : NEXT i
  FOR i = 0 TO 15 : putRom(OYSTER_ROW, OYSTER_COL + i, tOyster(i)) : NEXT i
  FOR i = 0 TO 7  : putRom(DATEJ_ROW, DATEJ_COL + i, tDate(i)) : NEXT i

  DIM aw(16) as UByte = {3, 5, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 7, 7, 6, 4, 2}
  DIM ad as UInteger = 22592
  FOR i = 0 TO 16
    fillMem(ad + 16 - aw(i), 78, CAST(UByte, aw(i) SHL 1))
    ad = ad + 32
  NEXT i

  PAPER 8
  CIRCLE cx, cy, rOuter
  CIRCLE cx, cy, rOuter - 5
  drawFace()
  drawDate(dia)

  ' Tabla de agujas: POKE directo (mismo motivo que drawHand).
  ' CAST(Byte, INT(...)): INT() se fusiona inline a coste cero y
  ' preserva el redondeo del original; la variable Integer tmp
  ' desaparece.
  DIM sn as Fixed = 0
  DIM cs as Fixed = 1
  DIM sd as Fixed = CAST(Fixed, SIN(PI / 150.0))
  DIM cd as Fixed = CAST(Fixed, COS(PI / 150.0))
  DIM ang as Fixed

  FOR i = 0 TO NPOS - 1
    POKE AXTAB + i + OFF_HORA,        CAST(Byte, INT(rHora * sn + 0.5))
    POKE AXTAB + i + OFF_HORA + NPOS, CAST(Byte, INT(rHora * cs + 0.5))
    POKE AXTAB + i + OFF_MIN,         CAST(Byte, INT(rMin  * sn + 0.5))
    POKE AXTAB + i + OFF_MIN + NPOS,  CAST(Byte, INT(rMin  * cs + 0.5))
    POKE AXTAB + i + OFF_SEC,         CAST(Byte, INT(rSec  * sn + 0.5))
    POKE AXTAB + i + OFF_SEC + NPOS,  CAST(Byte, INT(rSec  * cs + 0.5))

    ang = sn * cd + cs * sd
    cs  = cs * cd - sn * sd
    sn  = ang
  NEXT i

  OVER 1
  drawHand(hi, OFF_HORA)
  drawHand(mi, OFF_MIN)
  drawHand(si, OFF_SEC)

DO
  ASM
  halt
  END ASM

  ' v31: el puerto 00FE tiene A0=0 (ULA activa) y A8-A15=0, asi que
  ' selecciona las 8 semi-filas a la vez: un solo IN detecta cualquier
  ' tecla. (253/251/247 tienen A0=1: la ULA no responde, bus flotante)
  IF ((IN 254) BAND 31) <> 31 THEN EXIT DO

  frames = frames + 1

  IF beepLeft <> 0 THEN
    beepLeft = beepLeft - 1
    IF beepLeft = 0 THEN OUT 254, 0
  END IF

  IF (frames BAND 7) = 0 THEN
    ' Nota: en ZX BASIC el scope es por funcion, no por bloque:
    ' este DIM (sin inicializador) es una estatica global mas,
    ' sin codigo de inicializacion por iteracion.
    DIM oldSi as UByte
    oldSi = si
    si = si + 1
    IF si = NPOS THEN si = 0
    drawHand(si, OFF_SEC)
    drawHand(oldSi, OFF_SEC)

    secSteps = secSteps + 1
    IF secSteps = 60 THEN
      secSteps = 0

      DIM oldMi as UByte
      oldMi = mi
      mi = mi + 1
      IF mi = NPOS THEN mi = 0
      drawHand(mi, OFF_MIN)
      drawHand(oldMi, OFF_MIN)

      hourAcc = hourAcc + 1
      IF hourAcc >= 12 THEN
        hourAcc = hourAcc - 12
        DIM oldHi as UByte
        oldHi = hi
        hi = hi + 1
        IF hi = NPOS THEN
          hi = 0
          IF dia = DIASMES THEN dia = 1 ELSE dia = dia + 1
          drawDate(dia)
        END IF
        drawHand(hi, OFF_HORA)
        drawHand(oldHi, OFF_HORA)
      END IF
    END IF

    OUT 254, 16
    beepLeft = 1 + ((frames SHR 3) BAND 1)
  END IF
LOOP

BORDER 7 : PAPER 7 : INK 0 : BRIGHT 0 : OVER 0 : INVERSE 0
CLS