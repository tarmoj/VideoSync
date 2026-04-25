import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia


ApplicationWindow {
    width: 640
    height: 480
    visible: true
    property string version: "0.1.0"
    title: qsTr("VideoSync") + " " + version
    color: Material.background

    property string role: "" // "host" or "guest"
    property color backgroundEndColor: role==="host" ?  "darkgreen" : "darkblue"

    background: Rectangle {
       gradient: Gradient {
          GradientStop { position: 0.0; color: Material.backgroundColor }
          GradientStop { position: 0.6; color: Material.backgroundColor }
          GradientStop { position: 0.8; color: backgroundEndColor.darker() }
          GradientStop { position: 1.0; color: backgroundEndColor }
       }
    }

    flags: Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint

    header: ToolBar {
        id: toolBar
        width: parent.width

        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

        background: Rectangle {color: "transparent" }

        topPadding: parent.SafeArea ? parent.SafeArea.margins.top : 10
        bottomPadding: 10

        contentItem:  Item {
            //anchors.fill: parent
            anchors.topMargin: 10
            implicitHeight: titleLabel.implicitHeight + 10

            Label {
                id: titleLabel
                anchors.centerIn: parent
                text: title
                font.pointSize: 16
                font.bold: true
                horizontalAlignment: Qt.AlignHCenter

            }

            ToolButton {
                id: menuButton

                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "qrc:/images/menu.svg"
                onClicked: drawer.opened ? drawer.close() : drawer.open()
            }
        }
    }

    Drawer {
       id: drawer
       //width is automatic
       //height: window.height - toolBar.height
       y: toolBar.height
       property int marginLeft: 20

       //background: Rectangle {anchors.fill:parent; color: Material.backgroundColor.lighter()}


       ColumnLayout {
          anchors.fill: parent
          spacing: 5
          visible: true

          ToolButton {
              text: qsTr("Load")
          }

          // MenuItem {
          //    text: qsTr("Info")
          //    icon.source: "qrc:/images/info.svg"
          //    onTriggered: {
          //       drawer.close()
          //       helpDialog.open()
          //    }
          // }


          Item {Layout.fillHeight: true}

       }

    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10


        RowLayout {
            id: menuRow
            //spacing: 10
            Layout.fillWidth: true


            Label {
               text: qsTr("Guest")
               horizontalAlignment: Text.AlignRight
            }

            Switch {
                id: hostGuestSwitch
                text: qsTr("Host")
                checked: false
                onCheckedChanged: {
                    role = checked ? "host" : "guest"
                }
            }

            Label {
                id: connectionLabel
                text: qsTr("Connections: ")
            }

            Label {
                id: ipLabel
                text: qsTr("IP: ")
            }

            Label {
                id: videoLabel
                text: qsTr("Video: ")
            }

        }

        Item {
            id: videoArea
            Layout.fillHeight: true
            Layout.fillWidth: true

            Video {
                id: videoPlayer
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                source: "" // Set the video source here
            }


        }

        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Button {
                id: playButton
                text: qsTr("Play")
                onClicked: {
                    // Implement play functionality
                }
            }

            Button {
                id: pauseButton
                text: qsTr("Pause")
                onClicked: {
                    // Implement pause functionality
                }
            }

            Slider {
                id: seekSlider
                //Layout.preferredWidth: parent.width/3
                from: 0
                to: 1
                value: 0
                // position is 0..1
                onValueChanged: {
                    // Implement seek functionality
                }
            }

            Label {
                id: timeLabel
                text: qsTr("00:00.00")
            }

            Item { Layout.fillWidth: true }
        }


    }
}
