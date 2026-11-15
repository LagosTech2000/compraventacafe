# Programa del lector de huella (FingerprintBridge)

Programa de Windows 11 (64 bits) para la PC que tiene el lector **ZKTeco ZK9500**.
Vive junto al reloj (bandeja del sistema) y hace de puente entre el lector y el sistema:

- Carga en la memoria del lector las huellas registradas y, cuando alguien pone
  un dedo, le dice al sistema quién es (1:N). El navegador de esa PC abre su panel
  o llena el campo de persona de la página.
- Cuando un administrador pide «Registrar huella» desde el navegador de esa PC,
  toma el dedo 3 veces, junta las lecturas y manda la plantilla (nunca la imagen).
- Dice si el lector está conectado («Lector listo» abajo a la izquierda en el sistema).

Usa el `libzkfp.dll` que instala el **ZKFinger SDK 5.x** en `C:\Windows\System32`:
ningún archivo del SDK va en este repositorio.

## Compilar

Con el SDK de .NET 8 (en Windows: `winget install Microsoft.DotNet.SDK.8`; en
WSL: `sudo apt install dotnet-sdk-8.0`):

```
cd tools/fingerprint_bridge
dotnet publish -c Release
```

Sale un solo archivo, `bin/Release/net8.0-windows/win-x64/publish/FingerprintBridge.exe`,
que no necesita instalar .NET en la PC del lector.

## Carpeta para instalar en otra PC

```
tools/fingerprint_bridge/package.sh
```

Compila el programa y arma `tools/fingerprint_bridge/instalador/` (fuera de git):
`1-ZKFinger-SDK/setup.exe` (el driver, copiado de las Descargas de Windows o de la
carpeta que se le pase), `2-FingerprintBridge.exe` y `LEEME.txt` con los pasos. Se copia
completa a la PC del lector.

## Instalar en la PC del lector

1. Instala el ZKFinger SDK (como administrador) y conecta el ZK9500. En PowerShell,
   `Get-PnpDevice | ? InstanceId -like '*VID_1B55*'` debe decir `Status: OK`.
2. Copia `FingerprintBridge.exe` a `C:\Program Files\FingerprintBridge\` (o donde quieras)
   y ábrelo. Windows puede avisar «Windows protegió su PC» (no está firmado):
   «Más información → Ejecutar de todas formas».
3. En el navegador de esa PC, entra como administrador a **Administración → Lectores de
   huella → Agregar lector**. Ese navegador queda enlazado y la página da un código de
   6 números (vence en 15 minutos).
4. En la ventana del programa escribe la dirección del sistema (con `https://`) y el código.
5. Abajo a la izquierda del sistema debe decir **«Lector listo»**.

El programa arranca solo con Windows (menú del ícono → «Iniciar con Windows»).
Otro navegador de la misma PC se enlaza desde la página del lector con «Usar en este navegador».

## Probar contra el sistema en WSL

Con `bin/dev` corriendo en WSL, en la ventana del programa escribe
`http://localhost:3000` (WSL comparte `localhost` con Windows). El resto es igual.

## Si algo falla

El programa escribe lo que pasa en `%APPDATA%\FingerprintBridge\bridge.log`; ahí también
está `settings.json` (la llave del lector va cifrada para ese usuario de Windows).

| Lo que pasa | Qué revisar |
| --- | --- |
| «Programa del lector apagado» en el sistema | Que el programa esté abierto (ícono junto al reloj) y la PC tenga internet. |
| «Lector desconectado» | El cable USB, otro puerto, y que el SDK esté instalado. |
| «No se encontró libzkfp.dll» en el log | Reinstala el ZKFinger SDK como administrador. |
| «El sistema rechazó el lector» en el log | El lector se desactivó o se emparejó otro: pide un código nuevo y empareja otra vez. |
