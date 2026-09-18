use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GeneralConfig {
    #[serde(default = "default_terminal")]
    pub terminal: String,
    #[serde(default = "default_true")]
    pub hold_session: bool,
    #[serde(default = "default_true")]
    pub notify_on_missing: bool,
}

fn default_terminal() -> String {
    "auto".to_string()
}

fn default_true() -> bool {
    true
}

impl Default for GeneralConfig {
    fn default() -> Self {
        Self {
            terminal: default_terminal(),
            hold_session: default_true(),
            notify_on_missing: default_true(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Preset {
    pub name: String,
    pub cmd: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Param {
    pub key: String,
    pub prompt: String,
    #[serde(default)]
    pub default: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ToolMode {
    Terminal,
    Gui,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Tool {
    pub name: String,
    pub binary: String,
    pub package: String,
    pub mode: ToolMode,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub presets: Vec<Preset>,
    #[serde(default)]
    pub params: Vec<Param>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Category {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub icon: String,
    #[serde(default)]
    pub tools: Vec<Tool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Config {
    #[serde(default)]
    pub general: GeneralConfig,
    #[serde(default)]
    pub categories: Vec<Category>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            general: GeneralConfig::default(),
            categories: Vec::new(),
        }
    }
}
