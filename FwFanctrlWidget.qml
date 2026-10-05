import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "fw-fanctrl"

    property var strategies: []
    property string currentStrategy: ""
    property bool usingDefault: false
    property var fanSpeed: null
    property var temperature: null
    property bool active: false
    property bool available: false
    property bool statusLoading: false
    property bool listLoading: false
    property bool actionRunning: false
    property string pendingStrategy: ""
    property string lastError: ""
    property string listError: ""
    property bool popoutOpen: false

    // The bar pill only shows the strategy, so poll slowly unless the popout
    // (which shows live speed and temperature) is open.
    readonly property int activePollInterval: 5000
    readonly property int idlePollInterval: 60000

    readonly property string displayStrategy: available && currentStrategy !== "" ? currentStrategy : "Unavailable"
    readonly property var selectorItems: {
        const items = [{
            "strategy": "",
            "label": "Automatic",
            "automatic": true
        }];

        for (let i = 0; i < strategies.length; i++) {
            items.push({
                "strategy": strategies[i],
                "label": strategies[i],
                "automatic": false
            });
        }

        return items;
    }

    Component.onCompleted: {
        Qt.callLater(() => refreshAll(false));
    }

    onPopoutOpenChanged: {
        if (popoutOpen) {
            refreshAll(false);
        }
    }

    Timer {
        interval: root.popoutOpen ? root.activePollInterval : root.idlePollInterval
        running: true
        repeat: true
        onTriggered: root.refreshStatus(false)
    }

    function parseResult(output, exitCode, fallbackMessage) {
        if (exitCode !== 0) {
            return {
                "ok": false,
                "error": fallbackMessage
            };
        }

        const trimmed = (output || "").trim();
        if (trimmed === "") {
            return {
                "ok": false,
                "error": fallbackMessage
            };
        }

        try {
            const payload = JSON.parse(trimmed);
            if (!payload || payload.status !== "success") {
                return {
                    "ok": false,
                    "error": payload && payload.reason ? payload.reason : fallbackMessage
                };
            }

            return {
                "ok": true,
                "payload": payload
            };
        } catch (error) {
            return {
                "ok": false,
                "error": "fw-fanctrl returned an invalid response"
            };
        }
    }

    function refreshAll(notifyOnError) {
        refreshStatus(notifyOnError);
        refreshStrategies(notifyOnError);
    }

    function refreshStatus(notifyOnError) {
        if (statusLoading || actionRunning) {
            return;
        }

        statusLoading = true;
        Proc.runCommand("", ["fw-fanctrl", "--output-format", "JSON", "print"], (stdout, exitCode) => {
            statusLoading = false;
            const result = parseResult(stdout, exitCode, "Unable to query the fw-fanctrl service");

            if (!result.ok || typeof result.payload.strategy !== "string"
                    || typeof result.payload.default !== "boolean"
                    || typeof result.payload.active !== "boolean") {
                available = false;
                lastError = result.ok ? "fw-fanctrl returned incomplete status data" : result.error;
                if (notifyOnError) {
                    ToastService.showError("Framework Fan Control", lastError);
                }
                return;
            }

            currentStrategy = result.payload.strategy;
            usingDefault = result.payload.default;
            fanSpeed = result.payload.speed !== undefined ? result.payload.speed : null;
            temperature = result.payload.temperature !== undefined ? result.payload.temperature : null;
            active = result.payload.active;
            available = true;
            lastError = "";
        }, 0, 4000);
    }

    function refreshStrategies(notifyOnError) {
        if (listLoading || actionRunning) {
            return;
        }

        listLoading = true;
        Proc.runCommand("", ["fw-fanctrl", "--output-format", "JSON", "print", "list"], (stdout, exitCode) => {
            listLoading = false;
            const result = parseResult(stdout, exitCode, "Unable to load fw-fanctrl strategies");

            if (!result.ok || !Array.isArray(result.payload.strategies)) {
                listError = result.ok ? "fw-fanctrl returned an invalid strategy list" : result.error;
                if (notifyOnError) {
                    ToastService.showError("Framework Fan Control", listError);
                }
                return;
            }

            const newStrategies = [];
            for (let i = 0; i < result.payload.strategies.length; i++) {
                const strategy = result.payload.strategies[i];
                if (typeof strategy === "string" && strategy !== "" && newStrategies.indexOf(strategy) === -1) {
                    newStrategies.push(strategy);
                }
            }

            strategies = newStrategies;
            listError = "";
        }, 0, 4000);
    }

    function selectStrategy(strategy, automatic) {
        if (!available || statusLoading || actionRunning) {
            return;
        }

        actionRunning = true;
        pendingStrategy = automatic ? "__automatic__" : strategy;

        const command = automatic
            ? ["fw-fanctrl", "--output-format", "JSON", "reset"]
            : ["fw-fanctrl", "--output-format", "JSON", "use", strategy];

        Proc.runCommand("", command, (stdout, exitCode) => {
            const result = parseResult(stdout, exitCode, "Unable to change the fw-fanctrl strategy");
            actionRunning = false;
            pendingStrategy = "";

            if (!result.ok || typeof result.payload.strategy !== "string"
                    || typeof result.payload.default !== "boolean") {
                lastError = result.ok ? "fw-fanctrl returned incomplete strategy data" : result.error;
                ToastService.showError("Framework Fan Control", lastError);
                return;
            }

            currentStrategy = result.payload.strategy;
            usingDefault = result.payload.default;
            available = true;
            lastError = "";

            ToastService.showInfo(
                "Framework Fan Control",
                automatic ? "Using configured defaults" : "Using " + result.payload.strategy
            );
            root.closePopout();
            Qt.callLater(() => root.refreshStatus(false));
        }, 0, 4000);
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "mode_fan"
                size: root.iconSize
                color: root.available ? Theme.widgetIconColor : Theme.error
                opacity: root.available && !root.active ? 0.55 : 1
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.displayStrategy
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: root.available ? Theme.widgetTextColor : Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DankIcon {
                name: "mode_fan"
                size: root.iconSize
                color: root.available ? Theme.widgetIconColor : Theme.error
                opacity: root.available && !root.active ? 0.55 : 1
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.displayStrategy
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: root.available ? Theme.widgetTextColor : Theme.error
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Framework Fan Control"
            detailsText: {
                if (!root.available) {
                    return root.lastError || "fw-fanctrl service unavailable";
                }
                if (root.usingDefault) {
                    return "Automatic mode • effective strategy: " + root.currentStrategy;
                }
                return "Manual strategy override";
            }
            showCloseButton: true

            Binding {
                target: root
                property: "popoutOpen"
                value: popout.parentPopout ? popout.parentPopout.shouldBeVisible : false
            }

            headerActions: Component {
                DankActionButton {
                    iconName: "refresh"
                    iconColor: Theme.surfaceVariantText
                    buttonSize: Theme.iconSize + Theme.spacingXS
                    enabled: !root.statusLoading && !root.listLoading && !root.actionRunning
                    tooltipText: "Refresh"
                    tooltipSide: "bottom"
                    onClicked: root.refreshAll(true)
                }
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingL

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                {
                                    "label": "Speed",
                                    "value": root.available && root.fanSpeed !== null ? root.fanSpeed + "%" : "—",
                                    "icon": "speed"
                                },
                                {
                                    "label": "Temperature",
                                    "value": root.available && root.temperature !== null ? root.temperature + "°C" : "—",
                                    "icon": "device_thermostat"
                                },
                                {
                                    "label": "Service",
                                    "value": root.available ? (root.active ? "Active" : "Paused") : "Offline",
                                    "icon": !root.available
                                        ? "error"
                                        : root.active ? "check_circle" : "pause_circle"
                                }
                            ]

                            StyledRect {
                                width: (parent.width - Theme.spacingS * 2) / 3
                                height: statContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                Column {
                                    id: statContent

                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXXS

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: Theme.spacingXS

                                        DankIcon {
                                            name: modelData.icon
                                            size: Theme.iconSizeSmall
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.label
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    StyledText {
                                        text: modelData.value
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        text: "Fan strategy"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        width: parent.width
                        visible: (root.listLoading && root.strategies.length === 0)
                            || root.listError !== ""
                        text: root.listError !== "" ? root.listError : "Loading strategies…"
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.listError !== "" ? Theme.error : Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankListView {
                        id: strategyList

                        width: parent.width
                        height: parent.height - y
                        clip: true
                        spacing: Theme.spacingXS
                        model: root.selectorItems

                        delegate: StyledRect {
                            id: strategyRow

                            required property var modelData
                            readonly property bool selected: modelData.automatic
                                ? root.usingDefault
                                : !root.usingDefault && root.currentStrategy === modelData.strategy
                            readonly property bool pending: root.pendingStrategy === (
                                modelData.automatic ? "__automatic__" : modelData.strategy
                            )

                            width: ListView.view.width
                            height: Math.max(Theme.iconSize, labelColumn.implicitHeight) + Theme.spacingS * 2
                            radius: Theme.cornerRadius
                            color: {
                                if (selected) {
                                    return Theme.primaryContainer;
                                }
                                if (strategyMouseArea.containsMouse) {
                                    return Theme.surfaceContainerHighest;
                                }
                                return Theme.surfaceContainerHigh;
                            }
                            opacity: (root.available && !root.statusLoading && !root.actionRunning)
                                || pending ? 1 : 0.55

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: strategyRow.pending
                                        ? "hourglass_top"
                                        : strategyRow.selected ? "check_circle" : "radio_button_unchecked"
                                    size: Theme.iconSize - 4
                                    color: strategyRow.selected ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    id: labelColumn

                                    width: parent.width - Theme.iconSize - Theme.spacingS
                                    spacing: Theme.spacingXXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        width: parent.width
                                        text: strategyRow.modelData.label
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: strategyRow.selected ? Font.Medium : Font.Normal
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        visible: strategyRow.modelData.automatic
                                        text: root.usingDefault && root.currentStrategy !== ""
                                            ? "Use configured defaults (currently " + root.currentStrategy + ")"
                                            : "Restore configured charging/discharging defaults"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: strategyMouseArea

                                anchors.fill: parent
                                enabled: root.available && !root.statusLoading && !root.actionRunning
                                    && !strategyRow.selected
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.selectStrategy(
                                    strategyRow.modelData.strategy,
                                    strategyRow.modelData.automatic
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 360
    popoutHeight: 470
}
