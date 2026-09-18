#!/usr/bin/env bash
#
# kali-rofi-launcher.sh
# Dynamic 2-step menu launcher for kali-ormachy with Omarchy theme inheritance.
#

set -euo pipefail

# --- Helper Functions ---

find_binary() {
    if [ -n "${KALI_ORMACHY_BIN:-}" ]; then
        if [ -x "$KALI_ORMACHY_BIN" ]; then
            echo "$KALI_ORMACHY_BIN"
            return 0
        fi
        echo "Error: specified KALI_ORMACHY_BIN='$KALI_ORMACHY_BIN' does not exist or is not executable" >&2
        return 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local candidates=(
        "$script_dir/kali-ormachy"
        "$script_dir/../target/release/kali-ormachy"
        "$script_dir/../target/debug/kali-ormachy"
        "$HOME/.local/bin/kali-ormachy"
        "/usr/local/bin/kali-ormachy"
        "/usr/bin/kali-ormachy"
    )

    for cand in "${candidates[@]}"; do
        if [ -x "$cand" ]; then
            echo "$cand"
            return 0
        fi
    done

    if command -v kali-ormachy >/dev/null 2>&1; then
        command -v kali-ormachy
        return 0
    fi

    return 1
}

resolve_theme() {
    if [ -n "${ROFI_THEME:-}" ] && [ -f "$ROFI_THEME" ]; then
        echo "$ROFI_THEME"
        return 0
    fi

    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    local installed_theme="$xdg_config/ormachy-kali/kali-ormachy.rasi"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local dev_theme="$script_dir/../themes/kali-ormachy.rasi"

    local candidates=(
        "$installed_theme"
        "$dev_theme"
        "/usr/share/ormachy-kali/kali-ormachy.rasi"
    )

    for cand in "${candidates[@]}"; do
        if [ -f "$cand" ]; then
            # Ensure ~/.config/rofi/config.rasi exists so @import does not fail
            if [ ! -f "$HOME/.config/rofi/config.rasi" ]; then
                mkdir -p "$HOME/.config/rofi" 2>/dev/null || true
                touch "$HOME/.config/rofi/config.rasi" 2>/dev/null || true
            fi
            echo "$cand"
            return 0
        fi
    done

    return 1
}

run_rofi() {
    local prompt="$1"
    shift

    if [ -n "${ROFI_CMD:-}" ]; then
        $ROFI_CMD -dmenu -p "$prompt" "$@"
        return $?
    elif command -v rofi >/dev/null 2>&1; then
        local theme_flags=()
        if [ -n "${ROFI_THEME:-}" ] && [ -f "$ROFI_THEME" ]; then
            theme_flags=("-theme" "$ROFI_THEME")
        fi
        rofi -dmenu -p "$prompt" "${theme_flags[@]}" "$@"
        return $?
    elif command -v wofi >/dev/null 2>&1; then
        wofi --dmenu -p "$prompt" "$@"
        return $?
    else
        echo "Error: neither 'rofi' nor 'wofi' was found in PATH (and ROFI_CMD is not set)." >&2
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "kali-ormachy" "Rofi não encontrado no sistema."
        fi
        return 127
    fi
}

get_tool_mode() {
    local cat="$1"
    local tool="$2"
    local mode=""

    if [ -n "$cat" ]; then
        mode=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" tools --category "$cat" --format json 2>/dev/null | awk -v target="$tool" '
            BEGIN { in_target = 0 }
            index($0, "\"name\": \"" target "\"") > 0 { in_target = 1 }
            in_target && /"mode":/ {
                sub(/.*"mode": "/, "");
                sub(/".*/, "");
                print;
                exit;
            }
        ')
    fi

    if [ -z "$mode" ]; then
        mode=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" --format json categories 2>/dev/null | awk -v target="$tool" '
            BEGIN { in_target = 0 }
            index($0, "\"name\": \"" target "\"") > 0 { in_target = 1 }
            in_target && /"mode":/ {
                sub(/.*"mode": "/, "");
                sub(/".*/, "");
                print;
                exit;
            }
        ')
    fi

    echo "${mode:-terminal}"
}

launch_install_in_terminal() {
    local cmd="$1"
    local term="${TERMINAL:-}"

    if [ -z "$term" ]; then
        for candidate in kitty foot alacritty xterm; do
            if command -v "$candidate" >/dev/null 2>&1; then
                term="$candidate"
                break
            fi
        done
    fi

    local term_bin
    term_bin=$(basename "${term:-sh}")

    case "$term_bin" in
        kitty)
            "$term" --hold sh -c "$cmd; exec \$SHELL" &
            ;;
        foot)
            "$term" --hold sh -c "$cmd; exec \$SHELL" &
            ;;
        alacritty)
            "$term" --hold -e sh -c "$cmd; exec \$SHELL" &
            ;;
        xterm)
            "$term" -hold -e sh -c "$cmd; exec \$SHELL" &
            ;;
        *)
            if [ -n "$term" ] && command -v "$term" >/dev/null 2>&1; then
                "$term" -e sh -c "$cmd; exec \$SHELL" &
            else
                echo "Erro: Nenhum emulador de terminal encontrado para executar '$cmd'." >&2
                return 1
            fi
            ;;
    esac
}

copy_to_clipboard() {
    local text="$1"
    if command -v wl-copy >/dev/null 2>&1; then
        printf "%s" "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf "%s" "$text" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf "%s" "$text" | xsel --clipboard --input
    else
        echo "Warning: no clipboard tool found (wl-copy, xclip, xsel)" >&2
    fi
}

# --- Argument Parsing ---

DRY_RUN=0
CONFIG_ARGS=()
CATEGORY=""
TOOL=""
PRESET=""
EXTRA_PARAMS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --config)
            if [ -n "${2:-}" ]; then
                CONFIG_ARGS=("--config" "$2")
                shift 2
            else
                echo "Error: --config requires a path argument" >&2
                exit 1
            fi
            ;;
        -c|--category)
            if [ -n "${2:-}" ]; then
                CATEGORY="$2"
                shift 2
            else
                echo "Error: --category requires an argument" >&2
                exit 1
            fi
            ;;
        -t|--tool)
            if [ -n "${2:-}" ]; then
                TOOL="$2"
                shift 2
            else
                echo "Error: --tool requires an argument" >&2
                exit 1
            fi
            ;;
        -p|--preset)
            if [ -n "${2:-}" ]; then
                PRESET="$2"
                shift 2
            else
                echo "Error: --preset requires an argument" >&2
                exit 1
            fi
            ;;
        --param)
            if [ -n "${2:-}" ]; then
                EXTRA_PARAMS+=("$2")
                shift 2
            else
                echo "Error: --param requires key=value" >&2
                exit 1
            fi
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --category <id>     Select category directly"
            echo "  -t, --tool <name>       Select tool directly"
            echo "  -p, --preset <idx|name> Select preset directly"
            echo "      --param <key=val>   Specify tool parameter (can be repeated)"
            echo "      --config <path>     Custom configuration file path"
            echo "      --dry-run           Print resolved commands without executing"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# --- Initialization ---

KALI_ORMACHY_BIN=$(find_binary) || {
    echo "Error: kali-ormachy binary not found. Build it with 'cargo build --release' or place it in PATH." >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "kali-ormachy" "Binário kali-ormachy não encontrado."
    fi
    exit 1
}

ROFI_THEME=$(resolve_theme || true)

# --- Step 1: Category Selection ---

cat_id="$CATEGORY"
if [ -z "$cat_id" ]; then
    categories_list=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" categories)
    if [ -z "$categories_list" ]; then
        echo "Error: No categories found." >&2
        exit 1
    fi

    set +e
    cat_selection=$(printf "%s\n" "$categories_list" | run_rofi "Kali Ormachy")
    rc=$?
    set -e

    if [ $rc -eq 127 ]; then
        exit 127
    elif [ $rc -ne 0 ] || [ -z "$cat_selection" ]; then
        exit 0
    fi

    cat_id=$(printf "%s\n" "$cat_selection" | awk -F'\t' '{print ($2 != "" ? $2 : $1)}' | tr -d '\r' | xargs)
fi

# --- Step 2: Tool Selection ---

tool_name="$TOOL"
if [ -z "$tool_name" ]; then
    tools_list=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" tools --category "$cat_id")
    if [ -z "$tools_list" ]; then
        echo "Error: No tools found for category '$cat_id'." >&2
        exit 1
    fi

    set +e
    tool_selection=$(printf "%s\n" "$tools_list" | run_rofi "Ferramenta ($cat_id)")
    rc=$?
    set -e

    if [ $rc -eq 127 ]; then
        exit 127
    elif [ $rc -ne 0 ] || [ -z "$tool_selection" ]; then
        exit 0
    fi

    tool_name=$(printf "%s\n" "$tool_selection" | awk -F'\t' '{
        if ($2 != "") {
            print $2
        } else {
            sub(/^(\xe2\x9c\x93|\xe2\x9c\x97|✓|✗)[ \t]*/, "", $1);
            sub(/[ \t]+-.*$/, "", $1);
            print $1
        }
    }' | tr -d '\r' | xargs)
fi

# --- Step 3: Tool Presence Verification ---

set +e
check_output=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" check --tool "$tool_name" 2>/dev/null)
check_status=$?
set -e

if [ $check_status -ne 0 ]; then
    # Tool is missing
    install_cmd="${check_output:-sudo pacman -S $tool_name}"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -i security-low "kali-ormachy" "Ferramenta $tool_name não encontrada.\nInstale com: $install_cmd"
    fi

    missing_menu=$(printf "Instalar agora (%s)\nCopiar comando de instalação\nCancelar\n" "$install_cmd")
    set +e
    missing_choice=$(printf "%s" "$missing_menu" | run_rofi "Dependência ausente: $tool_name")
    rc=$?
    set -e

    if [ $rc -eq 127 ]; then
        exit 127
    elif [ $rc -ne 0 ] || [ -z "$missing_choice" ]; then
        exit 0
    fi

    case "$missing_choice" in
        *"Instalar agora"*)
            if [ "$DRY_RUN" = "1" ]; then
                echo "[DRY-RUN] Executar instalação: $install_cmd"
            else
                launch_install_in_terminal "$install_cmd"
            fi
            exit 0
            ;;
        *"Copiar comando"*)
            if [ "$DRY_RUN" = "1" ]; then
                echo "[DRY-RUN] Copiado para a área de transferência: $install_cmd"
            else
                copy_to_clipboard "$install_cmd"
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send -u low -i edit-copy "kali-ormachy" "Comando copiado:\n$install_cmd"
                fi
            fi
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
fi

# --- Step 4: Dispatch Tool (GUI or Terminal) ---

tool_mode=$(get_tool_mode "$cat_id" "$tool_name")
[ -z "$tool_mode" ] && tool_mode="terminal"

dry_run_flags=()
if [ "$DRY_RUN" = "1" ]; then
    dry_run_flags=("--dry-run")
fi

if [ "$tool_mode" = "gui" ]; then
    "$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" launch-tool --name "$tool_name" "${dry_run_flags[@]}"
    exit $?
fi

# Terminal tool: handle presets and params
preset_arg=()
if [ -n "$PRESET" ]; then
    preset_arg=("--preset" "$PRESET")
else
    presets_list=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" presets --tool "$tool_name" 2>/dev/null || true)
    if [ -n "$presets_list" ]; then
        preset_count=$(printf "%s\n" "$presets_list" | grep -c . || true)
        if [ "$preset_count" -gt 1 ]; then
            set +e
            preset_choice=$(printf "%s\n" "$presets_list" | run_rofi "Preset ($tool_name)")
            rc=$?
            set -e

            if [ $rc -eq 127 ]; then
                exit 127
            elif [ $rc -ne 0 ] || [ -z "$preset_choice" ]; then
                exit 0
            fi

            preset_idx=$(printf "%s\n" "$preset_choice" | awk -F'\t' '{print ($2 != "" ? $2 : $1)}' | tr -d '\r' | xargs)
            preset_arg=("--preset" "$preset_idx")
        else
            preset_arg=("--preset" "0")
        fi
    fi
fi

# Parameters prompt
param_args=()
params_list=$("$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" params --tool "$tool_name" 2>/dev/null || true)

if [ -n "$params_list" ]; then
    while IFS=$'\t' read -r p_key p_prompt p_default || [ -n "$p_key" ]; do
        [ -z "$p_key" ] && continue

        # Check if already given via CLI extra params
        param_override=""
        for ep in "${EXTRA_PARAMS[@]}"; do
            if [[ "$ep" == "$p_key="* ]]; then
                param_override="${ep#*=}"
                break
            fi
        done

        if [ -n "$param_override" ]; then
            param_args+=("--param" "${p_key}=${param_override}")
        else
            p_label="${p_prompt:-$p_key:}"
            filter_opts=()
            if [ -n "$p_default" ]; then
                filter_opts=("-filter" "$p_default")
            fi

            set +e
            p_val=$(printf "%s" "$p_default" | run_rofi "$p_label" "${filter_opts[@]}")
            rc=$?
            set -e

            if [ $rc -eq 127 ]; then
                exit 127
            elif [ $rc -ne 0 ]; then
                exit 0
            fi

            final_val="${p_val:-$p_default}"
            param_args+=("--param" "${p_key}=${final_val}")
        fi
    done <<< "$params_list"
fi

# Add any extra params that weren't prompted
for ep in "${EXTRA_PARAMS[@]}"; do
    ep_key="${ep%%=*}"
    already_included=0
    for ((i = 0; i < ${#param_args[@]}; i++)); do
        if [[ "${param_args[i]}" == "${ep_key}="* ]]; then
            already_included=1
            break
        fi
    done
    if [ $already_included -eq 0 ]; then
        param_args+=("--param" "$ep")
    fi
done

"$KALI_ORMACHY_BIN" "${CONFIG_ARGS[@]}" launch-tool \
    --name "$tool_name" \
    "${preset_arg[@]}" \
    "${param_args[@]}" \
    "${dry_run_flags[@]}"
exit $?
