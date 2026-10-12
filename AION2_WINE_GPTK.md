# AION 2 con Wine y Game Porting Toolkit

Configuración comprobada el 12 de octubre de 2026 en un MacBook Pro M3 Pro con macOS 26.6.2. AION 2 abrió desde Steam para macOS con NotProton, Wine 11 de Sikarugir y D3DMetal 4.0b2. La resolución del juego quedó en 1512×982. Se usó la instalación existente del juego; no se copiaron ni modificaron sus archivos.

## Componentes

- [mac-windows-gaming](https://github.com/Xipzer/mac-windows-gaming) instaló el lanzador libre de NotProton y el motor Sikarugir Wine 11 con D3DMetal (Game Porting Toolkit).
- La corrección de Wine/Rosetta de [Yuki-fox/aion2-wine-compat](https://github.com/Yuki-fox/aion2-wine-compat), revisión `71a5dcdd05fad062a7b9b7be9fea49fb0ba62db5`, se compiló localmente y se cargó solo para la aplicación Steam `3393110`. Su fuente, prueba y licencia MIT están en [`scripts/aion2-wine-gptk`](scripts/aion2-wine-gptk).
- Steam para macOS quedó configurado para usar `notproton` solo con AION 2. La opción de lanzamiento de AION 2 es `%command% WINEDLLOVERRIDES=gameoverlayrenderer64,gameoverlayrenderer=`.
- El lanzador establece `NOTPROTON_RETINA=0` solo para AION 2. Así Wine anuncia una resolución lógica menor en esta pantalla Retina. El instalador integra este ajuste y la corrección Wine/Rosetta en el código fuente y en `notproton.dylib`, porque Steam puede volver a generar el script `run` al arrancar.
- Para AION 2, el lanzador omite `overlay-shim.dylib` de NotProton, pero sigue inyectando `compat_cpuid.dylib`. El registro de Wine mostraba que la capa Metal del overlay seguía cargada aunque el overlay de Steam estuviera desactivado. Una sesión posterior confirmó que el overlay dejó de cargarse, pero AION 2 volvió a cerrarse; la exclusión no resolvió el problema.

## Resultado y límite del diagnóstico

El juego permanecía en el splash con Wine/D3DMetal cargados y aproximadamente 220–230 % de CPU. Una prueba del lanzador libre sin inyección del overlay también terminó abriendo el juego según la confirmación del usuario. Después, con el módulo de Wine/Rosetta y el overlay activo, AION 2 volvió a abrir. Por eso estas pruebas no aíslan una causa única; la configuración actualmente funcional incluye el módulo.

El módulo reconoce una secuencia concreta de instrucciones durante una transición de 64 a 32 bits, reconstruye el contexto esperado y entrega la excepción a Wine. No modifica archivos del juego ni desactiva NCGuard. Es experimental y puede necesitar cambios si se actualizan el juego, Wine o macOS.

## Resolución y opciones de Steam

Con el juego cerrado, se ajustaron los seis valores `ResolutionSizeX/Y`, `LastUserConfirmedResolutionSizeX/Y` y `RestoredWindowResolutionSizeX/Y` a `1512` y `982` en `GameUserSettings.ini` del prefijo de AION 2 (`~/Library/Application Support/Steam/steamapps/compatdata/3393110/pfx/drive_c/users/gabrielpena/AppData/Local/AION2/Saved_Steam/Config/Windows/`). Se hizo una copia del archivo antes del cambio. El usuario confirmó que el juego abrió y mostró 1512×982. Esta preferencia del juego se conserva en el prefijo; el instalador de Wine no la reescribe.

Dejar **Metal HUD desactivado** en la configuración de NotProton. Al activarlo desde la interfaz se insertó `MTL_HUD_ENABLED=1` delante de `%command%` en las opciones de lanzamiento de Steam; esa forma produjo `OS Error 260` en esta versión del puente. Se quitó la variable y el juego volvió a abrir. Mantener los gráficos de NotProton en `Automatic` y probar los ajustes de calidad dentro del juego de uno en uno.

Dos sesiones de monitoreo registraron un cierre del juego: en la primera, CPU máx. 90,6 °C y GPU máx. 81,5 °C; en la segunda, con Modo Juego forzado y límite de 60 FPS, CPU máx. 79,3 °C y GPU máx. 70,0 °C. macOS no registró advertencia térmica. Por eso no hay evidencia suficiente para atribuir el cierre al calor. El límite `FrameRateLimit=60.000000` quedó en `GameUserSettings.ini`, con copia del archivo anterior. Modo Juego volvió a la política automática después de la prueba.

Una tercera sesión, sin el overlay de NotProton y con Modo Juego en automático, también terminó durante el juego. Registró CPU máx. 85,4 °C, GPU máx. 74,4 °C, RAM máx. 15,6 GiB e intercambio de memoria de 2,7 GiB. No hubo advertencia térmica ni informe de fallo de macOS. El registro de Wine contiene varios `mmap() error Cannot allocate memory` al reservar direcciones virtuales y un `GL_INVALID_FRAMEBUFFER_OPERATION`, sin pila de fallo ni relación temporal suficiente para atribuirles el cierre. Los breadcrumbs de NCSOFT muestran que el personaje entró al mapa `100010` y siguió en juego; no registran la causa del cierre. Quedaban 3,4 GiB libres en disco. Se limpiaron solo las cachés descargables `Cache` y `Code Cache` de Chrome, con Chrome cerrado, y el espacio libre subió a 7,9 GiB. Hace falta otra sesión para comprobar si el margen de disco influía.

Después se eliminaron 22 videos descargados de fondos de pantalla de macOS (9,72 GiB). Con unos 20 GiB libres, AION 2 se cerró nuevamente tras entrar al mapa `100010`. La sesión registró CPU máx. 80,4 °C, GPU máx. 70,7 °C, RAM máx. 15,3 GiB e intercambio de 2,5 GiB. No apareció informe de fallo ni mensaje concluyente al salir. El espacio insuficiente y el sobrecalentamiento quedan menos probables como causas principales, aunque esta prueba no determina la causa.

El registro del lanzador reveló que `STEAM_DYLD_INSERT_LIBRARIES` aún incluía `gameoverlayrenderer.dylib` de Steam para macOS, pese a haber desactivado el overlay de Windows y omitido el shim de NotProton. La corrección siguiente filtra solo esa biblioteca para AION 2, conserva `steamloader.dylib` y `compat_cpuid.dylib`, y agrega el canal `+seh` de Wine para capturar excepciones en la próxima sesión. Todavía no hay resultado de esa prueba.

## Reaplicar tras una actualización

Si Steam o NotProton reemplazan el lanzador, **cerrar Steam completamente** y ejecutar desde este repositorio:

```sh
python3 scripts/aion2-wine-gptk/install.py status
python3 scripts/aion2-wine-gptk/install.py install
```

El instalador compila y prueba el módulo, actualiza el código fuente del puente, recompila su biblioteca integrada, hace copias de los archivos que modifica y vuelve a firmar Steam localmente. `status` es de solo lectura y se puede ejecutar con Steam abierto. Para retirar esta corrección, cerrar Steam y ejecutar:

```sh
python3 scripts/aion2-wine-gptk/install.py uninstall
```

La configuración previa de CrossOver y Steam se guardó en `~/Library/Application Support/aion2-gptk-rollback-20261012/`. No borrar esta carpeta hasta confirmar que el juego sigue abriendo en futuras sesiones. Los registros de lanzamiento de Steam contienen parámetros privados de autenticación; no publicarlos sin revisarlos y ocultarlos primero.
