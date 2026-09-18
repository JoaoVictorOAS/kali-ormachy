#!/usr/bin/env bash
#
# tests/rofi_launcher_test.sh
# Automated integration tests for scripts/kali-rofi-launcher.sh and themes/kali-ormachy.rasi
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LAUNCHER="$ROOT_DIR/scripts/kali-rofi-launcher.sh"
MOCK_ROFI="$SCRIPT_DIR/mock_rofi.sh"
TEST_CONFIG="$SCRIPT_DIR/fixtures/test_config.toml"
THEME_FILE="$ROOT_DIR/themes/kali-ormachy.rasi"

# Ensure kali-ormachy binary is available
export KALI_ORMACHY_BIN="$ROOT_DIR/target/release/kali-ormachy"
if [ ! -x "$KALI_ORMACHY_BIN" ]; then
    echo "Compiling release binary before running tests..."
    (cd "$ROOT_DIR" && cargo build --release)
fi

export ROFI_CMD="$MOCK_ROFI"

PASSED=0
FAILED=0

run_test() {
    local test_name="$1"
    shift
    printf "Running %-55s " "$test_name..."
    if output=$("$@" 2>&1); then
        echo "OK"
        PASSED=$((PASSED + 1))
    else
        echo "FAILED"
        echo "--- Output ---"
        echo "$output"
        echo "--------------"
        FAILED=$((FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if ! echo "$haystack" | grep -qF -e "$needle"; then
        echo "Assertion failed: expected output to contain '$needle'" >&2
        echo "Actual output:" >&2
        echo "$haystack" >&2
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if echo "$haystack" | grep -qF -e "$needle"; then
        echo "Assertion failed: expected output NOT to contain '$needle'" >&2
        echo "Actual output:" >&2
        echo "$haystack" >&2
        return 1
    fi
}

# --- Test 1: Bash Syntax Validation ---
test_syntax() {
    bash -n "$LAUNCHER"
}

# --- Test 2: Theme Zero Hardcoded Colors ---
test_theme_conformance() {
    [ -f "$THEME_FILE" ] || return 1
    # Must import system or omarchy rofi configuration
    grep -q '@import "~/.config/rofi/config.rasi"' "$THEME_FILE" || return 1
    # Must NOT contain hardcoded hex colors
    if grep -qE '#[0-9a-fA-F]{3,8}' "$THEME_FILE"; then
        echo "Error: Hardcoded hex colors found in $THEME_FILE" >&2
        return 1
    fi
    # Must NOT contain rgb or rgba colors
    if grep -qE 'rgba?\(' "$THEME_FILE"; then
        echo "Error: Hardcoded rgb/rgba colors found in $THEME_FILE" >&2
        return 1
    fi
}

# --- Test 3: Launcher Help Flag ---
test_help_flag() {
    local out
    out=$("$LAUNCHER" --help)
    assert_contains "$out" "Usage:"
    assert_contains "$out" "--category"
    assert_contains "$out" "--tool"
    assert_contains "$out" "--dry-run"
}

# --- Test 4: Missing Binary Error Handling ---
test_missing_binary() {
    local out
    local rc=0
    out=$(KALI_ORMACHY_BIN="/nonexistent/kali-ormachy-xyz" "$LAUNCHER" 2>&1) || rc=$?
    [ $rc -ne 0 ] || return 1
    assert_contains "$out" "does not exist or is not executable"
}

# --- Test 5: Missing Tool Flow - Option "Instalar agora" (Hermetic) ---
test_missing_tool_install_option() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✗ MockMissing - Mock Missing Tool\tMockMissing' \
        MOCK_ROFI_MISSING_CHOICE="Instalar agora (sudo pacman -S mock-missing-pkg)" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "[DRY-RUN] Executar instalação: sudo pacman -S mock-missing-pkg"
}

# --- Test 6: Missing Tool Flow - Option "Copiar comando" (Hermetic) ---
test_missing_tool_copy_option() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✗ MockMissing - Mock Missing Tool\tMockMissing' \
        MOCK_ROFI_MISSING_CHOICE="Copiar comando de instalação" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "[DRY-RUN] Copiado para a área de transferência: sudo pacman -S mock-missing-pkg"
}

# --- Test 7: Missing Tool Flow - Option "Cancelar" (Hermetic) ---
test_missing_tool_cancel_option() {
    local out
    local rc=0
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✗ MockMissing - Mock Missing Tool\tMockMissing' \
        MOCK_ROFI_MISSING_CHOICE="Cancelar" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    ) || rc=$?
    [ $rc -eq 0 ] || return 1
    [ -z "$out" ] || return 1
}

# --- Test 8: Installed CLI Tool Full Interactive Flow (Hermetic) ---
test_installed_cli_tool_interactive() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✓ MockCLI - Mock CLI Tool\tMockCLI' \
        MOCK_ROFI_PRESET=$'Preset One\t0' \
        MOCK_ROFI_PARAM="test_hermetic_value" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "sh -c 'echo test_hermetic_value'"
}

# --- Test 9: Installed GUI Tool Immediate Dispatch ---
test_installed_gui_tool() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✓ MockGUI - Mock GUI Tool\tMockGUI' \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "sh"
    # Verify it did not try to prompt for presets or parameters
    assert_not_contains "$out" "Preset"
}

# --- Test 10: Multi-preset CLI Tool with Parameters ---
test_cli_multi_preset_with_params() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✓ MockCLI - Mock CLI Tool\tMockCLI' \
        MOCK_ROFI_PRESET=$'Preset One\t0' \
        MOCK_ROFI_PARAM="hello_kali" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "sh -c 'echo hello_kali'"
}

# --- Test 11: Headless Direct Execution (Skipping Rofi Prompts) ---
test_headless_direct_execution() {
    local out
    out=$("$LAUNCHER" --category reverse --tool GDB --preset 0 --param binary_path=/bin/ls --dry-run)
    assert_contains "$out" "gdb -q /bin/ls"
}

# --- Test 12: Cancellation at Category Selection ---
test_cancel_at_category() {
    local rc=0
    MOCK_ROFI_CANCEL_CAT=1 "$LAUNCHER" --dry-run || rc=$?
    [ $rc -eq 0 ] || return 1
}

# --- Test 13: Cancellation at Tool Selection ---
test_cancel_at_tool() {
    local rc=0
    MOCK_ROFI_CAT=$'󰘔 Engenharia Reversa\treverse' \
    MOCK_ROFI_CANCEL_TOOL=1 \
    "$LAUNCHER" --dry-run || rc=$?
    [ $rc -eq 0 ] || return 1
}

# --- Test 14: Cancellation at Preset Selection ---
test_cancel_at_preset() {
    local rc=0
    MOCK_ROFI_CAT=$'󰘔 Engenharia Reversa\treverse' \
    MOCK_ROFI_TOOL=$'✓ GDB - GNU Debugger\tGDB' \
    MOCK_ROFI_CANCEL_PRESET=1 \
    "$LAUNCHER" --dry-run || rc=$?
    [ $rc -eq 0 ] || return 1
}

# --- Test 15: Cancellation at Param Prompt ---
test_cancel_at_param() {
    local rc=0
    MOCK_ROFI_CAT=$'󰘔 Engenharia Reversa\treverse' \
    MOCK_ROFI_TOOL=$'✓ GDB - GNU Debugger\tGDB' \
    MOCK_ROFI_PRESET=$'Depurar Binário\t0' \
    MOCK_ROFI_CANCEL_PARAM=1 \
    "$LAUNCHER" --dry-run || rc=$?
    [ $rc -eq 0 ] || return 1
}

# --- Test 16: Default Param Fallback on Empty Input ---
test_cli_tool_default_param_fallback() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✓ MockCLI - Mock CLI Tool\tMockCLI' \
        MOCK_ROFI_PRESET=$'Preset One\t0' \
        MOCK_ROFI_PARAM="" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "sh -c 'echo hello'"
}

# --- Test 17: Parameter CLI Flag Override ---
test_cli_tool_param_override() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✓ MockCLI - Mock CLI Tool\tMockCLI' \
        MOCK_ROFI_PRESET=$'Preset One\t0' \
        "$LAUNCHER" --config "$TEST_CONFIG" --param "greeting=custom_override" --dry-run
    )
    assert_contains "$out" "sh -c 'echo custom_override'"
}

# --- Test 18: Second Preset Selection ---
test_cli_tool_second_preset() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✓ MockCLI - Mock CLI Tool\tMockCLI' \
        MOCK_ROFI_PRESET=$'Preset Two\t1' \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "sh -c 'echo goodbye'"
}

# --- Test 19: Hyphenated Tool Name Extraction (Aircrack-ng with tab) ---
test_hyphenated_tool_aircrack_tab() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰛳 Redes & Wi-Fi\tnetwork' \
        MOCK_ROFI_TOOL=$'✗ Aircrack-ng - Suite de auditoria de redes 802.11\tAircrack-ng' \
        MOCK_ROFI_MISSING_CHOICE="Instalar agora (sudo pacman -S aircrack-ng)" \
        "$LAUNCHER" --dry-run
    )
    assert_contains "$out" "[DRY-RUN] Executar instalação: sudo pacman -S aircrack-ng"
    assert_not_contains "$out" "sudo pacman -S Aircrack "
}

# --- Test 20: Hyphenated Tool Name Extraction (Aircrack-ng fallback without tab) ---
test_hyphenated_tool_aircrack_no_tab() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰛳 Redes & Wi-Fi\tnetwork' \
        MOCK_ROFI_TOOL=$'✗ Aircrack-ng - Suite de auditoria de redes 802.11' \
        MOCK_ROFI_MISSING_CHOICE="Instalar agora (sudo pacman -S aircrack-ng)" \
        "$LAUNCHER" --dry-run
    )
    assert_contains "$out" "[DRY-RUN] Executar instalação: sudo pacman -S aircrack-ng"
    assert_not_contains "$out" "sudo pacman -S Aircrack "
}

# --- Test 21: Hyphenated Tool Name Extraction (Hermetic Mock-Hyphen-Tool) ---
test_hyphenated_tool_hermetic() {
    local out
    out=$(
        MOCK_ROFI_CAT=$'󰙨 Categoria de Teste\ttesting' \
        MOCK_ROFI_TOOL=$'✗ Mock-Hyphen-Tool - Mock Tool with Hyphen in Name\tMock-Hyphen-Tool' \
        MOCK_ROFI_MISSING_CHOICE="Instalar agora (sudo pacman -S mock-hyphen-pkg)" \
        "$LAUNCHER" --config "$TEST_CONFIG" --dry-run
    )
    assert_contains "$out" "[DRY-RUN] Executar instalação: sudo pacman -S mock-hyphen-pkg"
    assert_not_contains "$out" "sudo pacman -S Mock "
}

echo "======================================================="
echo "Kali-Ormachy Task 6: Rofi Dynamic Flow & Theming Tests"
echo "======================================================="

run_test "test_syntax" test_syntax
run_test "test_theme_conformance" test_theme_conformance
run_test "test_help_flag" test_help_flag
run_test "test_missing_binary" test_missing_binary
run_test "test_missing_tool_install_option" test_missing_tool_install_option
run_test "test_missing_tool_copy_option" test_missing_tool_copy_option
run_test "test_missing_tool_cancel_option" test_missing_tool_cancel_option
run_test "test_installed_cli_tool_interactive" test_installed_cli_tool_interactive
run_test "test_installed_gui_tool" test_installed_gui_tool
run_test "test_cli_multi_preset_with_params" test_cli_multi_preset_with_params
run_test "test_headless_direct_execution" test_headless_direct_execution
run_test "test_cancel_at_category" test_cancel_at_category
run_test "test_cancel_at_tool" test_cancel_at_tool
run_test "test_cancel_at_preset" test_cancel_at_preset
run_test "test_cancel_at_param" test_cancel_at_param
run_test "test_cli_tool_default_param_fallback" test_cli_tool_default_param_fallback
run_test "test_cli_tool_param_override" test_cli_tool_param_override
run_test "test_cli_tool_second_preset" test_cli_tool_second_preset
run_test "test_hyphenated_tool_aircrack_tab" test_hyphenated_tool_aircrack_tab
run_test "test_hyphenated_tool_aircrack_no_tab" test_hyphenated_tool_aircrack_no_tab
run_test "test_hyphenated_tool_hermetic" test_hyphenated_tool_hermetic

echo "======================================================="
echo "Results: $PASSED passed; $FAILED failed"
echo "======================================================="

if [ $FAILED -ne 0 ]; then
    exit 1
fi
exit 0
