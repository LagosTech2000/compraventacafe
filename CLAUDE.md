# compraventacafe

Software a medida de compra y venta de café para "Compra de Café el Rey David".
Herramienta interna, unos 10 usuarios, UI 100% en español.

## Reglas de trabajo (no negociables)

1. **No se inventan reglas de negocio.** Lo que falte se deja como punto abierto
   y se pregunta. Ver "Puntos abiertos" abajo.
2. **Nada que dependa de un punto abierto se construye.** Se pregunta o se
   detiene el trabajo.
3. **El código se escribe en inglés; la interfaz, solo en español** vía i18n.
   Ningún nombre de clase, tabla, columna o ruta lleva español.
4. **Sin secretos en el repositorio.** En desarrollo, PostgreSQL conecta por
   socket Unix con autenticación peer. En producción, variables de entorno.
5. **Cada commit se notifica a Fernando**: mostrar el mensaje completo del
   commit (título y cuerpo, con su hash) y una descripción corta de lo que
   cambia. Los mensajes de commit **no llevan** la línea `Co-Authored-By`.
6. **El desarrollo ocurre dentro de WSL (Ubuntu)**, en `~/code/compraventacafe`,
   nunca en `/mnt/c` ni en OneDrive. Sin Docker.

## Fuentes de verdad

| Documento | Qué define | Dónde |
| --- | --- | --- |
| Contexto técnico — Sistema de café | Decisiones técnicas, versiones y puntos abiertos | `claude.ai/code/artifact/6e691138-7661-4021-b95d-90f906d32172` |
| `docs/2026-09-27/CONTEXTO_CAFE_REY_DAVID.md` | Negocio: cuestionario del cliente + su Excel `COSECHA_2026L.xlsm`. Cada dato etiquetado `[VERIFICADO]`, `[CALCULADO]` o `[DESCONOCIDO]` | Solo local. **No se construye sobre un `[DESCONOCIDO]`.** |
| `docs/2026-09-26/PREGUNTAS_CLIENTE.md` | Primer cuestionario (ya respondido; sus respuestas están en el contexto) | Solo local |
| `docs/2026-09-28/PREGUNTAS_PRESTAMOS.md` | Preguntas de préstamos y pago con café (pendientes de respuesta) | Solo local |
| `docs/2026-09-28/PREGUNTAS_COMPRAVENTA.md` | Preguntas pendientes de compra y venta: quintal oro, cálculo por estado, calidad, precio, retención, salidas, contratos (pendientes de respuesta) | Solo local |
| `docs/2026-09-26/AMBIENTE.md` | Cómo montar y operar el ambiente | Solo local |

`docs/` se organiza en carpetas `AAAA-MM-DD` por **fecha de creación** del
archivo: la carpeta más reciente tiene lo más nuevo. Un documento nuevo va en
la carpeta del día en que se crea; al editarlo después, no se mueve.
**`docs/` es solo local**: está en `.gitignore` y nunca se sube a GitHub (el
repositorio es público y ahí va información del negocio del cliente).

El doc técnico etiqueta cada afirmación: `[CONFIRMADO]` (decidido por el dueño),
`[VERIFICADO: fuente]`, `[RECOMENDADO]`, `[RESUELTO]`, `[ABIERTO]`.

## Stack

| Pieza | Decisión |
| --- | --- |
| Framework | Rails 8.1.x |
| Ruby | 3.4.x — ver `.ruby-version` (Render lo lee) |
| Base de datos | PostgreSQL 18, igual en local y en Render |
| Frontend | Hotwire + vistas ERB |
| CSS | Tailwind (`tailwindcss-rails`, binario standalone, sin Node) |
| Autorización | Pundit |
| Autenticación | Generador nativo de Rails 8. **No Devise.** |
| Tests | RSpec (`rspec-rails`), `factory_bot_rails`, `pundit-matchers`; system specs con Capybara + Cuprite (Chrome sin ventana); `bullet` (consultas por fila) |
| Tareas en segundo plano | Sin Solid Queue/Cache/Cable. Las actualizaciones en vivo usan Action Cable con el adaptador `async` (en el mismo proceso: una instancia, un proceso de Puma) |
| Gráficos | Chart.js 4.4.7, build UMD oficial en `vendor/javascript/chart.umd.min.js` (importmap, sin Node) |
| Hosting | Render, plan de pago |
| Repositorio | `github.com/LagosTech2000/compraventacafe` |

## Glosario español ↔ inglés

El único lugar donde vive el español es `config/locales/es.yml`.

| Doc / UI (español) | Código (inglés) |
| --- | --- |
| Usuario del sistema | `User` |
| Persona | `Person` |
| Cliente | `Client` |
| Colaborador | `Collaborator` |
| Permiso | `Permission` |
| Módulo | `AppModule` (`Module` es palabra reservada de Ruby) |
| Ver / crear / editar / borrar | `read` / `create` / `update` / `destroy` |
| Administración | `administration` |
| Compra de café | `trading` |
| Fincas | `farms` |
| Préstamos | `loans` |
| Reportería | `reports` |
| Productor / intermediario / finca propia | `Producer` (`kind`: `producer` / `intermediary` / `own_farm`) |
| Carrero (rol de persona: trae el café con los carros del negocio y gana comisión) / pago a carrero | `Hauler` / `HaulerPayment` (`trading/hauler_payments#show` = recibo) |
| Precio por libra neta del carrero / comisión del carrero | `Hauler#price_per_pound`; en la compra `hauler_price_per_pound`, `hauler_commission` (las de antes del 2026-10-24: `hauler_cans`, `hauler_can_price`, `hauler_commission_percent`, `Hauler::CAN_POUNDS`) |
| Tipo de daño (amarillo, broca, verde, pulpa, pelado) | `Purchase#damage_types` (`Purchase::DAMAGE_TYPES`: `yellow` / `borer` / `green` / `pulp` / `peeled`) |
| Préstamo tipo intermediario (10 días sin interés, para cualquiera) | `Loan#interest_grace` (`Loan::GRACE_DAYS`, `Loan#interest_starts_on`) |
| Tarea por monto fijo / por manzana / por barril / por abono | `PayrollTask#pricing`: `fixed` / `per_manzana` / `per_barrel` / `per_fertilizer` (`quantity`, `unit_price`, `barrel_liters`, `quantity_unit`) |
| Clave del IHCAFE (Instituto Hondureño del Café) | `Producer#ihcafe_code` |
| Ficha / resumen del productor | `ProducerProfile` |
| Zona | `Zone` |
| Compra (pesada) | `Purchase` |
| Uva / pergamino húmedo / pergamino seco | `cherry` / `wet_parchment` / `dry_parchment` |
| Humedad / daño / rendimiento | `humidity_percent` / `damage_percent` / `yield_factor` |
| Quintales (QQ) | `quintals` |
| Temporada | `Season` (`season_year` en la compra) |
| Compra anulada | `voided` (`voided_at`, `voided_by`) |
| Factura (recibo al productor) | `Invoice` |
| Cancelada / pago parcial / pendiente de pago (PXP) | `paid` / `partial` / `pending` (`Invoice::PAYMENT_STATUSES`; filtro `unpaid` = pendiente o parcial) |
| Abono a factura (pago al productor) / recibo de pago | `InvoicePayment` / `trading/invoice_payments#show` |
| Cierre diario | `DailyClose` |
| Préstamo / abono | `Loan` / `LoanPayment` |
| Insumo / insumo del préstamo | `Supply` / `LoanSupply` |
| Préstamo en efectivo / en insumos / mixto | `Loan#kind`: `cash` / `supplies` / `mixed` |
| Pago con café (abonar préstamos con una compra) | `PurchaseLoanSettlement`; abono con `payment_method: "coffee"` |
| Estado de cuenta / historial crediticio | `CreditAccount` |
| Score de pago | `PayerScore` |
| Recibo de abono | `loans/payments#show` (`LoanPayment#display_number`) |
| Finca (del negocio o de un productor) | `Farm` (`producer_id` vacío = del negocio) |
| Extensión territorial (manzanas / hectáreas / m²) | `Farm#area_value` + `area_unit` (`manzana` / `hectare` / `square_meter`), `FarmArea` |
| Cifras de la finca (café vendido, corte, rendimiento) | `FarmProfile`; reporte `FarmsReport` («Rendimiento de fincas») |
| Horas extra / días extra / valor de la hora extra | `PayrollOvertime` (`hours`, `extra_days`, por período) / `Payroll#overtime_hour_rate` |
| Fusionar personas | `PersonMerge` (`administration/person_merges`), acción de auditoría `merge` |
| Planilla (por día / por obra o tarea / corte por lata) | `Payroll` (`kind`: `daily` / `task` / `harvest`) |
| Rol de planilla / salario por día / salario propio | `PayrollRole` / `daily_wage` / `PayrollMember#daily_wage_override` |
| Empleado de planilla | `PayrollMember` (una `Person` con rol `Collaborator`) |
| Asistencia (día completo / medio día) | `PayrollAttendance` (`day_fraction` 1 / 0.5) |
| Latas cortadas / precio de la lata | `HarvestEntry` (`cans`) / `Payroll#can_price` |
| Caporal (en corte: no corta, salario por día) | `PayrollMember#paid_by_day?` (tiene rol o salario propio) |
| Tarea (obra) / participante | `PayrollTask` / `PayrollTaskParticipant` |
| Semanal / quincenal / mensual | `pay_frequency`: `weekly` / `biweekly` / `monthly` (`PayPeriod`) |
| Pago de planilla / planilla de pago | `PayrollPayment` + `PayrollPaymentLine` (`PayrollPaymentIssuer`) |
| Descuento de planilla (abono a préstamo) | `LoanPayment` con `payment_method: "payroll"` |
| Gasto de planilla / categoría de gasto | `PayrollExpense` / `ExpenseCategory` |
| Reporte / reporte sugerido / filtro guardado ("Mis filtros") | `Report` (`app/reports/`) / `ReportPreset` / `SavedReport` |
| Período del reporte (hoy, este mes, temporada…) | `ReportPeriod` |
| Cifras del reporte / agrupar por | `Report.kpi` / `Report.group` |
| Plazo del préstamo (días) | `Loan#term_days` (no se guarda: sale de las fechas) |
| Datos que le faltan al productor / a la persona / a la finca | `Producer#missing_fields` / `Person#missing_fields` / `Farm#missing_fields` |
| Buscador al escribir (productor, persona, colaborador) | `PickerSearch` (`picker_searches#show`, `record_picker_controller.js`) |
| Ficha del productor en «Nueva compra» | `trading/producer_cards#show` |
| Etapas del préstamo (entregado, con abonos, pagado) | `LoanLifecycle` (`LifecycleSteps`, `shared/_lifecycle`) |
| Versión de los datos (caché de reportes) | `DataVersion` |
| Límite de solicitudes (auditoría) | acción `rate_limited` (`RateLimitAudit`) |
| Mi configuración (datos, foto, contraseña, ventana o panel lateral, menú arriba o a la izquierda, huellas) | `UserSettingsController`; `User#window_style` (`modal` / `drawer`), `User#nav_position` (`top` / `left`) |
| Usuarios conectados / páginas recientes de un usuario | `Presence` + `PresenceChannel` / `PageVisit` |
| Café en la bolsa | `CoffeeMarket` (`coffee_markets#show`) |
| Foto de perfil (persona o usuario) | `ProfilePhoto` (`HasPhoto`) |
| Ubicación en el mapa | `latitude` / `longitude` (`HasAddress#located?`) |
| Huella digital (passkey) / entrar con huella | `WebauthnCredential` / `PasskeySessionsController` |
| Documentos privados (pagaré / contrato privado de préstamo) | `PrivateDocument` (`key`: `promissory_note` / `loan_contract`) |
| Variable de un documento / impresión de un documento | `PrivateDocumentVariables` (`<span data-variable="person.full_name">`) / `PrivateDocumentPrint` |
| Estado civil / nacionalidad | `Person#civil_status` / `Person#nationality` |
| Número en letras | `NumberWords` (palabras en `es.yml`, `number_words`) |
| Comercialización | `sales` |
| Comprador (exportador / beneficio / otro) | `Buyer` (`kind`: `exporter` / `processor` / `other`) |
| Salida de camión / báscula local / báscula del comprador | `Shipment` / `origin_*` / `destination_*` (`ArrivalsController`, `shipments/:id/arrival`) |
| Nota de peso / remisión | `Shipment#weight_note_number` / `remission_number` |
| Transportista / camión / motorista de la salida | `Carrier` / `Truck` (`own`: del negocio) / `Shipment#driver` (un `StaffMember`) o `driver_name` |
| Pesadas de la salida (báscula local) | `ShipmentWeighing` (`Shipment#origin_weight_mode`: `single` / `weighings`) |
| En camino / pesada sin vender / vendida | `Shipment#status`: `in_transit` / `received` / `sold` (+ `voided`) |
| Venta / salida vendida / cobro de venta | `Sale` / `SaleLine` / `SalePayment` (`SaleIssuer`) |
| Precio por libra / por quintal (100 lb) | `Sale#price_unit`: `pound` / `quintal` (`Sale::QUINTAL_POUNDS`) |
| Tolerancia de diferencia de peso | `SiteSetting#weight_tolerance_percent` (`WeightTolerance`) |
| Inventario / kárdex | `CoffeeStock` / `StockLedger` (`sales/stock#show`), reporte `CoffeeStockReport` |
| Cierre de comercialización | `SalesDailyClose` |
| Control financiero | `finance` |
| Cuenta (caja / banco) / saldo de la cuenta | `MoneyAccount` (`kind`: `cash` / `bank`, `default_for`) / `AccountBalance` |
| Banco de la cuenta / tarjeta de la cuenta | `MoneyAccount#bank_key` (`HondurasBank`, `db/data/honduras_banks.yml`, `other`) / `finance/money_accounts/_card` (arte en `_card_art`, SVG; `BankCardHelper`), `.bank-card-*` |
| Gasto / inversión / comprobante | `Expense` (`kind`: `expense` / `investment`) / `ExpenseReceipt` |
| Categoría financiera (dos niveles) | `FinanceCategory` (`parent`) |
| Otro ingreso / transferencia entre cuentas | `OtherIncome` / `AccountTransfer` |
| Presupuesto mensual | `Budget` / `BudgetSheet` |
| Movimientos de dinero (libro único) | `MoneyMovements` (`MovementFilter`, `finance/movements`) |
| Consolidación (dar cuenta a lo registrado sin cuenta) | `AccountConsolidation` (`finance/consolidation`, `ConsolidationFilter`) |
| Cuenta de un pago de cualquier módulo | `money_account_id` (`HasMoneyAccount`) |
| Ingresos (todo lo que entró) | `finance/incomes` (`IncomeFilter`) |
| Planilla interna / rol / empleado | `StaffMember` / `StaffRole` (`salary`, `pay_frequency`, `overtime_hour_rate`) |
| Pago de un período / anticipo / meta con bono | `StaffPayment` (`StaffPaymentIssuer`, `finance/staff_payments#show` = recibo) / `StaffAdvance` / `StaffGoal` (`met`) |
| Asistencia de la planilla interna / hoja de planilla (quincena, mes, acumulado) | `StaffAttendance` (`day_fraction` 1 / 0.5) / `StaffSheet` (`finance/staff_sheet`, `staff_sheet_controller.js`) |

## Modelo de permisos

No hay roles fijos: cada usuario recibe, **por módulo**, permisos separados de
ver, crear, editar y borrar.

- `AppModule::KEYS` y `AppModule::ACTIONS` son la lista canónica de módulos y
  acciones. Su orden es el de todos los menús, las tarjetas del Inicio y
  las pantallas de permisos: **Administración va al final** (Fernando,
  2026-10-13). Agregar un módulo = una clave ahí + una entrada en `es.yml` + su
  namespace de controladores. Nada más.
- `Permission` es una fila por `(user, module_key)` con cuatro banderas
  booleanas. Índice único en `[user_id, module_key]`.
- `User#can?(module_key, action)` es el único punto de decisión.
- `User#admin` da acceso completo y es quien administra usuarios.
- Las políticas de Pundit heredan de `ApplicationPolicy`, declaran su
  `module_key` y delegan todo a `User#can?`. No metas lógica de permisos en
  controladores ni vistas: pregunta a la política.
- `ApplicationController` tiene `after_action :verify_authorized`: una acción
  que olvide autorizar **falla**. Eso es intencional.

### Reglas de usuarios

- Solo un administrador crea usuarios. **No existe registro público**, y hay un
  spec que lo verifica.
- Los usuarios se **desactivan, nunca se borran** (conserva el rastro de sus
  registros). Un usuario inactivo no puede iniciar sesión ni continuar una
  sesión abierta.
- **No se puede desactivar ni quitar `admin` al último administrador activo.**
  Validación en `User`, con mensaje en español.
- La recuperación de contraseña la hace un administrador desde el panel
  (`reset_password`). El flujo por correo del generador de Rails está
  **desconectado del `routes.rb`** porque no hay servicio de correo; los
  archivos se conservan con un comentario.

## Entidades núcleo

`Person` guarda identidad y contacto una sola vez. `Client` y `Collaborator` son
roles encima de `Person`, en tablas separadas, para que una misma persona pueda
ser ambas cosas a la vez y para que cada rol crezca con sus propios campos
cuando su módulo lo pida.

`User` (quien inicia sesión) es **una entidad aparte** de `Person`. No hay
relación entre ambas.

Campos de `Person` [CONFIRMADO]: `first_names` (Nombres), `last_names`
(Apellidos), `dni`, `rtn`, `phone`, `email`, `zone` (Zona), dirección
(`HasAddress`, con ubicación opcional en el mapa), foto de perfil
opcional (`HasPhoto`, 2026-10-13) y estado civil y nacionalidad
opcionales (`civil_status`, `nationality`, texto con el formato de los
nombres; Fernando, 2026-10-22: los pide el contrato de préstamo; se eligen
dato por dato al fusionar personas). Solo los nombres y apellidos son obligatorios. El resto se
agrega con migraciones cuando cada módulo lo pida.

**Zona de la persona** (Fernando, 2026-10-12: «que aparezca la zona de
donde es siempre, en todos los formularios»): vive en `people.zone_id`,
opcional, y sale en `shared/_person_fields` (todo formulario de persona,
con «Nueva zona»). La zona del productor **es la de su persona**
(`Producer has_one :zone, through: :person`; la migración
`MoveZoneToPeople` la pasó de `producers`). La compra sigue guardando su
propia zona.

**Roles en el formulario** (Fernando, 2026-10-12): todo formulario de
persona lleva una casilla por rol, Cliente, Colaborador y **Productor**
(`shared/_person_roles`), y **hay que marcar al menos uno**
(`Person#role_chosen`, solo cuando el formulario manda los roles; el
navegador avisa antes con `person_roles_controller.js`). Las casillas son
atributos de `Person` (`client_role=`, `collaborator_role=`,
`producer_role=` y `producer_kind` para un productor nuevo). Agregar o
quitar el rol de productor pide crear en `trading`; no se quita a quien
tiene compras, facturas o fincas. En el formulario del productor la casilla
«Productor» va marcada y fija.

**`dni` tiene 13 dígitos y `rtn` 14, solo números** [CONFIRMADO], y cada uno es **único por
persona** (validación + índice único parcial). Se aceptan con guiones o
espacios y se guardan solo los dígitos. **Ninguno es obligatorio**
[CONFIRMADO]: pueden quedar en blanco.

Los roles se asignan con casillas en el formulario de la persona. Las pantallas
de personas, clientes y colaboradores viven en el módulo `administration` y usan
sus permisos (`PersonPolicy`).

**Administración amplía** (Fernando, 2026-10-14), con los permisos de
Administración (no los de cada módulo):
- **Fincas** (`administration/farms`, `Administration::FarmPolicy`) y
  **Zonas** (`administration/zones`, `Administration::ZonePolicy`): listas,
  detalle, crear, editar y borrar **solo lo que nada usa** (una finca con
  compras o planillas se desactiva; una zona con personas o compras se
  queda). Reusan los formularios de Fincas y Compra de café (`namespace:`).
- El detalle de una persona productora muestra **su ficha de productor**
  (tipo, clave IHCAFE, QQ, compras, facturas y sus fincas) y «Editar
  productor» (`administration/producers#edit`, el formulario del
  productor, `Administration::ProducerPolicy`).
- **Fusionar personas** (`PersonMerge`, `administration/person_merges`,
  **solo administradores**: no se deshace): para la misma persona
  registrada dos veces. Se elige a la otra y cuál queda; después, **dato
  por dato**, qué valor se conserva (nombres, DNI, RTN, teléfono, correo,
  zona, dirección, ubicación, foto; tipo y clave IHCAFE si las dos son
  productoras). Por defecto queda el de la principal, salvo que solo la
  otra lo tenga. Todo lo de la otra pasa a la principal: roles, compras,
  facturas, fincas (**las del mismo nombre se juntan en una**: sus compras
  y planillas pasan a la que queda, que llena lo que le falte), préstamos y
  su lugar en planillas; luego la otra **se borra**. **No se fusionan dos
  personas de la misma planilla.** Todo o nada, y queda en la auditoría
  (acción `merge`, con lo que pasó y qué datos se tomaron de la otra).

## Convenciones de formularios (obligatorias)

**1. Los campos obvios se validan en el modelo y en el formulario.** Nombres,
DNI, RTN, teléfono y correo usan un formato de `FieldFormats`
(`app/models/field_formats.rb`):

```ruby
validates :dni, field_format: :dni                                    # modelo
form.text_field :dni, **field_format_attributes(Person, :dni, :dni)   # vista
```

El formulario lleva `data: { controller: "form-validation" }` para que el
navegador muestre los mensajes en español. Los mensajes viven en `es.yml` bajo
`errors.messages`. Formato nuevo = una entrada en `FieldFormats::REGISTRY` + su
mensaje. Reglas actuales:

| Campo | Regla | Se guarda |
| --- | --- | --- |
| Nombres / apellidos | Letras, espacios, `'`, `.`, `-` | Sin espacios repetidos |
| DNI | 13 dígitos | Solo dígitos (se aceptan guiones y espacios) |
| RTN | 14 dígitos | Solo dígitos |
| Clave IHCAFE | `XX-XX-XXXXX`, letras o números (9 + 2 guiones) | En mayúsculas y con guiones (se acepta sin guiones o con espacios) |
| Teléfono | 8 dígitos, `+504` opcional | Solo los 8 dígitos; se muestra `9999-0000` con `format_phone` |
| Correo | Formato de correo | En minúsculas |
| Contraseña | Mínimo 8 caracteres (máx. 72) al crearla o cambiarla; el login no la valida | Cifrada |

Todo campo de un modelo auditado tiene su nombre en `es.yml`
(`activerecord.attributes`), también los `*_id`: sale en etiquetas,
errores y la auditoría; sin él se ve el nombre en inglés («Buyer»).
`spec/models/attribute_names_spec.rb` lo revisa.

Un campo de confirmación usa `confirmation_attributes`: el navegador avisa si
no coincide antes de enviar.

**2. Toda dirección es departamento + municipio + dirección.** El modelo incluye
`HasAddress` (columnas `department_id`, `municipality_id`, `address_line`) y
el formulario renderiza `shared/address_fields`. Sin departamento, la lista de
municipios queda vacía y deshabilitada; al elegirlo se filtra
(`address_controller.js`). Se muestra con `format_address`.

Los 18 departamentos y 298 municipios viven en
`db/data/honduras_divisions.yml` (códigos del SAT, 2023) y se cargan con
`HondurasDivisions.load!` (idempotente), que corre en una migración, antes de
la suite de tests y con `bin/rails honduras_divisions:load` en
`bin/render-build.sh` y `bin/setup`. La migración sola no basta: en una base
nueva `db:migrate` carga `db/schema.rb` y se salta las migraciones. Son datos de referencia: los nombres de lugares son la única excepción
a "el español solo vive en `es.yml`".

**3. El usuario nunca ve una pantalla de error del servidor.** `ErrorHandling`
(incluido en `ApplicationController`) convierte cada error en una alerta en
español (`shared/_flash`, con `role="alert"` y botón para cerrarla).
Avisos y alertas salen como **toasts** abajo a la derecha, encima de la
página (`toast_controller.js`, Fernando, 2026-10-12): entran deslizándose,
se cierran con la ×, y un aviso se va solo a los 7 segundos (con barra de
tiempo; se pausa con el puntero o el foco encima). Viven en `#toasts`, al
final del `<body>` y siempre presente: una página que vuelve a sí misma
(morph tras un formulario) lo empareja por id; dibujados dentro de
`<main>`, el aviso se mezclaba con el encabezado (Fernando, 2026-10-25).
Una alerta de error se
queda hasta cerrarla, para no perder su código de referencia. Los toasts
están **siempre encima de modales y de la guía de ayuda**, y se pueden usar
ahí: son un popover (capa superior del navegador) que vive dentro del
diálogo abierto de más arriba (`toast_region_controller.js`), porque un
modal vuelve inerte lo que queda fuera de él.

| Error | Qué ve el usuario |
| --- | --- |
| Sin permiso, registro inexistente, formulario incompleto | Alerta y vuelve al inicio (páginas) o al formulario (envíos) |
| Página pedida en un formato que no tiene (bots que piden el login como JSON) | 406, no 500 |
| Formulario expirado (CSRF) | Alerta para recargar e intentar de nuevo |
| Error inesperado | Alerta genérica con un **código de referencia** |

- Nunca se muestra el mensaje ni la clase de la excepción. El error completo va
  al log y a `Rails.error` con el mismo código de referencia (los primeros 8
  caracteres del `request_id`).
- Los errores inesperados solo se convierten en alerta si
  `config.x.friendly_errors` está activo: sí en producción, no en desarrollo
  (el desarrollador ve la traza). Los specs lo activan donde lo prueban.
- Una página que falla no redirige a sí misma: se muestra `errors/show` dentro
  del layout. Si hasta eso falla, Rails sirve las páginas estáticas en español
  de `public/` (400, 404, 406, 422, 500).
- No agregues `rescue` en controladores para mostrar errores: agrega el caso
  en `ErrorHandling`.
- **Todo error queda en la auditoría** (`ErrorAudit`, acción `error`,
  Fernando 2026-10-12): usuario, ruta completa, método, pantalla
  (controlador#acción), código (400/403/404/422/500), error, mensaje, código
  de referencia, datos enviados (filtrados), de dónde venía, navegador y, en
  5xx, las líneas del código donde falló, en `audit_events.details`. Los de
  usuarios con sesión se guardan todos; de visitantes sin sesión solo los
  5xx (los bots que prueban direcciones no llenan la auditoría). Auditar
  nunca rompe la respuesta. Lo que no llega a un controlador (dirección
  inexistente, fallo en un middleware) pasa por `config.exceptions_app`,
  que lo audita y sirve la página estática en español de `public/`.
- **Dirección que no existe**: la ruta comodín al final de `routes.rb`
  (`ErrorsController#not_found`, que no tapa `/rails/...` ni las rutas que
  agregan las gemas después) la convierte en aviso en español «La página
  que buscas no existe», de vuelta al inicio y auditada, en todos los
  ambientes (también en desarrollo, en vez de la página de error de Rails).
- **Con la sesión iniciada**, la página de inicio de sesión lleva al inicio
  (`SessionsController#redirect_signed_in`). En los specs, `sign_in` cierra
  la sesión abierta antes de entrar con otro usuario.
- Un **502/503 de Render** (la app no respondió: despliegue, caída, memoria)
  lo sirve el proxy de Render: la app no puede cambiar esa página ni
  auditarla, porque la petición nunca le llega. Se reduce configurando el
  Health Check Path `/up` en Render.

**4. Todo cambio de datos queda auditado.** Un modelo nuevo con datos del
negocio incluye `Auditable` y se agrega a `AuditEvent::AUDITED_TYPES` (un spec
verifica que coincidan). Cada evento guarda usuario (y su correo como copia),
acción, registro (con un `audit_label` legible aunque el registro se borre),
campos antes/después, IP y `request_id` (el mismo del código de referencia de
los errores).

- Se escribe en la misma transacción que el cambio: si el cambio se revierte,
  el evento también.
- Solo se agrega: `AuditEvent#readonly?` impide modificar o borrar eventos.
- Nunca se guardan secretos: `Auditable::SENSITIVE_ATTRIBUTES` se registra
  como `[FILTERED]` ("(oculto)" en pantalla).
- Inicio, cierre e intentos fallidos de sesión se registran en
  `SessionsController`.
- La pantalla (Administración → Auditoría) es solo para administradores y
  filtra por fechas, usuario, acción, entidad y texto, en páginas de 50.
  Los bots bloqueados por buscar direcciones de ataque (`scanner_ban`) se
  siguen auditando, pero no salen salvo con «Mostrar bloqueos de bots»
  (`AuditEventFilter#show_bot_blocks`, Fernando 2026-10-14).

**5. Listas, detalles y ventanas.**

- **Modal reutilizable**: el layout tiene un `<dialog>` con el Turbo Frame
  `modal` (`ModalSupport`, `modal_controller.js`). Un enlace con
  `modal_link_to` / `detail_button` abre su página ahí; la página usa el layout
  `modal` sin navegación. `page_link_to` sale del modal a página completa.
  Los modales se apilan: un `modal_link_to` dentro de un modal abre el
  siguiente (`modal_2`, `modal_3`, `ModalSupport::MODAL_FRAMES`) encima, sin
  perder el de abajo (p. ej. "Nueva zona" desde "Nuevo productor").
  Un modal (y la guía de ayuda) se cierra al tocar el fondo **solo si el
  clic empieza y termina en el fondo**: seleccionar texto en un campo y
  soltar afuera no lo cierra ni pierde lo escrito (Fernando, 2026-10-12).
- Al guardar desde el modal, el controlador llama `close_modal_with`: cierra el
  modal y refresca la página de atrás con el aviso. Si el modal se abrió desde
  un campo (`picker=1`), en vez de refrescar emite un evento de ventana
  (`producer:created`, `zone:created`) y el campo agrega y selecciona la nueva
  opción, sin perder lo ya escrito en el formulario.
- En listas, el detalle se abre con el botón **"Detalle"** en el modal; nunca
  con el id o el nombre subrayado. **Un clic en cualquier parte de la fila**
  (o de su tarjeta) hace lo mismo que su botón (Fernando, 2026-10-12):
  `row_link_controller.js` en el `<body>` busca en la fila el enlace con
  `data-row-link` (`detail_button` ya lo trae; un «Abrir» lo agrega a
  mano) y deja en paz los controles propios de la fila. El botón se queda. Los botones "Cancelar" usan `cancel_button`
  (cierra el modal si está dentro de uno).
- **Toda lista tiene filtros y paginación**: una subclase de `ListFilter`
  (`field :q, :text`, `:date`, `:id`, `:choice`) + `render layout:
  "shared/filters"` con `filter_text_field` / `filter_date_field` /
  `filter_select` + `shared/pagination`. Los valores inválidos se ignoran.
  Dentro del bloque de filtros usa claves de traducción completas, no `t(".x")`.
- **Toda columna se ordena** (Fernando, 2026-10-13), salvo la de acciones.
  - **Listas por páginas** (las de `ListFilter`): ordena el servidor, sobre
    **toda** la lista filtrada. El filtro declara cada columna con `sorts`
    (SQL; `text(...)` para texto en orden español sin mayúsculas ni
    acentos, con ICU `es-x-icu` si la base lo tiene; `joins:` si hace
    falta; `ruby:` para valores calculados como el saldo de un préstamo,
    que carga todos los registros filtrados). Los encabezados usan
    `sort_th(label, :key, sorting)` (`TableSortHelper`): suben, bajan y
    vuelven al orden propio de la lista. `?sort=&dir=` viaja en
    `to_params` (página siguiente, etiquetas) y en campos ocultos con
    `form=` que dejan el orden al cambiar un filtro. Responden dentro del
    frame de la lista (`list_frame`, o el frame que ya tenía), sin
    recargar; en un modal no cambian la URL. Ordenar no es un filtro: no
    sale en las etiquetas. Lista nueva = su `sorts` + `sort_th`; un spec
    (`spec/requests/list_sorting_spec.rb`) recorre cada lista, cada
    columna y ambas direcciones.
  - **Tablas que muestran todas sus filas** (detalles, recibos de planilla,
    datos de un gráfico): ordena el navegador (`data-controller=
    "table-sort"`, `table_sort_controller.js`). Lee fechas `dd/mm/aaaa`,
    números y dinero; `data-sort-value` en la celda manda sobre el texto;
    `data-sort="false"` en el `th` lo deja fijo (la firma). Una tabla
    compartida (compras, facturas, préstamos, planillas) ordena en el
    servidor si recibe `sorting:` y en el navegador si no
    (`table_sort_data`).
  - Sin orden: formularios (permisos, asistencia), impresos (factura,
    cierre diario) y el mapa de calor de Reportería, que ya ordena a su
    manera.
- **Scroll infinito, nunca «Anterior / Siguiente»** (Fernando,
  2026-10-13): `shared/pagination` deja al final de la lista un ancla
  (`data-infinite-list-anchor`) con «Cargar más», que pide la página
  siguiente al acercarse a la pantalla (`infinite_list_controller.js`).
  Pide la misma URL con `page=N+1` (con `frame:`, solo ese frame) y agrega
  sus filas: el n-ésimo `tbody` o lista de `.data-card` antes del ancla,
  dentro de su padre, recibe las filas del n-ésimo de la página nueva. Una
  fila con un id que ya está en la página no se repite. Sin endpoint
  propio: la página normal sirve. Reportería sigue con su turbo stream.
- **Tablas que se ven completas**: se adaptan al ancho de su contenedor (sirve
  igual en página y en modal) con consultas de contenedor de Tailwind
  (`@container`, `@3xl:`…): en angosto, tarjetas (`.data-card`); en medio, las
  columnas clave; en ancho, todas. La columna de acciones usa `.cell-actions`
  (fija a la derecha, nunca se pierde al desplazar). Los detalles largos
  (observaciones) van solo en la pantalla de detalle.
- **Filtros en celular**: se pliegan si no hay ninguno activo
  (`collapsible_filters_controller.js`); "activo" = distinto del valor por
  defecto.
- **Orden**: toda lista muestra primero lo más reciente (`newest_first`,
  definido en `ApplicationRecord`; compras por fecha y hora de compra, facturas por
  número). Las listas desplegables y el buscador de productor, que sirven para
  elegir por nombre, se quedan en orden alfabético. Excepción: el cierre diario
  agrupa canceladas, luego pendientes de pago, luego sin facturar (más
  recientes primero dentro de cada grupo).
- **Guías de ayuda (`HelpGuide`)**: toda pantalla tiene un botón "?"
  (`help_guide_button`) que abre su guía en un panel lateral propio
  (`<dialog id="help-guide">`), distinto del modal y encima de él si ambos
  están abiertos. Va en la navegación, junto a la × del modal y en el login.
  El texto vive en `es.yml` bajo `help_guides.screens.<ruta del controlador>.<acción>`
  (`new`/`create`/`edit`/`update` usan `form`), con `title`, `summary`,
  `steps` y `tips` opcionales. **Pantalla nueva = su guía**: un spec falla si
  una ruta GET no la tiene. Procesos que cruzan pantallas van en
  `help_guides.processes` y se ponen con
  `help_guide_button HelpGuide.process(:nombre), label: true` donde ocurre
  el proceso (Fernando, 2026-10-18: en todos los módulos): etapas de la
  compra, abonos a factura, carreros, pago con café, interés y score del
  préstamo, pagar un período, corte por lata, varios roles y préstamos en
  planilla, fusionar personas y filtros guardados
  (`spec/requests/process_guides_spec.rb`). Las guías solo
  describen lo que el sistema ya hace; nunca reglas de negocio abiertas.
- **Ancho de página**: el contenido llega a `max-w-[96rem]` para
  aprovechar monitores anchos; `form_surface_class` limita los formularios
  cortos a `max-w-5xl` salvo que pidan otro ancho. Los formularios de
  trabajo diario (nueva compra, facturar compras) usan todo el ancho con
  una columna lateral fija a la derecha (`@container` + `@5xl:`), que deja
  a la vista el cálculo o el pago y el botón de guardar. Los detalles con
  datos al lado (pesadas, ficha del productor) usan una columna lateral en
  `xl`/`lg`.
- **Barra del módulo**: cada módulo tiene su `_nav` (también
  `administration/_nav`, con lo que el usuario puede ver), que empieza con
  `shared/module_title` (ícono + nombre). No hay encabezado grande aparte.
  Se distingue del menú principal (Fernando, 2026-10-12): el principal son
  píldoras en una barra flotante; la del módulo (`.subnav`) es una banda
  plana con **pestañas subrayadas** (la actual en negrita con línea
  gruesa), el nombre del módulo fijo a la izquierda al desplazar en el
  celular (`.subnav-title`) y su acción principal aparte al final
  (`.subnav-action`). **Más clara** (Fernando, 2026-10-25: «muy opaca»):
  la banda es una tarjeta clara con borde y sombra suave sobre el fondo,
  las pestañas en texto más oscuro y la actual con tinte café suave.
- **Consultas sin recargar la página** (Fernando, 2026-10-12): filtrar,
  ordenar una columna, agrupar, cambiar de período o de reporte y cargar
  más **nunca recargan la página**: responden dentro de su Turbo Frame, con
  `data-turbo-action="advance"` para que la URL (y el botón atrás) sigan la
  consulta. `shared/filters` recibe `frame:` para apuntar al frame en vez
  de `_top`. Las respuestas a un frame que no es modal usan el layout
  `turbo_rails/frame` (`ModalSupport`). `frame_scroll_controller.js`
  mantiene la posición mientras el frame se reemplaza, y lo que no cambia
  con la consulta se conserva con `data-turbo-permanent` (los gráficos al
  ordenar). Cada caso lleva un system spec que comprueba que el `<body>` no
  se reemplazó. Aplica a Reportería y a las listas de Compras y Facturas;
  es la regla para pantallas nuevas.
- **Listas con filtros en vivo** (Compras y Facturas, Fernando, 2026-10-12;
  **todas las listas con filtros**, Fernando, 2026-10-18: personas,
  usuarios, zonas, fincas, auditoría, productores, carreros, préstamos,
  estados de cuenta, insumos, categorías de gastos, planillas). Las listas
  sencillas ponen arriba de sus resultados `live_list_status(@filter,
  campo: opciones o lambda)`: cuántos hay (`ListFilter#total_count`, que
  cuenta lo filtrado tras `#results`) y una etiqueta por filtro activo (la
  búsqueda `q` sale como «Búsqueda: «…»»). `spec/system/live_lists_spec.rb`
  las recorre.
  `shared/filters` con `live: true` y `frame:`, dentro de un elemento con
  `live_filter_controller.js`. Sin botón «Filtrar»: listas, fechas y
  casillas aplican al cambiar; la búsqueda, 350 ms después de dejar de
  escribir. El formulario queda **fuera** del frame de resultados (no se
  pierde el foco ni lo que se escribe); dentro van `shared/filter_status`
  (cantidad, períodos rápidos `quick_periods` y etiquetas `filter_chips`
  con su × y «Limpiar todo»), el resumen y la tabla. Períodos y × cambian
  campos del formulario y lo envían: el formulario es la única verdad.
  `ListFilter#to_params` conserva un campo vaciado a propósito ("") para
  que la página siguiente no vuelva a su valor por defecto.
  El frame de resultados lleva **`target: "_top"`**: sus enlaces (abrir,
  asistencia, pagar) van a la página completa, y solo la paginación
  (`shared/pagination` con `frame:`, que pide solo el frame) y las
  etiquetas apuntan al frame con
  `data-turbo-frame`. Sin eso, un enlace a otra página da «Content missing».
- **Buscador al escribir** (Fernando, 2026-10-18: «que al escribir más de 3
  caracteres se muestre un dropdown con los resultados»): un campo que
  elige de una lista que crece (productor de la compra o dueño de la
  finca; persona del préstamo o de la fusión; colaborador de la planilla)
  **no carga la lista con el formulario**. `record_picker_controller.js`
  (con `shared/_record_picker_search` y `record_picker_data(:tipo,
  selected:, missing_message:)`) pide `picker_search/:kind?q=` (JSON,
  `PickerSearch`: 20 por vez, con «hay más») desde 3 caracteres, 250 ms
  después de dejar de escribir, y muestra los resultados debajo: clic, o
  flechas y Enter. Escribir o pegar la etiqueta completa la elige sola.
  Busca cada palabra en nombres y apellidos sin mayúsculas ni acentos, y
  números en DNI y RTN (`Person.picker_search`); productores también por
  clave IHCAFE. Cada resultado trae lo que el formulario usa
  (`PickerSearch.data`: zona, fincas, datos faltantes). Quién busca:
  `PickerSearchPolicy` (quien puede abrir un formulario que elige ese
  tipo). En los specs, `pick_record(campo, etiqueta)` espera a que quede
  elegido. Listas cortas (zonas, carreros, insumos) siguen siendo
  desplegables.
- **Ruta de navegación en todos los módulos** (Fernando, 2026-10-18, como
  en Fincas): `shared/_breadcrumbs` con `ModuleBreadcrumbsHelper` en los
  detalles a página completa: compra y factura van por su productor
  (Productores › productor › …), el préstamo por su estado de cuenta, cada
  recibo por lo que pagó, el carrero, la persona, el usuario y la finca de
  Administración. En el modal no sale (tiene «Atrás»).
  `spec/requests/breadcrumbs_spec.rb`.
- **Pestañas en los detalles** (`shared/_tabs` o `shared/_tab_bar` +
  `tab_panel`, `tabs_controller.js`, cambian sin pedir al servidor):
  estado de cuenta (préstamos / historial), carrero (compras / pagos) y
  persona (datos / productor / carrero). En papel salen todas.
- **Cambios sin guardar** (Fernando, 2026-10-18, como en la asistencia):
  Nueva compra, Nuevo préstamo, Facturar compras, Pagar período y la tarea
  llevan `unsaved-changes` (`unsaved_changes_actions`): con cambios, salir
  de la página **o cerrar la ventana** (×, fondo, Escape, «Atrás»;
  `modal_controller.js#mayLeave`, por `data-dirty`) pregunta antes.
  Refrescar la misma página (al guardar algo en el modal) no pregunta.
- **Fotos en las listas** de personas (personas, productores, préstamos,
  estados de cuenta, empleados de planilla): `with_avatar(person)`; las
  iniciales las dibuja el CSS (`.avatar-initials`), así el texto de la
  celda sigue siendo el nombre. Precarga `photo_info`.
- **Filtros**: los campos se acomodan por ancho (`auto-fill`, mínimo
  12rem) y el botón «Filtrar» va en la misma fila cuando cabe.
- **Listas desplegables**: nunca con la primera opción en blanco. Campo
  opcional: "Sin … asignado" (`shared.select.*`). Campo obligatorio: "Selecciona
  …". Filtro: "Todos".

## Comandos

```bash
sudo service postgresql start   # si systemd no está activo en WSL
bin/dev                         # servidor + Tailwind en watch
bundle exec rspec               # suite completa
bundle exec rspec spec/policies # solo políticas
bundle exec rspec spec/system   # pantallas con JavaScript (requiere Google Chrome en WSL)
bin/rails db:migrate
bin/rails db:seed               # requiere ADMIN_NAME, ADMIN_EMAIL y ADMIN_PASSWORD
bin/rails demo:seed             # datos ficticios para la demo (no en producción)
bin/rails demo:reports          # un año ficticio de operación (sep 2025 a hoy) para ver los reportes; tarda ~2 min
bin/prod-data-tolocal           # reemplaza la base local con los datos de producción (y aplica las migraciones locales); la URL vive solo en ~/.config/compraventacafe/production_database_url (chmod 600), nunca en el repo
bin/rubocop
bin/brakeman --no-pager
```

**Todo cambio lleva specs** (Fernando, 2026-10-12). Lo que pasa en pantalla
con JavaScript (controladores Stimulus) se prueba con un system spec en
`spec/system/` (`type: :system`, `sign_in_as(user)`, ver
`spec/support/system.rb`), incluidos casos como vaciar un campo. Chrome se
instala una vez en WSL; `BROWSER_PATH` apunta a otro si hace falta. El
concern de direcciones se llama `HasAddress` porque `Addressable` es una gema
que trae Capybara.

El primer administrador se crea con `db:seed` leyendo `ADMIN_NAME`,
`ADMIN_EMAIL` y `ADMIN_PASSWORD` del entorno. Nunca se escriben credenciales en el repo.

## Interfaz

- Responsive desde el inicio, en todas las pantallas.
- Estilo híbrido: *clay* (esquinas muy redondeadas, dos sombras) en navegación,
  tarjetas y botones; tablas y formularios de datos **planos**, porque el sistema
  maneja tablas de dinero, planillas y reportes.
- La paleta vive como tokens `@theme` en `app/assets/tailwind/application.css`.
  Es el único lugar a editar cuando se defina la paleta real; la actual es
  provisional. Tipografía: Inter, alojada en la app (`app/assets/fonts`), sin
  servicios externos.
- **Ícono del navegador** (provisional, un grano de café en el café de la
  paleta; Fernando 2026-10-14): `public/icon.svg` es el original y de él
  salen `icon.png` (512), `favicon.ico` (16/32/48) y
  `apple-touch-icon.png` / `apple-touch-icon-precomposed.png` (180, sin
  esquinas transparentes: iOS las redondea). Los navegadores piden estos
  nombres aunque la página no los enlace; si faltan, cada visita deja un
  404 en la auditoría (`spec/requests/icons_spec.rb`). Cuando llegue el
  logo del cliente, se reemplazan los cinco y se sube el `?v=` de sus
  enlaces en el layout (`public/` va con caché de un año).
- **Componentes de estilo** (úsalos en vez de repetir clases): `btn`,
  `btn-primary`, `btn-sm` (píldoras clay); `nav-pill` / `nav-pill-active`
  (vía `nav_link_class`; dentro de `.subnav` el activo va en tono suave);
  `glass` (encabezado fijo translúcido); `tile` (tarjeta que enlaza, con
  `shared/_tile` e `icon`); `stat` (cifras); `panel` (contenedor plano de
  tablas, detalles y filtros); `data-table`, `data-card`, `cell-actions`;
  `field-label`, `field-input`; `badge` + `badge-success` / `badge-danger` /
  `badge-neutral`; `empty-state`; `link`; `flash-notice` / `flash-alert`;
  `modal`; `toast` (avisos flotantes, en `shared/_flash`). Los mensajes
  dentro de la página (errores del formulario, avisos de contexto) siguen
  con `flash-notice` / `flash-alert`. Los formularios de página completa
  usan `form_surface_class`.
- Íconos: `icon(:nombre)` (`IconsHelper`), decorativos y ocultos a lectores
  de pantalla; el texto al lado lleva el significado.
- Impresión: `print:` oculta lo interactivo y las tablas se compactan en
  papel. **Original y copia siempre en hojas separadas** (factura, recibos
  de abono a factura, de abono a préstamo y de pago a carrero; Fernando,
  2026-10-16): la copia va en un contenedor con `print:break-before-page`,
  y `spec/requests/printables_spec.rb` lo revisa en cada uno. **Todo impreso
  empieza con `shared/_print_letterhead`** (logo, nombre y ubicación del
  negocio; a la derecha qué documento es, número, ORIGINAL/COPIA y estado):
  facturas, recibos de pago y de abono, planilla de pago, cierre diario,
  estado de cuenta y reportes. Reglas globales en `@media print`
  (`application.css`): nunca se imprimen botones, ayuda, etiquetas, toasts
  ni la barra de guardar; tarjetas y paneles planos con línea fina; las
  insignias llevan borde (se leen aunque el navegador no imprima fondos);
  `print-exact` conserva los colores del logo. Un spec revisa el
  encabezado en cada impreso (`spec/requests/printables_spec.rb`).
- `raise_on_missing_translations` está activo en desarrollo y test: una clave
  que falte en `es.yml` rompe la página o el spec.
- El nombre del negocio, su ubicación, su RTN y su logo se configuran en
  Administración → Configuración del sitio (`SiteSetting`, solo
  administradores) y se leen con `business_name`, `business_location`,
  `business_rtn` y `business_logo` (`SiteHelper`). El RTN es opcional (14
  dígitos, como el de una persona) y sale **solo en las facturas**, bajo el
  nombre y la ubicación (`shared/_print_letterhead` con `rtn: true`;
  Fernando, 2026-10-15). Mientras no se guarde, salen de
  `es.yml` (`negocio.*`). El logo se guarda en la base (no hay
  almacenamiento de archivos en el servidor), se sirve en `/site_logo`
  (público, por el inicio de sesión) y solo acepta PNG, JPG, WebP o GIF
  de hasta 1 MB, revisados por su contenido; SVG no.
- Locale `:es` únicamente. Zona horaria `America/Tegucigalpa`.

## Módulos

| Clave | Estado |
| --- | --- |
| `administration` | Usuarios y permisos, auditoría, configuración del sitio y documentos privados (solo administradores); respaldo de datos (solo el usuario con id 1); personas, clientes y colaboradores, con su ficha de productor; fincas y zonas (permisos del módulo); fusionar personas (solo administradores) |
| `sales` | Comercialización: salidas de camiones con báscula local y del comprador, ventas por libra o quintal de 100 lb con cobros por abonos, compradores, inventario por estado del café con kárdex y cierre diario |
| `finance` | Control financiero: cuentas (caja y bancos) con saldo y estado de cuenta, ingresos, gastos e inversiones con categoría de dos niveles y comprobante, otros ingresos, transferencias, presupuesto mensual, la planilla interna del negocio (roles, anticipos, horas extra, metas y bonos) y el libro único de movimientos de todos los módulos |
| `trading` | Demo: zonas, productores (con pestañas y QQ por temporada), carreros con su comisión y pagos con recibo, compras con cálculo por estado del café y anulación, facturas imprimibles (original y copia) con estado de pago, cierre diario |
| `farms` | Fincas, planillas por día, por obra y de corte por lata, con roles y salarios, asistencia o latas por día, pagos por período (semanal, quincenal, mensual) con descuento a préstamos, planilla de pago imprimible y gastos por planilla |
| `loans` | Préstamos en efectivo, insumos o mixtos a cualquier persona con interés simple, catálogo de insumos, abonos (también con café desde una compra o descontados en planilla) con recibo imprimible, estados de cuenta con historial crediticio y score de pago |
| `reports` | Una pantalla para todos los reportes del sistema (compras, facturas, productores, préstamos, abonos, insumos, planillas, pagos por empleado, latas, gastos, rendimiento de fincas, personas y entradas/salidas de dinero) con filtros, cifras comparadas, gráficos, tabla con carga continua, reportes sugeridos, filtros guardados por usuario y exportación CSV |

## Seguridad y carga (Fernando, 2026-10-12)

- **Límite por IP delante de la app** (`rack-attack`,
  `config/initializers/rack_attack.rb`): 3,000 solicitudes por 5 minutos por
  IP (alto: la oficina sale por una sola IP de Starlink; no cuentan assets,
  logo ni `/up`), y una IP que pide direcciones de ataque (`/wp-admin`,
  `.env`, `.php`…) 3 veces en 10 minutos queda bloqueada 1 hora. Responde
  429 con `public/429.html` en español. En los tests está apagado;
  `with_rack_attack` lo enciende (`spec/support/rate_limits.rb`).
  **Sin precarga al pasar el puntero** (Fernando, 2026-10-15: salía mucho
  el 429): `<meta name="turbo-prefetch" content="false">` en el layout,
  porque Turbo 8 pedía cada enlace sobre el que se detenía el puntero, y
  toda la oficina comparte el límite. **Carga al presionar** (Fernando,
  2026-10-18: que siempre se sienta rápida): `instant_click.js` enciende
  esa precarga solo para el enlace sobre el que **se presiona** el botón
  del mouse; el clic usa esa misma petición (una por clic, como antes) y
  se ganan los ~100–200 ms entre presionar y soltar.
- **Cloudflare va delante** de `comreydavid.com` (Fernando, 2026-10-16):
  sin más, `remote_ip` era el servidor de Cloudflare, compartido entre
  usuarios y bots, y el bloqueo de un bot que buscaba `/.env` dejaba a
  la oficina con 429 una hora (era la causa real, no Starlink).
  `config/initializers/trusted_proxies.rb` confía en los rangos publicados
  de Cloudflare: `remote_ip` es la IP real del visitante para rack-attack,
  el límite del login y la auditoría. Si Cloudflare publica rangos nuevos,
  se agregan ahí.
- **Límite por usuario en pantallas caras**
  (`ApplicationController.rate_limit_per_user`): respaldo 3 por hora, CSV
  de reportes 10 por minuto, gráficos 60 por minuto. Pasado el límite,
  alerta en español (`ErrorHandling#handle_rate_limited`; en un frame, la
  alerta va dentro del frame). El inicio de sesión sigue con 10 intentos
  por 3 minutos por IP.
- Cada límite superado queda en la auditoría **una vez por IP, regla y
  período** (acción `rate_limited`, `RateLimitAudit`), no por solicitud.
- **Caché**: `:memory_store` acotado en producción y en test (lo usan los
  contadores de `rate_limit`, la cotización de `CoffeeMarket` y las cifras,
  gráficos y conteos de Reportería). Los specs lo limpian antes de cada
  ejemplo.
- **Caché de reportes** (Fernando, 2026-10-18): `Report#cached` guarda
  cifras, gráficos y conteo con una clave de reporte, filtros (sin el
  orden ni la página), día, módulos que el usuario ve y `DataVersion`, que
  **todo modelo `Auditable` cambia al confirmar su transacción**: un
  cambio nunca queda tapado por una copia vieja. 30 min como tope. La
  tabla (filas) no se cachea. `spec/reports/report_cache_spec.rb`.
- **Consultas por fila** (N+1): la gema `bullet` avisa en desarrollo y
  **hace fallar** el spec que carga la página en test;
  `spec/requests/query_growth_spec.rb` comprueba que las listas y el
  Inicio no hacen una consulta más por fila. `Payroll#periods_to_pay`
  mira primero qué días tienen trabajo anotado y solo calcula esos
  períodos; `CreditAccount` usa los préstamos precargados.
- **Respuestas comprimidas** (gzip, `Rack::Deflater` en
  `config/application.rb`): páginas, turbo streams, JSON y CSV; imágenes
  y el zip del respaldo van tal cual. **YJIT** lo enciende Rails solo
  (`config.yjit`) si el Ruby lo trae; el log de arranque dice si quedó
  activo (`config/initializers/yjit.rb`): **verificar en Render**.
- **Tiempo máximo por consulta** en producción: `statement_timeout` 15 s
  (`DB_STATEMENT_TIMEOUT` lo cambia; `bin/render-build.sh` lo pone en 0
  para migraciones y cargas).
- **Bloqueo optimista** (`lock_version`) en compras, facturas, préstamos y
  planillas. Los formularios de compra, préstamo y planilla mandan
  `lock_version`; si alguien guardó antes, no se guarda nada y sale «Alguien
  más guardó cambios…» (`ActiveRecord::StaleObjectError` en
  `ErrorHandling`, auditado como error 409). `lock_version` no entra en los
  cambios auditados.
- **CI** (`.github/workflows/ci.yml`): Brakeman, bundler-audit, importmap
  audit, Rubocop y RSpec (con PostgreSQL 18 y Chrome) en cada push a
  `main`/`staging` y en cada PR; Dependabot semanal.

## Actualizaciones en vivo (Fernando, 2026-10-12)

- Las páginas de Inicio, Compra de café (Resumen, Compras, detalle de
  compra, Facturas, detalle de factura, Cierre diario, Productores y su
  detalle) y Préstamos (Resumen, Préstamos, detalle, Estados de cuenta) se
  **actualizan solas** cuando otra persona cambia los datos. Fincas y
  Reportería no, por ahora.
- Cómo: el modelo incluye `LiveUpdates` y declara `live_updates :trading`
  (o `:loans`); tras cada commit avisa «refresh» a ese canal
  (`broadcast_refresh_later_to`, agrupa ráfagas). La página se suscribe con
  `live_updates_from :trading` (`LiveUpdatesHelper`) y Turbo 8 vuelve a
  pedirla y aplica solo lo que cambió (morph, conserva el scroll). Por el
  canal no viaja ningún dato: cada usuario recibe la página con sus
  permisos. Quien hizo el cambio no se recarga dos veces (request id).
- Avisan: `Purchase` (también a `sales`), `Invoice`, `InvoicePayment`, `Producer`, `Hauler`, `HaulerPayment` a `trading`;
  salidas, ventas, cobros y compradores a `sales`; cuentas, gastos,
  ingresos, transferencias, presupuesto y planilla interna a `finance`;
  `Loan` a `loans`; `LoanPayment` a los dos (pago con café). Página nueva
  en vivo = `live_updates_from`; modelo nuevo = `include LiveUpdates`.
- `live_refresh_controller.js` (en el `<body>`): con una ventana abierta
  (modal, guía) la actualización espera a que se cierre; conserva los
  toasts y los `<details>` abiertos, y los atributos que un elemento marca
  con `data-live-keep` (el morph devuelve todo a como lo manda el
  servidor: lo que el JavaScript cambia a mano, como el `hidden` del botón
  «Filtrar» de los filtros en vivo, se marca así); las filas nuevas (`tr`/`li`/`.data-card`
  con id) entran con brillo y las cifras (`.stat dd`, `[data-live-value]`)
  que cambian dan un pulso. «En vivo» abajo a la izquierda mientras la
  conexión está abierta.
- Action Cable autentica con la cookie de sesión y rechaza usuarios
  inactivos (`ApplicationCable::Connection`). Adaptador `async`: con más
  de una instancia o más workers de Puma habría que pasar a Solid Cable o
  Redis. En test los specs de pantalla corren los jobs en línea.

**Usuarios conectados** (`Presence`, Fernando, 2026-10-13): toda página con
sesión mantiene **una** suscripción a `PresenceChannel` (`presence.js`,
importado una vez en `application.js`; sobrevive a las visitas de Turbo y se
suelta en una página sin `<meta name="presence">`, como el inicio de sesión
tras salir). Un usuario está conectado mientras tenga alguna pestaña abierta.
En el Inicio van en la fila del saludo, al otro extremo: círculos
pequeños con las iniciales y un punto verde; al pasar el puntero o con el
foco abren **su tarjeta** (`dashboard/_active_user_card`, `.presence-card`:
una tarjeta clara, no un tooltip), que sigue abierta mientras el puntero o
el foco estén dentro, para hacer clic y desplazarse (Fernando, 2026-10-16); más de
`Presence::AVATARS` se juntan en «+N». Al lado, con un **anillo gris** en
vez del punto verde, quienes no están conectados pero tuvieron actividad en
la última hora (`Presence::RECENT_WINDOW`, Fernando 2026-10-14: un celular
bloqueado o una pestaña dormida cortan la conexión, pero la sesión sigue en
uso). La actividad es de la sesión (`Session#last_seen_at`, `seen!`): cada
solicitud la mueve, como mucho una vez por minuto, y cerrar la pestaña
también. Quien cierra sesión sale, porque su sesión se borra. El tooltip
dice «En línea» o «Última actividad: 09:42». Al entrar o salir alguien se
reemplazan por el stream de Turbo `presence` (solo nombres y horas). **El usuario con
id 1 nunca sale como conectado** (`Presence::HIDDEN_USER_IDS`), pero ve a los
demás.
**Y solo él ve, al pasar el puntero, la última actividad y la página en
que está cada uno** (`Presence::WATCHER_IDS`, Fernando 2026-10-15):
`presence.js` avisa por el canal (`visit`) cada página que se abre, la de
un modal o panel lateral y, al cerrarlo, la de abajo; se guarda en la sesión
(`Session#visited!`: ruta y título, `last_path`, `last_page_title`, y
cuenta como actividad). Con varias sesiones sale la más reciente. Su tarjeta trae además, con
enlaces y desplazamiento propio, la página en que está (abre la página
completa), **las páginas recientes** (`PageVisit`, las últimas
`PageVisit::KEEP` por usuario; fuera del respaldo, como las sesiones) y
**lo que hizo** (sus eventos de auditoría; abre el detalle en el modal),
los últimos `Presence::CARD_ITEMS` de cada uno. Solo se guardan rutas
propias de la app (nunca `//otro-sitio`). El panel se reemplaza con
**morph** y cada círculo tiene el mismo id en línea o reciente
(`presence_user_N`): una tarjeta abierta no se cierra ni pierde su
desplazamiento cuando llega una actualización. Su Inicio
escucha `Presence::WATCH_STREAM` en vez de `presence`, y solo su página
recibe ese stream firmado: a los demás no les llega ni la ruta. Vive en la memoria del proceso, como el adaptador `async`.

**Café en la bolsa** (`CoffeeMarket`, Fernando, 2026-10-13): tarjeta del
Inicio, a todo el ancho (precio, línea y rangos en una fila; apilados en
angosto), con el arábica «C» de ICE Nueva York (`KC=F`, centavos de dólar por
libra): precio, cambio contra la sesión anterior, línea del último mes,
rangos del día y de 52 semanas. Sale del endpoint público de gráficos de
Yahoo Finanzas (gratis, sin clave, **no es una API oficial**: puede cambiar
o fallar). Se pide aparte en un frame perezoso (`coffee_markets#show`), se
guarda 15 min en la caché (un fallo, 2 min) y si no responde dice «no
disponible». Es solo referencia: no toca el precio de las compras. En los
specs nunca sale a internet (`spec/support/outside_services.rb`).

**Mi configuración** (Fernando, 2026-10-13): el nombre del usuario en la
navegación abre su configuración en el modal (`UserSettingsController`,
`UserSettingPolicy`: cada quien la suya). Es un formulario completo: **sus
datos** (foto, nombre y correo), la pantalla (abajo) y **su contraseña**;
cambiar el correo o la contraseña pide la contraseña actual
(`password_challenge` de `has_secure_password`). Nunca cambia permisos,
`admin` ni `active`. Debajo, aparte del formulario, sus **huellas**
(ver «Huella digital»). Las opciones de pantalla:
- **Páginas que se abren encima** (`window_style`): `modal` (ventana al
  centro) o `drawer` (panel que entra desde la derecha; `.modal.drawer`).
  El drawer **mide lo que su página necesita, hasta el 90 % del ancho**
  (Fernando, 2026-10-13): un formulario corto no queda en un panel vacío
  (mínimo 34rem); los párrafos se ajustan al ancho de los campos en vez
  de ensancharlo, y una página con tablas o con `@container` toma el
  90 %. En el drawer, un `modal_link_to` navega **dentro
  del mismo panel** (`ModalSupport#modal_frame_for`), salvo un `?picker=1`,
  que se apila encima para no perder el formulario de abajo.
- **Menú principal** (`nav_position`): `top` o `left` (`layouts/_sidebar`,
  desde `lg`; en el celular sigue arriba). El de la izquierda **se esconde
  a solo íconos** con su botón (`sidebar_controller.js`): al pasar el
  puntero o con el foco, el ícono crece y su nombre sale en un tooltip al
  lado, **sin ensanchar la barra**. Se recuerda en la cookie
  `sidebar_collapsed` (`SidebarState`), no en el usuario: la página llega
  del servidor ya plegada y plegar no escribe nada ni se audita.
- **«Atrás»** (`modal_controller.js`, en el layout `modal`): cada ventana
  recuerda las páginas que mostró (solo las pedidas con GET); «Atrás» vuelve
  a la anterior, o, si no hay, cierra la ventana de arriba y deja la de
  abajo. Guardar un formulario sigue cerrando la ventana y refrescando la
  página.

**Huella digital** (passkeys, WebAuthn, gema `webauthn`; Fernando,
2026-10-13): **una forma más de entrar, la contraseña sigue sirviendo**.
Cada usuario registra la huella (o el desbloqueo) de cada dispositivo en Mi
configuración (`WebauthnCredentialsController`, `WebauthnCredential`: solo
la llave pública, con nombre del dispositivo y último uso); en el inicio de
sesión, «Entrar con huella» deja que el dispositivo elija la llave (sin
escribir el correo: credenciales descubribles con verificación del usuario)
y entra (`PasskeySessionsController`, mismo límite de intentos que el
login, auditado como `sign_in` con `method: passkey`; un usuario inactivo
no entra). `passkey_controller.js` hace las dos ceremonias. La parte
confiable (`Passkeys.relying_party`) es el host de la petición: una huella
solo sirve en el dominio donde se registró (en Render, el de producción) y
WebAuthn exige HTTPS o `localhost`. En los specs: `WebAuthn::FakeClient`
en los de petición y el autenticador virtual de Chrome en el de pantalla
(visitando `localhost`, no una IP).

**Fotos de perfil** (`ProfilePhoto`, `HasPhoto`, Fernando 2026-10-13):
personas (y por ellas productores, clientes, colaboradores) y usuarios.
Se guardan en la base, en su propia tabla (no hay almacenamiento de
archivos en el servidor), solo JPG, PNG o WebP revisados por su contenido,
de hasta 1 MB: el navegador achica la foto a 512 px antes de enviarla
(`photo_input_controller.js`, `shared/_photo_field`, con botón en
español). Se sirven en `/profile_photos/:id?v=` a usuarios con sesión.
`avatar(record)` muestra la foto o las iniciales; para listas,
`includes(:photo_info)`, que no carga los bytes. La foto se audita sin sus
bytes.

**Ubicación en el mapa** (Fernando, 2026-10-13, con OpenStreetMap: gratis
y sin clave): personas y fincas tienen `latitude` y `longitude`
opcionales (`HasAddress`: las dos o ninguna, dentro del globo). El mapa
está en `shared/_address_fields` (`location_map_controller.js`, Leaflet
1.9.4 vendorizado en `vendor/javascript/leaflet.js` y su CSS en
`app/assets/stylesheets/leaflet.css`): tocar el mapa pone el pin
(arrastrable), «Usar mi ubicación» usa la del dispositivo y las
coordenadas se pueden escribir o pegar de Google Maps. Los detalles de
productor, persona y finca muestran el mapa con «Abrir en Google Maps»
(`shared/_location`). Las teselas salen de `config.x.map_tiles_url`
(en test, ninguna: los specs no salen a internet). En el mapa solo va el
crédito obligatorio, «© OpenStreetMap» con enlace a su página de derechos
(licencia ODbL y política de teselas), en 8 px; el de Leaflet no se
muestra (BSD no lo pide).

**Respaldo de datos** (`DataBackup`, Administración → Respaldo, Fernando
2026-10-12; **solo el usuario con id 1**, y mientras sea administrador:
`User::DATA_EXPORTER_ID`, `User#data_exporter?`, Fernando 2026-10-13; a
los demás no les aparece. El CSV de cada reporte sigue para quien ve el
reporte): descarga un `.zip` con una carpeta
`respaldo-AAAA-MM-DD-HHMM/` que trae `base.dump` (pg_dump formato custom,
sin datos de `sessions`), `csv/` con una tabla por archivo (BOM para Excel,
sin `password_digest` ni sesiones) y `LEEME.txt` con cómo restaurar. Si el
servidor no tiene `pg_dump` o es más viejo que la base (PostgreSQL 18), el
respaldo trae solo los CSV y lo explica; la pantalla muestra ambas
versiones antes de descargar. **Verificar en Render** (`pg_dump --version`
en el shell del servicio). Cada descarga se audita (`backup`).

**Inicio** (`Dashboard`, `dashboard/show`), **sin huecos** (Fernando,
2026-10-12): cifras y módulos llenan cada fila (`flex-wrap` con
`flex-1`), y en pantallas anchas «Actividad reciente» va a la derecha con
la misma altura que la columna izquierda (pendientes + módulos) y se
desplaza por dentro (`contain: size`). Es un centro de operaciones con
saludo, propósito, fecha y temporada; acciones frecuentes (solo las que el
usuario puede hacer en módulos que puede ver); resumen de operaciones
(compras de hoy, QQ de la temporada, préstamos por cobrar, fincas activas y
pendientes); tareas pendientes, solo si existen (compras sin facturar,
facturas sin cancelar, préstamos vencidos, períodos por pagar, empleados
de planillas por día sin salario); actividad reciente de los módulos que
ve, con enlace; café en la bolsa y usuarios conectados; y sus módulos. La cifra
«Pendientes» (y «Ver el detalle» del panel) abre en el modal **Tareas
pendientes** (`PendingWorkController`): **una pestaña por tipo** con
cuántos hay (`tabs_controller.js`, cambian ahí mismo, también con las
flechas; nunca enlaces `#ancla`, que dentro de un frame cargaban el
Inicio), cada una con sus registros, lo más viejo primero, y el botón que lo resuelve (Facturar por productor,
Registrar abono, Pagar el período, Asignar salario), solo si el usuario
puede hacerlo. Los formularios se abren encima; «Atrás» vuelve a la lista. Todo sale de los datos y scopes existentes;
nada se estima ni se inventa.

Cada módulo tiene su namespace de controladores. Implementar una funcionalidad
es llenar su carpeta, no crearla.

### Documentos privados (Administración, Fernando, 2026-10-22)

- **Dos documentos fijos**: el pagaré y el contrato privado de préstamo
  (`PrivateDocument::KEYS`). No se agregan ni se borran: `PrivateDocument.
  ensure_all!` crea las dos filas vacías si faltan (en GET, sin auditoría).
  Ver y editar: **solo administradores** (`PrivateDocumentPolicy`).
- **El texto es del cliente y nunca va al repositorio** (es público): vive
  en la base. Las plantillas convertidas de sus Word, con sus variables,
  están en `docs/2026-10-22/documentos_privados/` (local) y se cargan con
  `bin/rails "private_documents:load[promissory_note|loan_contract,archivo.html]"`.
  Para producción: copiar el HTML en la vista «Código fuente» del editor.
- **Editor**: Jodit 4.17.1 (MIT), build «fat» vendorizado
  (`vendor/javascript/jodit.js`, pin sin precarga; su CSS en
  `vendor/stylesheets/jodit.css`, que no entra en `:app`), cargado solo
  en el formulario (`document_editor_controller.js`): negrita, alineación,
  tamaños, listas, tablas, pegar desde Word y vista HTML (área de texto,
  nada de otros sitios). Sin imágenes, archivos ni enlaces.
- **Variables**: `<span data-variable="grupo.nombre">` (`PrivateDocumentVariables`:
  persona, préstamo, fecha de impresión, negocio), puestas desde el panel
  derecho; en el editor son una sola pieza. Al guardar, `PrivateDocumentHtml`
  limpia el HTML (solo formato; variables desconocidas se quitan). Montos y
  tasas en letras con `NumberWords`. Un dato vacío se imprime como línea en
  blanco.
- **Imprimir, por préstamo** (Fernando, 2026-10-23; pide crear en
  `loans`, `PrivateDocumentPrintPolicy`): cada préstamo (fila o tarjeta
  del estado de cuenta y su detalle) lleva «Pagaré» y «Contrato»
  (`loans/loans/_print_buttons`; la tabla con `document_prints:`,
  `LoanDocumentPrints`). Abren la **vista previa** (`document_prints#new`,
  página completa, nada se guarda): el documento lleno con la persona y
  ese préstamo, el aviso de lo que saldrá en blanco y «Completar datos de
  la persona» (su formulario en el modal, si puede editar personas; al
  guardar la página se vuelve a llenar) o «del negocio» (admins).
  «Imprimir» guarda la impresión tal como salió (`PrivateDocumentPrint#body`,
  fuera de la auditoría) y la abre con la ventana de impresión
  (`print_controller.js`, `auto`). No hay impresión sin préstamo ni
  botones globales en el estado de cuenta.
- **Contador por préstamo y documento** junto a cada botón, para todos los
  que ven el préstamo; al pasar el puntero, **solo administradores** ven
  las últimas `PrivateDocumentPrint::HISTORY_SIZE` (fecha y usuario; abren
  el impreso), en una tarjeta fija en pantalla (`print_count_controller.js`)
  que la tabla no corta. Papel carta, con el membrete.
- El estado de cuenta de un productor lleva «Ver productor» (su página en
  Compra de café), para quien ve ese módulo.

### Comercialización (`sales`, Fernando, 2026-10-23)

Lo que ofrece el contrato: vender el café en inventario a exportadoras,
beneficios y otros compradores; el inventario sube con las compras y baja
con las ventas. Reglas que decidió Fernando el 2026-10-23 (respuestas a
`PREGUNTAS_COMPRAVENTA.md` §5–7, con las boletas de Beneficio Mendoza y
Café Henola: venta por QQ en Lempiras, documento del comprador,
contado/crédito, forma de pago) [CONFIRMADO]:

- **Inventario** (`CoffeeStock`): libras netas **por estado del café**. Las
  compras activas suman su `net_weight`; las salidas no anuladas restan su
  neto local. Se muestra también en QQ de compra (÷125). A una fecha (fin
  del día); de lo que salió, «en camino» y «pesado sin vender». El kárdex
  (`StockLedger`, `sales/stock#show`) lista cada compra y salida con el
  saldo después de cada una.
- **Salida de camión** (`Shipment`): comprador, estado del café, remisión,
  transportista y camión **de sus catálogos** (`Carrier`, `Truck`: dos
  catálogos sueltos, Fernando, 2026-10-25; Comercialización →
  Transportistas y Camiones, con su ficha y sus salidas, «Nuevo» desde la
  salida) y **motorista**: un empleado de la planilla interna o un nombre
  escrito (`driver`, `driver_name`). Lo que las salidas tenían escrito
  (transportista, placa) pasó a los catálogos en la migración. Se pesa en la **báscula local** (`origin_*`) y, al
  llegar, en la **del comprador** (`destination_*`, con nota de peso y
  fecha; `ArrivalsController`). Cada neto usa **el mismo cálculo de la
  compra** (`PurchaseCalculation` con sacos contados: bruto − 1 lb × saco,
  menos humedad y daño; uva × rendimiento), que guarda tara y neto y solo
  se recalcula si cambia una entrada. `weighing_calculator_controller.js`
  es la vista previa (y avisa, sin bloquear, si sale más que el
  inventario). La báscula local se escribe **en una cifra o por pesadas**,
  como en compras (`ShipmentWeighing`, Fernando, 2026-10-25): por pesadas,
  el bruto y los sacos son la suma y no se escriben. Etapas (`SalesLifecycle`): salió → pesada en destino →
  vendida → cobrada. Número correlativo con bloqueo consultivo.
- **Diferencia entre básculas**: neto del comprador − neto local, en lb y
  %, en la salida, la venta, las listas y los reportes. Se **resalta** si
  pasa (más o menos) la **tolerancia** de Configuración del sitio
  (`weight_tolerance_percent`, **vacía al inicio**: sin ella no se resalta
  nada; `WeightTolerance`). Anular la venta antes de cobrarla lo decide el
  usuario.
- **Venta** (`Sale`, `SaleIssuer`, como «Facturar compras»): **salida
  primero, venta después**: agrupa salidas **del mismo comprador** ya
  pesadas en destino y libres (líneas `SaleLine`, con sus pesos y monto;
  índice único parcial: una salida en una sola venta activa). Se cobra con
  el **peso del comprador**, **por libra o por quintal de 100 lb**
  (`Sale.amount_for`). Guarda netos y total. Documento del comprador
  (factura o comprobante). Imprimible (nota de venta, original y copia).
- **Cobro por abonos** (`SalePayment`), como las facturas: pendiente →
  cobro parcial → cobrada; contado = un abono por el total al crear la
  venta; cada cobro con recibo (original y copia). Registrar pide editar
  en `sales`.
- **Anular**: una venta **solo sin cobros** (con motivo); sus salidas
  quedan **libres** para otra venta y sus líneas quedan como registro. Una
  salida se anula aparte, solo si no está en una venta activa: su café
  vuelve al inventario. Ninguna se borra.
- **Comprador** (`Buyer`): catálogo propio para empresas (nombre o razón
  social, tipo, RTN, contacto, teléfono, correo, dirección); se desactiva.
  No es una `Person`.
- Pantallas: Resumen (qué sigue, inventario, hoy y temporada), Salidas,
  Ventas, Inventario, Cierre diario (impreso) y Compradores (con
  pestañas). En vivo (`live_updates :sales`; las compras también avisan a
  `sales`). Inicio: QQ en inventario, por cobrar y pendientes (salidas en
  camino, sin vender, ventas por cobrar). Reportería: `ShipmentsReport`,
  `SalesReport`, `CoffeeStockReport` y los cobros en «Entradas y salidas»
  (para quien ve Comercialización).
- **Contratos con exportador** (anticipos, aplicar libras a contratos en
  orden): **no se construyen**, siguen abiertos.

### Control financiero (`finance`, Fernando, 2026-10-23)

Lo que ofrece el contrato: registro, clasificación y control de todas las
salidas de dinero (gastos, inversiones y similares). Reglas [CONFIRMADO]:

- **Cuentas** (`MoneyAccount`): caja o banco, con saldo inicial y su
  fecha; cada una dice para qué formas de pago se sugiere (`default_for`).
  Saldo = inicial + entradas − salidas (`AccountBalance`, sumas en SQL de
  todas las fuentes). Se desactivan; no se borran. Estado de cuenta
  imprimible con el saldo después de cada movimiento. **La lista son
  tarjetas** tipo tarjeta de crédito (Fernando, 2026-10-25), con los
  colores de su banco: Ficohsa azul, Banco Atlántida rojo con blanco,
  BAC Honduras rojo, Banco de Occidente naranja con blanco; otro banco,
  uno de cuatro estilos (`OTHER_STYLES`, fijo por cuenta), y la caja,
  café. Toda la tarjeta abre el detalle, que la repite junto a sus datos.
  **Rediseñadas a partir de las tarjetas reales de cada banco** (Fernando,
  2026-10-24), sin sus logos ni marcas de Visa o Mastercard: el arte es
  un SVG por banco (`_card_art`), con chip, «sin contacto», número en
  relieve y el nombre del banco armado como en su tarjeta (`wordmark` en
  `honduras_banks.yml`). **Miden 26rem en la lista y en el detalle**; en
  angosto se achican enteras (todo adentro en `cqw`). **La caja va
  primero** (la más usada) y tiene su propio diseño, grabada como un
  billete: guilloché dorado que sale del medallión con el grano de café,
  marco dorado, el nombre del negocio como emisor y el saldo grande.
  El banco se elige de `db/data/honduras_banks.yml` (datos de referencia,
  como los departamentos) o «Otro banco» y se escribe (`bank_key`
  `other` + `bank_name`); una caja no lleva banco.
- **Cuenta en todos los pagos**: abonos a factura (también al facturar),
  pagos a carreros, préstamos (la parte en efectivo), abonos a préstamos
  (con café o por planilla no llevan), pagos de planilla, gastos de
  planilla y cobros de ventas llevan `money_account_id` (opcional,
  `HasMoneyAccount`); `money_account_controller.js` sugiere la de la forma
  de pago hasta que el usuario elige otra. Lo viejo queda «sin cuenta» y
  se muestra aparte. Los recibos dicen la cuenta.
- **Libro único** (`MoneyMovements`, «Movimientos»): todo lo que entra y
  sale de todos los módulos, **sin duplicar** (cada cosa se registra donde
  ocurre). Cada quien ve las fuentes de los módulos que puede ver. Las
  transferencias solo salen al elegir una cuenta. Cada movimiento lleva
  **fecha y hora** (su fecha a la hora en que se registró, `Movement#at`)
  y la lista va de lo más reciente a lo más viejo; los filtros siguen por
  día (Fernando, 2026-10-25).
- **Consolidación** (`finance/consolidation`, Fernando, 2026-10-25): los
  pagos y cobros de los otros módulos registrados sin cuenta, con filtros;
  se marcan (o «Marcar todos») y se les da una cuenta, o **la de su forma
  de pago** (los de planilla, sin forma de pago, esperan). **También la
  categoría** (Fernando, 2026-10-24: «que no se cambie para las entidades
  que no aplica»): solo en lo que la lleva (`AccountConsolidation::
  CATEGORIES`: los gastos de planilla, con las categorías de Fincas); al
  resto no se le toca y el aviso dice cuántos. Filtros: fechas, búsqueda,
  origen, forma de pago, entrada o salida y monto desde/hasta. Solo cambian
  cuenta y categoría, auditado como cambio del registro; pide editar en
  `finance`. «Entradas y salidas de
  dinero» (Reportería) lee de aquí, con filtro y agrupación por cuenta.
- **Gastos e inversiones** (`Expense`): categoría **propia, de dos
  niveles** (`FinanceCategory`; las de Fincas siguen aparte), detalle,
  beneficiario, fecha, monto, forma de pago, cuenta (obligatoria),
  número de comprobante y, **opcional, la foto o el PDF del comprobante**
  (`ExpenseReceipt`, en la base, JPG/PNG/WebP/PDF revisados por contenido,
  hasta 1 MB). Se editan y borran con permisos, auditados.
- **Otro ingreso** (`OtherIncome`: aporte del dueño, préstamo del banco…)
  y **transferencias** (`AccountTransfer`) se registran o se quitan.
- **Presupuesto** (`Budget`, `BudgetSheet`): por categoría de primer nivel
  y mes de la temporada, contra los gastos e inversiones de esa categoría
  y sus subcategorías. Resaltado al pasarse; en el Inicio y en Tareas
  pendientes.
- Resumen: saldos, el mes contra los mismos días del anterior, por dónde
  y en qué categoría salió, el presupuesto del mes y los últimos
  movimientos. Reportería: `ExpensesReport` (con KPI de presupuesto).
- **Ingresos** (`finance/incomes`, Fernando, 2026-10-24): todo lo que
  entró (cobros de ventas, abonos a préstamos en dinero y otros ingresos,
  de `MoneyMovements`, `IncomeFilter`), con el total y lo de cada origen;
  «Registrar ingreso» anota un `OtherIncome`. Las transferencias no son
  ingresos.
- **Planilla interna** (`finance/staff`, Fernando, 2026-10-24: «planilla
  interna del negocio») [CONFIRMADO]:
  - **Roles** (`StaffRole`): **salario mensual**; frecuencia semanal,
    quincenal o mensual (los períodos de `PayPeriod`, como Fincas); y **valor de la
    hora extra por rol** (sin él no se anotan horas). Los del Excel del
    cliente (CEO, Administración, Chofer, Cargador, Bodeguero, Trabajadora
    DMC, Cargador de bodega) los crea la migración `AddExcelStaffRoles`
    **sin salario**: un rol puede esperar sin salario ni frecuencia (las dos
    o ninguna, `StaffRole#priced?`) y nadie de ese rol tiene períodos por
    pagar hasta llenarlos (Fernando, 2026-10-24).
  - **Se paga como el Excel del cliente** (Fernando, 2026-10-25; cambia el
    «monto fijo por período» del 2026-10-24) [CONFIRMADO]: cada período paga
    **salario mensual ÷ 30 × días trabajados** (`StaffMember#period_days`,
    `#earned`), marcados día por día, completo o medio (`StaffAttendance`).
    **Mes de 30 días**: un período trabajado completo cuenta 15 días en
    quincena (30 mensual, 7 semanal) aunque tenga 16 o 13; si faltó,
    cuentan los días marcados, sin pasar de esos. El pago guarda el salario
    mensual y los días (`monthly_salary`, `days_worked`); `salary` es lo
    devengado. Los días de un período pagado no cambian.
  - **Hoja de planilla** (`finance/staff_sheet`, `StaffSheet`), el Excel
    vivo, con tres vistas: **Quincena** (1–15 o 16–fin: se marca la
    asistencia, `staff_sheet_controller.js` recalcula días, devengado y
    total = devengado − anticipos; «Pagar a los marcados» paga juntos los
    períodos ya vencidos de esa quincena, con la misma fecha, forma de pago
    y cuenta; quien tiene metas por revisar u horas extra se paga desde su
    estado), **Mes** (los días de cada quincena, devengado, anticipos,
    total, pagado y lo que falta) y **Acumulado** (lo pagado mes por mes en
    la temporada —lo entregado más los anticipos descontados— y, del mes
    actual, lo pagado y lo que falta, estimado como si trabajara los días
    que quedan). Imprimible con membrete y columna de firma. En el Excel
    del cliente, Nahum (13,000, 4 días, anticipo L 100) dice L 1,733.33: no
    le restaron el anticipo; aquí siempre se resta.
  - **Empleados** (`StaffMember`): una persona con rol Colaborador, una
    vez, en un rol, desde una fecha (fin opcional); se desactivan. Puede
    tener **salario propio** (`salary_override`, Fernando, 2026-10-24: dos
    choferes del mismo rol con pago distinto), que manda sobre el del rol;
    la frecuencia y la hora extra siguen siendo las del rol. Sus
    períodos siguen la frecuencia del rol; los pagados se quedan.
  - **Anticipos** (`StaffAdvance`): salen de la cuenta el día que se dan y
    se restan **completos del pago del período** que tiene esa fecha.
  - **Metas** (`StaffGoal`): texto y bono en lempiras por período; al
    pagar se marca si la cumplió (el bono se suma). Además, un **bono
    libre** con su motivo al pagar.
  - **Pago** (`StaffPayment`, `StaffPaymentIssuer`, todo o nada): salario
    + horas × valor de la hora + bonos − anticipos; guarda cada parte y su
    recibo (original y copia). Sale de la cuenta el neto
    (`MoneyMovements`: `staff_payments`, `staff_advances`; `AccountBalance`).
    El Resumen avisa los períodos que llegaron a su día de pago.
  - Decisiones de implementación, **pendientes de confirmar**: los
    períodos se pagan en orden y solo se quita el último (libera sus
    anticipos y metas); si los anticipos pasan de lo ganado no se paga; un
    anticipo o una meta no van en un período ya pagado; la cuenta es
    obligatoria; las vistas Mes y Acumulado cuentan por quincenas aunque
    un empleado se pague semanal o mensual.
- **La ganancia no se calcula**: cómo la calcula el dueño sigue abierto
  (pregunta 34).

### Compra de café (`trading`)

En la interfaz el módulo se llama **«Compra de café»**: las ventas irán en
un módulo aparte, más adelante (Fernando, 2026-10-11). Solo cambiaron los
textos; la clave y el código siguen siendo `trading`.

- **Cálculo de la compra** (`PurchaseCalculation`) [CONFIRMADO, Fernando,
  2026-10-10]. Tara de la macro del cliente: 1 lb por saco de 165 lb,
  redondeado hacia arriba. Después, según el estado del café:
  - Pergamino húmedo y seco: `(bruto − tara) × (1 − humedad%) × (1 − daño%)`.
    El daño es un porcentaje que se resta al peso neto (suele ser 2–2.5 %).
  - Uva: `(bruto − tara) × rendimiento`. No lleva humedad ni daño.
  - Quintales (QQ) = peso neto ÷ 125. Total = peso neto × precio por libra.
  - **Restado por daño** (pergamino): `damage_weight` = (bruto − tara) ×
    (1 − humedad%) × daño%, y `damage_amount` = esas libras × precio por
    libra. Se guardan en la compra y se muestran en el formulario, el
    detalle y «Facturar compras» (Fernando, 2026-10-12). En uva quedan
    vacíos. **La factura solo lleva las libras**, no los lempiras
    (Fernando, 2026-10-24: «quitar restado en lempiras por daño en las
    facturas»).
  - **Tipo de daño** (Fernando, 2026-10-24) [CONFIRMADO]: con daño mayor
    a 0, «Nueva compra» pide **al menos uno** de amarillo, broca, verde,
    pulpa o pelado (`Purchase#damage_types`, casillas que salen al
    escribir el daño; `purchase_calculator_controller.js` avisa). Sale en
    el detalle y en la factura. Las compras de antes sin tipo se pueden
    anular; al cambiarles el daño lo piden.
- **Forma de pesar** (`Purchase#weight_mode`) [CONFIRMADO, Fernando,
  2026-10-10]: `single` (peso bruto directo; sacos = bruto ÷ 165 y tara como
  arriba) o `weighings` (por pesadas, `PurchaseWeighing`: peso + sacos
  contados, enteros). Por pesadas, el bruto y los sacos son la suma (el
  bruto no se escribe, el campo queda de solo lectura) y la **tara = 1 lb ×
  sacos contados**. Al volver a peso directo se borran las pesadas.
- Se guarda el resultado en la compra y **solo se recalcula si cambia una
  entrada** (`Purchase::CALCULATION_INPUTS`), para que el histórico no cambie
  si la regla cambia. `purchase_calculator_controller.js` lo replica solo
  como vista previa; el servidor manda.
- Valores iniciales (`PurchaseDefaults`), todos editables: humedad 51 % en
  pergamino húmedo y 12 % en seco, daño 0 %, rendimiento 0.186 en uva. El
  daño vacío cuenta como 0 % (vista previa y servidor). Con datos
  incompletos la vista previa sigue mostrando sacos y tara. Al
  cambiar el estado en el formulario se ponen los del nuevo estado y se
  ocultan los campos que no aplican. Al cambiar de productor, la zona pasa a
  la del nuevo productor.
- **Temporada** (`Season`) [CONFIRMADO]: empieza cada 1 de septiembre y
  lleva el año en que empieza (la 2026 va del 2026-09-01 al 2027-08-31).
  Cada compra guarda su `season_year`, calculado de la fecha de compra.
  **En pantalla, impresos y reportes se llama con sus dos años**:
  «Temporada 2026-2027» (`Season#label`, Fernando, 2026-10-13); el número
  guardado y los parámetros (`season_year=2026`) siguen siendo el año en
  que empieza.
  Compras y facturas se filtran por temporada (solo las que tienen compras;
  una factura cae en la temporada de sus compras). Elegir una temporada
  borra las fechas del filtro (`season_filter_controller.js`).
- **Fecha y hora de la compra** (`purchased_at`): el formulario empieza con
  la hora actual y es editable. Toda pantalla e impreso la muestra con hora.
  Los filtros por fecha y el cierre diario cubren el día completo en hora de
  Tegucigalpa (`Purchase.on`, que acepta una fecha o un rango).
- **Anular compra** [CONFIRMADO]: una compra sin facturar se anula (no se
  borra) con el permiso de borrar (`PurchasePolicy#void?`). Queda registrada
  con quién y cuándo, pero sale de listas, totales, cierre diario y
  facturación (`Purchase.active`; `uninvoiced` ya la excluye). Las listas de
  compras la muestran solo con "Mostrar anuladas". No se edita, no se borra y
  no se puede deshacer.
- **Clave IHCAFE** del productor (`ihcafe_code`) [CONFIRMADO, Fernando,
  2026-10-12]: `XX-XX-XXXXX`, letras o números, **opcional y única**, para
  todos los tipos de productor. Se busca en la lista de productores.
- La página del productor (`ProducerProfile`) tiene cifras fijas (QQ,
  compras, total y precio promedio por libra de la temporada, QQ de todas,
  deuda en préstamos si se ven préstamos), una columna lateral (ficha con
  clave y datos de contacto, «Pendiente»: sin facturar y facturas por
  pagar, y préstamos con su score) y pestañas: resumen (QQ por temporada y
  por mes, estados del café, últimas compras), compras y facturas. El
  precio promedio es total ÷ libras netas; no es una regla de negocio.
- Las tablas de compras y facturas aceptan `show_producer: false` para no
  repetir el productor en su propia página.
- En "Facturar compras" se puede anular una compra o registrar una nueva para
  ese productor en un modal; al guardar, la lista se refresca.
- **Fincas de productores** [CONFIRMADO, Fernando, 2026-10-12]: van en la
  misma tabla `Farm` que las fincas del negocio, con `producer_id`. Cada
  productor tiene las suyas: un nombre se busca **solo entre las fincas de
  ese productor**, sin importar mayúsculas ni espacios; si existe se usa,
  si no se crea (`Farm.for_producer`; en el formulario del productor se
  escriben varias, `Producer#new_farm_names`). En el formulario de la finca
  se elige su productor con el buscador (vacío = del negocio); el dueño
  queda fijo cuando la finca tiene compras o planillas
  (`Farm#owner_locked?`). Nombres únicos entre las del negocio y, aparte, entre las de
  cada productor (dos productores pueden tener «Finca El Paraíso»). En el formulario del
  productor, sus fincas van en un desplegable con «Agregar finca», que pide
  el nombre en una ventanita y la agrega como «(nueva)» hasta guardar
  (`farm_adder_controller.js`, Fernando 2026-10-13). La
  compra puede llevar una finca de su productor (**opcional**,
  `Purchase#farm`), elegida en un desplegable que solo muestra las fincas
  del productor elegido (`producer_farms_controller.js`). El texto viejo
  `producers.farm_name` se convirtió en fincas y se asignó a sus compras
  (`ProducerFarmBackfill`, migración `AssignFarmsToProducers`). En el
  módulo Fincas aparecen con su dueño («Finca X · Ana Zelaya»).
- La factura lleva al pie **dos firmas**: la del cliente (el productor,
  con su nombre debajo) y la del comprador de café (Fernando, 2026-10-16).
- La factura muestra los **QQ** de cada compra y del total
  (`Invoice#quintals` = neto ÷ 125), también en su lista (Fernando,
  2026-10-13).
- Una factura agrupa compras sin facturar **del mismo productor**
  (`InvoiceIssuer`, con bloqueo de filas). Número correlativo con bloqueo
  consultivo (`Invoice::NUMBERING_LOCK_KEY`), mostrado con 4 dígitos.
- Una compra facturada **no se edita ni se borra** (`PurchasePolicy`). Una
  factura no se borra ni se edita.
- **Pago de facturas por abonos** [CONFIRMADO, Fernando, 2026-10-12, por
  observación del cliente: «parte en efectivo y otra pendiente de pago»]:
  una factura se paga con uno o más abonos (`InvoicePayment`: monto, fecha,
  forma de pago, quién registró), cada uno con su recibo imprimible
  (original y copia). Sin abonos está **pendiente**, con abonos que no
  cubren el total a pagar está en **pago parcial** y al cubrirlo pasa a
  **cancelada** (`Invoice#refresh_payment_status!`, que también guarda la
  fecha de pago y la forma: vacía si se usaron varias, «Varias formas»).
  Al facturar se elige pendiente, cancelada o pago parcial con el monto
  pagado (`InvoiceIssuer`, todo o nada). Registrar un abono pide editar en
  `trading`; quitarlo, borrar (`InvoicePaymentPolicy`). Las facturas
  canceladas de antes se migraron a un abono por su total. Decisiones de
  implementación, **pendientes de confirmar**: un abono no pasa del saldo
  ni va antes de la fecha de la factura o del último abono; solo se quita el
  último; el pago con café de una compra facturada solo toma lo que la
  factura todavía debe (`Purchase#available_for_loans`).
- **Cierre diario por estado de pago** (Fernando, 2026-10-14: «que tome en
  cuenta las facturas sin pagar, pagadas e igual las parcialmente
  pagadas»): el dinero del día se separa en **canceladas, con pago
  parcial, pendientes de pago y sin facturar** (`PurchaseSummary::
  PAYMENT_STATES`, `payment_states`), con una barra y, por estado, monto,
  compras y parte del total (`trading/_payment_states`, también en el
  Resumen y en Compras). «Con pago parcial» dice lo abonado y lo que falta
  de sus facturas (`partial_paid`, `partial_balance`: de la factura
  completa, aunque tenga compras de otros días), y el cierre lista esas
  facturas (`DailyClose#partial_invoices`). «Compras del día» y el impreso
  agrupan por los cuatro estados.
- **Cierre diario por productor** [CONFIRMADO, Fernando, 2026-10-12, por
  observación del cliente: «detallar a diario la compra de café de cada
  productor»]: el cierre diario tiene la sección «Por productor»
  (`DailyClose#by_producer`): lo que vendió cada uno ese día, el que más
  vendió primero, con su dinero en facturas canceladas, sin cancelar y sin
  facturar, desplegable con sus compras; también en el impreso. En
  Reportería, el sugerido «Compras de hoy por productor».
- **Ciclo de vida guiado** (`TradingLifecycle`, `shared/_lifecycle`; el
  préstamo tiene el suyo, `LoanLifecycle`): compra registrada →
  facturada → cancelada (pagada), como el flujo que describe el cliente. El
  parcial `trading/_lifecycle` muestra los pasos y el botón del siguiente paso
  en el detalle de compra, el de factura y al facturar. El Resumen del módulo
  tiene el panel "Qué sigue" con el trabajo pendiente de cada paso. La
  retención de fin de temporada no es un paso todavía (punto abierto).
- **Carreros** (`Hauler`, Fernando, 2026-10-16): gente que conoce
  productores con café listo, lo trae con los carros del negocio y lo pesa
  a cuenta del productor. Es un **rol de `Person`** (casilla «Carrero» en
  todo formulario de persona; agregarlo o quitarlo pide crear en
  `trading`), aparte del tipo de productor «Intermediario»
  (`intermediary`; antes se llamaba «Carrero (intermediario)», Fernando
  2026-10-16). **Precio por libra neta obligatorio al crearlo**, editable
  (`trading/haulers`; Fernando, 2026-10-24: «quitar comisión de los
  carreros y poner precio por libra neta nada más»). La compra puede
  llevar su carrero (**opcional**, `Purchase#hauler`) y guarda el precio
  **de ese día** (`hauler_price_per_pound`; cambiar el precio solo cuenta
  para compras nuevas; otro carrero en la compra toma el del nuevo).
  **Comisión = libras netas × precio por libra** (`Hauler.commission`),
  redondeada al centavo; `hauler_commission_controller.js` la muestra como
  vista previa en «Nueva compra». Las compras de antes del cambio
  **conservan su comisión** y su cálculo por latas (libras netas ÷ 16.5 ×
  precio de la lata × %, `Hauler.can_commission`) [CONFIRMADO: solo
  compras nuevas]; cada carrero empezó con el precio equivalente (lata ×
  % ÷ 16.5). **La paga
  el negocio, aparte**: no cambia la factura ni lo que se le paga al
  productor. Se le paga **por saldo acumulado** (comisiones de sus compras
  activas − pagos): cada pago (`HaulerPayment`, pide editar en `trading`)
  tiene su recibo imprimible, original y copia en hojas separadas, y
  guarda el saldo que quedó (`balance_after`) para que el recibo no
  cambie. Salen en «Entradas y salidas de dinero». Decisiones de
  implementación, **pendientes de confirmar**: un pago no pasa del saldo
  ni va antes del último; solo se quita el último; una compra no se anula,
  borra ni cambia de carrero o de peso si eso deja al carrero debiendo lo
  ya pagado; un carrero desactivado no se elige en compras nuevas. Al
  fusionar dos carreros, compras y pagos pasan al que queda.
- **Nueva compra, alrededor del productor** (Fernando, 2026-10-18):
  - **Datos que le faltan a la finca** elegida (extensión, dirección,
    ubicación: `Farm#missing_fields`), con «Completar datos de la finca»
    en un modal sin perder la compra (`farm_gaps_controller.js`,
    `farm:updated`). El botón sale a quien puede editar la finca (Fincas o
    Administración → Fincas); los demás solo ven el aviso.
  - **Un productor sin zona toma la zona de la compra** al registrarla
    (`Purchase#give_zone_to_producer`, en la misma transacción y auditado
    como cambio de la persona); nunca se reemplaza una zona que ya tiene,
    ni al editar una compra. El aviso lo dice («… no tenía zona: quedó en
    …»).
  - «**Nuevo carrero**» junto al campo del carrero (`hauler:created`, que
    trae su porcentaje y precio de la lata).
  - **La ficha del productor** al lado (`trading/producer_cards#show`,
    `record_card_controller.js`): café de la temporada, lo pendiente y, si
    ve Préstamos, lo que debe.
- **Datos que le faltan al productor** (Fernando, 2026-10-12): en «Nueva
  compra», al elegir productor sale un aviso con lo que tiene vacío (DNI,
  RTN, teléfono, correo, zona, dirección, clave IHCAFE:
  `Producer#missing_fields`) y «Completar datos», que abre su formulario
  en un modal sin perder la compra (`producer:updated` actualiza el aviso,
  el nombre y la zona; `producer_gaps_controller.js`). Solo avisa: ninguno
  es obligatorio.
- `bin/rails demo:seed` carga datos **ficticios** (nunca datos reales del
  Excel del cliente).

### Préstamos (`loans`) — fase 1

Reglas decididas por Fernando el 2026-09-28 [CONFIRMADO]:

- Se le presta a **cualquier `Person`** (cliente, colaborador, productor…).
  La persona se elige con el buscador `record_picker_controller.js` y se puede
  crear desde el formulario (`person:created`).
- **Interés simple con tasa mensual definida en cada préstamo**
  (`monthly_interest_rate`; puede ser 0). Corre por día sobre el **capital
  pendiente**: `capital × tasa × días ÷ 30` (`LoanBalance`).
- Un abono paga **primero el interés acumulado** y lo que sobra baja el
  capital. Cada abono guarda su reparto (`interest_amount`,
  `principal_amount`) para que el histórico no cambie si la regla cambia.
- Después de la fecha límite el interés sigue con la misma tasa; **no hay
  recargo por mora** (no está definido).
- Los abonos van en orden de fecha y no superan lo que se debe a esa fecha.
  Al quedar en cero, el préstamo se marca pagado (`paid_off_on`).
- Un préstamo con abonos no se edita ni se borra; un abono no se edita y
  **solo se quita el último** (`LoanPolicy`, `LoanPaymentPolicy`).
- **Score de pago** (`PayerScore`): préstamos pagados completos hasta su
  fecha límite ÷ préstamos ya pagados o vencidos × 100. 85+ Excelente, 70+
  Bueno, 50+ Regular, menos Riesgo; sin préstamos que cuenten, "Sin historial".
- `CreditAccount` arma el estado de cuenta de una persona: totales, sus
  préstamos con saldo a hoy, historial de préstamos y abonos, y score.
- **Insumos** (`Supply`) [CONFIRMADO, Fernando, 2026-10-10]: catálogo del
  módulo (Préstamos → Insumos) con nombre, unidad y precio predeterminado.
  No se borran: se desactivan y dejan de salir al prestar.
- **Préstamos mixtos** [CONFIRMADO]: un préstamo lleva efectivo
  (`cash_amount`, puede ser 0) y líneas de insumos (`LoanSupply`: cantidad ×
  precio unitario). El precio empieza en el predeterminado, se puede cambiar
  y se guarda en la línea. **Capital = efectivo + valor de los insumos**, y
  el interés corre sobre todo el capital. El efectivo vacío cuenta como 0
  (el formulario muestra `0.00` solo como placeholder). El capital no se escribe: lo
  calcula `Loan` (`loan_composition_controller.js` es solo vista previa).
- **Pago con café** [Fernando delegó la regla, 2026-10-10; diseño propuesto
  en esta sesión, pendiente de confirmar]: desde el detalle de una compra se
  abonan o saldan los préstamos de la persona del productor
  (`PurchaseLoanSettlement`, pantalla `trading/loan_settlements`). Reglas:
  - Cada abono es un `LoanPayment` normal con forma de pago "Con café" y
    `purchase_id`: paga interés primero y luego capital, y salda el préstamo
    si cubre todo a esa fecha. Fecha del abono: hoy por defecto, editable.
  - La suma de abonos de una compra no pasa del total de la compra. Se puede
    abonar mientras la compra no esté anulada ni su factura pagada.
  - Todos los abonos de una vez se guardan o ninguno (transacción, bloqueo
    de la compra).
  - Una compra con abonos no se edita, anula ni borra; para cambiarla se
    quita el abono (solo el último de cada préstamo, regla existente).
  - La factura muestra el total de compras, cada abono restado y el **total
    a pagar** al productor. El total de la factura (café comprado) no cambia.
  - Requiere crear en `loans` y ver en `trading`
    (`PurchaseLoanSettlementPolicy`). Sin permiso de préstamos, la compra no
    muestra deudas.

- **Etapas del préstamo** (Fernando, 2026-10-18, como las de la compra):
  préstamo entregado → con abonos → pagado (`LoanLifecycle`, de sus
  abonos y `paid_off_on`), con lo que debe hoy, «Registrar abono» y, si
  pasó la fecha límite, el aviso de vencido. Vencido no es una etapa.
- **Datos que le faltan a la persona** (`Person#missing_fields`, Fernando,
  2026-10-18): Nuevo préstamo y el empleado de planilla avisan, bajo el
  buscador, lo que la persona tiene vacío, con «Completar datos» en un
  modal (`shared/_person_gaps`, `record_gaps_controller.js`,
  `person:updated`); la ficha del préstamo se recarga. Solo avisa.
- **Préstamo tipo intermediario** (Fernando, 2026-10-24) [CONFIRMADO]: la
  casilla «Préstamo tipo intermediario: los primeros 10 días no generan
  interés» (`Loan#interest_grace`) se le puede dar **a cualquier persona**,
  no solo a los productores intermediarios (Fernando, el mismo día). Los
  días 1–10 nunca cobran; desde el día 11 corre normal (`LoanBalance`
  cuenta desde `Loan#interest_starts_on`).
- **Plazo en días** (Fernando, 2026-10-12): el formulario tiene «Plazo
  (días)» entre la fecha del préstamo y la fecha límite. Escribir los días
  llena la fecha límite y elegir la fecha muestra los días
  (`loan_term_controller.js`); se guardan solo las fechas y el detalle
  muestra el plazo (`Loan#term_days`).

- **Ficha de la persona en «Nuevo préstamo»** (Fernando, 2026-10-15): el
  formulario usa todo el ancho y a la derecha (abajo en angosto) lleva la
  tarjeta de la persona elegida (`loans/borrowers#show`, frame
  `borrower-card`, `record_card_controller.js` la recarga en cada
  `record-picker:picked`): contacto, roles y zona; lo que debe hoy, score,
  préstamos por cobrar y vencidos (`CreditAccount`); y, si es productor y
  el usuario ve Compra de café, el café de la temporada y lo pendiente
  (`ProducerProfile`). Pide ver Préstamos (`CreditAccountPolicy`).

- **Recibo de abono**: cada abono tiene su recibo imprimible (original y
  copia, **cada uno en su hoja**, Fernando 2026-10-13) con el saldo que quedó a la fecha del abono. Al
  registrar un abono se abre solo en el modal (`close_modal_with visit:`).

### Fincas (`farms`) — fase 1

Reglas decididas por Fernando el 2026-10-10 [CONFIRMADO]:

- Varias fincas (`Farm`); cada una con muchas planillas (`Payroll`), cada una
  con nombre, fechas (fin opcional) y tipo:
  - **Por día** (`daily`): días de asistencia × salario por día. El salario
    sale del **rol** del empleado en esa planilla (`PayrollRole`) o de su
    **salario propio**, que manda sobre el del rol. La asistencia se marca
    por día: completo (1), medio (½) o ausente (sin registro).
  - **Por obra / tarea** (`task`): el valor de la tarea se divide en **partes
    iguales** entre quienes la hicieron (L 1,000 entre 4 = L 250 c/u); se
    paga en el período de la fecha en que se terminó. El valor es un
    **monto fijo o cantidad × precio** (`PayrollTask#pricing`, Fernando,
    2026-10-16): **por manzana** (las trabajadas, sin pasar de la
    extensión de la finca; si la finca no la tiene, el formulario la pide
    y se guarda en la finca junto con la tarea, todo o nada), **por
    barril** (fumigación, foliar: barriles × precio por barril; los
    litros del barril, 200 por defecto, solo se anotan) o **por abono
    aplicado** (quintales o libras × precio). `task_pricing_controller.js`
    muestra los campos de cada forma y calcula el valor; el servidor
    manda. Una obra puede durar
    un día o unas horas: planilla con la misma fecha de inicio y fin. Los centavos que sobran van uno a uno a los primeros
    por apellido (decisión de implementación).
  - **Corte de café** (`harvest`): latas por empleado por día × precio de la
    lata de la planilla. Las latas van **de cuarto en cuarto** (0.25, 0.50,
    0.75, 1.00, 1.25…; `HarvestEntry::CAN_STEP`, Fernando, 2026-10-12). Los **caporales** no cortan: tienen salario fijo
    por día (Fernando, 2026-10-10). En corte, quien tiene rol o salario
    propio gana por día con asistencia (`PayrollMember#paid_by_day?`), y
    los cortadores van sin rol y ganan por latas. La asistencia se marca
    igual que en la planilla por día (completo, medio, ausente), y las
    pantallas los muestran en grillas separadas. Un empleado con latas no
    pasa a ganar por día, ni al revés. Cada línea de pago guarda cómo se
    ganó (`PayrollPaymentLine#basis`).
- Empleados = personas con rol **Colaborador** (`PayrollMember`).
- **Una persona en varios roles** (Fernando, 2026-10-17: «trabajó como
  chofer por 3 días y luego como jornalero por 2 días»): **solo en
  planillas por día**, la misma persona puede estar varias veces, **una por
  rol** (índice único `payroll_id, person_id, payroll_role_id` con
  `NULLS NOT DISTINCT`: un salario propio sin rol cuenta como un rol más).
  En corte y por obra cada persona va una vez, y una planilla con alguien
  repetido no deja de ser por día. **Un día va en un solo rol**
  (`PayrollAttendance#day_free_in_other_roles`; la asistencia borra antes
  de marcar, así un día se pasa de un rol a otro en un solo guardado).
  «Otro rol» en Empleados abre el formulario con la persona elegida.
  Al pagar, **una tarjeta por persona** con lo de cada rol y sus préstamos
  descontados **una vez, sin pasar de su total**
  (`PayrollPaymentIssuer#person_lines`); la planilla de pago trae **una
  línea por rol** con su firma. Decisión de implementación: el descuento se
  reparte entre sus líneas en orden (ninguna queda bajo cero) y los abonos
  apuntan a su primera línea. La pestaña «Préstamos» la muestra una vez.
  Guía `help_guides.processes.payroll_several_roles`.
- **Períodos** (`PayPeriod`): semanal (cierra el sábado), quincenal (1–15 y
  16–fin de mes) o mensual (fin de mes). El primero empieza en la fecha de
  inicio y el último termina en la de fin. **Un período nunca termina el
  mismo día que empieza** (Fernando: "se paga el sábado lo trabajado durante
  la semana"): una planilla que empieza un sábado paga ese día con el
  sábado siguiente. Solo una planilla que termina ese mismo día (obra de un
  día) tiene un período de un día. Los períodos por venir se listan como
  "Próximo" hasta la fecha de fin (sin fecha de fin, solo el siguiente). El último día de un período es su día de
  pago: desde ese día está "por pagar" (`PayPeriod#due?`).
- **Editar una planilla**: la frecuencia y las fechas se pueden cambiar
  siempre; los períodos pagados se quedan como se pagaron y los que faltan
  se recalculan con la configuración nueva (un período sin pagar que choca
  con uno pagado termina el día antes). Las fechas no pueden dejar fuera
  días con trabajo o pagos registrados, y con pagos el tipo ya no cambia.
  Salarios, roles y precio de la lata cambian lo que se calcula para los
  períodos sin pagar; lo pagado queda guardado.
- **Pago de un período** (`PayrollPaymentIssuer`): guarda lo calculado
  (`PayrollCalculation`) por empleado; al pagar se puede **abonar a
  préstamos** desde el salario, monto manual por préstamo, nunca más de lo
  que gana (abono normal con forma "Descuento de planilla"; requiere crear
  en `loans`). Un período pagado queda cerrado (asistencia, latas y tareas).
  Solo se quita el pago del último período, con sus abonos.
- **Préstamos de los empleados** (Fernando, 2026-10-17): la planilla tiene
  la pestaña «Préstamos» (solo para quien ve Préstamos,
  `Loans::CreditAccountPolicy`): cada empleado con lo que debe hoy, sus
  préstamos por cobrar y vencidos, su score y «Estado de cuenta» en el
  modal (`PayrollLoanFilter`, filas calculadas con `CreditAccount`).
  «Abonar» junto a cada préstamo abre el abono normal (efectivo,
  transferencia o cheque; pide crear en `loans`) con `payroll_id`: al
  guardar vuelve a la pestaña con el recibo abierto. «Pagar período»
  enlaza el estado de cuenta de quien debe. Guía de proceso
  `help_guides.processes.payroll_loans`. No cambia ninguna regla del
  descuento de planilla.
- **Sin séptimo día, décimo, IHSS ni otras deducciones o bonos** por ahora
  (las horas y días extra sí, ver abajo).
- **Gastos** por planilla con fecha, categoría (catálogo `ExpenseCategory`,
  se desactiva, no se borra), descripción y monto. Costo total de la
  planilla = pagado (bruto) + gastos.
- El Resumen del módulo muestra los períodos terminados sin pagar y una
  tarjeta por planilla activa o por iniciar (período de hoy, día de pago,
  lo que lleva, empleados y «Asistencia/Latas de hoy»), la que se paga
  primero arriba.
- **Fincas propias** (Fernando, 2026-10-18): las listas de fincas (Fincas
  y Administración) filtran por dueño: todas, las del negocio («Fincas
  propias») o las de productores (`FarmFilter#owner`).
- **Extensión de la finca** (Fernando, 2026-10-14): opcional, en
  manzanas, hectáreas o metros cuadrados, la que el usuario prefiera; se
  guarda como se escribió (`area_value`, `area_unit`) y las otras se
  calculan (`FarmArea`): **1 manzana = 6,988.96 m²** [CONFIRMADO], 1 ha =
  10,000 m². El formulario tiene una casilla por unidad y al escribir en
  una se llenan las otras (`farm_area_controller.js`, `farms/farms/
  _area_fields`); la lista de fincas la muestra y ordena.
- **Cifras de la finca** (Fernando, 2026-10-14; `FarmProfile`,
  `farms/farms/_profile`): bajo las cuentas de planillas, «Café vendido de
  la finca» (QQ, valor, compras y precio promedio por libra de las compras
  que la nombran; solo para quien ve Compra de café), «Corte de café»
  (latas, pagado por latas, días de corte y cortadores, si tiene
  planillas de corte), «Rendimiento por extensión» (QQ por manzana y
  hectárea, valor y latas por manzana; sin extensión, pide escribirla) y
  «Lo generado contra lo gastado» (valor del café comprado − planillas
  pagadas − gastos, y costo por QQ). Son de todas las fechas; por período
  y para comparar fincas, el reporte **Rendimiento de fincas**
  (`FarmsReport`, pide Fincas y Compra de café).
- **Horas y días extra** (Fernando, 2026-10-14): cada planilla por día o de
  corte tiene, opcional, el **valor de la hora extra**
  (`Payroll#overtime_hour_rate`; no en planillas por obra). En la
  asistencia, al final de la fila de quien gana por día (también los
  caporales del corte), sus **horas extra y días extra del período**
  (`PayrollOvertime`, uno por empleado y período). Horas × valor de la hora
  de la planilla; días × su salario por día; se suman a «A pagar» y al pago
  del período, y la línea de pago guarda horas, valor, días y monto
  (`PayrollPaymentLine#overtime_*`). Sin valor de la hora no se anotan
  horas (la casilla queda cerrada con el aviso). Decisiones de
  implementación, **pendientes de confirmar**: los días extra van de medio
  en medio (como la asistencia) y las horas aceptan cualquier decimal.
- **Grilla de asistencia y latas** con columnas de ancho fijo
  (`timesheet-grid`, `.timesheet-cell`): cada casilla queda centrada bajo
  su día y su total (Fernando, 2026-10-14: «aparecen desalineados»; un
  system spec mide la alineación).
- **Navegación del módulo** (Fernando, 2026-10-13: «hay muchas
  redirecciones y en varias partes no hay manera de regresar»): la finca es
  una **página** (centro de sus planillas), no un modal; se abre con
  «Abrir» o tocando su fila, y su lista de planillas no repite la columna
  «Finca» (`show_farm: false`). Finca, planilla, asistencia/latas, «Pagar
  período» y planilla de pago llevan arriba la ruta **Fincas › finca ›
  planilla › pantalla** (`shared/_breadcrumbs`, `FarmsBreadcrumbsHelper`;
  en el celular, solo «← padre»): una planilla siempre muestra su finca,
  venga de donde venga. Las pestañas de la planilla cambian dentro del
  frame `payroll-tab` sin recargar (la URL sigue). La acción principal de
  la planilla es «Asistencia/Latas de hoy»; en la asistencia, «Pagar este
  período» se resalta al llegar su día de pago y «Ver la planilla»
  regresa; «Pagar período» tiene «Revisar asistencia/latas» y su
  «Cancelar» vuelve a los períodos; la planilla de pago tiene «Volver a
  la planilla». Las cifras de finca y planilla llenan cada fila (sin
  huecos). `shared/_breadcrumbs` sirve para cualquier pantalla con padres.
- **Asistencia en pantalla** (Fernando pidió Fincas más moderna e
  intuitiva, 2026-10-12): cada día es un botón que se toca para pasar de —
  a 1 y a ½ (`day-toggle`, `timesheet_controller.js`; el campo oculto es lo
  que se envía). «Todos» llena un día y «Todo el período» a una persona.
  Se guarda con una barra fija abajo que avisa los cambios sin guardar y
  pregunta antes de salir (`unsaved_changes_controller.js`). El detalle de
  la planilla muestra arriba el período de hoy y filtra los períodos con
  etiquetas de estado (frame `periods-list`); las listas de planillas usan
  filtros en vivo (`farms/payrolls/_live_list`), igual que la pestaña
  Empleados. «Pagar período» deja fecha, totales y botón en una columna
  fija a la derecha. Las tareas eligen a sus participantes con tarjetas
  marcables, «Todos / Ninguno» y cuántas personas van.

### Reportería (`reports`)

Pedido por Fernando el 2026-10-11: reportes globales (no de un módulo) con
gráficos, filtros útiles para el dueño, carga continua, reportes sugeridos y
filtros guardados por usuario. Los reportes solo **resumen datos que el
sistema ya guarda**; no agregan reglas de negocio.

- **Una pantalla** (`reports/reports#show`, `/reports/:key`): arriba se elige
  el reporte, un reporte sugerido o uno de «Mis filtros»; después vienen los
  filtros, las cifras, los gráficos (plegables, abiertos por defecto) y la
  tabla.
- **Un reporte = una clase en `app/reports/`** que hereda de `Report` y
  declara `filter`, `column`, `measure`, `group`, `kpi` y `detail`, y
  define `scope`, `apply_filters` y `charts` con los constructores de la
  base (`over_time`, `over_time_by`, `breakdown`, `pareto`, `age_buckets`,
  `weekday_hours`). Reporte nuevo = su clase + su lugar en `Report.catalog` +
  su parcial de filtros (`reports/reports/filters/_<key>`) + sus textos en
  `reports.types.<key>`.
- Todo se calcula **en la base de datos sobre todos los registros
  filtrados**, no sobre las filas cargadas. Las fechas con hora (compras) se
  agrupan en hora de Tegucigalpa.
- **Período** (`ReportPeriod`): hoy, ayer, esta semana, semana pasada, este
  mes, mes pasado, últimos 30 o 90 días, esta temporada, temporada pasada,
  las últimas 5 temporadas, este año, año pasado, todo o personalizado. Los
  períodos llegan hasta hoy, y **las cifras se comparan con el mismo tramo
  del período anterior** (este mes hasta hoy contra el mes pasado hasta el
  mismo día). Un filtro guardado guarda la clave del período, no las fechas:
  «Este mes» siempre es el mes en curso.
- **Agrupar por** (día, semana, mes, productor, zona, estado, finca…)
  convierte la tabla en sumas por grupo. Los encabezados ordenan.
- **Todo dentro del frame `report`** (`reports/reports#show`): elegir
  reporte, sugerido o «Mis filtros» (`navigate_select_controller.js` con
  `frame`), filtros, orden y agrupar navegan solo ese frame. El título de
  la pestaña lo pone `document_title_controller.js`. La página lleva
  `turbo-cache-control: no-cache` para que atrás/adelante pidan la consulta
  al servidor. Los gráficos van en un contenedor permanente cuyo id depende
  de los filtros sin el orden: ordenar no los recarga.
- **Tabla con carga continua**: 50 filas por página; la siguiente llega como
  turbo stream cuando el botón «Cargar más» se acerca a la pantalla
  (`infinite_scroll_controller.js`). Los gráficos cargan aparte, en su
  propio frame (`reports/reports#charts`), para que la tabla no los espere.
- **Gráficos** (`report_chart_controller.js`): barras, apiladas,
  horizontales, líneas, combinados con segundo eje, Pareto, dona,
  dispersión y mapa de calor (HTML). Bajo cada uno, «Ver los datos» muestra
  sus números.
- **Mapa** (Fernando, 2026-10-13; `Report#locations`, `reports/reports/_map`,
  `report_map_controller.js` con Leaflet): un círculo por persona o finca
  con ubicación (`Report::PLACES`), su área según la cifra del reporte, con
  su nombre y cifra al pasar y «Abrir» su página; abajo, cuántos no salen
  por no tener ubicación. Lo traen compras (la finca de la compra, o el
  productor si la finca no tiene punto), productores, facturas, préstamos
  (abre el estado de cuenta), personas, planillas, latas y gastos (abren la
  finca). Solo dibuja datos guardados; no estima ubicaciones. La demo trae
  puntos ficticios alrededor de Morocelí.
- **Permisos**: un reporte pide ver Reportería **y** ver el módulo de donde
  salen sus datos (`ReportPolicy`, `Report.module_keys`). Personas y
  Entradas y salidas cruzan módulos y piden los tres. Guardar filtros solo
  pide ver Reportería: son de cada usuario y nadie más los ve.
- **Reportes sugeridos** (`ReportPreset`): preguntas frecuentes ya filtradas
  (compras sin facturar, facturas pendientes, préstamos vencidos,
  productores que dejaron de vender…).
- **Exportar**: CSV con todas las filas filtradas (hasta 50,000), con BOM
  para que Excel lea los acentos.
- **Entradas y salidas de dinero**: salen los abonos a facturas (cada uno
  en su fecha), los pagos a carreros, préstamos en efectivo (los insumos no son dinero),
  planillas (lo entregado) y gastos; entran los abonos en efectivo,
  transferencia o cheque (con café o por planilla no se mueve dinero). Las
  ventas de café todavía no existen en el sistema.
- `config/brakeman.ignore` marca como falsos positivos el SQL de la base de
  reportes: el orden y las columnas salen de lo que el reporte declara en
  código, nunca de un parámetro.

## Puntos abiertos

| Punto | Qué bloquea | Quién decide |
| --- | --- | --- |
| Tabla de precios (zona + calidad + bolsa) y categorías de calidad | Precio automático; hoy es manual | Cliente |
| Retención de fin de temporada | Reporte de retención | Cliente |
| Reportes por temporada (qué muestran) | El reporte de temporada que pida el cliente; los reportes generales ya filtran por temporada | Cliente |
| Préstamos: recargo por mora | Mora | Cliente |
| Pago con café: confirmar las reglas propuestas (ver Préstamos) | Ajustes al abono con compra | Fernando / Cliente |
| Abonos a factura: confirmar orden por fecha, quitar solo el último y tope del pago con café (ver Compra de café) | Ajustes a los abonos | Fernando / Cliente |
| Pagos a carreros: confirmar orden por fecha, quitar solo el último y que una compra no deje al carrero debiendo lo ya pagado (ver Carreros) | Ajustes a los pagos de carreros | Fernando / Cliente |
| Inventario de insumos (existencias, costo de compra) | Control de bodega de insumos | Cliente |
| Horas y días extra: confirmar días extra de medio en medio y horas con cualquier decimal | Ajustes a las extras de planilla | Fernando / Cliente |
| Planillas: séptimo día, décimo, IHSS u otras deducciones o bonos | Cálculo legal de planillas | Cliente |
| Si la factura siempre agrupa hasta 4 compras | Hoy no hay límite | Cliente |
| Control financiero: confirmar decisiones de implementación (la cuenta es opcional en los pagos de los otros módulos y obligatoria en gastos e ingresos; el presupuesto solo cuenta los gastos e inversiones de Control financiero, no los gastos de planilla; otros ingresos y transferencias no se editan, se quitan y se registran de nuevo) | Ajustes a Control financiero | Fernando / Cliente |
| Cómo calcula el dueño la ganancia | Reporte de ganancias | Cliente |
| Comercialización: confirmar decisiones de implementación (una salida lleva un solo estado del café y una venta también; salir con más de lo que hay en inventario avisa y no bloquea; la tolerancia resalta la diferencia en ambos sentidos; cobros en orden de fecha, sin pasar del saldo y quitando solo el último; la venta no se edita, se anula y se rehace) | Ajustes a Comercialización | Fernando / Cliente |
| Contratos: moneda, cobro, anticipos del exportador | Ventas / contratos | Cliente |
| Reporte exacto que piden el contador y el SAR | Reportería | Cliente |
| `pg_dump` en Render (versión ≥ 18) | Que el respaldo incluya `base.dump` en producción | Fernando + Render |
| Numeración inicial de facturas (el Excel va por ~2,800) | Hoy empieza en 0001 | Cliente |
| Documentos privados: «Pagaré No.», representante del negocio, lugar de pago, finca, forma de entrega, precio y calidad del café y garantía | Se quedan como línea en blanco para llenar a mano | Cliente |
| Logo y colores (dijeron que tienen) | Pulido visual | Cliente |
| Servicio de correo | Recuperación de contraseña por correo | Fernando |
| Transferencia del workspace de Render al cliente | Pasar a Render de pago (etapa 3) | Fernando + Render |
| Si el despliegue espera a que pasen los tests | Configurar el despliegue (etapa 2) | Fernando |
| Paleta de colores y tipografía | Pulido visual antes de la demo | Fernando |
| Qué pasa si el cliente rechaza el estilo en la demo | — | Fernando |

Resueltos: versión de Ruby (3.4.x), Ubuntu 24.04 LTS, ambiente WSL, regla del
último administrador activo (se bloquea), idioma del código (inglés), campos de
`Person`, personas/clientes/colaboradores en `administration`, formato,
unicidad y obligatoriedad de DNI (13 dígitos) y RTN (14 dígitos): ninguno es
obligatorio. Préstamos fase 1: tasa mensual por préstamo, interés simple
por día sobre saldo, abono a interés y luego capital, score por puntualidad
(Fernando, 2026-09-28). Fincas fase 1: tipos de planilla, roles y salario propio, asistencia por
día, quincena 1–15 / 16–fin de mes, obra en partes iguales, latas por día,
descuento manual a préstamos, gastos con categoría (Fernando, 2026-10-10).
Cálculo por estado del café (uva con rendimiento,
pergamino con humedad 51 %/12 % y daño), QQ = neto ÷ 125, temporada desde el
1 de septiembre y anulación de compras (Fernando, 2026-10-10).

## Etapas del proyecto

1. **Desarrollo** hasta una demo principal **súper básica**. La prioridad es
   avanzar funcionalidad, no infraestructura.
2. **Tras la demo**: montar la app en Render **gratuito**.
3. **App completa, para entregar**: Render **de pago**, a costo del cliente.
