import QtQuick 2.15

// Frag95 SDDM greeter — a Windows 9x "Welcome" login dialog on the teal desktop.
// Deliberately uses only core QtQuick (Rectangle / TextInput / Image / MouseArea)
// plus SDDM's injected globals (sddm, userModel, sessionModel, keyboard) so it
// stays Qt6-clean — no Qt5-era SddmComponents that black-screen on Qt6 SDDM.
Rectangle {
    id: root
    width: 1024
    height: 768
    color: "#008080"          // Win9x desktop teal

    property int sessionIndex: sessionModel.lastIndex

    function doLogin() {
        msg.text = ""
        sddm.login(userField.text, passField.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            msg.text = "Incorrect user name or password."
            passField.text = ""
            passField.forceActiveFocus()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 20

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "logo.png"
            width: dialog.width
            sourceSize.width: dialog.width
            fillMode: Image.PreserveAspectFit
            smooth: false
            visible: status === Image.Ready
        }

        // ---------------- login dialog ----------------
        Item {
            id: dialog
            width: 420
            height: 220
            anchors.horizontalCenter: parent.horizontalCenter

            Bevel { anchors.fill: parent; face: "#c0c0c0" }

            Rectangle {                       // title bar
                id: titleBar
                anchors { left: parent.left; top: parent.top; right: parent.right; margins: 3 }
                height: 26
                color: "#000080"
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                    text: "Welcome to Frag95"
                    color: "white"
                    font.family: "Liberation Sans"
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Column {
                anchors { left: parent.left; right: parent.right; top: titleBar.bottom; leftMargin: 16; rightMargin: 16; topMargin: 18 }
                spacing: 12

                Row {
                    spacing: 8
                    Text { width: 86; height: 26; text: "User name:"; verticalAlignment: Text.AlignVCenter
                           font.family: "Liberation Sans"; font.pixelSize: 14; color: "black" }
                    Item {
                        width: 250; height: 26
                        Bevel { anchors.fill: parent; face: "white"; sunken: true }
                        TextInput {
                            id: userField
                            anchors { fill: parent; leftMargin: 5; rightMargin: 5 }
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Liberation Sans"; font.pixelSize: 14; color: "black"
                            clip: true
                            text: userModel.lastUser
                            onAccepted: passField.forceActiveFocus()
                            KeyNavigation.tab: passField
                        }
                    }
                }

                Row {
                    spacing: 8
                    Text { width: 86; height: 26; text: "Password:"; verticalAlignment: Text.AlignVCenter
                           font.family: "Liberation Sans"; font.pixelSize: 14; color: "black" }
                    Item {
                        width: 250; height: 26
                        Bevel { anchors.fill: parent; face: "white"; sunken: true }
                        TextInput {
                            id: passField
                            anchors { fill: parent; leftMargin: 5; rightMargin: 5 }
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Liberation Sans"; font.pixelSize: 14; color: "black"
                            echoMode: TextInput.Password
                            passwordCharacter: "*"
                            clip: true
                            onAccepted: doLogin()
                        }
                    }
                }

                Text {
                    id: msg
                    text: keyboard.capsLock ? "Caps Lock is on." : ""
                    color: "#a00000"
                    font.family: "Liberation Sans"; font.pixelSize: 12
                }
            }

            MouseArea {                       // OK button
                id: okBtn
                width: 86; height: 28
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 16; bottomMargin: 14 }
                onClicked: doLogin()
                Bevel { anchors.fill: parent; face: "#c0c0c0"; sunken: okBtn.pressed }
                Text { anchors.centerIn: parent; text: "OK"
                       font.family: "Liberation Sans"; font.pixelSize: 14; color: "black" }
            }
        }

        // ---------------- session + power ----------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            MouseArea {                       // session cycler
                width: 230; height: 28
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
                Bevel { anchors.fill: parent; face: "#c0c0c0"; sunken: pressed }
                Item {
                    anchors { fill: parent; margins: 4 }
                    Repeater {
                        model: sessionModel
                        delegate: Text {
                            anchors.centerIn: parent
                            visible: index === root.sessionIndex
                            text: "Session: " + name
                            font.family: "Liberation Sans"; font.pixelSize: 13; color: "black"
                        }
                    }
                }
            }

            MouseArea {                       // restart
                width: 100; height: 28
                enabled: sddm.canReboot
                onClicked: sddm.reboot()
                Bevel { anchors.fill: parent; face: "#c0c0c0"; sunken: pressed }
                Text { anchors.centerIn: parent; text: "Restart"
                       font.family: "Liberation Sans"; font.pixelSize: 13; color: "black" }
            }

            MouseArea {                       // shut down
                width: 110; height: 28
                enabled: sddm.canPowerOff
                onClicked: sddm.powerOff()
                Bevel { anchors.fill: parent; face: "#c0c0c0"; sunken: pressed }
                Text { anchors.centerIn: parent; text: "Shut Down..."
                       font.family: "Liberation Sans"; font.pixelSize: 13; color: "black" }
            }
        }
    }

    Component.onCompleted: {
        if (userField.text.length > 0) passField.forceActiveFocus()
        else userField.forceActiveFocus()
    }
}
