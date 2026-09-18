---
name: kali-ormachy-plugin
description: Use when designing, configuring, testing, or modifying the kali-ormachy security launcher for Omarchy (Hyprland)
---

# Kali-Ormachy Plugin Skill

## Overview
Guia técnico e operacional para o desenvolvimento e manutenção do **kali-ormachy**, um launcher categorizado para ferramentas de segurança e auditoria (Kali/BlackArch) integrado ao ambiente Omarchy (Hyprland Wayland).

## When to Use
- Adicionar ou modificar categorias, ferramentas ou presets no catálogo.
- Implementar ou estender o Core Engine em Rust (`src/`).
- Configurar ou ajustar a integração visual com o Rofi/Wofi respeitando o tema do Omarchy.
- Implementar a integração com o emulador de terminal (`kitty`, `foot`, `alacritty`) garantindo a preservação da sessão.
- Ajustar os atalhos globais do Hyprland (`hyprland.conf`).

## When NOT to Use
- Para scripts de exploração ou desenvolvimento de exploits (este plugin é um launcher/menu do sistema, não um exploit).
- Para configurações genéricas de pacotes não relacionadas ao Omarchy ou Hyprland.

---

## Quick Reference

| Componente | Localização / Padrão | Responsabilidade |
| :--- | :--- | :--- |
| **Core Engine** | `src/` (Rust) | CLI, validação de PATH, montagem de comandos e presets |
| **Configuração Padrão** | `config.default.toml` | Catálogo base distribuído com o plugin |
| **Configuração Usuário** | `~/.config/ormachy-kali/config.toml` | Customizações, novas ferramentas e presets do usuário |
| **Rofi Theme** | `themes/kali-launcher.rasi` | Menu dmenu herdando `@theme` do Omarchy |
| **Hyprland Keybind** | `~/.config/hypr/hyprland.conf` | Atalho global (ex: `$mainMod, K, exec, kali-ormachy launch-rofi`) |

---

## Padrões de Execução (Core Patterns)

### 1. Terminal Runner com Preservação de Sessão
Para comandos interativos (`nmap`, `sqlmap`, `ffuf`), o terminal NÃO pode fechar após a execução:

```bash
# Kitty
kitty --hold -e sh -c "<comando>; exec $SHELL"

# Foot
foot --hold sh -c "<comando>; exec $SHELL"

# Alacritty
alacritty --hold -e sh -c "<comando>; exec $SHELL"
```

### 2. Ferramentas GUI em Segundo Plano
Ferramentas com interface gráfica (`burpsuite`, `wireshark`, `ghidra`) rodam desacopladas:

```bash
setsid <comando_gui> >/dev/null 2>&1 &
```

### 3. Detecção de Dependência Ausente
Quando o binário não for encontrado no `$PATH`:
1. Disparar notificação rápida:
   ```bash
   notify-send -u critical -i security-low "kali-ormachy" "Ferramenta <name> não encontrada.\nInstale com: sudo pacman -S <pacote>"
   ```
2. Oferecer ação rápida no Rofi para abrir terminal com comando de instalação ou copiar para clipboard (`wl-copy`).

### 4. Herança de Tema do Omarchy
No arquivo `.rasi`, importar o tema atual do Omarchy sem definir cores estáticas:
```rasi
@import "~/.config/rofi/config.rasi"
/* ou arquivo de variáveis de cores gerado pelo Omarchy */
```

---

## Catálogo de Ferramentas
Consulte [references/catalog-schema.md](references/catalog-schema.md) para a estrutura completa de dados (TOML/JSON) com as 6 categorias e mais de 25 ferramentas mapeadas para seus pacotes do Arch/BlackArch.

---

## Erros Comuns e Cuidados
- **Hardcodar cores no Rofi:** Quebra o visual dinâmico do Omarchy quando o usuário troca o tema do sistema.
- **Não usar `--hold` no terminal:** Causa o fechamento instantâneo da janela assim que o comando termina, impedindo a leitura dos resultados.
- **Depender de containers por padrão:** As ferramentas devem rodar no host Arch nativo para máxima velocidade e acesso direto às interfaces de rede.
