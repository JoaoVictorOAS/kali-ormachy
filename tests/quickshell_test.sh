#!/usr/bin/env bash
#
# tests/quickshell_test.sh
# Verification and integration tests for Quickshell / QML frontend
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
QUICKSHELL_DIR="$ROOT_DIR/quickshell"

# Locate cargo and kali-ormachy binary
CARGO_CMD="${HOME}/.cargo/bin/cargo"
if ! command -v "$CARGO_CMD" >/dev/null 2>&1; then
    CARGO_CMD="$(command -v cargo 2>/dev/null || true)"
fi

export KALI_ORMACHY_BIN="$ROOT_DIR/target/release/kali-ormachy"
if [ ! -x "$KALI_ORMACHY_BIN" ]; then
    echo "Compiling release binary before running tests..."
    if [ -n "$CARGO_CMD" ] && [ -x "$CARGO_CMD" ]; then
        (cd "$ROOT_DIR" && "$CARGO_CMD" build --release)
    else
        echo "Error: cargo not found to compile release binary" >&2
        exit 1
    fi
fi

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
        echo "Assertion failed: expected content to contain '$needle'" >&2
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if echo "$haystack" | grep -qF -e "$needle"; then
        echo "Assertion failed: expected content NOT to contain '$needle'" >&2
        return 1
    fi
}

# Test 1: File Existence & Non-Empty Check
test_files_exist() {
    local files=(
        "$QUICKSHELL_DIR/KaliLauncher.qml"
        "$QUICKSHELL_DIR/CategoryButton.qml"
        "$QUICKSHELL_DIR/ToolCard.qml"
        "$QUICKSHELL_DIR/README.md"
    )
    for f in "${files[@]}"; do
        if [ ! -f "$f" ]; then
            echo "Missing required file: $f" >&2
            return 1
        fi
        if [ ! -s "$f" ]; then
            echo "File is empty: $f" >&2
            return 1
        fi
    done
}

# Test 2: Balanced Delimiters in QML Files
test_qml_balanced_delimiters() {
    for f in "$QUICKSHELL_DIR"/*.qml; do
        local open_braces close_braces open_parens close_parens
        open_braces=$(grep -o '{' "$f" | wc -l)
        close_braces=$(grep -o '}' "$f" | wc -l)
        if [ "$open_braces" -ne "$close_braces" ]; then
            echo "Unbalanced braces in $f (open: $open_braces, close: $close_braces)" >&2
            return 1
        fi

        open_parens=$(grep -o '(' "$f" | wc -l)
        close_parens=$(grep -o ')' "$f" | wc -l)
        if [ "$open_parens" -ne "$close_parens" ]; then
            echo "Unbalanced parentheses in $f (open: $open_parens, close: $close_parens)" >&2
            return 1
        fi
    done
}

# Test 3: CategoryButton.qml Structure
test_category_button_structure() {
    local content
    content=$(cat "$QUICKSHELL_DIR/CategoryButton.qml")
    assert_contains "$content" "import QtQuick"
    assert_contains "$content" "import QtQuick.Layouts"
    assert_contains "$content" "property string categoryId"
    assert_contains "$content" "property string categoryName"
    assert_contains "$content" "property string icon"
    assert_contains "$content" "property int toolCount"
    assert_contains "$content" "property bool active"
    assert_contains "$content" "signal clicked()"
    assert_contains "$content" "MouseArea"
    assert_contains "$content" "Behavior on color"
}

# Test 4: ToolCard.qml Structure
test_tool_card_structure() {
    local content
    content=$(cat "$QUICKSHELL_DIR/ToolCard.qml")
    assert_contains "$content" "import QtQuick"
    assert_contains "$content" "import QtQuick.Layouts"
    assert_contains "$content" "property var toolData"
    assert_contains "$content" "property bool installed"
    assert_contains "$content" "signal launchRequested(string toolName, string presetName)"
    assert_contains "$content" "signal installRequested(string packageName, string toolName)"
    assert_contains "$content" "Não instalado"
    assert_contains "$content" "Instalado"
    assert_contains "$content" "Repeater"
    assert_contains "$content" "presetChip"
    assert_contains "$content" "root.launchRequested(root.name, modelData.name)"
}

# Test 5: KaliLauncher.qml Structure
test_kali_launcher_structure() {
    local content
    content=$(cat "$QUICKSHELL_DIR/KaliLauncher.qml")
    assert_contains "$content" "import Quickshell"
    assert_contains "$content" "import Quickshell.Io"
    assert_contains "$content" "import Quickshell.Wayland"
    assert_contains "$content" "PanelWindow {"
    assert_contains "$content" "WlrLayershell.layer: WlrLayer.Overlay"
    assert_contains "$content" "WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand"
    assert_contains "$content" "Process {"
    assert_contains "$content" "StdioCollector {"
    assert_contains "$content" "CategoryButton {"
    assert_contains "$content" "ToolCard {"
    assert_contains "$content" "categoriesList"
    assert_contains "$content" "displayTools"
    assert_contains "$content" "function launchTool(toolName, presetName)"
    assert_contains "$content" "function installTool(packageName, toolName)"
    assert_contains "$content" "Quickshell.execDetached"
}

# Test 6: CLI categories JSON Schema
test_cli_categories_json_schema() {
    "$KALI_ORMACHY_BIN" categories --format json | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'Expected JSON array'
assert len(data) > 0, 'Categories list should not be empty'
for cat in data:
    assert 'id' in cat, 'Missing id in category'
    assert 'name' in cat, 'Missing name in category'
    assert 'icon' in cat, 'Missing icon in category'
    assert 'tools' in cat, 'Missing tools in category'
    assert isinstance(cat['tools'], list), 'Category tools should be a list'
"
}

# Test 7: CLI tools JSON Schema
test_cli_tools_json_schema() {
    "$KALI_ORMACHY_BIN" tools --category recon --format json | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'Expected JSON array'
assert len(data) > 0, 'Recon tools list should not be empty'
for tool in data:
    assert 'name' in tool, 'Missing name in tool'
    assert 'binary' in tool, 'Missing binary in tool'
    assert 'package' in tool, 'Missing package in tool'
    assert 'mode' in tool, 'Missing mode in tool'
    assert 'description' in tool, 'Missing description in tool'
    assert 'installed' in tool, 'Missing installed status in tool'
    assert isinstance(tool['installed'], bool), 'Installed status must be a boolean'
    assert 'presets' in tool, 'Missing presets in tool'
    assert isinstance(tool['presets'], list), 'Presets must be a list'
"
}

# Test 8: CLI check JSON Schema
test_cli_check_json_schema() {
    # check exits with 1 if tool is uninstalled, but still outputs valid JSON
    ("$KALI_ORMACHY_BIN" check --tool nmap --format json || true) | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, dict), 'Expected JSON object'
assert 'tool' in data, 'Missing tool in check'
assert 'binary' in data, 'Missing binary in check'
assert 'package' in data, 'Missing package in check'
assert 'installed' in data, 'Missing installed in check'
assert isinstance(data['installed'], bool), 'Installed must be boolean'
"
}

# Test 9: CLI launch-tool dry-run parity
test_cli_launch_dry_run_parity() {
    local out1 out2
    out1=$("$KALI_ORMACHY_BIN" launch-tool --name Nmap --preset 0 --dry-run)
    assert_contains "$out1" "nmap -T4 -F 127.0.0.1"

    out2=$("$KALI_ORMACHY_BIN" launch-tool --name Nmap --preset "Varredura Rápida de Portas" --dry-run)
    assert_contains "$out2" "nmap -T4 -F 127.0.0.1"
}

# Test 10: Node.js Simulation of QML JavaScript Filtering & Launching Logic
test_node_qml_simulation() {
    node -e "
const fs = require('fs');
const { execSync } = require('child_process');

const binPath = process.env.KALI_ORMACHY_BIN;
const catsJson = execSync(\`\${binPath} categories --format json\`).toString();
const categories = JSON.parse(catsJson);

const reconToolsJson = execSync(\`\${binPath} tools --category recon --format json\`).toString();
const reconTools = JSON.parse(reconToolsJson);

// Simulate category tools cache
const cache = { 'recon': reconTools };

// Simulate QML updateDisplayTools with no search query and category 'recon'
let selectedCategoryId = 'recon';
let searchQuery = '';
let displayTools = [];

function updateDisplayTools(q, catId) {
    let query = (q || '').trim().toLowerCase();
    let baseList = [];
    if (query.length > 0 || catId === 'all') {
        for (let c in cache) {
            baseList = baseList.concat(cache[c] || []);
        }
    } else {
        baseList = cache[catId] || [];
    }

    if (query.length === 0) {
        return baseList;
    } else {
        return baseList.filter(t => {
            let nameMatch = t.name && t.name.toLowerCase().includes(query);
            let binMatch = t.binary && t.binary.toLowerCase().includes(query);
            let descMatch = t.description && t.description.toLowerCase().includes(query);
            let presetMatch = t.presets && t.presets.some(p => p.name && p.name.toLowerCase().includes(query));
            return nameMatch || binMatch || descMatch || presetMatch;
        });
    }
}

// 1. Initial recon listing
let list1 = updateDisplayTools('', 'recon');
if (list1.length !== reconTools.length) {
    throw new Error('Expected list length ' + reconTools.length + ', got ' + list1.length);
}

// 2. Search 'nmap'
let listNmap = updateDisplayTools('nmap', 'recon');
if (listNmap.length === 0 || !listNmap.some(t => t.name.toLowerCase() === 'nmap')) {
    throw new Error('Search for nmap failed');
}

// 3. Search 'porta' (matches description 'Scanner de portas...')
let listPortas = updateDisplayTools('porta', 'recon');
if (listPortas.length === 0) {
    throw new Error('Search by description keyword failed');
}

// 4. Search non-existing keyword
let listEmpty = updateDisplayTools('termoinexistente999', 'recon');
if (listEmpty.length !== 0) {
    throw new Error('Expected 0 results for non-existing query, got ' + listEmpty.length);
}

// 5. Build launch arguments
function buildLaunchArgs(toolName, presetName) {
    let args = [binPath, 'launch-tool', '--name', toolName];
    if (presetName && presetName.length > 0) {
        args.push('--preset');
        args.push(presetName);
    }
    return args;
}

let args = buildLaunchArgs('Nmap', 'Varredura Rápida de Portas');
if (args.length !== 6 || args[3] !== 'Nmap' || args[5] !== 'Varredura Rápida de Portas') {
    throw new Error('Launch arguments malformed: ' + JSON.stringify(args));
}
"
}

# Test 11: README Documentation Completeness
test_readme_completeness() {
    local readme
    readme=$(cat "$QUICKSHELL_DIR/README.md")
    assert_contains "$readme" "KaliLauncher.qml"
    assert_contains "$readme" "CategoryButton.qml"
    assert_contains "$readme" "ToolCard.qml"
    assert_contains "$readme" "shell.qml"
    assert_contains "$readme" "hyprland.conf"
    assert_contains "$readme" "Catppuccin Mocha"
    assert_contains "$readme" "categories --format json"
    assert_contains "$readme" "tools --category"
    assert_contains "$readme" "launch-tool"
}

echo "=== Running Quickshell / QML Integration Test Suite ==="
run_test "File existence & non-empty" test_files_exist
run_test "QML balanced braces and parentheses" test_qml_balanced_delimiters
run_test "CategoryButton.qml structure & properties" test_category_button_structure
run_test "ToolCard.qml structure & properties" test_tool_card_structure
run_test "KaliLauncher.qml structure & Quickshell integration" test_kali_launcher_structure
run_test "CLI categories --format json schema" test_cli_categories_json_schema
run_test "CLI tools --category <id> --format json schema" test_cli_tools_json_schema
run_test "CLI check --tool <name> --format json schema" test_cli_check_json_schema
run_test "CLI launch-tool dry-run argument parity" test_cli_launch_dry_run_parity
run_test "Node.js simulation of QML business & search logic" test_node_qml_simulation
run_test "quickshell/README.md documentation completeness" test_readme_completeness

echo ""
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
