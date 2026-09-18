use kali_ormachy::checker::{get_install_command, is_binary_installed};

#[test]
fn test_sh_always_installed() {
    assert!(is_binary_installed("sh"));
}

#[test]
fn test_install_command_format() {
    assert_eq!(get_install_command("nmap"), "sudo pacman -S nmap");
    assert_eq!(get_install_command("wireshark-qt"), "sudo pacman -S wireshark-qt");
}

#[test]
fn test_non_existent_binary() {
    assert!(!is_binary_installed("__non_existent_binary_xyz_12345__"));
}

#[test]
fn test_empty_binary_name() {
    assert!(!is_binary_installed(""));
}
