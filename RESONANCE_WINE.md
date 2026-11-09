# FINAL FANTASY RESONANCE con NotProton

Configuración para FINAL FANTASY RESONANCE (Steam App ID `3259780`) en Steam para macOS. Con estos ajustes el juego superó el aviso de Visual C++ y abrió con Retina desactivado el 8 de noviembre de 2026.

## Instalación guiada desde cero

Descomprime el paquete completo, o descarga la rama `wine-runtime-lab` de este fork. En un Mac con Apple Silicon y macOS 15 o posterior, abre `Instalar-RESONANCE.command`. También puedes ejecutarlo desde la carpeta descomprimida:

```sh
bash Instalar-RESONANCE.command
```

Si faltan las herramientas de compilación de Apple, el script abre su instalador. Cuando termine, vuelve a ejecutar el comando. Si faltan Steam o el puente libre, el script pide permiso y utiliza [mac-windows-gaming](https://github.com/Xipzer/mac-windows-gaming) en la revisión `c0bbee764f4317b4bcaeea08a0fb46cb051691e7` para instalar los componentes necesarios. NotProton guarda una copia de Steam, modifica y vuelve a firmar la app, y queda como herramienta predeterminada de compatibilidad para juegos de Windows. Si ya está instalado con el motor Wine 11 esperado, se reutiliza.

Inicia sesión, confirma la instalación del juego en la biblioteca predeterminada y cierra Steam cuando el instalador lo solicite. El primer inicio crea el entorno de Wine; si aparece el aviso de Visual C++, ciérralo para que el instalador pueda aplicar el ajuste. El paquete contiene los scripts y esta guía. Los juegos y componentes binarios se obtienen en cada Mac.

El código de NotProton se descarga del [fork `lechuit/NotProton`, rama `wine11-free-base`](https://github.com/lechuit/NotProton/tree/wine11-free-base), fijado a `5b8d18683b619b66390be8cbcffc1fbf47e45971`. Esa rama conserva el código del PR original; el instalador aplica el parche libre en el Mac. El fork protege esa copia del código. El instalador base, las descargas del motor, el puente precompilado y las firmas de Steam siguen dependiendo de sus fuentes externas.

Para consultar el estado sin aplicar cambios:

```sh
bash Instalar-RESONANCE.command --status
```

### Reparación después de una actualización de Steam

Si el puente dejó de funcionar tras actualizar Steam, usa `scripts/setup-notproton.sh --skip-build` desde una copia de la revisión indicada de `mac-windows-gaming`, siempre que siga disponible la compilación en la caché de NotProton. Si falta esa compilación, sigue la guía de instalación de dicho proyecto antes de volver a ejecutar el instalador de RESONANCE. La instalación guiada se detiene si detecta un puente incompleto o diferente, para que puedas elegir cómo repararlo.

## Restaurar la configuración

1. Instala el juego y arráncalo una vez con NotProton para que Steam cree su prefijo de Wine. Si aparece el aviso de Visual C++, cierra el juego.
2. Confirma que Steam descargó **Steamworks Common Redistributables**. El instalador usa `steamapps/common/Steamworks Shared/_CommonRedist/vcredist/2022/VC_redist.x64.exe` de la biblioteca de Steam.
3. Cierra Steam completamente y ejecuta desde la raíz de este repositorio:

   ```sh
   python3 scripts/resonance-wine/install.py status
   python3 scripts/resonance-wine/install.py install
   python3 scripts/resonance-wine/install.py status
   ```

4. Abre Steam y lanza RESONANCE. Si el juego no permite elegir la resolución en el modo actual, prueba el modo **Ventana**.

## Ajustes que se guardan

| Ajuste | Dónde se aplica |
| --- | --- |
| Microsoft Visual C++ Redistributable x64 | Prefijo de RESONANCE: `steamapps/compatdata/3259780/pfx`. |
| Preferencia `native,builtin` para `msvcp140`, `msvcp140_1`, `msvcp140_2`, `vcruntime140` y `vcruntime140_1` | Registro de Wine del mismo prefijo. Wine prueba primero las bibliotecas instaladas por Microsoft. |
| `%command% NOTPROTON_RETINA=0` | Opciones de lanzamiento del juego en Steam. NotProton usa la resolución lógica de la pantalla; el valor depende de la pantalla y de la escala configurada en macOS. |

Para volver al modo Retina, quita `NOTPROTON_RETINA=0` de las opciones de lanzamiento de RESONANCE y conserva las demás. Si reinstalas el juego y se pierde su prefijo, vuelve a ejecutar `install` tras crearlo. El repositorio guarda el procedimiento y sus parámetros; los binarios de Microsoft, partidas, registros y credenciales permanecen fuera de Git.

## Resultado observado

| Sesión | Máxima CPU | Máxima GPU |
| --- | ---: | ---: |
| Antes de desactivar Retina | 86,8 °C | 85,0 °C |
| Después de desactivar Retina | 80,0 °C | 72,8 °C |

Son máximos de las lecturas promedio de los sensores durante cada sesión. Después del cambio, macOS se mantuvo en estado térmico normal. Las sesiones no controlaron la escena ni la carga del juego, así que los valores sirven como referencia y no aíslan el efecto de la resolución.
