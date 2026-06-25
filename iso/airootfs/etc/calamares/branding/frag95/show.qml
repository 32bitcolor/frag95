/* Minimal Frag95 installer slideshow. Replace with real slides later. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#008080"
            Text {
                anchors.centerIn: parent
                color: "#FFFFFF"
                font.pixelSize: 28
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                text: "Frag95\n\nA 90s-aesthetic, gaming-first Linux distro.\nInstalling — this won't take long."
            }
        }
    }
}
