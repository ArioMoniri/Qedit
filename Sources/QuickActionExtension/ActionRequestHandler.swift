import Foundation
import AppKit
import UniformTypeIdentifiers

/// Finder Quick Action / Service (Module B entry point).
///
/// Receives the file the user selected in Finder and hands it to the host app via the
/// `qedit://open?path=...` URL scheme. No UI — it forwards and returns immediately.
/// The unsandboxed host app then opens the file for editing.
final class ActionRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let fileTypeID = UTType.fileURL.identifier
        let providers = (context.inputItems as? [NSExtensionItem])
            .map { $0.compactMap(\.attachments).flatMap { $0 } } ?? []

        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(fileTypeID) }) else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        provider.loadItem(forTypeIdentifier: fileTypeID, options: nil) { item, _ in
            let fileURL = Self.fileURL(from: item)
            if let path = fileURL?.path,
               let openURL = AppInfo.openURL(forPath: path) {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(openURL)
                    context.completeRequest(returningItems: [], completionHandler: nil)
                }
            } else {
                context.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL: return url
        case let nsurl as NSURL: return nsurl as URL
        case let data as Data: return URL(dataRepresentation: data, relativeTo: nil)
        default: return nil
        }
    }
}
