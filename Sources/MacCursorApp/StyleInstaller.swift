import AppKit
import MacCursorRender
import UniformTypeIdentifiers

/// The menu's Import Style… and Remove Style… flows. A pack file is read and checked fully in
/// memory before anything is written; installing asks once, with a preview.
@MainActor
final class StyleInstaller {
    private let store = StyleStore.shared
    /// Selects a style by id (saves the setting and redraws).
    private let select: (String) -> Void
    private let showProblems: (String, String, [String]) -> Void

    init(
        select: @escaping (String) -> Void,
        showProblems: @escaping (String, String, [String]) -> Void
    ) {
        self.select = select
        self.showProblems = showProblems
    }

    func importStyle() {
        let panel = NSOpenPanel()
        panel.title = "Import Style"
        panel.message = "Choose a MacCursor style file (.\(PackArchive.fileExtension))."
        panel.prompt = "Import"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let type = UTType(filenameExtension: PackArchive.fileExtension) {
            panel.allowedContentTypes = [type]
        }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url)
    }

    func importFile(_ url: URL) {
        let name = url.lastPathComponent
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? .max
        guard size <= PackArchive.maxArchiveBytes, let data = try? Data(contentsOf: url) else {
            showProblems(
                "Couldn't import “\(name)”", "",
                ["\(name): is larger than 2 MB or can't be read"])
            return
        }
        let files: [String: Data]
        switch PackArchive.read(data) {
        case .failure(let p):
            showProblems(
                "Couldn't import “\(name)”", "This isn't a valid style file.",
                [p.described(in: name)])
            return
        case .success(let f): files = f
        }
        let load = StylePackLoader.load(files: files)
        guard let pack = load.pack, load.problems.isEmpty else {
            showProblems(
                "Couldn't import “\(name)”", "The style has problems its author needs to fix:",
                load.problems.map { $0.described(in: name) })
            return
        }

        let decision = PackInstall.decide(pack, in: store.library)
        var replacing: StylePack?
        switch decision {
        case .refuse(let why):
            alert("Can't import “\(pack.name)”", why)
            return
        case .replace(let old): replacing = old
        case .install: break
        }
        guard confirm(pack, replacing: replacing) else { return }
        do {
            _ = try PackInstall.install(
                files: files, id: pack.id, into: StyleStore.userDirectory,
                replacing: replacing?.folder)
        } catch {
            alert("Couldn't import “\(pack.name)”", error.localizedDescription)
            return
        }
        store.reloadNow()
        select(pack.id)
        log("imported style \(pack.id) from \(name)")
    }

    private func confirm(_ pack: StylePack, replacing old: StylePack?) -> Bool {
        let a = NSAlert()
        if let old {
            let from = old.version.map { " \($0)" } ?? ""
            let to = pack.version.map { " \($0)" } ?? ""
            a.messageText = "Replace “\(old.name)”\(from) with \(pack.name)\(to)?"
        } else {
            a.messageText = "Import “\(pack.name)”?"
        }
        var details = ["By \(pack.author)", "Licence: \(pack.license)"]
        if let v = pack.version { details.append("Version \(v)") }
        a.informativeText = details.joined(separator: " · ")
        if let image = SnapshotRenderer.sheet(for: pack, compact: true) {
            let size = NSSize(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
            let view = NSImageView(frame: NSRect(origin: .zero, size: size))
            view.image = NSImage(cgImage: image, size: size)
            a.accessoryView = view
        }
        a.addButton(withTitle: old == nil ? "Import" : "Replace")
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return a.runModal() == .alertFirstButtonReturn
    }

    func removeStyle(currentID: String) {
        let packs = store.library.user
        guard !packs.isEmpty else { return }
        let a = NSAlert()
        a.messageText = "Remove a style"
        a.informativeText = "The style's folder is moved to the Trash."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        for p in packs { popup.addItem(withTitle: p.name) }
        if let i = packs.firstIndex(where: { $0.id == currentID }) { popup.selectItem(at: i) }
        a.accessoryView = popup
        a.addButton(withTitle: "Move to Trash")
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let pack = packs[popup.indexOfSelectedItem]
        guard let folder = pack.folder else { return }
        do {
            try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
        } catch {
            alert("Couldn't remove “\(pack.name)”", error.localizedDescription)
            return
        }
        store.reloadNow()
        if pack.id == currentID { select(StyleLibrary.defaultID) }
        log("removed style \(pack.id)")
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}
