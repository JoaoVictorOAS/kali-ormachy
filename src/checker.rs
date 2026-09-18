//! Binary existence detection and package manager installation helper.
//!
//! Provides sub-millisecond validation of tool binaries in the host system's
//! `$PATH` and constructs the appropriate Arch Linux (`pacman`) installation commands.

use which::which;

/// Checks whether an executable binary exists in the system's `$PATH`.
///
/// Returns `true` if the binary is found and executable, `false` otherwise.
/// Performance is typically sub-millisecond as it only traverses `$PATH` directories.
pub fn is_binary_installed(binary: &str) -> bool {
    if binary.trim().is_empty() {
        return false;
    }
    which(binary).is_ok()
}

/// Formats the Pacman installation command for a given package name.
///
/// Returns a string formatted as `sudo pacman -S <package>`.
pub fn get_install_command(package: &str) -> String {
    format!("sudo pacman -S {package}")
}
