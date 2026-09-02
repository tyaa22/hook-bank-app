import SwiftUI

extension View {
    /// Dismisses the keyboard when called.
    public func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
