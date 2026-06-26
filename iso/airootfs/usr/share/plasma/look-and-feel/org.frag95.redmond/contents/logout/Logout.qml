/*
 * Frag95 logout greeter — a Windows 9x "Shut Down" dialog.
 *
 * The stock Breeze logout screen sets Kirigami.Theme.Complementary and lets the
 * labels inherit it; with our Win98 scheme that resolves to dark text on the
 * dark dim, so it's unreadable. This replacement uses ONLY core QtQuick with
 * explicit Win95 colors (gray dialog, black text) so contrast can't be defeated
 * by theme/colorscheme resolution. It honors the same signal contract the
 * ksmserver logout greeter connects to.
 */
import QtQuick

Item {
    id: root

    // --- signal contract the greeter connects to (names must match Breeze) ---
    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    focus: true
    Keys.onEscapePressed: root.cancelRequested()

    // A reusable Win95 raised/pressed push button (Qt6 inline component).
    component Win95Button: Item {
        id: btn
        property alias text: lbl.text
        signal clicked()
        implicitWidth: Math.max(104, lbl.implicitWidth + 28)
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            color: "#c0c0c0"
            Rectangle { anchors { left: parent.left; top: parent.top; right: parent.right }
                        height: 2; color: ma.pressed ? "#404040" : "#ffffff" }
            Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2; color: ma.pressed ? "#404040" : "#ffffff" }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2; color: ma.pressed ? "#ffffff" : "#404040" }
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 2; color: ma.pressed ? "#ffffff" : "#404040" }
        }
        Text { id: lbl; anchors.centerIn: parent; color: "black"
               font.family: "Liberation Sans"; font.pixelSize: 14 }
        MouseArea { id: ma; anchors.fill: parent; onClicked: btn.clicked() }
    }

    // Dim the screen; a click on the backdrop cancels.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }
    }

    // The Win95 dialog.
    Rectangle {
        id: dlg
        anchors.centerIn: parent
        width: 520
        height: 190
        color: "#c0c0c0"

        Rectangle { anchors { left: parent.left; top: parent.top; right: parent.right }
                    height: 2; color: "#ffffff" }
        Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 2; color: "#ffffff" }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 2; color: "#404040" }
        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 2; color: "#404040" }

        Rectangle {                       // title bar
            id: tb
            anchors { left: parent.left; top: parent.top; right: parent.right; margins: 3 }
            height: 26
            color: "#000080"
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                text: "Shut Down Frag95"
                color: "white"; font.bold: true
                font.family: "Liberation Sans"; font.pixelSize: 15
            }
        }

        Text {
            id: prompt
            anchors { top: tb.bottom; left: parent.left; topMargin: 22; leftMargin: 24 }
            text: "What do you want the computer to do?"
            color: "black"; font.family: "Liberation Sans"; font.pixelSize: 14
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
            spacing: 10
            Win95Button { text: "Log Out";   onClicked: root.logoutRequested() }
            Win95Button { text: "Restart";   onClicked: root.rebootRequested() }
            Win95Button { text: "Shut Down"; onClicked: root.haltRequested() }
            Win95Button { text: "Cancel";    onClicked: root.cancelRequested() }
        }
    }
}
