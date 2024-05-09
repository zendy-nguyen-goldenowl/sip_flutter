package com.catelt.sip_flutter.utils

enum class RegisterSipState() {
    /// Initial state for registrations.
    None,

    /// Registration is in progress.
    Progress,

    /// Registration is successful.
    Ok,

    /// Unregistration succeeded.
    Cleared,

    /// Registration failed.
    Failed,

    /// Refreshing
    Refreshing,
}