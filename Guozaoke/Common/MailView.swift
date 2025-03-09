//
//  MailView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/18.
//

import SwiftUI
import MessageUI
import Foundation

func writeLog(message: String) {
    let fileManager = FileManager.default
    let logDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let logFile = logDirectory.appendingPathComponent("app.txt")
    
    let logMessage = "\(Date()) - \(message)\n"
    
    if fileManager.fileExists(atPath: logFile.path) {
        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(logMessage.data(using: .utf8)!)
            fileHandle.closeFile()
        }
    } else {
        try? logMessage.write(to: logFile, atomically: true, encoding: .utf8)
    }
}

struct MailView: UIViewControllerRepresentable {
    var subject: String
    var body: String
    var recipient: String
    
    var didFinish: (Result<MFMailComposeResult, Error>) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setSubject(subject) 
        mailComposer.setMessageBody(body, isHTML: false)
        mailComposer.setToRecipients([recipient])
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(didFinish: didFinish)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var didFinish: (Result<MFMailComposeResult, Error>) -> Void
        
        init(didFinish: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            self.didFinish = didFinish
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                if let error = error {
                    self.didFinish(.failure(error))
                } else {
                    self.didFinish(.success(result))
                }
            }
        }
    }
}
