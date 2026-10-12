# AION 2 con Wine y Game Porting Toolkit

Configuración comprobada el 12 de octubre de 2026 en un MacBook Pro M3 Pro con macOS 26.6.2. AION 2 abrió desde Steam para macOS con NotProton, Wine 11 de Sikarugir y D3DMetal 4.0b2. Se usó la instalación existente del juego; no se copiaron ni modificaron sus archivos.

## Componentes

- [mac-windows-gaming](https://github.com/Xipzer/mac-windows-gaming) instaló el lanzador libre de NotProton y el motor Sikarugir Wine 11 con D3DMetal (Game Porting Toolkit).
- La corrección de Wine/Rosetta de [Yuki-fox/aion2-wine-compat](https://github.com/Yuki-fox/aion2-wine-compat), revisión `71a5dcdd05fad062a7b9b7be9fea49fb0ba62db5`, se compiló localmente y se cargó solo para la aplicación Steam `3393110`. Su fuente, prueba y licencia MIT están en [`scripts/aion2-wine-gptk`](scripts/aion2-wine-gptk).
- Steam para macOS quedó configurado para usar `notproton` solo con AION 2. La opción de lanzamiento de AION 2 es `%command% WINEDLLOVERRIDES=gameoverlayrenderer64,gameoverlayrenderer=`.

## Resultado y límite del diagnóstico

El juego permanecía en el splash con Wine/D3DMetal cargados y aproximadamente 220–230 % de CPU. Una prueba del lanzador libre sin inyección del overlay también terminó abriendo el juego según la confirmación del usuario. Después, con el módulo de Wine/Rosetta y el overlay activo, AION 2 volvió a abrir. Por eso estas pruebas no aíslan una causa única; la configuración actualmente funcional incluye el módulo.

El módulo reconoce una secuencia concreta de instrucciones durante una transición de 64 a 32 bits, reconstruye el contexto esperado y entrega la excepción a Wine. No modifica archivos del juego ni desactiva NCGuard. Es experimental y puede necesitar cambios si se actualizan el juego, Wine o macOS.

## Reaplicar tras una actualización

Si Steam o NotProton reemplazan el lanzador, ejecutar desde este repositorio:

```sh
python3 scripts/aion2-wine-gptk/install.py status
python3 scripts/aion2-wine-gptk/install.py install
```

El instalador compila y prueba el módulo, hace una copia del lanzador antes de editarlo, y conserva permisos. Para retirar solo esta corrección:

```sh
python3 scripts/aion2-wine-gptk/install.py uninstall
```

La configuración previa de CrossOver y Steam se guardó en `~/Library/Application Support/aion2-gptk-rollback-20261012/`. No borrar esta carpeta hasta confirmar que el juego sigue abriendo en futuras sesiones. Los registros de lanzamiento de Steam contienen parámetros privados de autenticación; no publicarlos sin revisarlos y ocultarlos primero.
