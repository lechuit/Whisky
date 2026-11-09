# FINAL FANTASY RESONANCE con NotProton

Configuración para FINAL FANTASY RESONANCE (Steam App ID `3259780`) en Steam para macOS. Con estos ajustes el juego superó el aviso de Visual C++ y abrió con Retina desactivado el 8 de noviembre de 2026.

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
