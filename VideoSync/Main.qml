import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Dialogs


ApplicationWindow {
    width: 640
    height: 480
    visible: true
    property string version: "0.2.0"
    title: qsTr("VideoSync") + " " + version
    color: Material.background

    property string role: "guest" // "host" or "guest"
    property bool applyingRemoteUpdate: false
    property bool syncReady: false
    property url currentVideoSource: testVideoSource
    property string currentVideoName: (fileHelper ? fileHelper.videoFileName(currentVideoSource) : "")
    property color backgroundEndColor: role==="host" ?  "darkgreen" : "darkblue"

    function formatVideoTime(ms) {
        const totalSeconds = Math.max(0, Math.floor((ms || 0) / 1000))
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60

        return String(hours).padStart(2, "0") + ":"
            + String(minutes).padStart(2, "0") + ":"
            + String(seconds).padStart(2, "0")
    }

    Component.onCompleted: {
        if (syncManager) {
            syncManager.role = role
            syncManager.updateLocalIp()
        }
        syncReady = true
    }

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
          anchors.margins: 10
          spacing: 5
          visible: true

          Button {
              text: qsTr("Load Video")
              onClicked: fileDialog.open()
          }

          Button {
              text: qsTr("Test Video")
              onClicked: {
                  videoPlayer.stop()
                  currentVideoSource = testVideoSource
                  drawer.close()
              }
          }

          Button {
              text: qsTr("Update IP")
              onClicked: {
                  if (syncManager) {
                      syncManager.updateLocalIp()
                  }
              }
          }

          Label {
              text: qsTr("WS Port")
          }

          SpinBox {
              id: wsPortSpinBox
              from: 1024
              to: 65535
              editable: true
              value: syncManager ? syncManager.wsPort : 9870
              onValueModified: {
                  if (syncManager) {
                      syncManager.wsPort = value
                  }
              }
          }

          Label {
              text: qsTr("Host IP")
              visible: role === "guest"
          }

          TextField {
              id: hostIpField
              visible: role === "guest"
              placeholderText: qsTr("192.168.1.100")
              text: syncManager ? syncManager.hostIp : ""
              onEditingFinished: {
                  if (syncManager) {
                      syncManager.hostIp = text
                  }
              }
          }

          Button {
              visible: role === "guest"
              text: syncManager && syncManager.connected ? qsTr("Disconnect") : qsTr("Connect")
              onClicked: {
                  if (!syncManager) {
                      return
                  }

                  if (syncManager.connected) {
                      syncManager.disconnectFromHost()
                  } else {
                      syncManager.hostIp = hostIpField.text
                      syncManager.connectToHost()
                  }
              }
          }

          Label {
              text: syncManager ? syncManager.connectionStatus : qsTr("Sync unavailable")
              wrapMode: Text.Wrap
          }

          Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }


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
                checked: role === "host"
                onCheckedChanged: {
                    role = checked ? "host" : "guest"
                    if (syncManager) {
                        syncManager.role = role
                    }
                }
            }

            Label {
                id: connectionLabel
                text: role === "host"
                    ? qsTr("Connections: %1").arg(syncManager ? syncManager.connectionCount : 0)
                    : qsTr("Status: %1").arg(syncManager && syncManager.connected ? qsTr("Connected") : qsTr("Disconnected"))
            }

            Label {
                id: ipLabel
                text: qsTr("IP: %1").arg(syncManager ? syncManager.localIp : "-")
            }

            Label {
                id: videoLabel
                text: currentVideoName || qsTr("No video")
                elide: Text.ElideMiddle
                Layout.maximumWidth: 150
            }

        }

        Rectangle {
            id: videoArea
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "transparent"
            border.color: Material.frameColor
            border.width: 1
            radius: 4

            Video {
                id: videoPlayer
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                source: currentVideoSource
                property bool isPlaying: playbackState===MediaPlayer.PlayingState

                onPlaybackStateChanged: {
                    if (!syncReady || applyingRemoteUpdate) {
                        return
                    }

                    if (playbackState === MediaPlayer.PlayingState) {
                        syncManager.sendCommand("play", position, true)
                    } else if (playbackState === MediaPlayer.PausedState) {
                        syncManager.sendCommand("pause", position, false)
                    } else if (playbackState === MediaPlayer.StoppedState) {
                        syncManager.sendCommand("stop", 0, false)
                    }
                }
            }


        }

        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Button {
                id: playButton
                text: videoPlayer.isPlaying ? qsTr("Pause") : qsTr("Play")
                onClicked: {
                    videoPlayer.isPlaying ?  videoPlayer.pause() : videoPlayer.play()
                }
            }

            Button {
                id: stopButton
                text: qsTr("Stop")
                onClicked: {
                    videoPlayer.stop()
                }
            }

            Slider {
                id: seekSlider
                from: 0
                to: 1
                Layout.fillWidth: true
                Binding {
                    target: seekSlider
                    property: "value"
                    value: videoPlayer.duration > 0 ? videoPlayer.position / videoPlayer.duration : 0
                    when: !seekSlider.pressed
                }
                onMoved: {
                    if (videoPlayer.duration > 0) {
                        const targetPosition = Math.floor(value * videoPlayer.duration)
                        videoPlayer.position = targetPosition
                        if (syncManager && syncReady && !applyingRemoteUpdate) {
                            syncManager.sendCommand("seek", targetPosition, videoPlayer.isPlaying)
                        }
                    }
                }
            }

            Label {
                id: timeLabel
                text: formatVideoTime(videoPlayer.position)
            }

            Item { Layout.fillWidth: true }
        }


    }

    Timer {
        id: periodicSyncTimer
        interval: 200
        running: role === "host"
        repeat: true
        onTriggered: {
            if (syncManager) {
                syncManager.sendState(videoPlayer.position, videoPlayer.isPlaying)
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select Video")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Video files (*.mp4 *.m4v *.mov *.avi *.mkv *.wmv)"), qsTr("All files (*)")]
        onAccepted: {
            const resolved = fileHelper ? fileHelper.resolveVideoUrl(selectedFile) : selectedFile
            if (resolved.toString().length > 0) {
                videoPlayer.stop()
                currentVideoSource = resolved
                drawer.close()
            }
        }
    }

    Connections {
        target: syncManager ? syncManager : null

        function onRemoteCommandReceived(action, position, playing) {
            applyingRemoteUpdate = true

            if (action === "seek") {
                videoPlayer.position = Math.max(0, position)
            } else if (action === "play") {
                if (position >= 0) {
                    videoPlayer.position = position
                }
                videoPlayer.play()
            } else if (action === "pause") {
                if (position >= 0) {
                    videoPlayer.position = position
                }
                videoPlayer.pause()
            } else if (action === "stop") {
                videoPlayer.stop()
            }

            if (action === "seek" && playing) {
                videoPlayer.play()
            }

            applyingRemoteUpdate = false
        }

        function onRemoteStateReceived(position, playing) {
            if (role !== "guest") {
                return
            }

            const targetPosition = Math.max(0, position)
            const diff = Math.abs(videoPlayer.position - targetPosition)

            applyingRemoteUpdate = true

            if (diff > 500) {
                videoPlayer.position = targetPosition
            } else if (diff > 50) {
                videoPlayer.playbackRate = videoPlayer.position < targetPosition ? 1.05 : 0.95
            } else {
                videoPlayer.playbackRate = 1.0
            }

            if (playing && videoPlayer.playbackState !== MediaPlayer.PlayingState) {
                videoPlayer.play()
            }

            if (!playing && videoPlayer.playbackState === MediaPlayer.PlayingState) {
                videoPlayer.pause()
            }

            applyingRemoteUpdate = false
        }
    }
}
