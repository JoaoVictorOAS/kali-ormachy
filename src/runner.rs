use std::io::{Error, ErrorKind};
use std::path::Path;
use std::process::{Command, Stdio};

#[cfg(unix)]
use std::os::unix::process::CommandExt;

use crate::checker::is_binary_installed;

/// Resolves the terminal emulator binary to use according to Omarchy's hierarchy:
/// 1. Explicitly configured terminal (if not "auto" or empty)
/// 2. $TERMINAL environment variable (if set and available)
/// 3. Omarchy default hierarchy: kitty -> foot -> alacritty
/// 4. Fallback to $TERMINAL if set, or "kitty" default
pub fn resolve_terminal(configured: &str) -> String {
    let configured_clean = configured.trim();
    if !configured_clean.is_empty() && configured_clean != "auto" {
        return configured_clean.to_string();
    }

    // Check $TERMINAL env variable if set and binary exists, excluding generic wrapper xdg-terminal-exec
    if let Ok(env_term) = std::env::var("TERMINAL") {
        let env_term_clean = env_term.trim();
        if !env_term_clean.is_empty()
            && env_term_clean != "xdg-terminal-exec"
            && is_binary_installed(env_term_clean)
        {
            return env_term_clean.to_string();
        }
    }

    // Check candidates in hierarchy: kitty -> foot -> alacritty
    for candidate in &["kitty", "foot", "alacritty"] {
        if is_binary_installed(candidate) {
            return candidate.to_string();
        }
    }

    // Fallback if xdg-terminal-exec is installed
    if is_binary_installed("xdg-terminal-exec") {
        return "xdg-terminal-exec".to_string();
    }

    // If $TERMINAL was specified in env, use it even if not verified in PATH
    if let Ok(env_term) = std::env::var("TERMINAL") {
        let env_term_clean = env_term.trim();
        if !env_term_clean.is_empty() {
            return env_term_clean.to_string();
        }
    }

    // Default fallback in Omarchy ecosystem
    "kitty".to_string()
}

/// Builds the terminal execution command vector with session-holding flags and shell preservation.
///
/// Terminal-specific flag formats:
/// - kitty: `kitty [--hold] -e sh -c "<cmd>[; exec $SHELL]"`
/// - foot: `foot [--hold] sh -c "<cmd>[; exec $SHELL]"`
/// - alacritty: `alacritty [--hold] -e sh -c "<cmd>[; exec $SHELL]"`
/// - generic: `<term> -e sh -c "<cmd>[; exec $SHELL]"`
pub fn build_terminal_command(terminal: &str, command: &str, hold: bool) -> Vec<String> {
    let bin_name = Path::new(terminal)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(terminal)
        .trim()
        .to_lowercase();

    let shell_cmd = if hold {
        if command.trim().is_empty() {
            "exec $SHELL".to_string()
        } else {
            format!("{command}; exec $SHELL")
        }
    } else {
        command.to_string()
    };

    match bin_name.as_str() {
        "kitty" => {
            if hold {
                vec![
                    terminal.to_string(),
                    "--hold".to_string(),
                    "-e".to_string(),
                    "sh".to_string(),
                    "-c".to_string(),
                    shell_cmd,
                ]
            } else {
                vec![
                    terminal.to_string(),
                    "-e".to_string(),
                    "sh".to_string(),
                    "-c".to_string(),
                    shell_cmd,
                ]
            }
        }
        "foot" => {
            if hold {
                vec![
                    terminal.to_string(),
                    "--hold".to_string(),
                    "sh".to_string(),
                    "-c".to_string(),
                    shell_cmd,
                ]
            } else {
                vec![
                    terminal.to_string(),
                    "sh".to_string(),
                    "-c".to_string(),
                    shell_cmd,
                ]
            }
        }
        "alacritty" => {
            if hold {
                vec![
                    terminal.to_string(),
                    "--hold".to_string(),
                    "-e".to_string(),
                    "sh".to_string(),
                    "-c".to_string(),
                    shell_cmd,
                ]
            } else {
                vec![
                    terminal.to_string(),
                    "-e".to_string(),
                    "sh".to_string(),
                    "-c".to_string(),
                    shell_cmd,
                ]
            }
        }
        _ => {
            vec![
                terminal.to_string(),
                "-e".to_string(),
                "sh".to_string(),
                "-c".to_string(),
                shell_cmd,
            ]
        }
    }
}

/// Dispatches a graphical user interface (GUI) process detached from the current session.
///
/// Uses `setsid` to ensure the GUI application runs in a new session and process group,
/// detached from the calling terminal/process, with standard I/O streams redirected to null.
pub fn spawn_gui(command: &str) -> Result<(), Error> {
    let cmd = command.trim();
    if cmd.is_empty() {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            "GUI command cannot be empty",
        ));
    }

    if is_binary_installed("setsid") {
        Command::new("setsid")
            .arg("sh")
            .arg("-c")
            .arg(cmd)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()?;
    } else {
        #[cfg(unix)]
        {
            let mut process = Command::new("sh");
            process
                .arg("-c")
                .arg(cmd)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .process_group(0);
            process.spawn()?;
        }

        #[cfg(not(unix))]
        {
            Command::new("sh")
                .arg("-c")
                .arg(cmd)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()?;
        }
    }

    Ok(())
}
