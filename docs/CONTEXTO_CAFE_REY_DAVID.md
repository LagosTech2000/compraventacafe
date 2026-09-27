# Contexto del negocio: Compra de Café el Rey David

Documento de contexto para desarrollar el sistema de compra y venta de café.
Lo que sigue sale de dos fuentes del cliente:

- **[CUESTIONARIO]**: respuestas escritas del cliente a 42 preguntas (PDF, sept. 2026). Respuestas cortas, a veces de una palabra.
- **[EXCEL]**: su libro de trabajo actual `COSECHA_2026L.xlsm` (10 hojas + macros VBA), cosecha nov-2025 a abr-2026.

## Regla para quien use este documento

Cada dato lleva una etiqueta:

- `[VERIFICADO: fuente]`: leído directamente en el cuestionario, en una celda/fórmula del Excel, o en el código VBA.
- `[CALCULADO: ...]`: comprobado haciendo la cuenta sobre los datos reales del Excel.
- `[DESCONOCIDO]`: no hay dato. **No construir sobre esto sin preguntar al cliente.** Si una tarea depende de un `[DESCONOCIDO]`, detenerse y preguntar.

No inventar reglas de negocio. Si algo no está aquí, no se sabe.

---

## 1. El negocio

| Dato | Valor | Fuente |
|---|---|---|
| Puntos de compra | 1, en Mata de Plátano, Moroceli | [VERIFICADO: CUESTIONARIO p.4] |
| Temporada | Compran todo el año | [VERIFICADO: CUESTIONARIO p.2] |
| Compras por día | Normal ~30, día ocupado ~100 | [VERIFICADO: CUESTIONARIO p.3] |
| Compras por día (datos reales) | 126 días con compras; mediana 29 filas/día; máximo 80 | [CALCULADO: EXCEL, hoja INGRESO DE CAFE] |
| Volumen de la temporada | ~3,850 filas de compra; ~1,600 nombres distintos (con duplicados por escritura) | [CALCULADO: EXCEL] |
| Moneda | Lempiras (formato `"L "#,##0.00`) | [VERIFICADO: VBA modSalidasTotales] |
| Quién usará el sistema | "Secretari@" | [VERIFICADO: CUESTIONARIO p.5] |
| Anula/corrige compras | El o la gerente | [VERIFICADO: CUESTIONARIO p.20] |
| Problema principal | "Poca eficiencia" | [VERIFICADO: CUESTIONARIO p.6] |
| Dispositivos | "Todas las opciones" (computadora, laptop, celular, tablet) → debe ser responsive | [VERIFICADO: CUESTIONARIO p.41] |
| Logo/colores | Sí tienen; **no se han recibido** | [VERIFICADO: CUESTIONARIO p.40] · archivo [DESCONOCIDO] |
| Qué quieren ver en la demo | Respondieron "¿?" | [DESCONOCIDO] |

### Flujo diario descrito por el cliente [VERIFICADO: CUESTIONARIO p.1]

1. Pesan el café.
2. Hacen la factura.
3. La marcan como cancelada (pagada) o pendiente de pago.
4. La guardan para, al final de temporada, hacer la retención.

La **retención de fin de temporada**: cómo se calcula, qué porcentaje, a quién se reporta → [DESCONOCIDO].

---

## 2. Compra de café

### Qué compran

- Estados del café: **uva, pergamino húmedo, pergamino seco** [VERIFICADO: CUESTIONARIO p.7].
- El Excel **no tiene columna para el estado del café**: todas las filas usan la misma fórmula. [VERIFICADO: EXCEL, encabezados de INGRESO DE CAFE]
  - Cómo cambia el cálculo según el estado (uva vs. húmedo vs. seco) → [DESCONOCIDO].
- Unidad de compra: **libras** [VERIFICADO: CUESTIONARIO p.8].
- Calidad: sí clasifican por calidad; categorías → [DESCONOCIDO]. No clasifican variedad. [VERIFICADO: CUESTIONARIO p.9]
  - En el Excel, la calidad solo aparece como texto libre en OBSERVACIONES (col H): "PULPA", "PULPA Y AMARILLO", "VERDE", "PERICO", "SOBRE FERMENTO", "1.5%VERDE Y DAÑO". [VERIFICADO: EXCEL]

### A quién le compran [VERIFICADO: CUESTIONARIO p.10–12]

- Productores, intermediarios (les llaman **"carreros"**) y fincas propias.
- Datos que piden: nombre, dirección, RTN, finca.
- Siempre se registra al vendedor (no hay compras anónimas).
- El café de fincas propias "se registra igual" que el comprado [VERIFICADO: CUESTIONARIO p.30].

**Problema de datos**: en el Excel el productor es texto libre, sin catálogo. Hay variantes del mismo nombre ("VALENTIN TREJO" / "VALENTIN  TREJO") y de la misma zona: "BUENAS NOCHES" / "B.N." / "buenas noches"; "EL CHILITO - MARIO" / "EL CHILITO/MARIO" / "EL CHILITO(DON MARIO)"; "MATA DE PLATANO" / "M. DE PL."; "LAS LABRANZAS" / "LAS LAB."; "PUEBLO NUEVO" / "P.N.". ~260 valores distintos de dirección. [CALCULADO: EXCEL] → El sistema necesita catálogos de productores y zonas. Si se migra el histórico, hay que normalizar.

### Precio [VERIFICADO: CUESTIONARIO p.13, p.15]

- Depende de **calidad, zona y bolsa**. "Cambia de lunes a viernes."
- Quién lo decide → [DESCONOCIDO].
- Pasos que describe el cliente: 1) identificar la zona, 2) observar la calidad, 3) peso neto × precio.
- Tabla de precios por zona/calidad → [DESCONOCIDO]. En el Excel el precio se escribe a mano en cada fila (col J), no hay tabla.
- Precio real por libra neta (col J, en Lempiras), promedio por mes [CALCULADO: EXCEL, filas con precio > 10]:

| Mes | Filas | Mín | Máx | Promedio |
|---|---|---|---|---|
| 2025-11 | 412 | 27 | 58 | 55.0 |
| 2025-12 | 1225 | 54 | 62 | 57.5 |
| 2026-01 | 1051 | 35 | 61 | 57.1 |
| 2026-02 | 787 | 40 | 56 | 45.8 |
| 2026-03 | 323 | 32 | 52.5 | 44.2 |
| 2026-04 | 11 | 35 | 42 | 39.8 |

### Cálculo del peso neto y del total (regla actual)

Fuente: macro `modIngresoCafeAuto.RecalcularFilaIngreso` [VERIFICADO: VBA].

```
sacos    = peso_bruto / 165                 # "PESO_SACO_LLENO = 165", con decimales
tara     = CEILING(sacos, 1) × 1 lb         # 1 libra por saco, redondeado hacia arriba
humedad  = valor col F; si > 1 se divide entre 100 (51 → 0.51)
peso_neto = (peso_bruto − tara) × (1 − humedad)   # si < 0 → 0
total     = peso_neto × precio_por_libra
```

Ejemplo real [CALCULADO: EXCEL]: bruto 146 lb, humedad 51 → sacos 0.8848, tara 1 → neto (146−1)×0.49 = **71.05 lb** → × L 58 = **L 4,120.90**.

La regla coincide exactamente con 3,054 de 3,846 filas [CALCULADO: EXCEL].

**Regla anterior (principio de temporada, ~788 filas)** [VERIFICADO: fórmula en celda I3]:
```
peso_neto = (peso_bruto − E) × (1 − humedad/100 − daño/100)
```
- `E` estaba fijo en 1 (tara de 1 lb total) y la columna G "DAÑO" se restaba como porcentaje.
- Ejemplo: bruto 43, humedad 51, daño 1 → (43−1)×0.48 = 20.16.
- **La macro actual ignora la columna DAÑO.** No se sabe si el daño se sigue descontando → [DESCONOCIDO].

Descuentos según el cliente: "del peso los sacos, la humedad 51% y daños" [VERIFICADO: CUESTIONARIO p.14].

Humedad en los datos: 51 en ~3,545 filas; también 52, 53, 54, 55, 57 [CALCULADO: EXCEL]. Si el "51%" es humedad medida o un factor fijo de conversión, y si cambia según el estado del café → [DESCONOCIDO].

### Pago al productor [VERIFICADO: CUESTIONARIO p.16–18]

- Efectivo, transferencia o cheque. Puede quedar **saldo pendiente**.
- Dan **adelantos**; el productor los paga o abona "cuando va vendiendo café".
- Al pagar se descuenta **interés** (del préstamo/adelanto).
- La hoja ANTICIPOS del Excel tiene columnas pero **ninguna fila de datos** [VERIFICADO: EXCEL]: `ID_ANTICIPO, FECHA, CLIENTE/EXPORTADOR, FORMA DE PAGO, CONCEPTO, MONTO ANTICIPO, MONTO APLICADO, SALDO PENDIENTE, SALDO RESTANTE, ESTADO, OBSERVACIONES`. Por el encabezado "CLIENTE/EXPORTADOR", parece ser para anticipos *recibidos del exportador*, no *dados al productor* → [DESCONOCIDO].

### Estado de pago (col M)

- Valores usados: "CANCELADO" (pagado) y "PXP" (pendiente). La macro trata `PXP` o `PENDIENTE` como deuda pendiente [VERIFICADO: VBA ActualizarTotalesBloqueUnico].
- En los datos hay ~35 variantes mal escritas: "CANCELADA", "CANCELAD", "C", "CANCELAO", "P X P", "PX P", "CANCEL. 19/12/25", "PXP 37452."… ~246 filas vacías [CALCULADO: EXCEL] → en el sistema debe ser una lista cerrada. Y guardar la fecha de pago en su propio campo, no dentro del texto.

### Factura / recibo al productor

Datos que lleva el recibo [VERIFICADO: CUESTIONARIO p.19]: nombre, ubicación, fecha, libras, precio, total, observaciones, firma de quien factura. Se imprime original y copia [VERIFICADO: EXCEL, hoja FACTURAS].

Macro `ImprimirFactura_G1aG4` [VERIFICADO: VBA]:
- Una factura agrupa **hasta 4 filas de compra**: los números de fila se escriben en FACTURAS!G1:G4.
- Toma el número de factura actual en E6, le suma 1 y lo formatea "0000". Lo escribe en original (E6) y copia (E24).
- Copia número de factura y estado (desde A14) a las columnas L y M de INGRESO DE CAFE, y luego imprime.

Observado en el archivo actual: G1:G4 y E6 están vacíos, el estado está en A15 (no en A14) y hay una celda "FILA A FACTURAR" en E2/F2 [VERIFICADO: EXCEL]. El diseño de la hoja ya no coincide con lo que espera la macro. Si hoy se usa así o no → [DESCONOCIDO].

Numeración real (col L): varias compras comparten número (filas 2–4 = factura 220). Los números no son correlativos por fecha (ej. 2877 y luego 2037) y ~216 filas no tienen número [CALCULADO: EXCEL]. Qué significa la columna D de la factura (valor 2680) → [DESCONOCIDO].

### Automatismos que hoy hace el Excel (candidatos a funcionalidad del sistema)

Fuente: hoja `INGRESO DE CAFE` (evento `Worksheet_Change`) + `modSalidasTotales` [VERIFICADO: VBA].

1. **Fecha automática**: al escribir el nombre, si no hay fecha pone la de hoy.
2. **Cierre diario**: al cambiar de fecha inserta un bloque con fecha, libras brutas compradas, sacos, número de productores (cuenta filas) y dinero del día.
3. **Llenado de camiones** (conteo en sacos de 165 lb desde la última salida):
   - Camión pequeño = **72 sacos**, grande = **140 sacos**.
   - Avisos cuando faltan 10, 5, 2 y 1 sacos.
   - Si se pasa de 72, pregunta: cerrar la carga o seguir hasta 140. Cerca de 140 pregunta: cerrar o fijar un nuevo objetivo.
   - Si falta 1 o 0.5 saco y el productor trae más, cierra la carga antes de esa fila.
   - Al cerrar inserta una fila amarilla **"SALIDA DE CARGA"** con totales (bruto, neto, sacos, dinero, número de productores, hora) y el número de camión.
4. **Bloque de totales** desde la última salida: libras brutas, sacos, libras netas, efectivo, productores. También muestra facturas y dinero PXP/PENDIENTE de toda la temporada, y cuántos sacos faltan para 72 y para 140.

Hay 12 filas amarillas de salida/resumen en el archivo [CALCULADO: EXCEL]. El número de camión se escribe en la col N de cada compra (valores 1–24, con errores: fechas, montos como 30000, texto) [CALCULADO: EXCEL].

---

## 3. Salida y venta de café

### Venta [VERIFICADO: CUESTIONARIO p.21–26]

- Venden a exportadoras, beneficios y otros compradores ("todas las opciones").
- Venden **pergamino seco y pergamino húmedo**, en **quintales (qq) y libras**.
- Precio de venta: **por contrato**.
- Registran fecha, comprador, cantidad, precio, factura y transporte, en **remisiones**.
- Sí llevan control de lo que les deben (crédito).
- Sí necesitan saber el café en bodega en todo momento (inventario).

### Hoja SALIDA DE CAFE [VERIFICADO: EXCEL]

Columnas: `Nº CAMION, FECHA, NUMERO DE REMISION, TRANSPORTISTA, LBS BRUTO, SACOS, LBS NETAS, SALIDA/ENTRADA`.

- 24 viajes (16-nov-2025 a 20-dic-2025). Remisión y transportista solo están llenos en 3 filas (remisiones 329–331, transportista "RONALDO (IZUZU)").
- `SACOS = LBS BRUTO / 160` (23 de 24 filas) [CALCULADO: EXCEL]. `LBS NETAS` son valores fijos; no comprobé cómo se obtienen (≈ 0.475–0.487 del bruto) → [DESCONOCIDO]. Por qué aquí 160 y en compras 165 → [DESCONOCIDO].

La hoja VIAJES DE CAMIONES tiene 1 fila (viaje 24, igual a la última de SALIDA DE CAFE) [VERIFICADO: EXCEL]. Parece duplicada o abandonada → [DESCONOCIDO].

### Hoja PESO CLIENTE (notas de peso del exportador) [VERIFICADO: EXCEL]

Columnas: `No CAMION, FECHA, No NOTA DE PESO, ID_SALDO_PESO, CLIENTE/EXPORTADOR, LBS_BRUTAS_CLIENTE, SACOS_CLIENTE, LBS_NETAS_CLIENTE, LBS_APLICADAS_TOTAL, SALDO_DISPONIBLE_LBS, OBSERVACIONES`.

- Cliente de ejemplo: **SOGIMEX S.A.** (exportador). Notas de peso con formato `EPNP43275`. ID interno `SP-AAMMDD-NNNN`.
- Un camión puede tener varias notas de peso.
- `LBS_NETAS_CLIENTE = LBS_BRUTAS_CLIENTE × 0.49` en todas las filas [CALCULADO: EXCEL].
- `SALDO_DISPONIBLE = NETAS − APLICADAS` (libras de la nota aún no asignadas a un contrato).

### Hoja CONTRATOS [VERIFICADO: EXCEL]

Columnas: `ID_CONTRATO, CLIENTE_EXPORTADOR, PRECIO_POR_LB, QUINTALES_CONTRATADOS, LIBRAS_NETAS_CONTRATADAS, NUMERO_REMISION, NUMERO_CAMION, ID_SALDO_PESO, NUMERO_NOTA_PESO, LBS_NETAS_CLIENTE, LIBRAS_APLICADAS_CONTRATO, LBS_NETAS_ACUMULADAS, LIBRAS_NETAS_RESTANTES, VALOR_APLICADO, ESTADO_CONTRATO, OBSERVACIONES_APLICADAS`.

Lógica que se ve en los datos [CALCULADO: EXCEL]:
- **1 qq = 100 lb** (60 qq → 6,000 lb; 150 qq → 15,000 lb).
- Las libras netas de las notas de peso se **aplican a contratos en orden**. Cuando un contrato se llena, el sobrante de la nota pasa al siguiente. Ejemplo: la nota `EPNP432` (5,272.89 lb) aporta 1,647.33 lb al contrato CON-20251217-001 (lo cierra en 6,000) y 3,625.56 lb al contrato 1072.
- `VALOR_APLICADO = LIBRAS_APLICADAS × PRECIO_POR_LB` (ej. 4,352.67 × 63 = 274,218.21).
- `LIBRAS_NETAS_RESTANTES = contratadas − acumuladas`. `ESTADO_CONTRATO` pasa de ABIERTO a CERRADO al llegar a 0.
- Precios de contrato vistos: 63 y 62.5 por lb.
- Una fila por aplicación: el contrato se repite en varias filas (a veces con ID vacío). El formato del ID no es uniforme ("CON-20251217-001" y "1072").
- Si el precio es en Lempiras o en dólares → [DESCONOCIDO] (no hay símbolo).
- Cómo se cobra el contrato, plazos, anticipos del exportador → [DESCONOCIDO].

### Relación compra → camión → nota de peso → contrato (según el Excel)

```
Compras (INGRESO DE CAFE, col N = Nº camión)
   └─► Salida / camión (SALIDA DE CAFE, Nº CAMION)
          └─► Nota(s) de peso del exportador (PESO CLIENTE, No CAMION)
                 └─► aplicación de libras a Contrato(s) (CONTRATOS, ID_SALDO_PESO)
```
Enlaces por número de camión e `ID_SALDO_PESO` [VERIFICADO: EXCEL]. Si este es el flujo completo en la práctica → confirmar con el cliente.

---

## 4. Fincas propias [VERIFICADO: CUESTIONARIO p.27–30]

- Tienen varias fincas propias. Cuántas y dónde → [DESCONOCIDO].
- Quieren controlar de cada finca: área, lotes, producción, gastos y trabajadores ("todas las opciones").
- Personal: ingenieros, capataz, trabajadores.
- Pago: efectivo; por día, **por lata (pago semanal)** y por tareas.
- El Excel **no tiene datos de fincas** [VERIFICADO: EXCEL]. Tarifas por lata o por día → [DESCONOCIDO].

## 5. Planilla (personal de bodega) [VERIFICADO: EXCEL, hoja PLANILLA]

Columnas: `EMPLEADO, CARGO, SALARIO BASE, días 1..31 (marca "X"), TOTAL QZ DIAS, ANTICIPOS QZ, TOTAL MES`.

- Cargos: C.E.O, administración, chofer, cargador, bodeguero, "trabajadora DMC", "carg. bodega".
- Solo tiene marcados los días 1–16: es una **quincena** aunque la columna dice "TOTAL MES".
- Regla que coincide en 14 de 15 filas [CALCULADO: EXCEL]:
  ```
  pago_quincena = SALARIO_BASE / 30 × días_trabajados − ANTICIPOS_QZ
  ```
  (ej. 15,000 / 30 × 12 − 1,500 = 4,500). La fila de "NAHUM" no resta el anticipo (probable error).
- Es personal de la bodega/compra, distinto de los trabajadores de finca de la sección 4.

## 6. Préstamos [VERIFICADO: CUESTIONARIO p.31–34]

- Prestan a **productores e intermediarios**.
- Cobran **interés simple**. Tasa, periodo (mensual/anual) y base de cálculo → [DESCONOCIDO].
- Se pagan **con café** (descontando de las compras).
- Quieren ver por préstamo: fecha inicial, saldo, interés, pagos hechos, fecha límite.
- No hay datos de préstamos en el Excel [VERIFICADO: EXCEL].

## 7. Reportes [VERIFICADO: CUESTIONARIO p.35–38]

- El dueño revisa "todos": café comprado en el día, dinero pagado, café en bodega y ganancias.
- Entregan informes al **contador** y al **SAR** (autoridad tributaria de Honduras). Formato requerido → [DESCONOCIDO].
- Necesitan **exportar a Excel**.
- Reportes que ya existen (en el Excel): cierre diario y totales desde la última salida (ver sección 2). Reportes a mano → no respondieron (p.36).

---

## 8. Hojas del Excel sin propósito claro

- **Hoja1**: 92 filas de compras del 2 al 4 de enero de 2026 (mismas columnas de compra, valores fijos sin fórmulas) y una columna M con números sueltos que suman 58.53. Propósito → [DESCONOCIDO].
- **Hoja2**: vacía.

---

## 9. Preguntas pendientes para el cliente (bloquean decisiones)

1. ¿Cambia el cálculo según compren **uva, pergamino húmedo o seco**? ¿Qué humedad o factor aplica a cada uno?
2. ¿El **51%** es humedad medida por muestra o un factor fijo? ¿Quién decide cuándo es 52–57%?
3. ¿Se sigue descontando **daño**? ¿Cómo se mide?
4. **Tabla de precios**: ¿cómo se combinan zona + calidad + bolsa? ¿Qué zonas y categorías de calidad existen?
5. **Retención de fin de temporada**: ¿qué porcentaje, sobre qué monto, y a quién se reporta?
6. **Préstamos/adelantos**: tasa de interés, periodo, y cómo se descuenta de cada compra (¿todo el saldo o un abono?).
7. ¿La factura siempre agrupa **hasta 4 compras**? ¿Por qué?
8. ¿Por qué **160** lb/saco en salidas y **165** en compras?
9. **Contratos**: ¿precio en Lempiras o dólares? ¿Cómo y cuándo paga el exportador?
10. ¿La hoja ANTICIPOS es para anticipos del exportador o para anticipos a productores?
11. Qué quieren ver primero en la demo (respondieron "¿?"). *Sugerencia basada en lo que más usan: registro de compra con cálculo automático + recibo imprimible + cierre diario.* (Es una sugerencia, no un requisito del cliente.)
12. Logo y colores (dijeron que tienen; no los enviaron).
13. ¿Qué reporte exacto piden el contador y el SAR?
14. Formato del recibo: foto de uno impreso.

---

## 10. Datos sensibles

El Excel contiene nombres reales de productores, RTN y teléfonos. Este documento no los reproduce. Para datos de prueba o semillas, **usar nombres ficticios**; no copiar el histórico real a repos ni a fixtures.
