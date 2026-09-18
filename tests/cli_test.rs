use kali_ormachy::cli::{execute, Cli};
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use clap::Parser;

fn get_temp_file_path(extension: &str) -> PathBuf {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let filename = format!("kali_test_cli_{}_{}.{}", std::process::id(), now, extension);
    std::env::temp_dir().join(filename)
}

#[test]
fn test_categories_text_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "categories"]).expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert!(output.contains("󰛐 Reconhecimento & OSINT\trecon"));
    assert!(output.contains("󰖟 Auditoria Web\tweb"));
    assert!(output.contains("󰛳 Redes & Wi-Fi\tnetwork"));
    assert!(output.contains("󰌋 Quebra de Senhas & Hashes\tpasswords"));
    assert!(output.contains("󰘔 Engenharia Reversa\treverse"));
    assert!(output.contains("󰈔 Forense & Resposta\tforensics"));
}

#[test]
fn test_categories_json_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "categories", "--format", "json"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    let json: serde_json::Value = serde_json::from_str(&output).expect("valid json expected");
    assert!(json.is_array());
    let categories = json.as_array().unwrap();
    assert_eq!(categories.len(), 6);
    assert_eq!(categories[0]["id"], "recon");
}

#[test]
fn test_tools_text_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "tools", "--category", "recon"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert!(output.contains("Nmap - Scanner de portas e auditoria de rede\tNmap"));
    assert!(output.contains("Masscan"));
    // Verify each line has indicator ✓ or ✗
    for line in output.lines() {
        assert!(line.starts_with('✓') || line.starts_with('✗'));
        assert!(line.contains('\t'));
    }
}

#[test]
fn test_tools_json_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "tools", "--category", "recon", "--format", "json"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    let json: serde_json::Value = serde_json::from_str(&output).expect("valid json expected");
    assert!(json.is_array());
    let tools = json.as_array().unwrap();
    assert!(tools.len() >= 5);
    let nmap = tools.iter().find(|t| t["name"] == "Nmap").expect("Nmap not found");
    assert!(nmap["installed"].is_boolean());
    assert_eq!(nmap["binary"], "nmap");
}

#[test]
fn test_tools_unknown_category_returns_error() {
    let cli = Cli::try_parse_from(["kali-ormachy", "tools", "--category", "unknown_category"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 1);
    let err_msg = String::from_utf8(stderr).unwrap();
    assert!(err_msg.contains("Error: category 'unknown_category' not found"));
}

#[test]
fn test_presets_text_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "presets", "--tool", "Nmap"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert!(output.contains("Varredura Rápida de Portas\t0"));
    assert!(output.contains("Scan Completo com Scripts Padrão\t1"));
    assert!(output.contains("Detecção de Versão e SO\t2"));
}

#[test]
fn test_presets_json_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "presets", "--tool", "Nmap", "--format", "json"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    let json: serde_json::Value = serde_json::from_str(&output).expect("valid json expected");
    assert!(json.is_array());
    let presets = json.as_array().unwrap();
    assert_eq!(presets.len(), 3);
    assert_eq!(presets[0]["name"], "Varredura Rápida de Portas");
    assert_eq!(presets[0]["cmd"], "nmap -T4 -F {target}");
}

#[test]
fn test_presets_unknown_tool_returns_error() {
    let cli = Cli::try_parse_from(["kali-ormachy", "presets", "--tool", "nonexistent"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 1);
    let err_msg = String::from_utf8(stderr).unwrap();
    assert!(err_msg.contains("Error: tool 'nonexistent' not found"));
}

#[test]
fn test_params_text_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "params", "--tool", "Nmap"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert!(output.contains("target\tAlvo (IP ou Domínio):\t127.0.0.1"));
}

#[test]
fn test_params_json_format() {
    let cli = Cli::try_parse_from(["kali-ormachy", "params", "--tool", "Nmap", "--format", "json"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    let json: serde_json::Value = serde_json::from_str(&output).expect("valid json expected");
    assert!(json.is_array());
    let params = json.as_array().unwrap();
    assert_eq!(params.len(), 1);
    assert_eq!(params[0]["key"], "target");
    assert_eq!(params[0]["default"], "127.0.0.1");
}

#[test]
fn test_params_unknown_tool_returns_error() {
    let cli = Cli::try_parse_from(["kali-ormachy", "params", "--tool", "nonexistent"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 1);
    let err_msg = String::from_utf8(stderr).unwrap();
    assert!(err_msg.contains("Error: tool 'nonexistent' not found"));
}

#[test]
fn test_check_installed_and_missing() {
    let temp_config = get_temp_file_path("toml");
    let toml_content = r#"
    [general]
    terminal = "auto"

    [[categories]]
    id = "test"
    name = "Test Category"

    [[categories.tools]]
    name = "InstalledTool"
    binary = "sh"
    package = "bash"
    mode = "terminal"

    [[categories.tools]]
    name = "MissingTool"
    binary = "nonexistent_bin_999888"
    package = "missing-tool-package"
    mode = "terminal"
    "#;
    fs::write(&temp_config, toml_content).unwrap();

    let config_arg = temp_config.to_str().unwrap();

    // Check installed tool -> exit code 0
    let cli_installed = Cli::try_parse_from([
        "kali-ormachy",
        "--config",
        config_arg,
        "check",
        "--tool",
        "InstalledTool",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli_installed, &mut stdout, &mut stderr).expect("execute failed");
    assert_eq!(exit_code, 0);

    // Check missing tool -> exit code 1, outputs pacman command
    let cli_missing = Cli::try_parse_from([
        "kali-ormachy",
        "--config",
        config_arg,
        "check",
        "--tool",
        "MissingTool",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli_missing, &mut stdout, &mut stderr).expect("execute failed");
    assert_eq!(exit_code, 1);
    let output = String::from_utf8(stdout).unwrap();
    assert_eq!(output.trim(), "sudo pacman -S missing-tool-package");

    // Check missing tool with json format
    let cli_missing_json = Cli::try_parse_from([
        "kali-ormachy",
        "--config",
        config_arg,
        "check",
        "--tool",
        "MissingTool",
        "--format",
        "json",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli_missing_json, &mut stdout, &mut stderr).expect("execute failed");
    assert_eq!(exit_code, 1);
    let json: serde_json::Value = serde_json::from_slice(&stdout).expect("valid json");
    assert_eq!(json["installed"], false);
    assert_eq!(json["package"], "missing-tool-package");
    assert_eq!(json["install_command"], "sudo pacman -S missing-tool-package");

    let _ = fs::remove_file(&temp_config);
}

#[test]
fn test_launch_tool_dry_run_defaults() {
    let cli = Cli::try_parse_from(["kali-ormachy", "launch-tool", "--name", "Nmap", "--dry-run"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert_eq!(output.trim(), "nmap -T4 -F 127.0.0.1");
}

#[test]
fn test_launch_tool_dry_run_with_custom_param() {
    let cli = Cli::try_parse_from([
        "kali-ormachy",
        "launch-tool",
        "--name",
        "Nmap",
        "--param",
        "target=192.168.1.100",
        "--dry-run",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert_eq!(output.trim(), "nmap -T4 -F 192.168.1.100");
}

#[test]
fn test_launch_tool_dry_run_with_preset_index() {
    let cli = Cli::try_parse_from([
        "kali-ormachy",
        "launch-tool",
        "--name",
        "Nmap",
        "--preset",
        "1",
        "--param",
        "target=10.0.0.1",
        "--dry-run",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert_eq!(output.trim(), "nmap -sC -sV -p- -T4 10.0.0.1");
}

#[test]
fn test_launch_tool_dry_run_with_preset_name() {
    let cli = Cli::try_parse_from([
        "kali-ormachy",
        "launch-tool",
        "--name",
        "Nmap",
        "--preset",
        "Detecção de Versão e SO",
        "--param",
        "target=10.0.0.2",
        "--dry-run",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert_eq!(output.trim(), "nmap -sV -O 10.0.0.2");
}

#[test]
fn test_launch_tool_dry_run_gui_tool() {
    let cli = Cli::try_parse_from(["kali-ormachy", "launch-tool", "--name", "Wireshark", "--dry-run"])
        .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert_eq!(output.trim(), "wireshark");
}

#[test]
fn test_config_explicit_missing_file_returns_error() {
    let missing_path = "/tmp/definitely_missing_config_987654.toml";
    let cli = Cli::try_parse_from([
        "kali-ormachy",
        "--config",
        missing_path,
        "categories",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 1);
    let err_msg = String::from_utf8(stderr).unwrap();
    assert!(err_msg.contains("Error: config file"));
    assert!(err_msg.contains(missing_path));
}

#[test]
fn test_config_explicit_custom_file_loads() {
    let temp_config = get_temp_file_path("toml");
    let toml_content = r#"
    [general]
    terminal = "foot"

    [[categories]]
    id = "special_cat"
    name = "Special Category"
    icon = "󰞷"

    [[categories.tools]]
    name = "SpecialTool"
    binary = "special_bin"
    package = "special-pkg"
    mode = "terminal"
    "#;
    fs::write(&temp_config, toml_content).unwrap();

    let cli = Cli::try_parse_from([
        "kali-ormachy",
        "--config",
        temp_config.to_str().unwrap(),
        "categories",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 0);
    let output = String::from_utf8(stdout).unwrap();
    assert!(output.contains("󰞷 Special Category\tspecial_cat"));
    assert!(!output.contains("recon"));

    let _ = fs::remove_file(&temp_config);
}

#[test]
fn test_launch_tool_missing_binary_fails_when_not_dry_run() {
    let temp_config = get_temp_file_path("toml");
    let toml_content = r#"
    [general]
    terminal = "auto"
    notify_on_missing = false

    [[categories]]
    id = "test"
    name = "Test Category"

    [[categories.tools]]
    name = "MissingTool"
    binary = "definitely_nonexistent_binary_xyz_123"
    package = "pkg-xyz"
    mode = "terminal"
    "#;
    fs::write(&temp_config, toml_content).unwrap();

    let cli = Cli::try_parse_from([
        "kali-ormachy",
        "--config",
        temp_config.to_str().unwrap(),
        "launch-tool",
        "--name",
        "MissingTool",
    ])
    .expect("parse failed");
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let exit_code = execute(cli, &mut stdout, &mut stderr).expect("execute failed");

    assert_eq!(exit_code, 1);
    let err_msg = String::from_utf8(stderr).unwrap();
    assert!(err_msg.contains("not installed"));

    let _ = fs::remove_file(&temp_config);
}

#[test]
fn test_binary_end_to_end_categories() {
    let bin_path = env!("CARGO_BIN_EXE_kali-ormachy");
    let output = std::process::Command::new(bin_path)
        .arg("categories")
        .output()
        .expect("failed to execute binary");

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("󰛐 Reconhecimento & OSINT\trecon"));
}

#[test]
fn test_binary_end_to_end_dry_run() {
    let bin_path = env!("CARGO_BIN_EXE_kali-ormachy");
    let output = std::process::Command::new(bin_path)
        .args(["launch-tool", "--name", "Nmap", "--preset", "0", "--param", "target=1.1.1.1", "--dry-run"])
        .output()
        .expect("failed to execute binary");

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert_eq!(stdout.trim(), "nmap -T4 -F 1.1.1.1");
}
