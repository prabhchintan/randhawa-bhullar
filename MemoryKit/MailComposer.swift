import SwiftUI
import MessageUI

/// The one address either app ever hands to Mail. Nothing else leaves the
/// device; this is a hand-off to the system compose sheet, not a send.
enum LoopMail {
    static let address = "loop@pulse.prabhchintan.com"
}

struct MailComposerSheet: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([LoopMail.address])
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
