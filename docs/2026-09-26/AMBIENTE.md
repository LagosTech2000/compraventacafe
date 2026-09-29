# Montaje del ambiente de desarrollo

Sistema de compra y venta de café. Este documento cubre **solo** cómo dejar la
máquina lista para trabajar. Las decisiones técnicas viven en el doc
*Contexto técnico — Sistema de café*.

El desarrollo ocurre **dentro de WSL (Ubuntu)**, no en Windows nativo, y **sin
Docker**.

| Pieza | Versión |
| --- | --- |
| Windows | 11 Home Single Language |
| WSL | WSL2 con Ubuntu 24.04 LTS |
| Ruby | 3.4.x (último parche de la rama) |
| Rails | 8.1.x |
| PostgreSQL | 18 (repositorio PGDG) |
| Node | 22 (solo para Claude Code) |
| Gestor de versiones | mise |

---

## Fase 0 — Instalar WSL2 + Ubuntu

Esto requiere permisos de administrador y un reinicio de Windows, así que se
corre a mano.

Abre **Windows Terminal como administrador** y ejecuta:

```powershell
wsl --list --online
wsl --install -d Ubuntu-24.04
```

El primer comando confirma qué versiones LTS ofrece Microsoft; si `Ubuntu-24.04`
no aparece con ese nombre exacto, usa el nombre que sí liste.

**Reinicia Windows.** Al primer arranque de Ubuntu te pedirá un usuario y
contraseña UNIX (sugerido: `ferna`). Esa contraseña es la de `sudo`; anótala.

Comprobación desde PowerShell:

```powershell
wsl -l -v
```

Debe mostrar `Ubuntu-24.04` en estado `Running` o `Stopped`, con `VERSION 2`.

---

## Fase 1 — Toolchain dentro de Ubuntu

Abre Ubuntu y clona el repositorio en el sistema de archivos de Linux:

```bash
mkdir -p ~/code && cd ~/code
git clone https://github.com/LagosTech2000/compraventacafe.git
cd compraventacafe
```

> **No trabajes desde `/mnt/c/...`.** OneDrive sincroniza `tmp/`, `log/` y
> `storage/` y bloquea archivos con el servidor corriendo; además el acceso de
> WSL al disco de Windows es varias veces más lento y pierde los bits de
> permiso en git. El respaldo real del proyecto es GitHub, no OneDrive.

Ejecuta el script de instalación:

```bash
bash scripts/bootstrap.sh
```

Instala, de forma idempotente: dependencias de compilación, mise, Ruby 3.4.x,
PostgreSQL 18, Node 22, Claude Code, Bundler, Rails 8.1 y GitHub CLI. También
habilita `systemd` en `/etc/wsl.conf` para que PostgreSQL arranque solo.

Si el resumen final dice que systemd está inactivo, desde PowerShell:

```powershell
wsl --shutdown
```

Y vuelve a entrar a Ubuntu. Sin systemd hay que arrancar la base a mano en cada
sesión con `sudo service postgresql start`.

Autentica GitHub para poder empujar sin pegar tokens:

```bash
gh auth login
```

### Comprobación de la Fase 1

En una terminal **nueva** (para que mise esté en el `PATH`):

```bash
ruby -v        # 3.4.x
rails -v       # 8.1.x
psql --version # 18.x
node -v        # v22.x
claude --version
psql -l        # lista las bases: el servidor responde por socket
```

---

## Fase 2 — Archivar la copia en OneDrive

Para no editar por error la copia vieja, renómbrala desde Windows:

```
C:\Users\ferna\OneDrive\Documentos\RUBY ON RAILS\compraventacafe
  →  ...\compraventacafe-archivo-windows
```

No la borres hasta confirmar que todo corre bien en WSL.

---

## Fase 3 — Trabajar

Desde Ubuntu:

```bash
cd ~/code/compraventacafe
claude
```

Esa sesión lee `CLAUDE.md` y continúa con la construcción de la fundación.

---

## Operación diaria

```bash
cd ~/code/compraventacafe

# La base, si systemd no está activo:
sudo service postgresql start

bin/dev                 # servidor + Tailwind en modo watch
bundle exec rspec       # suite de pruebas
bin/rubocop             # estilo
bin/brakeman --no-pager # análisis de seguridad
```

La app queda en `http://localhost:3000`, accesible desde el navegador de
Windows: WSL2 reenvía `localhost` automáticamente.

---

## Problemas conocidos

**`psql: could not connect to server`** — PostgreSQL no está corriendo.
Con systemd: `sudo systemctl start postgresql`. Sin systemd:
`sudo service postgresql start`.

**`ruby: command not found` en una terminal nueva** — mise no se activó.
Verifica que `~/.bashrc` tenga `eval "$(mise activate bash)"` y abre otra
terminal.

**Un script `.sh` falla con `\r: command not found`** — llegó con finales de
línea CRLF. El `.gitattributes` del repo lo previene; si pasa, revisa que
`git config core.autocrlf` sea `false` dentro de WSL y vuelve a clonar.

**`localhost:3000` no responde desde Windows** — arranca el servidor con
`bin/dev` (Rails 8 escucha en todas las interfaces por defecto en desarrollo).
Si persiste, `wsl --shutdown` y reintenta.

**FATAL: role does not exist** — el rol de PostgreSQL con tu nombre de usuario
Linux no se creó. Corre de nuevo `bash scripts/bootstrap.sh`.
