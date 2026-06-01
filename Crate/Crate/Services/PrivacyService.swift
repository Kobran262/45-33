import Foundation
import LocalAuthentication

enum PrivacyService {
    static func authenticateToDisable() async -> Bool {
        let context = LAContext()
        let reason = "Подтверди, что можно показать цены и личные истории."
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
