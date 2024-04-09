import Foundation

enum RegisterSipState : String, CaseIterable {
    /// Initial state for registrations.
    case None = "None"
    /// Registration is in progress.
    case Progress = "Progress"
    /// Registration is successful.
    case Ok = "Ok"
    /// Unregistration succeeded.
    case Cleared = "Cleared"
    /// Registration failed.
    case Failed = "Failed"
    /// Refreshing
    case Refreshing = "Refreshing"
}
