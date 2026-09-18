use kali_ormachy::runner::{build_terminal_command, resolve_terminal, spawn_gui};

#[test]
fn test_kitty_hold_command() {
    let cmd = build_terminal_command("kitty", "nmap -F 127.0.0.1", true);
    assert_eq!(
        cmd,
        vec![
            "kitty",
            "--hold",
            "-e",
            "sh",
            "-c",
            "nmap -F 127.0.0.1; exec $SHELL"
        ]
    );
}

#[test]
fn test_foot_hold_command() {
    let cmd = build_terminal_command("foot", "nmap -F 127.0.0.1", true);
    assert_eq!(
        cmd,
        vec![
            "foot",
            "--hold",
            "sh",
            "-c",
            "nmap -F 127.0.0.1; exec $SHELL"
        ]
    );
}

#[test]
fn test_alacritty_hold_command() {
    let cmd = build_terminal_command("alacritty", "sqlmap -u http://example.com", true);
    assert_eq!(
        cmd,
        vec![
            "alacritty",
            "--hold",
            "-e",
            "sh",
            "-c",
            "sqlmap -u http://example.com; exec $SHELL"
        ]
    );
}

#[test]
fn test_terminal_no_hold_commands() {
    let kitty_no_hold = build_terminal_command("kitty", "whoami", false);
    assert_eq!(
        kitty_no_hold,
        vec!["kitty", "-e", "sh", "-c", "whoami"]
    );

    let foot_no_hold = build_terminal_command("foot", "whoami", false);
    assert_eq!(
        foot_no_hold,
        vec!["foot", "sh", "-c", "whoami"]
    );

    let alacritty_no_hold = build_terminal_command("alacritty", "whoami", false);
    assert_eq!(
        alacritty_no_hold,
        vec!["alacritty", "-e", "sh", "-c", "whoami"]
    );
}

#[test]
fn test_generic_terminal_command() {
    let generic_hold = build_terminal_command("xterm", "htop", true);
    assert_eq!(
        generic_hold,
        vec!["xterm", "-e", "sh", "-c", "htop; exec $SHELL"]
    );

    let generic_no_hold = build_terminal_command("xterm", "htop", false);
    assert_eq!(
        generic_no_hold,
        vec!["xterm", "-e", "sh", "-c", "htop"]
    );
}

#[test]
fn test_terminal_path_handling() {
    let cmd_path = build_terminal_command("/usr/bin/kitty", "echo hello", true);
    assert_eq!(
        cmd_path,
        vec![
            "/usr/bin/kitty",
            "--hold",
            "-e",
            "sh",
            "-c",
            "echo hello; exec $SHELL"
        ]
    );

    let foot_path = build_terminal_command("/usr/local/bin/foot", "echo hello", true);
    assert_eq!(
        foot_path,
        vec![
            "/usr/local/bin/foot",
            "--hold",
            "sh",
            "-c",
            "echo hello; exec $SHELL"
        ]
    );
}

#[test]
fn test_resolve_terminal_explicit() {
    assert_eq!(resolve_terminal("foot"), "foot");
    assert_eq!(resolve_terminal("kitty"), "kitty");
    assert_eq!(resolve_terminal("alacritty"), "alacritty");
    assert_eq!(resolve_terminal("wezterm"), "wezterm");
}

#[test]
fn test_resolve_terminal_auto_fallback() {
    // When "auto" is passed, it should resolve to one of the valid terminals
    let term = resolve_terminal("auto");
    assert!(!term.trim().is_empty());
}

#[test]
fn test_spawn_gui_success() {
    // Spawning a no-op / true binary should succeed
    let result = spawn_gui("true");
    assert!(result.is_ok());
}

#[test]
fn test_spawn_gui_empty_command() {
    assert!(spawn_gui("").is_err());
    assert!(spawn_gui("   ").is_err());
}
