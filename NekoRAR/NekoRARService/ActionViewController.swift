//
//  ActionViewController.swift
//  NekoRARService
//
//  Created by 千葉牧人 on 2025/5/21.
//

import Cocoa

class ActionViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name("ActionViewController")
    }

    override func beginRequest(with context: NSExtensionContext) {
        guard let inputItem = context.inputItems.first as? NSExtensionItem,
              let attachments = inputItem.attachments,
              let itemProvider = attachments.first else {
            context.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
            return
        }

        let typeIdentifier = "public.file-url"
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (item, error) in
            if let error = error {
                context.cancelRequest(withError: error)
                return
            }

            guard let url = item as? URL else {
                context.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
                return
            }

            DispatchQueue.main.async {
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = [url.path]
                NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: Bundle.main.bundlePath), configuration: config, completionHandler: nil)
                context.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }
}
