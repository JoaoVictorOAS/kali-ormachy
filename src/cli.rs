use clap::{Args, Parser, Subcommand, ValueEnum};
use serde::Serialize;
use std::collections::HashMap;
use std::io::Write;
use std::process::{Command, Stdio};

use crate::checker::{get_install_command, is_binary_installed};
use crate::config_loader::{expand_tilde, load_config};
use crate::models::{Tool, ToolMode};
use crate::runner::{build_terminal_command, resolve_terminal, spawn_gui};

#[derive(ValueEnum, Clone, Copy, Debug, PartialEq, Eq, Default, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum OutputFormat {
    #[default]
    Text,
    Json,
}

#[derive(Parser, Debug)]
#[command(
    name = "kali-ormachy",
    about = "Omarchy Kali/BlackArch Security Tools Launcher",
    version
)]
pub struct Cli {
    /// Custom configuration file path
    #[arg(short, long, global = true)]
    pub config: Option<String>,

    /// Output format (text or json)
    #[arg(short, long, value_enum, default_value_t = OutputFormat::Text, global = true)]
    pub format: OutputFormat,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand, Debug, Clone)]
pub enum Commands {
    /// Lists categories for dmenu/rofi or JSON consumers
    Categories,

    /// Lists tools for a category
    Tools(ToolsArgs),

    /// Lists presets for a tool
    Presets(PresetsArgs),

    /// Returns parameters needed for a tool
    Params(ParamsArgs),

    /// Checks if a tool's binary is installed
    Check(CheckArgs),

    /// Installs a tool or package via pacman in an interactive terminal
    Install(InstallArgs),

    /// Launches a tool with resolved presets and parameters
    LaunchTool(LaunchToolArgs),
}

#[derive(Args, Debug, Clone)]
pub struct ToolsArgs {
    /// Category identifier (e.g. recon, web, network)
    #[arg(long, short = 'C')]
    pub category: String,
}

#[derive(Args, Debug, Clone)]
pub struct PresetsArgs {
    /// Tool name or binary
    #[arg(short, long)]
    pub tool: String,
}

#[derive(Args, Debug, Clone)]
pub struct ParamsArgs {
    /// Tool name or binary
    #[arg(short, long)]
    pub tool: String,
}

#[derive(Args, Debug, Clone)]
pub struct CheckArgs {
    /// Tool name or binary
    #[arg(short, long)]
    pub tool: String,
}

#[derive(Args, Debug, Clone)]
pub struct InstallArgs {
    /// Package name to install
    #[arg(short, long)]
    pub package: Option<String>,

    /// Tool name to install
    #[arg(short, long)]
    pub tool: Option<String>,

    /// Print the command without spawning the terminal
    #[arg(long)]
    pub dry_run: bool,
}

#[derive(Args, Debug, Clone)]
pub struct LaunchToolArgs {
    /// Tool name or binary
    #[arg(short, long)]
    pub name: String,

    /// Preset name or 0-based index
    #[arg(short, long)]
    pub preset: Option<String>,

    /// Parameters in key=value format (can be specified multiple times)
    #[arg(long = "param")]
    pub params: Vec<String>,

    /// Print the resolved command without spawning
    #[arg(long)]
    pub dry_run: bool,
}

/// Executes the parsed CLI command and returns the process exit code (0 on success, non-zero on failure).
pub fn execute<W: Write, E: Write>(
    cli: Cli,
    stdout: &mut W,
    stderr: &mut E,
) -> Result<i32, Box<dyn std::error::Error>> {
    // 1. Config loading with strict explicit path check
    let config = if let Some(ref config_path) = cli.config {
        let expanded = expand_tilde(config_path);
        if !expanded.exists() {
            writeln!(stderr, "Error: config file '{}' does not exist", config_path)?;
            return Ok(1);
        }
        load_config(Some(config_path))?
    } else {
        load_config(None)?
    };

    let format = cli.format;

    match cli.command {
        Commands::Categories => {
            match format {
                OutputFormat::Text => {
                    for cat in &config.categories {
                        if cat.icon.is_empty() {
                            writeln!(stdout, "{}\t{}", cat.name, cat.id)?;
                        } else {
                            writeln!(stdout, "{} {}\t{}", cat.icon, cat.name, cat.id)?;
                        }
                    }
                }
                OutputFormat::Json => {
                    let json_str = serde_json::to_string_pretty(&config.categories)?;
                    writeln!(stdout, "{}", json_str)?;
                }
            }
            Ok(0)
        }
        Commands::Tools(args) => {
            let cat = config.categories.iter().find(|c| {
                c.id.eq_ignore_ascii_case(&args.category) || c.name.eq_ignore_ascii_case(&args.category)
            });
            let Some(category) = cat else {
                writeln!(stderr, "Error: category '{}' not found", args.category)?;
                return Ok(1);
            };

            match format {
                OutputFormat::Text => {
                    for tool in &category.tools {
                        let indicator = if is_binary_installed(&tool.binary) { "✓" } else { "✗" };
                        if tool.description.is_empty() {
                            writeln!(stdout, "{indicator} {}\t{}", tool.name, tool.name)?;
                        } else {
                            writeln!(stdout, "{indicator} {} - {}\t{}", tool.name, tool.description, tool.name)?;
                        }
                    }
                }
                OutputFormat::Json => {
                    #[derive(Serialize)]
                    struct ToolWithStatus<'a> {
                        #[serde(flatten)]
                        tool: &'a Tool,
                        installed: bool,
                    }
                    let tools_with_status: Vec<ToolWithStatus> = category
                        .tools
                        .iter()
                        .map(|t| ToolWithStatus {
                            tool: t,
                            installed: is_binary_installed(&t.binary),
                        })
                        .collect();
                    let json_str = serde_json::to_string_pretty(&tools_with_status)?;
                    writeln!(stdout, "{}", json_str)?;
                }
            }
            Ok(0)
        }
        Commands::Presets(args) => {
            let tool = config
                .categories
                .iter()
                .flat_map(|c| &c.tools)
                .find(|t| t.name.eq_ignore_ascii_case(&args.tool) || t.binary.eq_ignore_ascii_case(&args.tool));
            let Some(tool) = tool else {
                writeln!(stderr, "Error: tool '{}' not found", args.tool)?;
                return Ok(1);
            };

            match format {
                OutputFormat::Text => {
                    for (idx, preset) in tool.presets.iter().enumerate() {
                        writeln!(stdout, "{}\t{}", preset.name, idx)?;
                    }
                }
                OutputFormat::Json => {
                    let json_str = serde_json::to_string_pretty(&tool.presets)?;
                    writeln!(stdout, "{}", json_str)?;
                }
            }
            Ok(0)
        }
        Commands::Params(args) => {
            let tool = config
                .categories
                .iter()
                .flat_map(|c| &c.tools)
                .find(|t| t.name.eq_ignore_ascii_case(&args.tool) || t.binary.eq_ignore_ascii_case(&args.tool));
            let Some(tool) = tool else {
                writeln!(stderr, "Error: tool '{}' not found", args.tool)?;
                return Ok(1);
            };

            match format {
                OutputFormat::Text => {
                    for param in &tool.params {
                        writeln!(stdout, "{}\t{}\t{}", param.key, param.prompt, param.default)?;
                    }
                }
                OutputFormat::Json => {
                    let json_str = serde_json::to_string_pretty(&tool.params)?;
                    writeln!(stdout, "{}", json_str)?;
                }
            }
            Ok(0)
        }
        Commands::Check(args) => {
            let tool = config
                .categories
                .iter()
                .flat_map(|c| &c.tools)
                .find(|t| t.name.eq_ignore_ascii_case(&args.tool) || t.binary.eq_ignore_ascii_case(&args.tool));
            let Some(tool) = tool else {
                writeln!(stderr, "Error: tool '{}' not found", args.tool)?;
                return Ok(1);
            };

            let installed = is_binary_installed(&tool.binary);
            let install_cmd = get_install_command(&tool.package);

            match format {
                OutputFormat::Text => {
                    if installed {
                        Ok(0)
                    } else {
                        writeln!(stdout, "{install_cmd}")?;
                        Ok(1)
                    }
                }
                OutputFormat::Json => {
                    #[derive(Serialize)]
                    struct CheckResult<'a> {
                        tool: &'a str,
                        binary: &'a str,
                        package: &'a str,
                        installed: bool,
                        install_command: &'a str,
                    }
                    let res = CheckResult {
                        tool: &tool.name,
                        binary: &tool.binary,
                        package: &tool.package,
                        installed,
                        install_command: &install_cmd,
                    };
                    let json_str = serde_json::to_string_pretty(&res)?;
                    writeln!(stdout, "{}", json_str)?;
                    if installed {
                        Ok(0)
                    } else {
                        Ok(1)
                    }
                }
            }
        }
        Commands::Install(args) => {
            let pkg = if let Some(ref p) = args.package {
                p.clone()
            } else if let Some(ref t) = args.tool {
                let found = config
                    .categories
                    .iter()
                    .flat_map(|c| &c.tools)
                    .find(|tool| tool.name.eq_ignore_ascii_case(t) || tool.binary.eq_ignore_ascii_case(t));
                if let Some(tool) = found {
                    tool.package.clone()
                } else {
                    t.clone()
                }
            } else {
                writeln!(stderr, "Error: either --package or --tool must be specified")?;
                return Ok(1);
            };

            let install_cmd = if is_binary_installed("yay") {
                format!("yay -S --needed {pkg}")
            } else if is_binary_installed("paru") {
                format!("paru -S --needed {pkg}")
            } else {
                format!("sudo pacman -S --needed {pkg}")
            };

            if args.dry_run {
                writeln!(stdout, "{install_cmd}")?;
                return Ok(0);
            }

            let terminal = resolve_terminal(&config.general.terminal);
            let term_cmd = build_terminal_command(&terminal, &install_cmd, true);
            Command::new(&term_cmd[0])
                .args(&term_cmd[1..])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()?;
            Ok(0)
        }
        Commands::LaunchTool(args) => {
            let tool = config
                .categories
                .iter()
                .flat_map(|c| &c.tools)
                .find(|t| t.name.eq_ignore_ascii_case(&args.name) || t.binary.eq_ignore_ascii_case(&args.name));
            let Some(tool) = tool else {
                writeln!(stderr, "Error: tool '{}' not found", args.name)?;
                return Ok(1);
            };

            // Resolve command template
            let template = if let Some(ref preset_arg) = args.preset {
                if let Ok(idx) = preset_arg.parse::<usize>() {
                    if let Some(p) = tool.presets.get(idx) {
                        p.cmd.clone()
                    } else {
                        writeln!(
                            stderr,
                            "Error: preset index {} out of bounds for tool '{}'",
                            idx, tool.name
                        )?;
                        return Ok(1);
                    }
                } else {
                    let name_part = preset_arg.split('\t').next().unwrap_or(preset_arg).trim();
                    if let Some(p) = tool
                        .presets
                        .iter()
                        .find(|p| p.name.eq_ignore_ascii_case(name_part) || p.name == preset_arg.as_str())
                    {
                        p.cmd.clone()
                    } else {
                        writeln!(
                            stderr,
                            "Error: preset '{}' not found for tool '{}'",
                            preset_arg, tool.name
                        )?;
                        return Ok(1);
                    }
                }
            } else if !tool.presets.is_empty() {
                tool.presets[0].cmd.clone()
            } else {
                tool.binary.clone()
            };

            // Build param map with defaults from tool, overridden by CLI args
            let mut param_map = HashMap::new();
            for p in &tool.params {
                param_map.insert(p.key.clone(), p.default.clone());
            }
            for arg in &args.params {
                if let Some((k, v)) = arg.split_once('=') {
                    param_map.insert(k.trim().to_string(), v.to_string());
                } else {
                    param_map.insert(arg.trim().to_string(), String::new());
                }
            }

            // Perform placeholder substitution
            let mut resolved_command = template;
            for (k, v) in &param_map {
                resolved_command = resolved_command.replace(&format!("{{{k}}}"), v);
            }

            if args.dry_run {
                writeln!(stdout, "{}", resolved_command)?;
                return Ok(0);
            }

            // Not dry-run: check binary installation
            if !is_binary_installed(&tool.binary) {
                if config.general.notify_on_missing && is_binary_installed("notify-send") {
                    let _ = Command::new("notify-send")
                        .args([
                            "-u",
                            "critical",
                            "-i",
                            "security-low",
                            "kali-ormachy",
                            &format!(
                                "Ferramenta {} não encontrada.\nInstale com: sudo pacman -S {}",
                                tool.name, tool.package
                            ),
                        ])
                        .spawn();
                }
                writeln!(
                    stderr,
                    "Error: binary '{}' for tool '{}' is not installed. Install with: sudo pacman -S {}",
                    tool.binary, tool.name, tool.package
                )?;
                return Ok(1);
            }

            match tool.mode {
                ToolMode::Terminal => {
                    let terminal = resolve_terminal(&config.general.terminal);
                    let term_cmd = build_terminal_command(
                        &terminal,
                        &resolved_command,
                        config.general.hold_session,
                    );
                    Command::new(&term_cmd[0])
                        .args(&term_cmd[1..])
                        .stdin(Stdio::null())
                        .stdout(Stdio::null())
                        .stderr(Stdio::null())
                        .spawn()?;
                    Ok(0)
                }
                ToolMode::Gui => {
                    spawn_gui(&resolved_command)?;
                    Ok(0)
                }
            }
        }
    }
}

/// Standard entrypoint invoked by `main()`.
pub fn run() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    let mut stdout = std::io::stdout();
    let mut stderr = std::io::stderr();
    let exit_code = execute(cli, &mut stdout, &mut stderr)?;
    if exit_code != 0 {
        std::process::exit(exit_code);
    }
    Ok(())
}
