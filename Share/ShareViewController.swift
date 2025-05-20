//
//  ShareViewController.swift
//  Share
//
//  Created by Adrian Castro on 18/2/25.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    private var isShowingAlert = false
    
    override func loadView() {
        view = UIView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItems()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isShowingAlert {
            dismiss(animated: false) {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.modalPresentationStyle = .overCurrentContext
        navigationController?.modalTransitionStyle = .crossDissolve
    }
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
    
    private func handleSharedItems() {
        guard let extensionContext = self.extensionContext else {
            completeRequest()
            return
        }
        
        guard let urlScheme = Bundle.main.object(forInfoDictionaryKey: "URLScheme") as? String, !urlScheme.isEmpty else {
            displayAlert(title: "Configuration Error", 
                        message: "URL Scheme is not properly configured in Info.plist")
            return
        }
        
        let supportedTypes: [UTType] = [
            .movie,
            .video,
            .image,
            .jpeg,
            .png,
            .gif,
            .pdf,
            .audio
        ]
        
        var itemURLs: [URL] = []
        
        let group = DispatchGroup()
        
        for inputItem in extensionContext.inputItems as! [NSExtensionItem] {
            guard let attachments = inputItem.attachments else { continue }
            
            for attachment in attachments {
                for type in supportedTypes {
                    if attachment.hasItemConformingToTypeIdentifier(type.identifier) {
                        group.enter()
                        attachment.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                            defer { group.leave() }
                            
                            if error != nil { return }
                            
                            if let url = item as? URL {
                                itemURLs.append(url)
                            } else if let data = item as? Data, let utiType = UTType(type.identifier),
                                      let ext = utiType.preferredFilenameExtension {
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
                                do {
                                    try data.write(to: tempURL)
                                    itemURLs.append(tempURL)
                                } catch { }
                            }
                        }
                        break
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if !itemURLs.isEmpty {
                self.openMainApp(with: itemURLs, urlScheme: urlScheme)
            } else {
                self.completeRequest()
            }
        }
    }
    
    private func openMainApp(with urls: [URL], urlScheme: String) {
        var urlComponents = URLComponents()
        urlComponents.scheme = urlScheme
        urlComponents.host = "share"
        
        var queryItems: [URLQueryItem] = []
        for url in urls {
            if let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryItems.append(URLQueryItem(name: "url", value: encodedURL))
            }
        }
        
        urlComponents.queryItems = queryItems
        
        guard let appURL = urlComponents.url else {
            completeRequest()
            return
        }
        
        var responder: UIResponder? = self
        
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(appURL)
                break
            }
            responder = responder?.next
        }
        
        completeRequest()
    }
    
    private func displayAlert(title: String, message: String) {
        isShowingAlert = true
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.isShowingAlert = false
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func completeRequest() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
