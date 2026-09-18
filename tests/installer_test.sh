#!/usr/bin/env bash
#
# tests/installer_test.sh
# Automated integration tests for Makefile and install.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
INSTALLER="$ROOT_DIR/install.sh"
MAKEFILE="$ROOT_DIR/Makefile"

# Sandbox setup
SANDBOX="$(mktemp -d /tmp/kali-ormachy-install-test-XXXXXX)"
cleanup() {
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

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
    bash -n "$INSTALLER"
}

# --- Test 2: Help Flag ---
test_help_flag() {
    local out
    out=$("$INSTALLER" --help)
    assert_contains "$out" "Uso: ./install.sh"
    assert_contains "$out" "--prefix"
    assert_contains "$out" "--config-dir"
    assert_contains "$out" "--hypr-conf"
    assert_contains "$out" "--dry-run"
    assert_contains "$out" "--uninstall"
}

# --- Test 3: Dry-Run Install Does Not Create Files ---
test_dry_run_install() {
    local test_prefix="$SANDBOX/dry_prefix"
    local test_config="$SANDBOX/dry_config"
    local test_hypr="$SANDBOX/dry_hypr/hyprland.conf"
    mkdir -p "$(dirname "$test_hypr")"
    touch "$test_hypr"

    local out
    out=$("$INSTALLER" --dry-run --prefix "$test_prefix" --config-dir "$test_config" --hypr-conf "$test_hypr")
    assert_contains "$out" "[DRY-RUN]"

    # Verify no files were actually installed
    [ ! -d "$test_prefix" ] || return 1
    [ ! -d "$test_config" ] || return 1
    [ ! -s "$test_hypr" ] || return 1
}

# --- Test 4: Dry-Run Uninstall Does Not Delete Files ---
test_dry_run_uninstall() {
    local test_prefix="$SANDBOX/dry_uninst_prefix"
    local test_config="$SANDBOX/dry_uninst_config"
    mkdir -p "$test_prefix/bin" "$test_config"
    touch "$test_prefix/bin/kali-ormachy" "$test_prefix/bin/kali-ormachy-rofi" "$test_config/kali-ormachy.rasi"

    local out
    out=$("$INSTALLER" --dry-run --uninstall --prefix "$test_prefix" --config-dir "$test_config")
    assert_contains "$out" "[DRY-RUN]"

    [ -f "$test_prefix/bin/kali-ormachy" ] || return 1
    [ -f "$test_prefix/bin/kali-ormachy-rofi" ] || return 1
    [ -f "$test_config/kali-ormachy.rasi" ] || return 1
}

# --- Test 5: Sandbox Installation ---
test_sandbox_install() {
    local test_prefix="$SANDBOX/inst_prefix"
    local test_config="$SANDBOX/inst_config"
    local test_hypr="$SANDBOX/inst_hypr/hyprland.conf"
    mkdir -p "$(dirname "$test_hypr")"
    echo "# Initial mock hyprland config" > "$test_hypr"

    # Run installer with --skip-build (target/release/kali-ormachy is already compiled)
    "$INSTALLER" --skip-build \
        --prefix "$test_prefix" \
        --config-dir "$test_config" \
        --hypr-conf "$test_hypr" \
        --yes

    # Check binaries
    [ -x "$test_prefix/bin/kali-ormachy" ] || return 1
    [ -x "$test_prefix/bin/kali-ormachy-rofi" ] || return 1

    # Check config & theme
    [ -f "$test_config/config.toml" ] || return 1
    [ -f "$test_config/kali-ormachy.rasi" ] || return 1

    # Check hyprland keybind addition
    grep -q "bind = \$mainMod, K, exec, kali-ormachy-rofi" "$test_hypr" || return 1
}

# --- Test 6: Reinstall Idempotency (Preserve User Config and Single Keybind) ---
test_reinstall_idempotency() {
    local test_prefix="$SANDBOX/inst_prefix"
    local test_config="$SANDBOX/inst_config"
    local test_hypr="$SANDBOX/inst_hypr/hyprland.conf"

    # Append custom marker to existing config
    echo "# USER_CUSTOM_MARKER=1" >> "$test_config/config.toml"

    # Run installer again
    "$INSTALLER" --skip-build \
        --prefix "$test_prefix" \
        --config-dir "$test_config" \
        --hypr-conf "$test_hypr" \
        --yes

    # Config must retain the user customization
    grep -q "USER_CUSTOM_MARKER=1" "$test_config/config.toml" || return 1

    # Hyprland bind must not be duplicated
    local bind_count
    bind_count=$(grep -c "kali-ormachy-rofi" "$test_hypr")
    [ "$bind_count" -eq 1 ] || return 1
}

# --- Test 7: Sandbox Uninstallation ---
test_sandbox_uninstall() {
    local test_prefix="$SANDBOX/inst_prefix"
    local test_config="$SANDBOX/inst_config"
    local test_hypr="$SANDBOX/inst_hypr/hyprland.conf"

    "$INSTALLER" --uninstall \
        --prefix "$test_prefix" \
        --config-dir "$test_config" \
        --hypr-conf "$test_hypr" \
        --yes

    # Binaries removed
    [ ! -f "$test_prefix/bin/kali-ormachy" ] || return 1
    [ ! -f "$test_prefix/bin/kali-ormachy-rofi" ] || return 1

    # Theme removed
    [ ! -f "$test_config/kali-ormachy.rasi" ] || return 1

    # User config preserved without --purge
    [ -f "$test_config/config.toml" ] || return 1

    # Hyprland keybind removed
    ! grep -q "kali-ormachy-rofi" "$test_hypr" || return 1
}

# --- Test 8: Sandbox Uninstallation with --purge ---
test_sandbox_uninstall_purge() {
    local test_prefix="$SANDBOX/purge_prefix"
    local test_config="$SANDBOX/purge_config"
    local test_hypr="$SANDBOX/purge_hypr/hyprland.conf"
    mkdir -p "$(dirname "$test_hypr")"
    echo "# Config" > "$test_hypr"

    "$INSTALLER" --skip-build \
        --prefix "$test_prefix" \
        --config-dir "$test_config" \
        --hypr-conf "$test_hypr" \
        --yes

    [ -f "$test_config/config.toml" ] || return 1

    "$INSTALLER" --uninstall --purge \
        --prefix "$test_prefix" \
        --config-dir "$test_config" \
        --hypr-conf "$test_hypr" \
        --yes

    # With purge, config.toml and config directory should be gone
    [ ! -f "$test_config/config.toml" ] || return 1
    [ ! -d "$test_config" ] || return 1
}

# --- Test 9: Makefile Dry-Run Targets ---
test_makefile_dry_run() {
    local out
    out=$(make -f "$MAKEFILE" -n install)
    assert_contains "$out" "target/release/kali-ormachy"
    assert_contains "$out" "scripts/kali-rofi-launcher.sh"
    assert_contains "$out" "config.default.toml"
    assert_contains "$out" "themes/kali-ormachy.rasi"

    out=$(make -f "$MAKEFILE" -n uninstall)
    assert_contains "$out" "rm -f"
}

# --- Test 10: Makefile Sandbox Install & Uninstall ---
test_makefile_sandbox_lifecycle() {
    local make_prefix="$SANDBOX/make_prefix"
    local make_config="$SANDBOX/make_config"

    # Install
    make -f "$MAKEFILE" install PREFIX="$make_prefix" XDG_CONFIG_HOME="$make_config" >/dev/null

    [ -x "$make_prefix/bin/kali-ormachy" ] || return 1
    [ -x "$make_prefix/bin/kali-ormachy-rofi" ] || return 1
    [ -f "$make_config/ormachy-kali/config.toml" ] || return 1
    [ -f "$make_config/ormachy-kali/kali-ormachy.rasi" ] || return 1

    # Preserve custom config on second make install
    echo "# MAKEFILE_CUSTOM_MARKER=1" >> "$make_config/ormachy-kali/config.toml"
    make -f "$MAKEFILE" install PREFIX="$make_prefix" XDG_CONFIG_HOME="$make_config" >/dev/null
    grep -q "MAKEFILE_CUSTOM_MARKER=1" "$make_config/ormachy-kali/config.toml" || return 1

    # Uninstall
    make -f "$MAKEFILE" uninstall PREFIX="$make_prefix" XDG_CONFIG_HOME="$make_config" >/dev/null

    [ ! -f "$make_prefix/bin/kali-ormachy" ] || return 1
    [ ! -f "$make_prefix/bin/kali-ormachy-rofi" ] || return 1
    [ ! -f "$make_config/ormachy-kali/kali-ormachy.rasi" ] || return 1
    # Config preserved
    [ -f "$make_config/ormachy-kali/config.toml" ] || return 1
}

# --- Test 11: Installed Theme Resolution in kali-rofi-launcher.sh ---
test_installed_theme_resolution() {
    local test_config="$SANDBOX/theme_test_config"
    mkdir -p "$test_config/ormachy-kali"
    touch "$test_config/ormachy-kali/kali-ormachy.rasi"

    local resolved
    resolved=$(XDG_CONFIG_HOME="$test_config" bash -c "
        eval \"\$(sed -n '/^resolve_theme() {/,/^}/p' '$ROOT_DIR/scripts/kali-rofi-launcher.sh')\"
        resolve_theme
    ")
    [ "$resolved" = "$test_config/ormachy-kali/kali-ormachy.rasi" ] || return 1
}

echo "======================================================="
echo "Kali-Ormachy Task 7: Installer & Makefile Tests"
echo "======================================================="

run_test "test_syntax" test_syntax
run_test "test_help_flag" test_help_flag
run_test "test_dry_run_install" test_dry_run_install
run_test "test_dry_run_uninstall" test_dry_run_uninstall
run_test "test_sandbox_install" test_sandbox_install
run_test "test_reinstall_idempotency" test_reinstall_idempotency
run_test "test_sandbox_uninstall" test_sandbox_uninstall
run_test "test_sandbox_uninstall_purge" test_sandbox_uninstall_purge
run_test "test_makefile_dry_run" test_makefile_dry_run
run_test "test_makefile_sandbox_lifecycle" test_makefile_sandbox_lifecycle
run_test "test_installed_theme_resolution" test_installed_theme_resolution

echo "======================================================="
echo "Results: $PASSED passed; $FAILED failed"
echo "======================================================="

if [ $FAILED -ne 0 ]; then
    exit 1
fi
exit 0
