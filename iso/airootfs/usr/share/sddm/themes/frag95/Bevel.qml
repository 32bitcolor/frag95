import QtQuick 2.15

// A classic Windows 9x two-tone 3D bevel: a flat face with a light edge on the
// top/left and a dark edge on the bottom/right (inverted when `sunken`, e.g.
// for text fields). Drop one in as a background and lay content over it.
Item {
    id: bevel
    property color face: "#c0c0c0"
    property bool sunken: false

    Rectangle { anchors.fill: parent; color: bevel.face }

    // top + left edge
    Rectangle { anchors { left: parent.left; top: parent.top; right: parent.right }
                height: 2; color: bevel.sunken ? "#808080" : "#ffffff" }
    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 2; color: bevel.sunken ? "#808080" : "#ffffff" }
    // bottom + right edge
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 2; color: bevel.sunken ? "#ffffff" : "#404040" }
    Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 2; color: bevel.sunken ? "#ffffff" : "#404040" }
}
