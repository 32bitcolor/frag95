/*
 * Frag95 GPU Mode — a system-tray plasmoid to switch a hybrid (Optimus) laptop
 * between Integrated / Hybrid / NVIDIA via envycontrol. Mirrors the Frag95
 * Performance plasmoid. Switching rewrites persistent configs, so it flags that
 * a reboot is needed and offers a "Reboot now" button. Auto-hides (Passive) on
 * machines without envycontrol (i.e. non-hybrid hardware).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string current: "unknown"
    property string pending: ""        // a mode chosen but not yet rebooted into
    property bool available: true      // is envycontrol present (hybrid laptop)?

    readonly property var modes: [
        { id: "integrated", label: "Integrated", desc: "Intel only — best battery",        icon: "battery" },
        { id: "hybrid",     label: "Hybrid",     desc: "Intel + NVIDIA on demand (default)", icon: "preferences-desktop-display" },
        { id: "nvidia",     label: "NVIDIA",     desc: "Dedicated GPU only — max performance", icon: "nvidia" }
    ]

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            if (source.indexOf("gpu-mode.sh query") !== -1) {
                var out = (data["stdout"] || "").trim()
                if (out === "envycontrol-missing" || out === "") {
                    root.available = false
                } else {
                    root.available = true
                    root.current = out
                }
            }
            disconnectSource(source)
        }
        function run(cmd) { connectSource(cmd) }
    }

    function readCurrent() { runner.run("/usr/local/bin/frag95-gpu-mode.sh query") }
    function apply(id) {
        runner.run("pkexec /usr/local/bin/frag95-gpu-mode.sh " + id)
        root.pending = id
    }

    Component.onCompleted: readCurrent()

    toolTipMainText: "Frag95 GPU Mode"
    toolTipSubText: pending !== "" ? ("Reboot to apply: " + pending) : ("Mode: " + current)

    // Hide on non-hybrid hardware; show otherwise.
    Plasmoid.status: available ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    compactRepresentation: Kirigami.Icon {
        source: "preferences-desktop-display"
        active: gpuMouse.containsMouse
        MouseArea {
            id: gpuMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            level: 3
            text: "GPU Mode"
        }

        Repeater {
            model: root.modes
            delegate: PlasmaComponents.ItemDelegate {
                Layout.fillWidth: true
                icon.name: modelData.icon
                down: root.current === modelData.id
                highlighted: root.current === modelData.id
                onClicked: root.apply(modelData.id)
                contentItem: ColumnLayout {
                    spacing: 0
                    PlasmaComponents.Label { text: modelData.label; font.bold: root.current === modelData.id }
                    PlasmaComponents.Label { text: modelData.desc; opacity: 0.7; font: Kirigami.Theme.smallFont }
                }
            }
        }

        // Reboot notice — GPU-mode changes only take effect after a reboot.
        Rectangle {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.pending !== ""
            radius: 3
            color: Kirigami.Theme.neutralBackgroundColor
            implicitHeight: rebootRow.implicitHeight + Kirigami.Units.smallSpacing * 2
            RowLayout {
                id: rebootRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    text: "Switched to " + root.pending + ". Reboot to apply."
                }
                PlasmaComponents.Button {
                    text: "Reboot now"
                    icon.name: "system-reboot"
                    onClicked: runner.run("pkexec systemctl reboot")
                }
            }
        }

        Item { Layout.fillHeight: true }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: "Current: " + root.current
        }
    }
}
