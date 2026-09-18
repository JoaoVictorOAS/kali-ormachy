import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // Wayland Layer Shell configuration
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "kali-ormachy-launcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: true

    // Binary configuration
    property string binPath: "kali-ormachy"

    // Reactive State
    property var categoriesList: []
    property var categoryToolsCache: ({})
    property string selectedCategoryId: "all"
    property string searchQuery: ""
    property var displayTools: []
    property bool isLoading: false
    property string statusText: "Carregando catálogo Kali-Ormachy..."
    property int totalTools: 0
    property int installedTools: 0
    property var pendingCategories: []

    // Omarchy / Catppuccin Mocha Palette
    property color mochaBase: "#1e1e2e"
    property color mochaMantle: "#181825"
    property color mochaCrust: "#11111b"
    property color mochaSurface0: "#313244"
    property color mochaSurface1: "#45475a"
    property color mochaText: "#cdd6f4"
    property color mochaSubtext: "#a6adc8"
    property color mochaBlue: "#89b4fa"
    property color mochaRed: "#f38ba8"
    property color mochaGreen: "#a6e3a1"

    Component.onCompleted: {
        root.loadCatalog();
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.forceActiveFocus();
            if (root.categoriesList.length === 0) {
                root.loadCatalog();
            }
        }
    }

    // Process to fetch categories list
    Process {
        id: categoriesProc
        command: [root.binPath, "categories", "--format", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.handleCategoriesOutput(this.text);
            }
        }
    }

    // Process to sequentially fetch tools for categories with installed status
    Process {
        id: toolsProc
        property string currentCatId: ""
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                root.handleToolsOutput(toolsProc.currentCatId, this.text);
            }
        }
    }

    // Fallback detached process launcher if needed
    Process {
        id: detachedProc
        command: []
    }

    // Logic Functions
    function loadCatalog() {
        root.isLoading = true;
        root.statusText = "Carregando catálogo Kali-Ormachy...";
        root.categoriesList = [];
        root.categoryToolsCache = {};
        root.pendingCategories = [];
        categoriesProc.running = true;
    }

    function handleCategoriesOutput(jsonText) {
        try {
            let cats = JSON.parse(jsonText);
            if (Array.isArray(cats)) {
                root.categoriesList = cats;
                root.pendingCategories = cats.map(function(c) { return c.id; });
                fetchNextCategoryTools();
            } else {
                root.isLoading = false;
                root.statusText = "Erro: formato de categorias inválido.";
            }
        } catch (e) {
            root.isLoading = false;
            root.statusText = "Erro ao processar categorias: " + e.message;
        }
    }

    function fetchNextCategoryTools() {
        if (root.pendingCategories.length > 0) {
            let nextCatId = root.pendingCategories.shift();
            toolsProc.currentCatId = nextCatId;
            toolsProc.command = [root.binPath, "tools", "--category", nextCatId, "--format", "json"];
            toolsProc.running = true;
        } else {
            root.isLoading = false;
            root.updateStats();
            root.updateDisplayTools();
        }
    }

    function handleToolsOutput(catId, jsonText) {
        try {
            let tools = JSON.parse(jsonText);
            if (Array.isArray(tools)) {
                let cache = Object.assign({}, root.categoryToolsCache);
                cache[catId] = tools;
                root.categoryToolsCache = cache;
            }
        } catch (e) {
            console.error("Erro ao carregar ferramentas da categoria " + catId + ":", e);
        }
        fetchNextCategoryTools();
    }

    function updateStats() {
        let total = 0;
        let installed = 0;
        for (let catId in root.categoryToolsCache) {
            let list = root.categoryToolsCache[catId] || [];
            total += list.length;
            for (let i = 0; i < list.length; i++) {
                if (list[i].installed === true) {
                    installed++;
                }
            }
        }
        root.totalTools = total;
        root.installedTools = installed;
        root.statusText = total + " ferramentas catalogadas • " + installed + " instaladas";
    }

    function updateDisplayTools() {
        let q = (root.searchQuery || "").trim().toLowerCase();
        let baseList = [];

        if (q.length > 0 || root.selectedCategoryId === "all") {
            for (let catId in root.categoryToolsCache) {
                let list = root.categoryToolsCache[catId] || [];
                baseList = baseList.concat(list);
            }
        } else {
            baseList = root.categoryToolsCache[root.selectedCategoryId] || [];
        }

        if (q.length === 0) {
            root.displayTools = baseList;
        } else {
            root.displayTools = baseList.filter(function(t) {
                let nameMatch = t.name && t.name.toLowerCase().indexOf(q) !== -1;
                let binMatch = t.binary && t.binary.toLowerCase().indexOf(q) !== -1;
                let descMatch = t.description && t.description.toLowerCase().indexOf(q) !== -1;
                let presetMatch = false;
                if (t.presets && Array.isArray(t.presets)) {
                    for (let p = 0; p < t.presets.length; p++) {
                        if (t.presets[p].name && t.presets[p].name.toLowerCase().indexOf(q) !== -1) {
                            presetMatch = true;
                            break;
                        }
                    }
                }
                return nameMatch || binMatch || descMatch || presetMatch;
            });
        }
    }

    function launchTool(toolName, presetName) {
        let args = [root.binPath, "launch-tool", "--name", toolName];
        if (presetName && presetName.length > 0) {
            args.push("--preset");
            args.push(presetName);
        }

        if (typeof Quickshell !== "undefined" && Quickshell.execDetached) {
            Quickshell.execDetached(args);
        } else {
            detachedProc.command = args;
            detachedProc.running = true;
        }
        root.visible = false;
    }

    function installTool(packageName, toolName) {
        let target = packageName || toolName;
        let installCmd = "sudo pacman -S --needed " + target;
        let args = ["sh", "-c", installCmd];

        if (typeof Quickshell !== "undefined" && Quickshell.execDetached) {
            Quickshell.execDetached(args);
        } else {
            detachedProc.command = args;
            detachedProc.running = true;
        }
    }

    // Dim Backdrop Scrim
    Rectangle {
        anchors.fill: parent
        color: "#aa11111b"

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // Main Centered Launcher Window
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: Math.min(1060, parent.width - 48)
        height: Math.min(700, parent.height - 48)
        radius: 14
        color: root.mochaMantle
        border.color: root.mochaSurface0
        border.width: 1
        clip: true

        // Intercept clicks inside card so dialog does not close
        MouseArea {
            anchors.fill: parent
            onClicked: { /* consume click */ }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Top Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "󰘳"
                    font.family: "JetBrainsMono Nerd Font, monospace"
                    font.pixelSize: 24
                    color: root.mochaBlue
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "Kali-Ormachy Security Tools"
                        font.family: "JetBrainsMono Nerd Font, sans-serif"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: root.mochaText
                    }

                    Text {
                        text: "Painel Nativo Quickshell para Omarchy Desktop"
                        font.family: "JetBrainsMono Nerd Font, sans-serif"
                        font.pixelSize: 12
                        color: root.mochaSubtext
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Refresh Button
                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 8
                    color: refreshMouse.containsMouse ? root.mochaSurface0 : root.mochaBase
                    border.color: root.mochaSurface1
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 16
                        color: root.mochaBlue
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.loadCatalog()
                    }
                }

                // Close Button
                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 8
                    color: closeMouse.containsMouse ? root.mochaRed : root.mochaBase
                    border.color: closeMouse.containsMouse ? root.mochaRed : root.mochaSurface1
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 16
                        color: closeMouse.containsMouse ? root.mochaCrust : root.mochaText
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                radius: 10
                color: root.mochaBase
                border.color: searchInput.activeFocus ? root.mochaBlue : root.mochaSurface0
                border.width: searchInput.activeFocus ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 18
                        color: searchInput.activeFocus ? root.mochaBlue : root.mochaSubtext
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: "JetBrainsMono Nerd Font, sans-serif"
                        font.pixelSize: 13
                        color: root.mochaText
                        selectByMouse: true
                        selectionColor: root.mochaBlue
                        selectedTextColor: root.mochaCrust
                        clip: true

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Buscar ferramenta, binário, comando ou preset (ex: nmap, wifi, sqlmap)..."
                            font: searchInput.font
                            color: "#6c7086"
                            verticalAlignment: Text.AlignVCenter
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.updateDisplayTools();
                        }

                        Keys.onEscapePressed: {
                            if (text.length > 0) {
                                text = "";
                            } else {
                                root.visible = false;
                            }
                        }

                        Keys.onReturnPressed: {
                            if (root.displayTools && root.displayTools.length > 0) {
                                let firstTool = root.displayTools[0];
                                if (firstTool.installed) {
                                    root.launchTool(firstTool.name, "");
                                } else {
                                    root.installTool(firstTool.package, firstTool.name);
                                }
                            }
                        }
                    }

                    // Clear search button
                    Rectangle {
                        visible: searchInput.text.length > 0
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: clearMouse.containsMouse ? root.mochaSurface0 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 12
                            color: root.mochaSubtext
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Body: Category Tabs (Left) + Tool Cards (Right)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // Sidebar: Categories
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    radius: 10
                    color: root.mochaBase
                    border.color: root.mochaSurface0
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        // "Todas as Ferramentas" Top Item
                        CategoryButton {
                            Layout.fillWidth: true
                            categoryId: "all"
                            categoryName: "Todas as Ferramentas"
                            icon: "󰘳"
                            toolCount: root.totalTools
                            active: root.selectedCategoryId === "all"
                            onClicked: {
                                root.selectedCategoryId = "all";
                                root.updateDisplayTools();
                            }
                        }

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.mochaSurface0
                        }

                        // Scrollable list of categories
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ColumnLayout {
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: root.categoriesList

                                    delegate: CategoryButton {
                                        Layout.fillWidth: true
                                        categoryId: modelData.id
                                        categoryName: modelData.name
                                        icon: modelData.icon || "󰘳"
                                        toolCount: (root.categoryToolsCache[modelData.id] ? root.categoryToolsCache[modelData.id].length : (modelData.tools ? modelData.tools.length : 0))
                                        active: root.selectedCategoryId === modelData.id
                                        onClicked: {
                                            root.selectedCategoryId = modelData.id;
                                            root.updateDisplayTools();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Main Tool List Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: root.mochaBase
                    border.color: root.mochaSurface0
                    border.width: 1

                    ScrollView {
                        id: toolsScrollView
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        ListView {
                            id: toolsListView
                            model: root.displayTools
                            spacing: 10
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: ToolCard {
                                width: toolsListView.width - 12
                                toolData: modelData
                                onLaunchRequested: function(toolName, presetName) {
                                    root.launchTool(toolName, presetName);
                                }
                                onInstallRequested: function(packageName, toolName) {
                                    root.installTool(packageName, toolName);
                                }
                            }
                        }
                    }

                    // Empty Search State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: root.displayTools.length === 0 && !root.isLoading

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰍉"
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 42
                            color: "#585b70"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.searchQuery.length > 0 ? ("Nenhuma ferramenta encontrada para \"" + root.searchQuery + "\"") : "Nenhuma ferramenta disponível nesta categoria"
                            font.family: "JetBrainsMono Nerd Font, sans-serif"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: root.mochaSubtext
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Verifique o termo buscado ou selecione outra categoria na barra lateral"
                            font.family: "JetBrainsMono Nerd Font, sans-serif"
                            font.pixelSize: 12
                            color: "#6c7086"
                        }
                    }

                    // Loading State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: root.isLoading && root.displayTools.length === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰑐"
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 36
                            color: root.mochaBlue

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.isLoading
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Carregando ferramentas de segurança..."
                            font.family: "JetBrainsMono Nerd Font, sans-serif"
                            font.pixelSize: 13
                            color: root.mochaSubtext
                        }
                    }
                }
            }

            // Footer Status Bar
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.statusText
                    font.family: "JetBrainsMono Nerd Font, sans-serif"
                    font.pixelSize: 12
                    color: root.mochaSubtext
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Esc: Fechar • Enter: 1º Resultado • Clique no card: Executar"
                    font.family: "JetBrainsMono Nerd Font, sans-serif"
                    font.pixelSize: 11
                    color: "#6c7086"
                }
            }
        }
    }

    // Global Key Handlers
    Keys.onEscapePressed: {
        root.visible = false;
    }
}
