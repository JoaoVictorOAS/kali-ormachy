# Kali-Ormachy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Desenvolver o plugin `kali-ormachy`, um launcher categorizado, ultra-rápido (<5ms) em Rust com interface dinâmica em Rofi (herdando temas do Omarchy), disparo persistente em terminal (`--hold`), execução desacoplada de ferramentas GUI e alertas de dependências faltantes com integração ao Hyprland.

**Architecture:** Arquitetura desacoplada em 3 camadas:
1. **Core Engine em Rust**: Carrega catálogos híbridos (TOML/JSON), valida `$PATH`, resolve terminal padrão e despacha processos.
2. **Frontend Rofi (Fase 1)**: Menus dmenu encadeados de 2 etapas (Categoria/Preset -> Alvo) estilizados via herança do tema do Omarchy.
3. **Frontend Quickshell/QML (Fase 2)**: Launcher nativo Omarchy consumindo saídas em JSON do Core Rust.

**Tech Stack:** Rust (edition 2021, `serde`, `serde_json`, `toml`, `clap`), Bash, Rofi / Wofi, Hyprland, Wayland (`wl-copy`), `notify-send`.

**Spec:** [.agents/skills/kali-ormachy-plugin/SKILL.md](../../../.agents/skills/kali-ormachy-plugin/SKILL.md) e [catalog-schema.md](../../../.agents/skills/kali-ormachy-plugin/references/catalog-schema.md)

## Global Constraints
- **Performance:** O Core Engine em Rust deve inicializar e retornar dados em < 5ms.
- **Nativo Obrigatório:** As ferramentas devem rodar no host Arch Linux / BlackArch; nunca impor containers por padrão.
- **Sessão Persistente:** Ferramentas interativas de terminal (`nmap`, `sqlmap`, `ffuf`) NUNCA fecham a janela ao terminar (`--hold` / `exec $SHELL`).
- **Zero Cores Hardcoded:** Todo estilo deve herdar o tema do Omarchy ativo (`@theme` / `.rasi`).
- **Tratamento de Dependências:** Ferramentas não encontradas no `$PATH` devem disparar `notify-send` e exibir menu no Rofi com `pacman -S <pacote>`.

---

## 👥 Matriz de Agentes de Execução

| Agente | Perfil / Especialidade | Fases de Atuação |
| :--- | :--- | :--- |
| **`agente-core-rust`** | Engenheiro de Sistemas Rust, CLI, Serde, Processos Unix | Fase 1 & Fase 2 |
| **`agente-ui-rofi`** | Especialista em Rofi/Wofi, CSS/Rasi, Theming Omarchy e Shell | Fase 3 |
| **`agente-system-integrator`**| Especialista em Hyprland, Wayland, Packaging e Instalação | Fase 4 |
| **`agente-quickshell-qml`** | Especialista em QML, Quickshell e Widgets Omarchy Desktop | Fase 5 (Roadmap) |

---

## Fase 1: Core Engine em Rust (Fundação & Modelos)
*Agente Responsável:* `agente-core-rust`

### Task 1: Scaffolding do Projeto Cargo e Modelos de Dados
**Files:**
- Create: `Cargo.toml`
- Create: `src/models.rs`
- Create: `tests/models_test.rs`

**Interfaces:**
- Produces: `Config`, `Category`, `Tool`, `Preset`, `Param`, `ToolMode` (deserializáveis via Serde de TOML e JSON).

- [ ] **Step 1: Escrever teste de deserialização dos modelos TOML e JSON**
```rust
// tests/models_test.rs
use kali_ormachy::models::Config;

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
    assert_eq!(config.categories.len(), 1);
    assert_eq!(config.categories[0].tools[0].name, "Nmap");
    assert_eq!(config.categories[0].tools[0].presets.len(), 1);
}
```

- [ ] **Step 2: Executar teste e verificar falha**
Run: `cargo test --test models_test`
Expected: FAIL (módulo ou crate inexistente).

- [ ] **Step 3: Implementar Cargo.toml e models.rs**
```toml
# Cargo.toml
[package]
name = "kali-ormachy"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
toml = "0.8"
clap = { version = "4.4", features = ["derive"] }
which = "6.0"

[lib]
name = "kali_ormachy"
path = "src/lib.rs"

[[bin]]
name = "kali-ormachy"
path = "src/main.rs"
```

```rust
// src/models.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeneralConfig {
    #[serde(default = "default_terminal")]
    pub terminal: String,
    #[serde(default = "default_true")]
    pub hold_session: bool,
    #[serde(default = "default_true")]
    pub notify_on_missing: bool,
}

fn default_terminal() -> String { "auto".to_string() }
fn default_true() -> bool { true }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Preset {
    pub name: String,
    pub cmd: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Param {
    pub key: String,
    pub prompt: String,
    #[serde(default)]
    pub default: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum ToolMode {
    Terminal,
    Gui,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Category {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub icon: String,
    #[serde(default)]
    pub tools: Vec<Tool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub general: GeneralConfig,
    #[serde(default)]
    pub categories: Vec<Category>,
}
```

- [ ] **Step 4: Executar testes de modelos e confirmar sucesso**
Run: `cargo test --test models_test`
Expected: PASS

- [ ] **Step 5: Commit**
Run: `git add Cargo.toml src/ tests/ && git commit -m "feat(core): setup cargo and data models"`

---

### Task 2: Carregamento Híbrido de Configurações (Config Loader)
**Files:**
- Create: `src/config_loader.rs`
- Create: `config.default.toml`
- Create: `tests/config_loader_test.rs`

**Interfaces:**
- Produces: `pub fn load_config(custom_path: Option<&str>) -> Result<Config, Box<dyn std::error::Error>>`
- Lógica de fallback: Carrega `~/.config/ormachy-kali/config.toml` (ou `.json`); se ausente, faz fallback para o catálogo padrão embutido.

- [ ] **Step 1: Escrever teste de fallback e parsing de catálogo padrão**
```rust
// tests/config_loader_test.rs
use kali_ormachy::config_loader::load_default_config;

#[test]
fn test_load_default_catalog_has_all_categories() {
    let config = load_default_config().expect("Failed to load default config");
    assert!(config.categories.len() >= 6, "Must contain all 6 security categories");
    let category_ids: Vec<String> = config.categories.into_iter().map(|c| c.id).collect();
    assert!(category_ids.contains(&"recon".to_string()));
    assert!(category_ids.contains(&"web".to_string()));
    assert!(category_ids.contains(&"network".to_string()));
    assert!(category_ids.contains(&"passwords".to_string()));
    assert!(category_ids.contains(&"reverse".to_string()));
    assert!(category_ids.contains(&"forensics".to_string()));
}
```

- [ ] **Step 2: Executar teste e verificar falha**
Run: `cargo test --test config_loader_test`
Expected: FAIL.

- [ ] **Step 3: Implementar config.default.toml e config_loader.rs**
Criar `config.default.toml` com o catálogo das 6 categorias mapeado em `catalog-schema.md`.
Implementar `config_loader.rs` embutindo o catálogo via `include_str!("../config.default.toml")`.

- [ ] **Step 4: Executar testes e confirmar sucesso**
Run: `cargo test --test config_loader_test`
Expected: PASS.

- [ ] **Step 5: Commit**
Run: `git add config.default.toml src/config_loader.rs tests/config_loader_test.rs && git commit -m "feat(core): implement hybrid config loader with embedded defaults"`

---

## Fase 2: Runner Engine, Terminal Resolver & Detecção de Dependências
*Agente Responsável:* `agente-core-rust`

### Task 3: Detecção de Binários e Validador de Dependências
**Files:**
- Create: `src/checker.rs`
- Create: `tests/checker_test.rs`

**Interfaces:**
- Produces: `pub fn is_binary_installed(binary: &str) -> bool`
- Produces: `pub fn get_install_command(package: &str) -> String` (`sudo pacman -S <package>`)

- [ ] **Step 1: Escrever teste do checker**
```rust
// tests/checker_test.rs
use kali_ormachy::checker::{is_binary_installed, get_install_command};

#[test]
fn test_sh_always_installed() {
    assert!(is_binary_installed("sh"));
}

#[test]
fn test_install_command_format() {
    assert_eq!(get_install_command("nmap"), "sudo pacman -S nmap");
}
```

- [ ] **Step 2: Executar teste e verificar falha**
Run: `cargo test --test checker_test`
Expected: FAIL.

- [ ] **Step 3: Implementar checker.rs com `which::which`**
- [ ] **Step 4: Executar testes e confirmar sucesso**
Run: `cargo test --test checker_test`
Expected: PASS.

- [ ] **Step 5: Commit**
Run: `git add src/checker.rs tests/checker_test.rs && git commit -m "feat(core): implement binary existence checker and pacman command helper"`

---

### Task 4: Terminal Command Builder & Despachante de Processos
**Files:**
- Create: `src/runner.rs`
- Create: `tests/runner_test.rs`

**Interfaces:**
- Produces: `pub fn resolve_terminal(configured: &str) -> String`
- Produces: `pub fn build_terminal_command(terminal: &str, command: &str, hold: bool) -> Vec<String>`
- Produces: `pub fn spawn_gui(command: &str) -> Result<(), std::io::Error>`

- [ ] **Step 1: Escrever testes para wrapper de terminais (Kitty, Foot, Alacritty)**
```rust
// tests/runner_test.rs
use kali_ormachy::runner::build_terminal_command;

#[test]
fn test_kitty_hold_command() {
    let cmd = build_terminal_command("kitty", "nmap -F 127.0.0.1", true);
    assert_eq!(cmd, vec!["kitty", "--hold", "-e", "sh", "-c", "nmap -F 127.0.0.1; exec $SHELL"]);
}

#[test]
fn test_foot_hold_command() {
    let cmd = build_terminal_command("foot", "nmap -F 127.0.0.1", true);
    assert_eq!(cmd, vec!["foot", "--hold", "sh", "-c", "nmap -F 127.0.0.1; exec $SHELL"]);
}
```

- [ ] **Step 2: Executar teste e verificar falha**
Run: `cargo test --test runner_test`
Expected: FAIL.

- [ ] **Step 3: Implementar runner.rs**
Implementar resolução de terminal (`$TERMINAL` -> `kitty` -> `foot` -> `alacritty`), montagem das flags de hold e `spawn_gui` desacoplado (`setsid`).
- [ ] **Step 4: Executar testes e confirmar sucesso**
Run: `cargo test --test runner_test`
Expected: PASS.
- [ ] **Step 5: Commit**
Run: `git add src/runner.rs tests/runner_test.rs && git commit -m "feat(runner): implement terminal session holding and detached gui dispatcher"`

---

### Task 5: Interface CLI do Binário Rust (`clap`)
**Files:**
- Create: `src/cli.rs`
- Modify: `src/main.rs`
- Create: `tests/cli_test.rs`

**Interfaces:**
- Comandos CLI disponíveis para o Rofi e Quickshell:
  - `kali-ormachy categories` (retorna categorias para dmenu)
  - `kali-ormachy tools --category <id>` (retorna ferramentas da categoria)
  - `kali-ormachy presets --tool <name>` (retorna presets da ferramenta)
  - `kali-ormachy check --tool <name>` (retorna 0 se instalado, 1 se ausente)
  - `kali-ormachy launch-tool --name <name> [--preset <idx>] [--param <key=val>]`

- [ ] **Step 1: Implementar testes e comandos da CLI**
- [ ] **Step 2: Validar tempo de execução (< 5ms)**
Run: `time ./target/release/kali-ormachy categories`
Expected: Total time < 0.005s.
- [ ] **Step 3: Commit**
Run: `git add src/cli.rs src/main.rs tests/cli_test.rs && git commit -m "feat(cli): expose fast subcommands for UI launchers"`

---

## Fase 3: Frontend Rofi (Fase 1 de Interface)
*Agente Responsável:* `agente-ui-rofi`

### Task 6: Script de Navegação Dinâmica em 2 Etapas e Theming Rofi
**Files:**
- Create: `scripts/kali-rofi-launcher.sh`
- Create: `themes/kali-ormachy.rasi`

**Interfaces:**
- Entrada: Execução do script via atalho ou terminal.
- Fluxo:
  1. Menu de Categorias (com ícones Nerd Font).
  2. Menu de Ferramentas / Presets com indicador visual de instalação (✓ ou ✗).
  3. Se a ferramenta estiver ausente: Abre submenu "Instalar (`sudo pacman -S <pkg>`)" / "Copiar comando".
  4. Se a ferramenta estiver instalada:
     - GUI: Dispara direto via `kali-ormachy launch-tool ...`
     - CLI com presets/params: Abre prompt rápido do Rofi (`rofi -dmenu -p "Alvo (IP/URL):"`) e despacha para o terminal.

- [ ] **Step 1: Criar tema `themes/kali-ormachy.rasi` com herança `@theme` do Omarchy**
- [ ] **Step 2: Implementar `scripts/kali-rofi-launcher.sh` consumindo a CLI Rust**
- [ ] **Step 3: Testar fluxo completo com ferramenta instalada (`nmap`) e ferramenta simulada ausente**
- [ ] **Step 4: Commit**
Run: `git add scripts/ themes/ && git commit -m "feat(rofi): implement dynamic 2-step menu launcher and theme inheritance"`

---

## Fase 4: Integração com o Ambiente do Sistema (Hyprland & Omarchy)
*Agente Responsável:* `agente-system-integrator`

### Task 7: Script de Instalação, Symlinks e Atalhos Hyprland
**Files:**
- Create: `Makefile`
- Create: `install.sh`
- Create: `docs/hyprland-setup.md`

**Interfaces:**
- Compila o binário em release (`cargo build --release`).
- Instala o binário em `~/.local/bin/kali-ormachy` ou `/usr/local/bin/`.
- Configura o atalho sugerido no `~/.config/hypr/hyprland.conf`:
  `bind = $mainMod, K, exec, ~/.local/bin/kali-ormachy-rofi`
- Copia a configuração inicial para `~/.config/ormachy-kali/config.toml`.

- [ ] **Step 1: Criar Makefile e install.sh**
- [ ] **Step 2: Escrever documentação passo a passo de setup no hyprland.conf**
- [ ] **Step 3: Commit**
Run: `git add Makefile install.sh docs/hyprland-setup.md && git commit -m "feat(install): add automated installer and hyprland integration guide"`

---

## Fase 5: Frontend Quickshell / QML (Fase 2 - Roadmap)
*Agente Responsável:* `agente-quickshell-qml`

### Task 8: Widget Nativo Quickshell para Omarchy
**Files:**
- Create: `quickshell/KaliLauncher.qml`
- Create: `quickshell/CategoryButton.qml`
- Create: `quickshell/ToolCard.qml`

**Interfaces:**
- Consome `kali-ormachy --format json` para carregar dados reativos.
- Renderiza painel visual com abas de categorias, barra de busca instantânea e disparo integrado de terminais.

- [ ] **Step 1: Desenhar a interface em QML alinhada com as convenções do Quickshell no Omarchy**
- [ ] **Step 2: Conectar eventos de clique ao `kali-ormachy launch-tool`**
- [ ] **Step 3: Commit**
Run: `git add quickshell/ && git commit -m "feat(quickshell): add native Omarchy desktop launcher widget"`
