#!/usr/bin/env bash
# Arma la carpeta para instalar el lector de huella en otra PC
# (tools/fingerprint_bridge/instalador/, fuera de git): el programa
# compilado, el instalador del ZKFinger SDK y LEEME.txt. Ni el programa
# compilado ni el SDK van al repositorio (es público).
#
#   tools/fingerprint_bridge/package.sh [carpeta del ZKFinger SDK]
#
# Sin argumento busca el SDK en las Descargas de Windows. Necesita el SDK
# de .NET 8 de Microsoft en ~/.dotnet-ms (el de apt no trae WindowsDesktop).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/instalador"
sdk="${1:-$(find /mnt/c/Users/*/Downloads -maxdepth 4 -type d -name 'ZKFinger Standard SDK*' 2>/dev/null | head -1 || true)}"
dotnet_root="${DOTNET_ROOT:-$HOME/.dotnet-ms}"

if [ -z "$sdk" ] || [ ! -f "$sdk/setup.exe" ]; then
  echo "No encontré el setup.exe del ZKFinger SDK. Pasa su carpeta: $0 \"/mnt/c/.../ZKFinger Standard SDK 5.3.0.33\"" >&2
  exit 1
fi

echo "Compilando el programa del lector..."
(cd "$here" && DOTNET_ROOT="$dotnet_root" "$dotnet_root/dotnet" publish -c Release --nologo -v quiet)

rm -rf "$out"
mkdir -p "$out/1-ZKFinger-SDK"
cp "$sdk/setup.exe" "$out/1-ZKFinger-SDK/setup.exe"
cp "$here/bin/Release/net8.0-windows/win-x64/publish/FingerprintBridge.exe" "$out/2-FingerprintBridge.exe"
sed 's/$/\r/' "$here/package/LEEME.txt" > "$out/LEEME.txt"

echo "Listo: $out"
ls -la "$out"
