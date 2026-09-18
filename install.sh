#!/usr/bin/env bash
#
# install.sh - Automated installer and Hyprland integrator for kali-ormachy
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_dry() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
}

print_help() {
    cat <<EOF
Uso: ./install.sh [OPÇÕES]

Instalador automatizado do kali-ormachy para integração com Omarchy / Hyprland.

Opções:
  --prefix <DIR>          Diretório base de instalação (padrão: \$HOME/.local)
  --config-dir <DIR>      Diretório de configurações (padrão: \${XDG_CONFIG_HOME:-\$HOME/.config}/ormachy-kali)
  --hypr-conf <ARQUIVO>   Caminho para o arquivo hyprland.conf
  --skip-hyprland         Não configurar atalho no hyprland.conf
  --skip-build            Pular compilação com cargo (usar binário existente em target/release)
  --dry-run               Simular passos de instalação sem alterar arquivos
  --uninstall             Desinstalar componentes do kali-ormachy
  --purge                 Na desinstalação, remover também arquivos de configuração do usuário
  -y, --yes,
  --non-interactive       Executar em modo não-interativo (respostas afirmativas automáticas)
  -h, --help              Exibir esta mensagem de ajuda

Exemplos:
  ./install.sh
  ./install.sh --dry-run
  ./install.sh --prefix /usr/local
  ./install.sh --uninstall
EOF
}

# Defaults
PREFIX="${HOME}/.local"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ormachy-kali"
HYPR_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
SKIP_HYPRLAND=false
SKIP_BUILD=false
DRY_RUN=false
UNINSTALL=false
PURGE=false
NON_INTERACTIVE=false

# Argument parsing
while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            if [ -z "${2:-}" ]; then
                log_error "A opção --prefix requer um argumento."
                exit 1
            fi
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --config-dir)
            if [ -z "${2:-}" ]; then
                log_error "A opção --config-dir requer um argumento."
                exit 1
            fi
            CONFIG_DIR="$2"
            shift 2
            ;;
        --config-dir=*)
            CONFIG_DIR="${1#*=}"
            shift
            ;;
        --hypr-conf)
            if [ -z "${2:-}" ]; then
                log_error "A opção --hypr-conf requer um argumento."
                exit 1
            fi
            HYPR_CONF="$2"
            shift 2
            ;;
        --hypr-conf=*)
            HYPR_CONF="${1#*=}"
            shift
            ;;
        --skip-hyprland)
            SKIP_HYPRLAND=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --uninstall)
            UNINSTALL=false # set to true below
            UNINSTALL=true
            shift
            ;;
        --purge)
            PURGE=true
            shift
            ;;
        -y|--yes|--non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            log_error "Opção desconhecida: $1"
            echo "Execute './install.sh --help' para ver as opções disponíveis." >&2
            exit 1
            ;;
    esac
done

BIN_DIR="${PREFIX}/bin"

# Locate cargo toolchain
find_cargo() {
    if command -v cargo >/dev/null 2>&1; then
        command -v cargo
        return 0
    elif [ -x "$HOME/.cargo/bin/cargo" ]; then
        echo "$HOME/.cargo/bin/cargo"
        return 0
    fi
    return 1
}

# --- Uninstall Routine ---
if [ "$UNINSTALL" = true ]; then
    echo -e "${BOLD}Iniciando desinstalação do kali-ormachy...${NC}"

    # Remove binaries
    for f in "$BIN_DIR/kali-ormachy" "$BIN_DIR/kali-ormachy-rofi"; do
        if [ -e "$f" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_dry "Remover executável: $f"
            else
                rm -f "$f"
                log_success "Removido: $f"
            fi
        fi
    done

    # Remove theme
    if [ -f "$CONFIG_DIR/kali-ormachy.rasi" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry "Remover tema: $CONFIG_DIR/kali-ormachy.rasi"
        else
            rm -f "$CONFIG_DIR/kali-ormachy.rasi"
            log_success "Removido: $CONFIG_DIR/kali-ormachy.rasi"
        fi
    fi

    # Handle config.toml
    if [ -f "$CONFIG_DIR/config.toml" ]; then
        if [ "$PURGE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                log_dry "Remover arquivo de configuração (--purge): $CONFIG_DIR/config.toml"
                log_dry "Remover diretório de configuração: $CONFIG_DIR"
            else
                rm -f "$CONFIG_DIR/config.toml"
                rmdir "$CONFIG_DIR" 2>/dev/null || true
                log_success "Configurações removidas (--purge)."
            fi
        else
            log_info "Configuração preservada em $CONFIG_DIR/config.toml (use --purge para remover)."
        fi
    fi

    # Handle Hyprland shortcut removal
    if [ "$SKIP_HYPRLAND" = false ] && [ -f "$HYPR_CONF" ]; then
        if grep -q "kali-ormachy-rofi" "$HYPR_CONF"; then
            remove_bind=false
            if [ "$NON_INTERACTIVE" = true ] || [ "$PURGE" = true ] || [ "$DRY_RUN" = true ] || [ ! -t 0 ]; then
                remove_bind=true
            else
                read -r -p "Deseja remover o atalho do kali-ormachy de $HYPR_CONF? [S/n]: " resp
                case "$resp" in
                    [nN][oO]|[nN]) remove_bind=false ;;
                    *) remove_bind=true ;;
                esac
            fi

            if [ "$remove_bind" = true ]; then
                if [ "$DRY_RUN" = true ]; then
                    log_dry "Remover linha de atalho do $HYPR_CONF"
                else
                    # Remove the comment and bind lines cleanly
                    sed -i '/# kali-ormachy: Kali Linux tools launcher/d' "$HYPR_CONF"
                    sed -i '/kali-ormachy-rofi/d' "$HYPR_CONF"
                    log_success "Atalho removido de $HYPR_CONF"
                fi
            fi
        fi
    fi

    echo -e "${GREEN}${BOLD}kali-ormachy desinstalado com sucesso.${NC}"
    exit 0
fi

# --- Install Routine ---
echo -e "${BOLD}Iniciando instalação do kali-ormachy...${NC}"

# Check prerequisites
check_prerequisites() {
    log_info "Verificando dependências do sistema..."

    # Check Cargo
    if CARGO_BIN=$(find_cargo); then
        log_success "Compilador Rust encontrado: $CARGO_BIN"
    else
        if [ "$SKIP_BUILD" = false ] && [ ! -f "$SCRIPT_DIR/target/release/kali-ormachy" ]; then
            log_error "Compilador Rust ('cargo') não encontrado no sistema nem em ~/.cargo/bin."
            log_error "Instale Rust executando: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            exit 1
        else
            log_warn "Cargo não detectado, mas o binário pré-compilado será utilizado."
        fi
    fi

    # Check Rofi / Wofi
    if command -v rofi >/dev/null 2>&1; then
        log_success "Launcher Rofi encontrado: $(command -v rofi)"
    elif command -v wofi >/dev/null 2>&1; then
        log_success "Launcher Wofi encontrado: $(command -v wofi)"
    else
        log_warn "Nem 'rofi' nem 'wofi' foram detectados no PATH."
        log_warn "Para utilizar o menu gráfico dinâmico, instale 'rofi-wayland' (sudo pacman -S rofi-wayland)."
    fi

    # Check notify-send
    if command -v notify-send >/dev/null 2>&1; then
        log_success "Notificador 'notify-send' encontrado."
    else
        log_warn "'notify-send' não detectado. Notificações do sistema podem ficar desabilitadas."
    fi
}

check_prerequisites

# Build release binary if needed
build_binary() {
    if [ "$SKIP_BUILD" = true ]; then
        log_info "Compilação pulada (--skip-build)."
        return 0
    fi

    local release_bin="$SCRIPT_DIR/target/release/kali-ormachy"

    if [ "$DRY_RUN" = true ]; then
        log_dry "Compilar binário de release: cargo build --release"
        return 0
    fi

    log_info "Compilando binário em modo release (cargo build --release)..."
    CARGO_BIN=$(find_cargo)
    PATH="$HOME/.cargo/bin:$PATH" "$CARGO_BIN" build --release --manifest-path "$SCRIPT_DIR/Cargo.toml"
    log_success "Compilação concluída com sucesso."
}

build_binary

# Install binaries
install_files() {
    log_info "Instalando binários e arquivos de configuração..."

    if [ "$DRY_RUN" = true ]; then
        log_dry "Criar diretório de binários: mkdir -p $BIN_DIR"
        log_dry "Instalar $SCRIPT_DIR/target/release/kali-ormachy -> $BIN_DIR/kali-ormachy (modo 755)"
        log_dry "Instalar $SCRIPT_DIR/scripts/kali-rofi-launcher.sh -> $BIN_DIR/kali-ormachy-rofi (modo 755)"
        log_dry "Criar diretório de configuração: mkdir -p $CONFIG_DIR"
        if [ ! -f "$CONFIG_DIR/config.toml" ]; then
            log_dry "Copiar $SCRIPT_DIR/config.default.toml -> $CONFIG_DIR/config.toml (modo 644)"
        else
            log_dry "Preservar arquivo existente: $CONFIG_DIR/config.toml"
        fi
        log_dry "Copiar $SCRIPT_DIR/themes/kali-ormachy.rasi -> $CONFIG_DIR/kali-ormachy.rasi (modo 644)"
        return 0
    fi

    mkdir -p "$BIN_DIR"
    install -m 755 "$SCRIPT_DIR/target/release/kali-ormachy" "$BIN_DIR/kali-ormachy"
    log_success "Binário instalado em: $BIN_DIR/kali-ormachy"

    install -m 755 "$SCRIPT_DIR/scripts/kali-rofi-launcher.sh" "$BIN_DIR/kali-ormachy-rofi"
    log_success "Launcher Rofi instalado em: $BIN_DIR/kali-ormachy-rofi"

    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_DIR/config.toml" ]; then
        install -m 644 "$SCRIPT_DIR/config.default.toml" "$CONFIG_DIR/config.toml"
        log_success "Configuração padrão copiada para: $CONFIG_DIR/config.toml"
    else
        log_info "Configuração existente preservada: $CONFIG_DIR/config.toml"
    fi

    install -m 644 "$SCRIPT_DIR/themes/kali-ormachy.rasi" "$CONFIG_DIR/kali-ormachy.rasi"
    log_success "Tema Rofi instalado em: $CONFIG_DIR/kali-ormachy.rasi"
}

install_files

# Hyprland integration
setup_hyprland() {
    if [ "$SKIP_HYPRLAND" = true ]; then
        log_info "Configuração do Hyprland ignorada (--skip-hyprland)."
        return 0
    fi

    local bind_bin="$BIN_DIR/kali-ormachy-rofi"
    local bind_line="bind = \$mainMod, K, exec, $bind_bin"

    if [ ! -f "$HYPR_CONF" ]; then
        log_info "Arquivo hyprland.conf não encontrado em: $HYPR_CONF"
        log_info "Para ativar o atalho global no Hyprland, adicione manualmente:"
        echo -e "  ${BOLD}$bind_line${NC}"
        return 0
    fi

    if grep -q "kali-ormachy-rofi" "$HYPR_CONF"; then
        log_success "Atalho do kali-ormachy já configurado em: $HYPR_CONF"
        return 0
    fi

    local add_bind=false
    if [ "$NON_INTERACTIVE" = true ] || [ "$DRY_RUN" = true ] || [ ! -t 0 ]; then
        add_bind=true
    else
        read -r -p "Deseja adicionar o atalho global (\$mainMod, K) ao seu hyprland.conf? [S/n]: " resp
        case "$resp" in
            [nN][oO]|[nN]) add_bind=false ;;
            *) add_bind=true ;;
        esac
    fi

    if [ "$add_bind" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry "Adicionar atalho a $HYPR_CONF:"
            log_dry "  # kali-ormachy: Kali Linux tools launcher"
            log_dry "  $bind_line"
        else
            {
                echo ""
                echo "# kali-ormachy: Kali Linux tools launcher"
                echo "$bind_line"
            } >> "$HYPR_CONF"
            log_success "Atalho adicionado com sucesso a $HYPR_CONF"
        fi
    else
        log_info "Configuração de atalho ignorada pelo usuário."
    fi
}

setup_hyprland

# Verify PATH
check_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *)
            log_warn "O diretório '$BIN_DIR' não está presente no seu PATH."
            log_warn "Para que o comando 'kali-ormachy-rofi' e atalhos funcionem corretamente,"
            log_warn "adicione a seguinte linha ao seu shell (~/.bashrc ou ~/.zshrc):"
            echo -e "  ${BOLD}export PATH=\"$BIN_DIR:\$PATH\"${NC}"
            ;;
    esac
}

check_path

echo ""
echo -e "${GREEN}${BOLD}✓ Instalação do kali-ormachy concluída com sucesso!${NC}"
echo -e "Execute '${BOLD}kali-ormachy-rofi${NC}' ou pressione ${BOLD}\$mainMod + K${NC} no Hyprland."
exit 0
