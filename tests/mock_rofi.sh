#!/usr/bin/env bash
#
# tests/mock_rofi.sh
# Mock Rofi frontend for automated testing of kali-rofi-launcher.sh
#

prompt=""
filter=""

while [ $# -gt 0 ]; do
    case "$1" in
        -p)
            prompt="$2"
            shift 2
            ;;
        -filter)
            filter="$2"
            shift 2
            ;;
        -theme|-dmenu)
            shift
            ;;
        *)
            shift
            ;;
    esac
done

input=$(cat)

if [ -n "${MOCK_ROFI_CANCEL:-}" ]; then
    exit 1
fi

case "$prompt" in
    *"Kali Ormachy"*)
        if [ -n "${MOCK_ROFI_CANCEL_CAT:-}" ]; then
            exit 1
        fi
        echo "${MOCK_ROFI_CAT:-󰘔 Engenharia Reversa	reverse}"
        ;;
    *"Ferramenta"*)
        if [ -n "${MOCK_ROFI_CANCEL_TOOL:-}" ]; then
            exit 1
        fi
        echo "${MOCK_ROFI_TOOL:-✓ GDB - GNU Debugger	GDB}"
        ;;
    *"Dependência ausente"*)
        if [ -n "${MOCK_ROFI_CANCEL_MISSING:-}" ]; then
            exit 1
        fi
        echo "${MOCK_ROFI_MISSING_CHOICE:-Instalar agora (sudo pacman -S nmap)}"
        ;;
    *"Preset"*)
        if [ -n "${MOCK_ROFI_CANCEL_PRESET:-}" ]; then
            exit 1
        fi
        echo "${MOCK_ROFI_PRESET:-Depurar Binário	0}"
        ;;
    *)
        if [ -n "${MOCK_ROFI_CANCEL_PARAM:-}" ]; then
            exit 1
        fi
        if [ -n "${MOCK_ROFI_PARAM:-}" ]; then
            echo "$MOCK_ROFI_PARAM"
        elif [ -n "$filter" ]; then
            echo "$filter"
        else
            echo "$input" | head -n 1
        fi
        ;;
esac
