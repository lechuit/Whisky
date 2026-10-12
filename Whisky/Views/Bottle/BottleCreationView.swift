//
//  BottleCreationView.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import WhiskyKit

struct BottleCreationView: View {
    @Binding var newlyCreatedBottleURL: URL?

    @State private var newBottleName: String = ""
    @State private var newBottleVersion: WinVersion = .win10
    @State private var newBottleURL: URL = UserDefaults.standard.url(forKey: "defaultBottleLocation")
                                           ?? BottleData.defaultBottleDir
    @State private var nameValid: Bool = false
    @State private var customWineRoot: URL?
    @State private var runtimeError: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("create.name", text: $newBottleName)
                    .onChange(of: newBottleName) { _, name in
                        nameValid = !name.isEmpty
                    }

                Picker("create.win", selection: $newBottleVersion) {
                    ForEach(WinVersion.allCases.reversed(), id: \.self) {
                        Text($0.pretty())
                    }
                }

                ActionView(
                    text: "create.path",
                    subtitle: newBottleURL.prettyPath(),
                    actionName: "create.browse"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = BottleData.containerDir
                    panel.begin { result in
                        if result == .OK, let url = panel.urls.first {
                            newBottleURL = url
                        }
                    }
                }
                Section("Wine runtime") {
                    Text(customWineRoot?.prettyPath() ?? "Bundled WhiskyWine")
                        .font(.caption)
                    HStack {
                        Button("Choose custom runtime…") { selectRuntime() }
                        if customWineRoot != nil {
                            Button("Use bundled runtime") { customWineRoot = nil }
                        }
                    }
                    Text("A custom runtime uses this new bottle only. Install its graphics libraries separately.")
                        .font(.caption)
                    if let runtimeError {
                        Text(runtimeError).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("create.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("create.cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("create.create") {
                        submit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!nameValid)
                }
            }
            .onSubmit {
                submit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.small)
    }

    func selectRuntime() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Select the Wine folder containing bin/wine and bin/wineserver."
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                customWineRoot = try WineRuntime(customRoot: url).root
                runtimeError = nil
            } catch {
                runtimeError = error.localizedDescription
            }
        }
    }

    func submit() {
        guard nameValid else { return }
        if let customWineRoot {
            do { _ = try WineRuntime(customRoot: customWineRoot) } catch {
                runtimeError = error.localizedDescription
                return
            }
        }
        newlyCreatedBottleURL = BottleVM.shared.createNewBottle(bottleName: newBottleName,
                                                                winVersion: newBottleVersion,
                                                                bottleURL: newBottleURL,
                                                                customWineRoot: customWineRoot)
        dismiss()
    }
}

#Preview {
    BottleCreationView(newlyCreatedBottleURL: .constant(nil))
}
