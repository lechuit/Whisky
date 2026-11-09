# Steam para macOS con NotProton y Wine 11

Este fork de Whisky reúne un instalador guiado y perfiles para **probar juegos de Windows de tu biblioteca de Steam en un Mac con Apple Silicon**. Una instalación de Steam y NotProton sirve para varios juegos. Cada juego conserva su propio entorno de Wine y puede necesitar ajustes distintos. Si existe una versión nativa para macOS, empieza por esa versión.

**No hay compatibilidad universal.** Un juego puede no arrancar o fallar en videos, controles, modo en línea o rendimiento. El soporte depende del juego, sus servicios y las versiones de macOS, Steam y Wine. No uses este flujo para eludir DRM, restricciones de acceso o sistemas antitrampas. Los juegos con controladores antitrampas de Windows o lanzadores externos pueden quedar fuera de esta configuración.

## 1. Requisitos

- Mac con **Apple Silicon**, **macOS 15 o posterior** y Terminal en modo nativo. La configuración de los perfiles se comprobó en un Mac; esto no certifica todas las versiones de macOS.
- Conexión a Internet y espacio para Steam, Wine y los juegos que elijas.
- Tu propia cuenta de Steam con acceso al juego. Iniciar sesión, aceptar acuerdos y confirmar descargas son pasos manuales.
- Permiso para instalar herramientas y aplicaciones. El instalador solicita las herramientas de línea de comandos de Apple si faltan. El instalador base puede instalar Rosetta, Homebrew, CMake y Steam si hacen falta.

## 2. Qué descargar

1. Descarga el [ZIP de la rama `wine-runtime-lab`](https://github.com/lechuit/Whisky/archive/refs/heads/wine-runtime-lab.zip) y descomprímelo. Usa la carpeta completa; el archivo `.command` necesita los scripts que están junto a él. Si usas Git, la alternativa es:

   ```sh
   git clone --branch wine-runtime-lab https://github.com/lechuit/Whisky.git
   cd Whisky
   ```

2. Para el ZIP de GitHub guardado en Descargas, abre Terminal y entra en la carpeta extraída:

   ```sh
   cd "$HOME/Downloads/Whisky-wine-runtime-lab"
   ```

   Si la guardaste en otro lugar, escribe `cd ` y arrastra la carpeta descomprimida a Terminal.

3. Puedes instalar [Steam para macOS desde Valve](https://store.steampowered.com/about/) antes de continuar. Si lo instalas por tu cuenta, déjalo en `/Applications/Steam.app`, ábrelo una vez, inicia sesión y espera las actualizaciones. Luego sal de Steam con **⌘Q**. Si Steam falta, el instalador guiado ofrece instalarlo.

No necesitas instalar la app Whisky ni descargar los juegos fuera de Steam. El instalador obtiene el código base de [lechuit/mac-windows-gaming](https://github.com/lechuit/mac-windows-gaming/tree/resonance-base) y el código de [lechuit/NotProton](https://github.com/lechuit/NotProton/tree/wine11-free-base), en revisiones fijadas. El instalador base descarga también el motor Sikarugir Wine 11, su plantilla y los componentes del puente desde las fuentes indicadas en su [inventario de dependencias](https://github.com/lechuit/mac-windows-gaming/blob/resonance-base/docs/SOURCES.md). Los forks conservan el código; esas descargas siguen siendo externas.

## 3. Instalar la base para elegir cualquier juego de tu biblioteca

Desde la carpeta del repositorio, ejecuta:

```sh
bash Instalar-RESONANCE.command --base-only
```

Aunque el archivo lleve el nombre de RESONANCE, `--base-only` prepara solo Steam y NotProton. No instala ni configura ese juego.

1. Si macOS abre el instalador de las herramientas de línea de comandos, completa la instalación y vuelve a ejecutar el comando.
2. Si el puente no está instalado, lee el aviso y confirma con `s` si deseas continuar. NotProton **modifica y vuelve a firmar tu copia local de Steam.app**, guarda una copia y configura la herramienta predeterminada de compatibilidad para juegos de Windows. El acuerdo de Steam restringe las modificaciones del cliente salvo excepciones; revisa las secciones 2.G y 4 antes de aceptar. Si ya tienes la instalación de Wine 11 esperada, el script la reutiliza.
3. Cuando te lo pida, abre Steam, inicia sesión y deja que termine de actualizarse. Después sal con **⌘Q** y continúa en Terminal. Espera a que indique que la base está lista.
4. Abre Steam y elige un título en **Biblioteca**. Para un juego de Windows, comprueba en **Propiedades → Compatibilidad** que se use **NotProton (free, Wine 11)**. Si necesitas elegirlo manualmente, activa **Forzar el uso de una herramienta de compatibilidad** y selecciónalo.
5. Pulsa **Instalar**. Espera que termine la descarga y pulsa **Jugar**. El primer arranque crea un entorno de Wine para ese título. Si falla, revisa primero los requisitos y el tipo de antitrampas o lanzador que usa; la instalación de la base no soluciona automáticamente los errores de cada juego.

## 4. Aplicar perfiles comprobados

| Juego | Qué hacer |
| --- | --- |
| **FINAL FANTASY RESONANCE** | Ejecuta `bash Instalar-RESONANCE.command` sin `--base-only`. Confirma la descarga en la biblioteca predeterminada de Steam, deja que el primer inicio cree el entorno de Wine y cierra el aviso de Visual C++ si aparece. Cuando el instalador lo pida, sal de Steam. El perfil instala Visual C++ x64 desde Steamworks, prioriza sus bibliotecas y desactiva Retina para el juego. [Guía completa](RESONANCE_WINE.md). |
| **AION 2** | Con la base instalada, sigue la [guía de AION 2](AION2_WINE_GPTK.md). Su instalador es independiente; los videos de los tutoriales pueden omitirse para evitar el bloqueo observado. |
| **Otros juegos** | Prueba primero con la base. Si necesitas un ajuste, aplícalo solo al juego afectado en sus propiedades. Por ejemplo, `%command% NOTPROTON_RETINA=0` desactiva Retina para ese título. Guarda las opciones anteriores antes de modificarlas. |

Para comprobar los ajustes de RESONANCE sin modificarlos:

```sh
bash Instalar-RESONANCE.command --status
```

Si Steam se actualiza y deja de cargar NotProton, consulta la [sección de reparación](RESONANCE_WINE.md#reparación-después-de-una-actualización-de-steam). Conserva una copia externa de partidas y preferencias antes de reinstalar o formatear. Si compartes registros para pedir ayuda, elimina tokens, datos de cuenta y rutas personales.

## Licencias, procedencia y uso

- **Proyecto independiente.** Este fork no está afiliado, certificado ni respaldado por Valve, Apple, Microsoft ni los editores de los juegos. Los nombres identifican sus productos; las marcas y los juegos pertenecen a sus titulares.
- **Licencias de código.** El código de Whisky se distribuye bajo la [GPLv3](LICENSE). El módulo de AION 2 conserva su [aviso MIT](scripts/aion2-wine-gptk/LICENSE). NotProton y los demás componentes mantienen las licencias y avisos de sus propios repositorios. El árbol original de Whisky conserva `Libraries/cabextract` de [cabextract](https://www.cabextract.org.uk/); ese ejecutable no forma parte del ZIP reducido. Conserva esos avisos al redistribuir y cumple las obligaciones de código fuente que correspondan a los binarios que distribuyas.
- **Distribución del paquete.** El ZIP reducido de RESONANCE contiene scripts, documentación y la licencia de este proyecto. No incluye juegos, credenciales, Steam, DLL de Valve o Microsoft ni binarios de Apple. El instalador obtiene las dependencias en cada Mac. No redistribuyas componentes de terceros sin comprobar que tienes permiso para hacerlo.
- **Términos de terceros.** La licencia de este repositorio no concede derechos sobre Steam, los juegos ni los componentes descargados. Usa copias a las que tengas acceso autorizado. Revisa el [Acuerdo de suscriptor de Steam](https://store.steampowered.com/subscriber_agreement/), los términos de cada juego y los que acompañan a los componentes de Apple, incluido [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/). La descarga y la instalación local no sustituyen esos términos ni garantizan que un proveedor admita esta configuración.
- **Sin garantía de funcionamiento.** La compatibilidad puede cambiar con actualizaciones. Consulta las condiciones de garantía y responsabilidad en las licencias aplicables.

---

## README original de Whisky

<div align="center">

  # Whisky 🥃 
  *Wine but a bit stronger*
  
  ![](https://img.shields.io/github/actions/workflow/status/IsaacMarovitz/Whisky/SwiftLint.yml?style=for-the-badge)
  [![](https://img.shields.io/discord/1115955071549702235?style=for-the-badge)](https://discord.gg/CsqAfs9CnM)
</div>

## Maintenance Notice

[Whisky is no longer actively maintained](https://docs.getwhisky.app/maintenance-notice). Apps and games may break at any time.

<img width="650" alt="Config" src="https://github.com/Whisky-App/Whisky/assets/42140194/d0a405e8-76ee-48f0-92b5-165d184a576b">

Familiar UI that integrates seamlessly with macOS

<div align="right">
  <img width="650" alt="New Bottle" src="https://github.com/Whisky-App/Whisky/assets/42140194/ed1a0d69-d8fb-442b-9330-6816ba8981ba">

  One-click bottle creation and management
</div>

<img width="650" alt="debug" src="https://user-images.githubusercontent.com/42140194/229176642-57b80801-d29b-4123-b1c2-f3b31408ffc6.png">

Debug and profile with ease

---

Whisky provides a clean and easy to use graphical wrapper for Wine built in native SwiftUI. You can make and manage bottles, install and run Windows apps and games, and unlock the full potential of your Mac with no technical knowledge required. Whisky is built on top of CrossOver 22.1.1, and Apple's own `Game Porting Toolkit`.

Translated on [Crowdin](https://crowdin.com/project/whisky).

---

## System Requirements
- CPU: Apple Silicon (M-series chips)
- OS: macOS Sonoma 14.0 or later

## Homebrew

Whisky is on homebrew! Install with 
`brew install --cask whisky`.

## My game isn't working!

Some games need special steps to get working. Check out the [wiki](https://github.com/IsaacMarovitz/Whisky/wiki/Game-Support).

---

## Credits & Acknowledgments

Whisky is possible thanks to the magic of several projects:

- [msync](https://github.com/marzent/wine-msync) by marzent
- [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) by Gcenx and doitsujin
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) by KhronosGroup
- [Sparkle](https://github.com/sparkle-project/Sparkle) by sparkle-project
- [SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion) by SwiftPackageIndex
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) by Apple
- [SwiftTextTable](https://github.com/scottrhoyt/SwiftyTextTable) by scottrhoyt
- [CrossOver 22.1.1](https://www.codeweavers.com/crossover) by CodeWeavers and WineHQ
- D3DMetal by Apple

Special thanks to Gcenx, ohaiibuzzle, and Nat Brown for their support and contributions!

---

<table>
  <tr>
    <td>
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="./images/cw-dark.png">
          <img src="./images/cw-light.png" width="500">
        </picture>
    </td>
    <td>
        Whisky doesn't exist without CrossOver. Support the work of CodeWeavers using our <a href="https://www.codeweavers.com/store?ad=1010">affiliate link</a>.
    </td>
  </tr>
</table>
