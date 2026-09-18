use crate::models::Config;
use std::path::{Path, PathBuf};

pub const DEFAULT_CONFIG_STR: &str = include_str!("../config.default.toml");

/// Loads the default embedded catalog configuration.
pub fn load_default_config() -> Result<Config, Box<dyn std::error::Error>> {
    let config: Config = toml::from_str(DEFAULT_CONFIG_STR)?;
    Ok(config)
}

/// Helper to expand `~` in path strings.
pub fn expand_tilde(path_str: &str) -> PathBuf {
    if let Some(stripped) = path_str.strip_prefix("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home).join(stripped);
        }
    }
    PathBuf::from(path_str)
}

/// Parses configuration content from string based on file path extension or format trial.
fn parse_config_content(content: &str, path: &Path) -> Result<Config, Box<dyn std::error::Error>> {
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        if ext.eq_ignore_ascii_case("json") {
            return Ok(serde_json::from_str(content)?);
        } else if ext.eq_ignore_ascii_case("toml") {
            return Ok(toml::from_str(content)?);
        }
    }

    // Try parsing as TOML first, then fallback to JSON
    match toml::from_str::<Config>(content) {
        Ok(c) => Ok(c),
        Err(_) => Ok(serde_json::from_str::<Config>(content)?),
    }
}

/// Loads configuration from a custom path, default user config directory (`~/.config/ormachy-kali/`),
/// or falls back to the embedded default configuration if the file does not exist.
pub fn load_config(custom_path: Option<&str>) -> Result<Config, Box<dyn std::error::Error>> {
    if let Some(custom) = custom_path {
        let path = expand_tilde(custom);
        if path.exists() {
            let content = std::fs::read_to_string(&path)?;
            return parse_config_content(&content, &path);
        } else {
            return load_default_config();
        }
    }

    // Attempt to load from user config directory (~/.config/ormachy-kali/)
    let config_dir = if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            Some(PathBuf::from(xdg).join("ormachy-kali"))
        } else {
            None
        }
    } else {
        None
    }
    .or_else(|| {
        std::env::var("HOME")
            .ok()
            .map(|home| PathBuf::from(home).join(".config").join("ormachy-kali"))
    });

    if let Some(dir) = config_dir {
        let toml_path = dir.join("config.toml");
        if toml_path.exists() {
            let content = std::fs::read_to_string(&toml_path)?;
            return parse_config_content(&content, &toml_path);
        }

        let json_path = dir.join("config.json");
        if json_path.exists() {
            let content = std::fs::read_to_string(&json_path)?;
            return parse_config_content(&content, &json_path);
        }
    }

    // Fallback to embedded default catalog
    load_default_config()
}
