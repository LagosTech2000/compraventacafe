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
5. **El desarrollo ocurre dentro de WSL (Ubuntu)**, en `~/code/compraventacafe`,
   nunca en `/mnt/c` ni en OneDrive. Sin Docker.

## Fuentes de verdad

| Documento | Qué define | Dónde |
| --- | --- | --- |
| Contexto técnico — Sistema de café | Decisiones técnicas, versiones y puntos abiertos | `claude.ai/code/artifact/6e691138-7661-4021-b95d-90f906d32172` |
| `docs/CONTEXTO_CAFE_REY_DAVID.md` | Negocio: cuestionario del cliente + su Excel `COSECHA_2026L.xlsm`. Cada dato etiquetado `[VERIFICADO]`, `[CALCULADO]` o `[DESCONOCIDO]` | En el repo. **No se construye sobre un `[DESCONOCIDO]`.** |
| `docs/PREGUNTAS_CLIENTE.md` | Cuestionario enviado al cliente | En el repo |
| `docs/AMBIENTE.md` | Cómo montar y operar el ambiente | En el repo |

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
| Compra y venta de café | `trading` |
| Fincas | `farms` |
| Préstamos | `loans` |
| Reportería | `reports` |
| Productor / carrero / finca propia | `Producer` (`kind`: `producer` / `intermediary` / `own_farm`) |
| Zona | `Zone` |
| Compra (pesada) | `Purchase` |
| Uva / pergamino húmedo / pergamino seco | `cherry` / `wet_parchment` / `dry_parchment` |
| Factura (recibo al productor) | `Invoice` |
| Cancelada / pendiente de pago (PXP) | `paid` / `pending` |
| Cierre diario | `DailyClose` |

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
`HondurasDivisions.load!`, que corre en una migración y antes de la suite de
tests. Son datos de referencia: los nombres de lugares son la única excepción
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

## Comandos

```bash
sudo service postgresql start   # si systemd no está activo en WSL
bin/dev                         # servidor + Tailwind en watch
bundle exec rspec               # suite completa
bundle exec rspec spec/policies # solo políticas
bin/rails db:migrate
bin/rails db:seed               # requiere ADMIN_EMAIL y ADMIN_PASSWORD
bin/rails demo:seed             # datos ficticios para la demo (no en producción)
bin/rubocop
bin/brakeman --no-pager
```

El primer administrador se crea con `db:seed` leyendo `ADMIN_EMAIL` y
`ADMIN_PASSWORD` del entorno. Nunca se escriben credenciales en el repo.

## Interfaz

- Responsive desde el inicio, en todas las pantallas.
- Estilo híbrido: *clay* (esquinas muy redondeadas, dos sombras) en navegación,
  tarjetas y botones; tablas y formularios de datos **planos**, porque el sistema
  maneja tablas de dinero, planillas y reportes.
- La paleta vive como tokens `@theme` en `app/assets/tailwind/application.css`.
  Es el único lugar a editar cuando se defina la paleta real; la actual es
  provisional. Clases de apoyo: `clay`, `btn`, `btn-primary`, `data-table`,
  `field-label`, `field-input`.
- `raise_on_missing_translations` está activo en desarrollo y test: una clave
  que falte en `es.yml` rompe la página o el spec.
- El nombre del negocio se lee con `t("negocio.nombre")`. Un solo lugar.
- Locale `:es` únicamente. Zona horaria `America/Tegucigalpa`.

## Módulos

| Clave | Estado |
| --- | --- |
| `administration` | Usuarios y permisos (solo administradores); personas, clientes y colaboradores (permisos del módulo) |
| `trading` | Demo: zonas, productores, compras con cálculo automático, facturas imprimibles (original y copia) con estado de pago, cierre diario |
| `farms` | Portada vacía |
| `loans` | Portada vacía |
| `reports` | Portada vacía |

Cada módulo tiene su namespace de controladores. Implementar una funcionalidad
es llenar su carpeta, no crearla.

### Compra y venta (`trading`)

- **Cálculo de la compra**: `PurchaseCalculation`, copia exacta de la macro
  actual del cliente (tara de 1 lb por saco de 165 lb, redondeado hacia
  arriba; se descuenta la humedad). Se guarda el resultado en la compra para
  que el histórico no cambie si la regla cambia. `purchase_calculator_controller.js`
  lo replica solo como vista previa; el servidor manda.
- Humedad por defecto 51 % (`PurchaseDefaults`), editable.
- Una factura agrupa compras sin facturar **del mismo productor**
  (`InvoiceIssuer`, con bloqueo de filas). Número correlativo con bloqueo
  consultivo (`Invoice::NUMBERING_LOCK_KEY`), mostrado con 4 dígitos.
- Una compra facturada **no se edita ni se borra** (`PurchasePolicy`). Una
  factura no se borra; solo pasa de pendiente a cancelada.
- `bin/rails demo:seed` carga datos **ficticios** (nunca datos reales del
  Excel del cliente).

## Puntos abiertos

| Punto | Qué bloquea | Quién decide |
| --- | --- | --- |
| Cálculo según estado del café (uva / húmedo / seco) y si el 51 % es fijo o medido | Ajustar `PurchaseCalculation` | Cliente |
| Si se sigue descontando **daño** y cómo se mide | `PurchaseCalculation` | Cliente |
| Tabla de precios (zona + calidad + bolsa) y categorías de calidad | Precio automático; hoy es manual | Cliente |
| Retención de fin de temporada | Reporte de retención | Cliente |
| Préstamos/adelantos: tasa, periodo, cómo se descuentan de la compra | Módulo `loans` y descuento al pagar | Cliente |
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
obligatorio.

## Etapas del proyecto

1. **Desarrollo** hasta una demo principal **súper básica**. La prioridad es
   avanzar funcionalidad, no infraestructura.
2. **Tras la demo**: montar la app en Render **gratuito**.
3. **App completa, para entregar**: Render **de pago**, a costo del cliente.
