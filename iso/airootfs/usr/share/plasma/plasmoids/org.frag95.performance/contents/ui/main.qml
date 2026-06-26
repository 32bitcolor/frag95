/*
 * Frag95 Performance — a system-tray plasmoid to switch the performance/cooling
 * profile (Silent / Balanced / Performance / Extreme). Lives in the tray next
 * to wifi/brightness/audio; click it for a popup that applies a profile via the
 * privileged frag95-performance.sh (pkexec + the 49-frag95-performance polkit
 * rule = no password for wheel users).
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

    property string current: "balanced"

    readonly property var profiles: [
        { id: "silent",      label: "Silent",      desc: "Quietest, coolest-running",     icon: "audio-volume-muted" },
        { id: "balanced",    label: "Balanced",    desc: "The default",                   icon: "speedometer" },
        { id: "performance", label: "Performance", desc: "Aggressive fans, full speed",   icon: "speedometer" },
        { id: "extreme",     label: "Extreme",     desc: "Cooler Boost — max fans",       icon: "temperature-warm" }
    ]

    // Run shell commands (read state / apply a profile) via the executable engine.
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            if (source.indexOf("performance-profile") !== -1) {
                var out = (data["stdout"] || "").trim()
                if (out.length > 0) root.current = out
            }
            disconnectSource(source)
        }
        function run(cmd) { connectSource(cmd) }
    }

    function readCurrent() { runner.run("cat /var/lib/frag95/performance-profile 2>/dev/null || echo balanced") }
    function apply(id) {
        runner.run("pkexec /usr/local/bin/frag95-performance.sh " + id)
        root.current = id
    }

    Component.onCompleted: readCurrent()

    toolTipMainText: "Frag95 Performance"
    toolTipSubText: "Profile: " + current

    // Keep the item shown in the tray.
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    compactRepresentation: Kirigami.Icon {
        source: "preferences-system-power-management"
        active: trayMouse.containsMouse
        MouseArea {
            id: trayMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            level: 3
            text: "Performance Profile"
        }

        Repeater {
            model: root.profiles
            delegate: PlasmaComponents.ItemDelegate {
                Layout.fillWidth: true
                icon.name: modelData.icon
                text: modelData.label
                down: root.current === modelData.id
                highlighted: root.current === modelData.id
                onClicked: { root.apply(modelData.id); root.expanded = false }
                contentItem: ColumnLayout {
                    spacing: 0
                    PlasmaComponents.Label { text: modelData.label; font.bold: root.current === modelData.id }
                    PlasmaComponents.Label { text: modelData.desc; opacity: 0.7; font: Kirigami.Theme.smallFont }
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
