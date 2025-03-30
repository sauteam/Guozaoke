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
    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?

    var recipients: [String] = []

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentation = presentation
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation, result: $result)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)

        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = DeviceUtils.getDeviceModel
        let name = device.systemName
        let messageBody = """

        
        --------------------------
        
        \(AppInfo.appName) \(AppInfo.appVersion) \n \(model) \(name) \(systemVersion)
        
        """
        vc.setMessageBody(messageBody, isHTML: false)
        
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

