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
| Tests | RSpec (`rspec-rails`), `factory_bot_rails`, `pundit-matchers` |
| Tareas en segundo plano | Ninguna en la fundación. Sin Solid Queue/Cache/Cable. |
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
| Productor / carrero / finca propia | `Producer` (`kind`: `producer` / `intermediary` / `own_farm`) |
| Zona | `Zone` |
| Compra (pesada) | `Purchase` |
| Uva / pergamino húmedo / pergamino seco | `cherry` / `wet_parchment` / `dry_parchment` |
| Humedad / daño / rendimiento | `humidity_percent` / `damage_percent` / `yield_factor` |
| Quintales (QQ) | `quintals` |
| Temporada | `Season` (`season_year` en la compra) |
| Compra anulada | `voided` (`voided_at`, `voided_by`) |
| Factura (recibo al productor) | `Invoice` |
| Cancelada / pendiente de pago (PXP) | `paid` / `pending` |
| Cierre diario | `DailyClose` |
| Préstamo / abono | `Loan` / `LoanPayment` |
| Insumo / insumo del préstamo | `Supply` / `LoanSupply` |
| Préstamo en efectivo / en insumos / mixto | `Loan#kind`: `cash` / `supplies` / `mixed` |
| Pago con café (abonar préstamos con una compra) | `PurchaseLoanSettlement`; abono con `payment_method: "coffee"` |
| Estado de cuenta / historial crediticio | `CreditAccount` |
| Score de pago | `PayerScore` |
| Recibo de abono | `loans/payments#show` (`LoanPayment#display_number`) |
| Finca | `Farm` |
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

## Modelo de permisos

No hay roles fijos: cada usuario recibe, **por módulo**, permisos separados de
ver, crear, editar y borrar.

- `AppModule::KEYS` y `AppModule::ACTIONS` son la lista canónica de módulos y
  acciones. Agregar un módulo = una clave ahí + una entrada en `es.yml` + su
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
(Apellidos), `dni`, `rtn`, `phone`, `email` y dirección (`Addressable`). Solo los nombres y
apellidos son obligatorios. El resto se agrega con migraciones cuando cada
módulo lo pida.

**`dni` tiene 13 dígitos y `rtn` 14, solo números** [CONFIRMADO], y cada uno es **único por
persona** (validación + índice único parcial). Se aceptan con guiones o
espacios y se guardan solo los dígitos. **Ninguno es obligatorio**
[CONFIRMADO]: pueden quedar en blanco.

Los roles se asignan con casillas en el formulario de la persona. Las pantallas
de personas, clientes y colaboradores viven en el módulo `administration` y usan
sus permisos (`PersonPolicy`).

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
| Teléfono | 8 dígitos, `+504` opcional | Solo los 8 dígitos; se muestra `9999-0000` con `format_phone` |
| Correo | Formato de correo | En minúsculas |
| Contraseña | Mínimo 8 caracteres (máx. 72) al crearla o cambiarla; el login no la valida | Cifrada |

Un campo de confirmación usa `confirmation_attributes`: el navegador avisa si
no coincide antes de enviar.

**2. Toda dirección es departamento + municipio + dirección.** El modelo incluye
`Addressable` (columnas `department_id`, `municipality_id`, `address_line`) y
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
español (`shared/_flash`, con `role="alert"` y botón para cerrarla):

| Error | Qué ve el usuario |
| --- | --- |
| Sin permiso, registro inexistente, formulario incompleto | Alerta y vuelve al inicio (páginas) o al formulario (envíos) |
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

**5. Listas, detalles y ventanas.**

- **Modal reutilizable**: el layout tiene un `<dialog>` con el Turbo Frame
  `modal` (`ModalSupport`, `modal_controller.js`). Un enlace con
  `modal_link_to` / `detail_button` abre su página ahí; la página usa el layout
  `modal` sin navegación. `page_link_to` sale del modal a página completa.
  Los modales se apilan: un `modal_link_to` dentro de un modal abre el
  siguiente (`modal_2`, `modal_3`, `ModalSupport::MODAL_FRAMES`) encima, sin
  perder el de abajo (p. ej. "Nueva zona" desde "Nuevo productor").
- Al guardar desde el modal, el controlador llama `close_modal_with`: cierra el
  modal y refresca la página de atrás con el aviso. Si el modal se abrió desde
  un campo (`picker=1`), en vez de refrescar emite un evento de ventana
  (`producer:created`, `zone:created`) y el campo agrega y selecciona la nueva
  opción, sin perder lo ya escrito en el formulario.
- En listas, el detalle se abre con el botón **"Detalle"** en el modal; nunca
  con el id o el nombre subrayado. Los botones "Cancelar" usan `cancel_button`
  (cierra el modal si está dentro de uno).
- **Toda lista tiene filtros y paginación**: una subclase de `ListFilter`
  (`field :q, :text`, `:date`, `:id`, `:choice`) + `render layout:
  "shared/filters"` con `filter_text_field` / `filter_date_field` /
  `filter_select` + `shared/pagination`. Los valores inválidos se ignoran.
  Dentro del bloque de filtros usa claves de traducción completas, no `t(".x")`.
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
  `help_guide_button HelpGuide.process(:nombre), label: true`. Las guías solo
  describen lo que el sistema ya hace; nunca reglas de negocio abiertas.
- **Listas desplegables**: nunca con la primera opción en blanco. Campo
  opcional: "Sin … asignado" (`shared.select.*`). Campo obligatorio: "Selecciona
  …". Filtro: "Todos".

## Comandos

```bash
sudo service postgresql start   # si systemd no está activo en WSL
bin/dev                         # servidor + Tailwind en watch
bundle exec rspec               # suite completa
bundle exec rspec spec/policies # solo políticas
bin/rails db:migrate
bin/rails db:seed               # requiere ADMIN_NAME, ADMIN_EMAIL y ADMIN_PASSWORD
bin/rails demo:seed             # datos ficticios para la demo (no en producción)
bin/rails demo:reports          # un año ficticio de operación (sep 2025 a hoy) para ver los reportes; tarda ~2 min
bin/rubocop
bin/brakeman --no-pager
```

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
- **Componentes de estilo** (úsalos en vez de repetir clases): `btn`,
  `btn-primary`, `btn-sm` (píldoras clay); `nav-pill` / `nav-pill-active`
  (vía `nav_link_class`; dentro de `.subnav` el activo va en tono suave);
  `glass` (encabezado fijo translúcido); `tile` (tarjeta que enlaza, con
  `shared/_tile` e `icon`); `stat` (cifras); `panel` (contenedor plano de
  tablas, detalles y filtros); `data-table`, `data-card`, `cell-actions`;
  `field-label`, `field-input`; `badge` + `badge-success` / `badge-danger` /
  `badge-neutral`; `empty-state`; `link`; `flash-notice` / `flash-alert`;
  `modal`. Los formularios de página completa usan `form_surface_class`.
- Íconos: `icon(:nombre)` (`IconsHelper`), decorativos y ocultos a lectores
  de pantalla; el texto al lado lleva el significado.
- Impresión: `print:` oculta lo interactivo y las tablas se compactan en
  papel; la factura cabe con original y copia en una hoja.
- `raise_on_missing_translations` está activo en desarrollo y test: una clave
  que falte en `es.yml` rompe la página o el spec.
- El nombre del negocio, su ubicación y su logo se configuran en
  Administración → Configuración del sitio (`SiteSetting`, solo
  administradores) y se leen con `business_name`, `business_location` y
  `business_logo` (`SiteHelper`). Mientras no se guarde, salen de
  `es.yml` (`negocio.*`). El logo se guarda en la base (no hay
  almacenamiento de archivos en el servidor), se sirve en `/site_logo`
  (público, por el inicio de sesión) y solo acepta PNG, JPG, WebP o GIF
  de hasta 1 MB, revisados por su contenido; SVG no.
- Locale `:es` únicamente. Zona horaria `America/Tegucigalpa`.

## Módulos

| Clave | Estado |
| --- | --- |
| `administration` | Usuarios y permisos, auditoría y configuración del sitio (solo administradores); personas, clientes y colaboradores (permisos del módulo) |
| `trading` | Demo: zonas, productores (con pestañas y QQ por temporada), compras con cálculo por estado del café y anulación, facturas imprimibles (original y copia) con estado de pago, cierre diario |
| `farms` | Fincas, planillas por día, por obra y de corte por lata, con roles y salarios, asistencia o latas por día, pagos por período (semanal, quincenal, mensual) con descuento a préstamos, planilla de pago imprimible y gastos por planilla |
| `loans` | Préstamos en efectivo, insumos o mixtos a cualquier persona con interés simple, catálogo de insumos, abonos (también con café desde una compra o descontados en planilla) con recibo imprimible, estados de cuenta con historial crediticio y score de pago |
| `reports` | Una pantalla para todos los reportes del sistema (compras, facturas, productores, préstamos, abonos, insumos, planillas, pagos por empleado, latas, gastos, personas y entradas/salidas de dinero) con filtros, cifras comparadas, gráficos, tabla con carga continua, reportes sugeridos, filtros guardados por usuario y exportación CSV |

Cada módulo tiene su namespace de controladores. Implementar una funcionalidad
es llenar su carpeta, no crearla.

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
  pergamino húmedo y 12 % en seco, daño 0 %, rendimiento 0.186 en uva. Al
  cambiar el estado en el formulario se ponen los del nuevo estado y se
  ocultan los campos que no aplican. Al cambiar de productor, la zona pasa a
  la del nuevo productor.
- **Temporada** (`Season`) [CONFIRMADO]: empieza cada 1 de septiembre y
  lleva el año en que empieza (la 2026 va del 2026-09-01 al 2027-08-31).
  Cada compra guarda su `season_year`, calculado de la fecha de compra.
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
- La página del productor tiene cifras fijas (QQ, compras y total de la
  temporada, QQ de todas) y pestañas: compras (por temporada), facturas y
  datos personales.
- En "Facturar compras" se puede anular una compra o registrar una nueva para
  ese productor en un modal; al guardar, la lista se refresca.
- Una factura agrupa compras sin facturar **del mismo productor**
  (`InvoiceIssuer`, con bloqueo de filas). Número correlativo con bloqueo
  consultivo (`Invoice::NUMBERING_LOCK_KEY`), mostrado con 4 dígitos.
- Una compra facturada **no se edita ni se borra** (`PurchasePolicy`). Una
  factura no se borra; solo pasa de pendiente a cancelada.
- **Ciclo de vida guiado** (`TradingLifecycle`): compra registrada →
  facturada → cancelada (pagada), como el flujo que describe el cliente. El
  parcial `trading/_lifecycle` muestra los pasos y el botón del siguiente paso
  en el detalle de compra, el de factura y al facturar. El Resumen del módulo
  tiene el panel "Qué sigue" con el trabajo pendiente de cada paso. La
  retención de fin de temporada no es un paso todavía (punto abierto).
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

- **Recibo de abono**: cada abono tiene su recibo imprimible (original y
  copia en una hoja) con el saldo que quedó a la fecha del abono. Al
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
    paga en el período de la fecha en que se terminó. Una obra puede durar
    un día o unas horas: planilla con la misma fecha de inicio y fin. Los centavos que sobran van uno a uno a los primeros
    por apellido (decisión de implementación).
  - **Corte de café** (`harvest`): latas por empleado por día × precio de la
    lata de la planilla. Los **caporales** no cortan: tienen salario fijo
    por día (Fernando, 2026-10-10). En corte, quien tiene rol o salario
    propio gana por día con asistencia (`PayrollMember#paid_by_day?`), y
    los cortadores van sin rol y ganan por latas. La asistencia se marca
    igual que en la planilla por día (completo, medio, ausente), y las
    pantallas los muestran en grillas separadas. Un empleado con latas no
    pasa a ganar por día, ni al revés. Cada línea de pago guarda cómo se
    ganó (`PayrollPaymentLine#basis`).
- Empleados = personas con rol **Colaborador** (`PayrollMember`).
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
- **Sin séptimo día, décimo, IHSS ni otras deducciones o bonos** por ahora.
- **Gastos** por planilla con fecha, categoría (catálogo `ExpenseCategory`,
  se desactiva, no se borra), descripción y monto. Costo total de la
  planilla = pagado (bruto) + gastos.
- El Resumen del módulo muestra los períodos terminados sin pagar.

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
- **Tabla con carga continua**: 50 filas por página; la siguiente llega como
  turbo stream cuando el botón «Cargar más» se acerca a la pantalla
  (`infinite_scroll_controller.js`). Los gráficos cargan aparte, en su
  propio frame (`reports/reports#charts`), para que la tabla no los espere.
- **Gráficos** (`report_chart_controller.js`): barras, apiladas,
  horizontales, líneas, combinados con segundo eje, Pareto, dona,
  dispersión y mapa de calor (HTML). Bajo cada uno, «Ver los datos» muestra
  sus números.
- **Permisos**: un reporte pide ver Reportería **y** ver el módulo de donde
  salen sus datos (`ReportPolicy`, `Report.module_keys`). Personas y
  Entradas y salidas cruzan módulos y piden los tres. Guardar filtros solo
  pide ver Reportería: son de cada usuario y nadie más los ve.
- **Reportes sugeridos** (`ReportPreset`): preguntas frecuentes ya filtradas
  (compras sin facturar, facturas pendientes, préstamos vencidos,
  productores que dejaron de vender…).
- **Exportar**: CSV con todas las filas filtradas (hasta 50,000), con BOM
  para que Excel lea los acentos.
- **Entradas y salidas de dinero**: salen facturas canceladas (total menos
  abonos con café), préstamos en efectivo (los insumos no son dinero),
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
| Inventario de insumos (existencias, costo de compra) | Control de bodega de insumos | Cliente |
| Planillas: séptimo día, décimo, IHSS u otras deducciones o bonos | Cálculo legal de planillas | Cliente |
| Si la factura siempre agrupa hasta 4 compras | Hoy no hay límite | Cliente |
| 160 lb/saco en salidas vs. 165 en compras | Salidas de camión | Cliente |
| Contratos: moneda, cobro, anticipos del exportador | Ventas / contratos | Cliente |
| Reporte exacto que piden el contador y el SAR | Reportería | Cliente |
| Numeración inicial de facturas (el Excel va por ~2,800) | Hoy empieza en 0001 | Cliente |
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
