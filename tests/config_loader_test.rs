use kali_ormachy::config_loader::{load_config, load_default_config};
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

fn get_temp_file_path(extension: &str) -> PathBuf {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let filename = format!("kali_test_config_{}_{}.{}", std::process::id(), now, extension);
    std::env::temp_dir().join(filename)
}

#[test]
fn test_load_default_catalog_has_all_categories() {
    let config = load_default_config().expect("Failed to load default config");
    assert!(config.categories.len() >= 6, "Must contain all 6 security categories");
    let category_ids: Vec<String> = config.categories.iter().map(|c| c.id.clone()).collect();
    assert!(category_ids.contains(&"recon".to_string()));
    assert!(category_ids.contains(&"web".to_string()));
    assert!(category_ids.contains(&"network".to_string()));
    assert!(category_ids.contains(&"passwords".to_string()));
    assert!(category_ids.contains(&"reverse".to_string()));
    assert!(category_ids.contains(&"forensics".to_string()));

    // Verify general config defaults
    assert_eq!(config.general.terminal, "auto");
    assert!(config.general.hold_session);
    assert!(config.general.notify_on_missing);

    // Verify recon tools count and details
    let recon = config.categories.iter().find(|c| c.id == "recon").unwrap();
    let recon_tools: Vec<String> = recon.tools.iter().map(|t| t.name.clone()).collect();
    assert!(recon_tools.contains(&"Nmap".to_string()));
    assert!(recon_tools.contains(&"Masscan".to_string()));
    assert!(recon_tools.contains(&"theHarvester".to_string()));
    assert!(recon_tools.contains(&"Amass".to_string()));
    assert!(recon_tools.contains(&"Maltego".to_string()));

    // Verify nmap has presets and params
    let nmap = recon.tools.iter().find(|t| t.name == "Nmap").unwrap();
    assert_eq!(nmap.presets.len(), 3);
    assert_eq!(nmap.params.len(), 1);
    assert_eq!(nmap.params[0].key, "target");
}

#[test]
fn test_load_config_fallback_when_path_none() {
    let config = load_config(None).expect("Failed to load config with None path");
    assert!(config.categories.len() >= 6);
}

#[test]
fn test_load_config_fallback_when_custom_path_missing() {
    let config = load_config(Some("/nonexistent/path/to/missing_file.toml"))
        .expect("Failed fallback when custom path does not exist");
    assert!(config.categories.len() >= 6);
    let category_ids: Vec<String> = config.categories.iter().map(|c| c.id.clone()).collect();
    assert!(category_ids.contains(&"recon".to_string()));
}

#[test]
fn test_load_config_custom_toml() {
    let temp_path = get_temp_file_path("toml");
    let toml_content = r#"
[general]
terminal = "foot"
hold_session = false
notify_on_missing = false

[[categories]]
id = "custom_cat"
name = "Custom Category"
icon = "󰞷"

[[categories.tools]]
name = "CustomTool"
binary = "custom_bin"
package = "custom-pkg"
mode = "terminal"
description = "Custom description"
"#;
    fs::write(&temp_path, toml_content).unwrap();

    let config = load_config(Some(temp_path.to_str().unwrap())).expect("Failed to load custom toml config");
    let _ = fs::remove_file(&temp_path);

    assert_eq!(config.general.terminal, "foot");
    assert!(!config.general.hold_session);
    assert!(!config.general.notify_on_missing);
    assert_eq!(config.categories.len(), 1);
    assert_eq!(config.categories[0].id, "custom_cat");
    assert_eq!(config.categories[0].tools[0].name, "CustomTool");
}

#[test]
fn test_load_config_custom_json() {
    let temp_path = get_temp_file_path("json");
    let json_content = r#"{
  "general": {
    "terminal": "alacritty",
    "hold_session": true,
    "notify_on_missing": true
  },
  "categories": [
    {
      "id": "json_cat",
      "name": "JSON Category",
      "tools": [
        {
          "name": "JsonTool",
          "binary": "jsontool",
          "package": "jsontool-pkg",
          "mode": "gui",
          "description": "Json tool description"
        }
      ]
    }
  ]
}"#;
    fs::write(&temp_path, json_content).unwrap();

    let config = load_config(Some(temp_path.to_str().unwrap())).expect("Failed to load custom json config");
    let _ = fs::remove_file(&temp_path);

    assert_eq!(config.general.terminal, "alacritty");
    assert_eq!(config.categories.len(), 1);
    assert_eq!(config.categories[0].id, "json_cat");
    assert_eq!(config.categories[0].tools[0].name, "JsonTool");
}

#[test]
fn test_load_config_tilde_fallback() {
    let config = load_config(Some("~/nonexistent_kali_test_file_987654.toml"))
        .expect("Tilde fallback should succeed with default config");
    assert!(config.categories.len() >= 6);
}

#[test]
fn test_load_config_malformed_syntax_returns_err() {
    let temp_path = get_temp_file_path("toml");
    fs::write(&temp_path, "invalid toml ::: content [[[").unwrap();
    let result = load_config(Some(temp_path.to_str().unwrap()));
    let _ = fs::remove_file(&temp_path);
    assert!(result.is_err(), "Malformed config must return error");
}

