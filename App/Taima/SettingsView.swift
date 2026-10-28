import SwiftUI
import TaimaCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var message: String?
    @State private var showingIntro = false
    @AppStorage("privacy.lock") private var lockEnabled = false
    @AppStorage("privacy.discreet") private var discreet = false
    @State private var confirmingErase = false
    @State private var typingErase = false
    @State private var eraseText = ""
    @State private var erasing = false
    @State private var showingHighlights = false
    @State private var showingBackupExport = false
    @State private var importingCSV = false
    @State private var confirmingCSV = false
    @State private var restoreURL: URL?
    @State private var restorePassphrase = ""
    @State private var restoring = false
    @AppStorage(DeviceBackupExclusion.key) private var excludeFromICloud = false

    var body: some View {
        NavigationStack {
            dialogs(Form {
                dataSection
                privacySection
                taimaSection
                noteSection
                updatesSection
                eraseSection
                aboutSection
            }
            .confirmationDialog("Delete all data?", isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Export a backup first") {
                    showingBackupExport = true
                }
                Button("Delete everything", role: .destructive) {
                    eraseText = ""
                    typingErase = true
                }
            } message: {
                Text("Every bag, photo, session, note, wishlist item, learned grower and setting is removed from this iPhone. Backups you already exported are not touched.")
            }
            .alert("Type DELETE to confirm", isPresented: $typingErase) {
                TextField("DELETE", text: $eraseText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Delete all data", role: .destructive) {
                    guard eraseText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE" else {
                        message = "Nothing was deleted. Type DELETE exactly to confirm."
                        return
                    }
                    erasing = true
                    Task {
                        do {
                            try await model.eraseEverything()
                            lockEnabled = false
                            discreet = false
                            erasing = false
                            dismiss()
                        } catch {
                            erasing = false
                            message = "Taima could not delete everything. \(error.localizedDescription)"
                        }
                    }
                }
            } message: {
                Text("This can't be undone.")
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    DismissButton()
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlowBackground())
            .fullScreenCover(isPresented: $showingIntro) { OnboardingView() }
            )
        }
    }

    private func dialogs(_ content: some View) -> some View {
        content
            .sheet(isPresented: $showingHighlights) { WhatsNewView(releases: ReleaseHighlights.all) }
            .sheet(item: $exportURL, onDismiss: removeExports) { url in
                ShareSheet(url: url)
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                guard let url = try? result.get() else { return }
                let access = url.startAccessingSecurityScopedResource()
                let encrypted = BackupArchive.isEncrypted(url)
                if access { url.stopAccessingSecurityScopedResource() }
                if encrypted {
                    restorePassphrase = ""
                    restoreURL = url
                } else {
                    runRestore(url, passphrase: nil)
                }
            }
            .alert("Backup passphrase", isPresented: Binding(get: { restoreURL != nil }, set: { if !$0 { restoreURL = nil } })) {
                SecureField("Passphrase", text: $restorePassphrase)
                Button("Cancel", role: .cancel) {}
                Button("Restore") {
                    if let url = restoreURL { runRestore(url, passphrase: restorePassphrase) }
                }
            } message: {
                Text("This backup is protected. Enter the passphrase it was made with.")
            }
            .confirmationDialog("Export a spreadsheet?", isPresented: $confirmingCSV, titleVisibility: .visible) {
                Button("Export CSV") { export { try model.csvFile() } }
            } message: {
                Text("A CSV file is plain text: anyone who gets it can read your collection and sessions. Photos are not included.")
            }
            .fileImporter(isPresented: $importingCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                guard let url = try? result.get() else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    message = "This file couldn't be read as text."
                    return
                }
                let added = model.importBags(CSVExport.parse(text))
                message = added == 0 ? "No bags found. The first row needs a column called name." : "Imported \(added) bag\(added == 1 ? "" : "s") as empty bags, without photos."
            }
            .sheet(isPresented: $showingBackupExport) {
                BackupExportSheet { url in exportURL = url }
                    .presentationDetents([.medium, .large])
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }

    /// Exports hold the whole collection; do not leave them in tmp.
    private func removeExports() {
        let tmp = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("Taima") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private var dataSection: some View {
        Section {
            NavigationLink {
                AutoBackupSettings()
            } label: {
                LabeledContent {
                    Text(AutoBackup.isOn ? (AutoBackup.lastBackup.map { $0.formatted(.relative(presentation: .named)) } ?? "On") : "Off")
                } label: {
                    Label("Automatic backups", systemImage: "clock.arrow.circlepath")
                }
            }
            Button("Export backup", systemImage: "square.and.arrow.up") { showingBackupExport = true }
            Button("Restore from backup", systemImage: "square.and.arrow.down") { importing = true }
                .disabled(restoring)
            Button("Export spreadsheet (CSV)", systemImage: "tablecells") { confirmingCSV = true }
            Button("Import spreadsheet (CSV)", systemImage: "square.and.arrow.down.on.square") { importingCSV = true }
            Toggle(isOn: $excludeFromICloud) {
                Label("Leave out of iCloud backups", systemImage: "icloud.slash")
            }
            .onChange(of: excludeFromICloud) { _, on in DeviceBackupExclusion.apply(on) }
        } header: {
            Text("Your data")
        } footer: {
            Text("Deleting Taima deletes everything in it, so keep a backup. Backups are protected with your passphrase. Leaving Taima out of iCloud backups keeps your records off Apple's servers, but then only your own backups can bring them back.")
        }
    }

    private var privacySection: some View {
        Section {
            Toggle(isOn: $lockEnabled) {
                Label("Lock with Face ID", systemImage: "faceid")
            }
            if lockEnabled && !PrivacyGate.deviceCanLock {
                Label("Set a passcode for this iPhone first; without one the lock can't work.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Toggle(isOn: $discreet) {
                Label("Discreet mode", systemImage: "eye.slash")
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Discreet mode switches to a plain notes icon and keeps strain names and photos off widgets, the Live Activity, notifications and the app switcher. The name under the icon stays Taima.")
        }
        .onChange(of: lockEnabled) { model.refreshShared() }
        .onChange(of: discreet) { _, on in
            DiscreetMode.apply(on)
            model.syncActivity()
            model.refreshShared()
        }
    }

    private var taimaSection: some View {
        Section("Taima") {
            Button("Show introduction", systemImage: "sparkles") { showingIntro = true }
            Button("What's new", systemImage: "gift") { showingHighlights = true }
            NavigationLink {
                LearningSettings()
            } label: {
                Label("Label reading", systemImage: "text.viewfinder")
            }
            Button("Improve older entries", systemImage: "wand.and.sparkles") {
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    model.showingEntryReview = true
                }
            }
            .disabled(model.bags.isEmpty)
        }
    }

    private var noteSection: some View {
        Section {
        } footer: {
            Text("Labels are read on this iPhone. Photos are stored without location data. Taima has no account or analytics. Its only network use is the optional daily update check, which downloads public files from GitHub and sends nothing about you.")
        }
    }

    private var updatesSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { model.updates.isEnabled },
                set: { UserDefaults.standard.set($0, forKey: UpdateService.checkKey) }
            )) {
                Label("Check for updates", systemImage: "arrow.triangle.2.circlepath")
            }
            Toggle(isOn: Binding(
                get: { model.updates.autoInstallsLibrary },
                set: { UserDefaults.standard.set($0, forKey: UpdateService.autoLibraryKey) }
            )) {
                Label("Update the strain library automatically", systemImage: "books.vertical")
            }
            .disabled(!model.updates.isEnabled)
            if let manifest = model.updates.libraryUpdate, !model.updates.autoInstallsLibrary {
                Button(model.updates.installingLibrary ? "Installing…" : "Install library update (\(manifest.strainCount.map { "\($0) strains" } ?? "new"))", systemImage: "arrow.down.circle") {
                    Task { await model.updates.installLibrary() }
                }
                .disabled(model.updates.installingLibrary)
            }
            Button("Check now", systemImage: "arrow.clockwise") {
                Task { await model.updates.checkIfDue(force: true) }
            }
            .disabled(!model.updates.isEnabled)
            LabeledContent("Strain library", value: "version \(LibraryStore.installedVersion) · \(model.strainCatalog.strains.count.formatted()) strains")
            if let expiry = model.updates.expiry {
                LabeledContent("Signed until", value: expiry.formatted(date: .abbreviated, time: .shortened))
            }
            if let error = model.updates.lastError {
                Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
            }
        } header: {
            Text("Updates")
        } footer: {
            Text("Once a day Taima downloads two public files from GitHub: the release list SideStore uses and the strain library. Nothing about you or your collection is sent. You're reminded the day before Taima's signature needs a refresh.")
        }
    }

    private var eraseSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingErase = true
            } label: {
                HStack {
                    Label("Delete all data", systemImage: "trash")
                    if erasing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(erasing)
        } footer: {
            Text("Removes every bag, photo, session and setting from this iPhone and starts Taima over. This can't be undone.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Mascot(size: 72)
                    Text("Taima").font(.headline)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            LabeledContent("Version", value: (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–") + " (\(ReleaseHighlights.currentBuild))")
            LabeledContent("Bags", value: "\(model.bags.count)")
        }
    }

    private func runRestore(_ url: URL, passphrase: String?) {
        restoring = true
        Task {
            do {
                let added = try await model.restore(from: url, passphrase: passphrase)
                message = added == 0 ? "Nothing new: every bag in the backup is already here." : "Restored \(added) bag\(added == 1 ? "" : "s")."
            } catch {
                message = error.localizedDescription
            }
            restoring = false
        }
    }

    private func export(_ make: () throws -> URL) {
        do {
            exportURL = try make()
        } catch {
            message = "Export failed. \(error.localizedDescription)"
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Done", systemImage: "checkmark") { dismiss() } }
}

/// Makes a backup, protected with a passphrase unless the person opts out.
struct BackupExportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: (URL) -> Void
    @State private var protect = true
    @State private var passphrase = ""
    @State private var confirm = ""
    @State private var working = false
    @State private var failure: String?

    private var valid: Bool { !protect || (passphrase.count >= 8 && passphrase == confirm) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Protect with a passphrase", isOn: $protect)
                    if protect {
                        SecureField("Passphrase (8 characters or more)", text: $passphrase)
                        SecureField("Repeat passphrase", text: $confirm)
                        if !confirm.isEmpty && confirm != passphrase {
                            Text("The passphrases don't match.").font(.footnote).foregroundStyle(.orange)
                        }
                    }
                } footer: {
                    Text(protect
                         ? "The backup is encrypted. Without the passphrase nobody, including you, can open it, so store it somewhere safe."
                         : "Without a passphrase, anyone who gets the file can read your whole collection and history.")
                }
                if let failure {
                    Section { Text(failure).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Export backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button("Export", systemImage: "checkmark") { export() }
                            .disabled(!valid)
                    }
                }
            }
        }
    }

    private func export() {
        working = true
        Task {
            do {
                let url = try await model.backupFile(passphrase: protect ? passphrase : nil)
                dismiss()
                try? await Task.sleep(for: .milliseconds(400))
                done(url)
            } catch {
                failure = "The backup could not be made. \(error.localizedDescription)"
            }
            working = false
        }
    }
}

/// Daily backups to a folder of the person's choosing.
struct AutoBackupSettings: View {
    @Environment(AppModel.self) private var model
    @State private var choosingFolder = false
    @State private var folderName = AutoBackup.folderURL?.lastPathComponent
    @State private var passphrase = BackupKeychain.passphrase ?? ""
    @State private var running = false
    @State private var refresh = 0

    var body: some View {
        Form {
            Section {
                Button(folderName.map { "Folder: \($0)" } ?? "Choose a folder", systemImage: "folder") { choosingFolder = true }
                if folderName != nil {
                    Button("Turn off", systemImage: "xmark.circle", role: .destructive) {
                        try? AutoBackup.setFolder(nil)
                        folderName = nil
                    }
                }
            } footer: {
                Text("Once a day, when you leave Taima, a backup is saved to this folder. The newest \(AutoBackup.keep) are kept. Pick a folder outside Taima, such as On My iPhone or a drive, so it survives deleting the app. A folder in iCloud Drive is uploaded to Apple.")
            }
            Section {
                SecureField("Passphrase (8 characters or more)", text: $passphrase)
                    .onSubmit(savePassphrase)
                    .onChange(of: passphrase) { savePassphrase() }
            } header: {
                Text("Protection")
            } footer: {
                Text(passphrase.count >= 8
                     ? "Automatic backups are encrypted. The passphrase is kept in this iPhone's Keychain; you need it to restore."
                     : "Without a passphrase of 8 characters or more, automatic backups are saved unencrypted.")
            }
            if folderName != nil {
                Section {
                    Button(running ? "Backing up…" : "Back up now", systemImage: "arrow.clockwise") {
                        running = true
                        Task {
                            await AutoBackup.run(model)
                            running = false
                            refresh += 1
                        }
                    }
                    .disabled(running)
                    let _ = refresh
                    if let last = AutoBackup.lastBackup {
                        LabeledContent("Last backup", value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let error = UserDefaults.standard.string(forKey: AutoBackup.errorKey) {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("Automatic backups")
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            guard let url = try? result.get() else { return }
            try? AutoBackup.setFolder(url)
            folderName = url.lastPathComponent
        }
    }

    private func savePassphrase() {
        BackupKeychain.passphrase = passphrase.count >= 8 ? passphrase : nil
    }
}
