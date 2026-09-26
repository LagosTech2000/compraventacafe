#!/usr/bin/env bash
#
# bootstrap.sh - Prepara el ambiente de desarrollo dentro de WSL (Ubuntu).
#
# Instala dependencias de compilacion, mise, Ruby 3.4.x, PostgreSQL 18,
# Node 22, Claude Code, Bundler, Rails 8.1 y GitHub CLI.
#
# Es idempotente: se puede volver a correr sin danar nada.
#
#   Uso:  bash scripts/bootstrap.sh
#
# Requisitos previos (fuera de este script):
#   - WSL2 + Ubuntu 24.04 LTS instalados desde Windows.
#   - Este repositorio clonado en el sistema de archivos de Linux (~/code/...),
#     NO en /mnt/c: OneDrive sincroniza tmp/ y log/ y el IO cruzado es lento.
#
set -euo pipefail

RUBY_SERIES="3.4"
RAILS_REQUIREMENT="~> 8.1.3"
PG_MAJOR="18"
NODE_MAJOR="22"
TIMEZONE="America/Tegucigalpa"
GIT_NAME="LagosTech2000"
GIT_EMAIL="fernandolagos2016@gmail.com"

MISE_BIN="$HOME/.local/bin/mise"
MISE_SHIMS="$HOME/.local/share/mise/shims"

# ------------------------------------------------------------------ utilidades

paso()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '    \033[0;32mok\033[0m  %s\n' "$*"; }
aviso() { printf '    \033[0;33m!!\033[0m  %s\n' "$*"; }
fatal() { printf '\n\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

hay() { command -v "$1" >/dev/null 2>&1; }

systemd_activo() { [ -d /run/systemd/system ]; }

mise_run() { "$MISE_BIN" exec -- "$@"; }

# -------------------------------------------------------------- comprobaciones

paso "Comprobando el entorno"

if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version; then
  ok "corriendo dentro de WSL"
else
  aviso "no parece WSL; el script sigue, pero fue escrito para Ubuntu en WSL"
fi

case "$PWD" in
  /mnt/*)
    aviso "estas en $PWD (disco de Windows)"
    aviso "muevete a ~/code/ antes de crear la app: OneDrive corrompe tmp/ y log/"
    ;;
  *)
    ok "ruta en el sistema de archivos de Linux: $PWD"
    ;;
esac

hay lsb_release && ok "$(lsb_release -ds)"

# --------------------------------------------------------- systemd persistente

paso "Asegurando systemd en WSL (para que PostgreSQL arranque solo)"

if systemd_activo; then
  ok "systemd ya esta corriendo"
elif [ -f /etc/wsl.conf ] && grep -q 'systemd=true' /etc/wsl.conf; then
  aviso "/etc/wsl.conf ya pide systemd, pero aun no esta activo"
  aviso "corre 'wsl --shutdown' en PowerShell y vuelve a entrar a Ubuntu"
else
  printf '[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
  ok "systemd habilitado en /etc/wsl.conf"
  aviso "corre 'wsl --shutdown' en PowerShell y vuelve a entrar para activarlo"
  aviso "mientras tanto PostgreSQL se arranca con: sudo service postgresql start"
fi

# ------------------------------------------------------------ paquetes del SO

paso "Actualizando indices de paquetes"
sudo apt-get update -qq
ok "apt actualizado"

paso "Instalando dependencias de compilacion"
sudo apt-get install -y -qq \
  build-essential git curl gnupg ca-certificates \
  libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgmp-dev \
  pkg-config autoconf bison tzdata
ok "dependencias base instaladas"

if systemd_activo; then
  if sudo timedatectl set-timezone "$TIMEZONE" 2>/dev/null; then
    ok "zona horaria: $TIMEZONE"
  else
    aviso "no se pudo fijar la zona horaria"
  fi
fi

# ------------------------------------------------------------------------ mise

paso "Instalando mise (gestor de versiones de Ruby y Node)"

if [ -x "$MISE_BIN" ]; then
  ok "mise ya instalado: $("$MISE_BIN" --version)"
else
  curl -fsSL https://mise.run | sh
  [ -x "$MISE_BIN" ] || fatal "mise no quedo en $MISE_BIN"
  ok "mise instalado: $("$MISE_BIN" --version)"
fi

if grep -q 'mise activate bash' "$HOME/.bashrc" 2>/dev/null; then
  ok "mise ya estaba activado en ~/.bashrc"
else
  {
    printf '\n'
    printf '# mise: gestor de versiones de Ruby/Node (scripts/bootstrap.sh)\n'
    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    printf 'eval "$(mise activate bash)"\n'
  } >> "$HOME/.bashrc"
  ok "mise activado en ~/.bashrc"
fi

export PATH="$HOME/.local/bin:$MISE_SHIMS:$PATH"

# ------------------------------------------------------------------------ Ruby

paso "Instalando Ruby ${RUBY_SERIES}.x"

RUBY_VERSION="$("$MISE_BIN" ls-remote ruby 2>/dev/null \
  | grep -E "^${RUBY_SERIES}\.[0-9]+\$" | tail -1 || true)"

[ -n "$RUBY_VERSION" ] \
  || fatal "no pude resolver el ultimo parche de Ruby ${RUBY_SERIES}.x"
ok "ultimo parche disponible: ruby $RUBY_VERSION"

"$MISE_BIN" use --global "ruby@${RUBY_VERSION}"
"$MISE_BIN" reshim >/dev/null 2>&1 || true
ok "$(mise_run ruby -v)"

# Render lee .ruby-version para elegir el runtime nativo.
if [ -f .ruby-version ] && [ "$(cat .ruby-version)" = "$RUBY_VERSION" ]; then
  ok ".ruby-version ya estaba en $RUBY_VERSION"
else
  printf '%s\n' "$RUBY_VERSION" > .ruby-version
  ok ".ruby-version fijado en $RUBY_VERSION"
fi

# ------------------------------------------------------------------ PostgreSQL

paso "Instalando PostgreSQL ${PG_MAJOR}"

if hay psql && psql --version | grep -q " ${PG_MAJOR}\."; then
  ok "$(psql --version) ya instalado"
else
  sudo apt-get install -y -qq postgresql-common
  sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    "postgresql-${PG_MAJOR}" "postgresql-client-${PG_MAJOR}" libpq-dev
  ok "$(psql --version) instalado desde PGDG"
fi

paso "Arrancando PostgreSQL"
if systemd_activo; then
  sudo systemctl enable --now postgresql
  ok "postgresql habilitado y corriendo bajo systemd"
else
  sudo service postgresql start || true
  ok "postgresql arrancado con 'service' (hay que repetirlo en cada sesion)"
fi

paso "Creando el rol de base de datos para $USER"
# Un rol superusuario con el mismo nombre que el usuario Linux permite que
# database.yml conecte por socket Unix con autenticacion peer: cero
# contrasenas en el repositorio, que es requisito del proyecto.
if sudo -u postgres psql -tAc \
     "SELECT 1 FROM pg_roles WHERE rolname='${USER}'" | grep -q 1; then
  ok "el rol '$USER' ya existe"
else
  sudo -u postgres createuser -s "$USER"
  ok "rol superusuario '$USER' creado"
fi

if sudo -u postgres psql -tAc \
     "SELECT 1 FROM pg_database WHERE datname='${USER}'" | grep -q 1; then
  ok "la base personal '$USER' ya existe"
elif createdb "$USER" 2>/dev/null; then
  ok "base personal '$USER' creada (permite usar 'psql' a secas)"
else
  aviso "no se pudo crear la base personal; no es critico"
fi

# ----------------------------------------------------------- Node + Claude Code

paso "Instalando Node ${NODE_MAJOR}"
# La app no necesita Node: tailwindcss-rails usa el binario standalone de
# Tailwind e importmap no compila nada. Node es solo para Claude Code.
"$MISE_BIN" use --global "node@${NODE_MAJOR}"
"$MISE_BIN" reshim >/dev/null 2>&1 || true
ok "node $(mise_run node -v)"

paso "Instalando Claude Code"
if mise_run npm ls -g --depth=0 2>/dev/null | grep -q '@anthropic-ai/claude-code'; then
  ok "claude-code ya instalado"
else
  mise_run npm install -g @anthropic-ai/claude-code
  "$MISE_BIN" reshim >/dev/null 2>&1 || true
  ok "claude-code instalado"
fi

# ------------------------------------------------------------- Bundler y Rails

paso "Instalando Bundler y Rails ${RAILS_REQUIREMENT}"
mise_run gem install bundler --no-document
mise_run gem install rails --no-document -v "$RAILS_REQUIREMENT"
"$MISE_BIN" reshim >/dev/null 2>&1 || true
ok "$(mise_run rails -v)"

# ------------------------------------------------------------------- git y gh

paso "Configurando git"
git config --global --get user.email >/dev/null 2>&1 \
  || git config --global user.email "$GIT_EMAIL"
git config --global --get user.name >/dev/null 2>&1 \
  || git config --global user.name "$GIT_NAME"
git config --global init.defaultBranch main
git config --global core.autocrlf false
ok "git: $(git config --global user.name) <$(git config --global user.email)>"

paso "Instalando GitHub CLI"
if hay gh; then
  ok "$(gh --version | head -1) ya instalado"
elif sudo apt-get install -y -qq gh; then
  ok "gh instalado"
else
  aviso "gh no esta en los repos; ver https://cli.github.com"
fi

if hay gh && ! gh auth status >/dev/null 2>&1; then
  aviso "gh sin autenticar. Corre: gh auth login"
fi

# --------------------------------------------------------------------- resumen

paso "Resumen"
printf '    ruby       %s\n' "$(mise_run ruby -e 'print RUBY_VERSION')"
printf '    rails      %s\n' "$(mise_run rails -v | awk '{print $2}')"
printf '    bundler    %s\n' "$(mise_run bundler -v | awk '{print $3}')"
printf '    postgres   %s\n' "$(psql --version | awk '{print $3}')"
printf '    node       %s\n' "$(mise_run node -v)"
if systemd_activo; then
  printf '    systemd    activo\n'
else
  printf '    systemd    inactivo - falta wsl --shutdown\n'
fi

printf '\n'
printf 'Listo. Abre una terminal NUEVA (para que mise entre al PATH) y sigue con:\n\n'
printf '    cd ~/code/compraventacafe\n'
printf '    claude\n\n'
printf 'Si systemd aparece inactivo, corre "wsl --shutdown" en PowerShell y\n'
printf 'vuelve a entrar a Ubuntu antes de continuar.\n'
