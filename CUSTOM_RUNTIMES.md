# Custom Wine runtime experiment

This fork can create a new bottle using a separate, user-installed macOS Wine runtime. Existing bottles still use bundled WhiskyWine unless their own metadata explicitly selects a custom root. Custom Wine is an experiment, not an Aion 2 compatibility fix.

## Select a runtime

Use **New Bottle → Choose custom runtime…**. If the setup screen offers to install WhiskyWine, **Use a custom runtime** continues without downloading that older engine once Rosetta is available. Select the folder with this layout:

```text
wine/
  bin/
    wine       # wine64 is also supported
    wineserver
  lib/
  share/
```

For the WineHQ macOS package, select `Wine Devel.app/Contents/Resources/wine`, not the `.app` itself. The executables must remain inside that root, including symlink targets. Missing or non-executable binaries produce an error instead of falling back to bundled Wine.

The CLI supports the same selection when creating a new bottle:

```sh
Whisky create "Aion 2 experiment" --runtime-root "/path/to/Wine Devel.app/Contents/Resources/wine"
```

Always use a new bottle for an engine experiment. Do not repoint an existing CrossOver/Whisky bottle or share Windows registries, saves, or Steam prefixes between engines. The runtime root is per bottle; this fork does not rewrite existing bottles to use it.

## Graphics and synchronization

The selected package must supply its own libraries and any separately installed graphics backend. Whisky does not copy CrossOver, D3DMetal, or Preview files into custom runtimes. It also refuses to install its old bundled DXVK DLLs into a custom bottle. Custom bottles initially disable patched sync and DXVK Async flags; their support depends on the selected Wine build.

A newer Wine version alone does not establish that DirectX 12, anticheat, controller integration, or a game will work. Logs include the selected executable and runtime root so attempts can be compared.

## Export a launcher descriptor

```sh
Whisky runtime-descriptor "/path/to/Wine Devel.app/Contents/Resources/wine" \
  --id wine-11.17 --display-name "Wine 11.17" > wine-11.17.json
```

The version 1 JSON descriptor contains `schemaVersion`, `id`, `displayName`, `backend` (`wine`), the absolute `root`, root-relative `wineLoader` and `wineServer`, and `steamAPI` (`unavailable`). Export validates executable paths; it does not verify Wine ABI, dynamically linked dependencies, graphics support, or native Steam integration. Consumers should independently validate and pin their registered executables.

## Build and verification

The Xcode project still requires SwiftLint. Add a real SwiftLint executable to PATH before building; do not bypass the build phase. The public WhiskyKit dependency uses HTTPS so building it does not require a GitHub SSH key.

```sh
swift test --package-path WhiskyKit --scratch-path .build/kit
xcodebuild -project Whisky.xcodeproj -scheme WhiskyCmd \
  -configuration Debug -derivedDataPath .build/lab CODE_SIGNING_ALLOWED=NO build
```

For the isolated Whisky Lab app, run:

```sh
PATH="/path/to/swiftlint:$PATH" scripts/build-whisky-lab.sh
```

The helper leaves the result at `.build/packaged/Whisky Lab.app`; it does not install it. `WHISKY_LAB_CONFIGURATION=Release` selects a release build. The `WHISKY_LAB` build flag fixes the GUI and embedded CLI data namespace to `com.lechuit.WhiskyLab`, including when the command-line process has no bundle identifier. Packaging sets the same app identity, gives the thumbnail extension its own suffix, disables upstream automatic updates, removes the upstream feed, and verifies local ad-hoc signatures. Default builds preserve original Whisky behavior.

Run the packaged `Contents/Resources/WhiskyCmd` to create Lab bottles or export descriptors. Lab bottles are stored under `~/Library/Containers/com.lechuit.WhiskyLab/Bottles`. Custom metadata must be opened with this fork, because an older Whisky app does not know about its runtime override.
