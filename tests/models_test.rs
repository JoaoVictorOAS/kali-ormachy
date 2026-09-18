use kali_ormachy::models::{Config, ToolMode};

#[test]
fn test_deserialize_toml_catalog() {
    let sample_toml = r#"
    [general]
    terminal = "auto"
    hold_session = true
    notify_on_missing = true

    [[categories]]
    id = "recon"
    name = "Reconhecimento & OSINT"
    icon = "󰛐"

    [[categories.tools]]
    name = "Nmap"
    binary = "nmap"
    package = "nmap"
    mode = "terminal"
    description = "Port scanner"
    presets = [
      { name = "Quick Scan", cmd = "nmap -T4 -F {target}" }
    ]
    params = [
      { key = "target", prompt = "Alvo:", default = "127.0.0.1" }
    ]
    "#;

    let config: Config = toml::from_str(sample_toml).expect("Failed to parse TOML");
    assert_eq!(config.general.terminal, "auto");
    assert!(config.general.hold_session);
    assert!(config.general.notify_on_missing);
    assert_eq!(config.categories.len(), 1);
    assert_eq!(config.categories[0].id, "recon");
    assert_eq!(config.categories[0].name, "Reconhecimento & OSINT");
    assert_eq!(config.categories[0].icon, "󰛐");
    assert_eq!(config.categories[0].tools.len(), 1);

    let tool = &config.categories[0].tools[0];
    assert_eq!(tool.name, "Nmap");
    assert_eq!(tool.binary, "nmap");
    assert_eq!(tool.package, "nmap");
    assert_eq!(tool.mode, ToolMode::Terminal);
    assert_eq!(tool.description, "Port scanner");
    assert_eq!(tool.presets.len(), 1);
    assert_eq!(tool.presets[0].name, "Quick Scan");
    assert_eq!(tool.presets[0].cmd, "nmap -T4 -F {target}");
    assert_eq!(tool.params.len(), 1);
    assert_eq!(tool.params[0].key, "target");
    assert_eq!(tool.params[0].prompt, "Alvo:");
    assert_eq!(tool.params[0].default, "127.0.0.1");
}

#[test]
fn test_deserialize_json_catalog() {
    let sample_json = r#"{
        "general": {
            "terminal": "kitty",
            "hold_session": false,
            "notify_on_missing": false
        },
        "categories": [
            {
                "id": "web",
                "name": "Auditoria Web",
                "icon": "󰖟",
                "tools": [
                    {
                        "name": "Burp Suite",
                        "binary": "burpsuite",
                        "package": "burpsuite",
                        "mode": "gui",
                        "description": "Proxy interception",
                        "presets": [],
                        "params": []
                    }
                ]
            }
        ]
    }"#;

    let config: Config = serde_json::from_str(sample_json).expect("Failed to parse JSON");
    assert_eq!(config.general.terminal, "kitty");
    assert!(!config.general.hold_session);
    assert!(!config.general.notify_on_missing);
    assert_eq!(config.categories.len(), 1);
    assert_eq!(config.categories[0].tools[0].mode, ToolMode::Gui);
}

#[test]
fn test_defaults_when_optional_fields_omitted() {
    let minimal_toml = r#"
    [[categories]]
    id = "recon"
    name = "Reconhecimento"

    [[categories.tools]]
    name = "Maltego"
    binary = "maltego"
    package = "maltego"
    mode = "gui"
    "#;

    let config: Config = toml::from_str(minimal_toml).expect("Failed to parse minimal TOML");
    assert_eq!(config.general.terminal, "auto");
    assert!(config.general.hold_session);
    assert!(config.general.notify_on_missing);
    assert_eq!(config.categories[0].icon, "");
    assert_eq!(config.categories[0].tools[0].description, "");
    assert!(config.categories[0].tools[0].presets.is_empty());
    assert!(config.categories[0].tools[0].params.is_empty());
}
