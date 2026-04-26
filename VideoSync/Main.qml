import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Dialogs
import QtCore


ApplicationWindow {
    id: app
    width: 640
    height: 480
    visible: true
    property string version: "0.2.4"
    title: qsTr("VideoSync") + " " + version
    color: Material.background

    property string role: "guest" // "host" or "guest"
    property bool applyingRemoteUpdate: false
    property bool syncReady: false
    property bool videoFullscreen: false
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

    function toggleVideoFullscreen() {
        videoFullscreen = !videoFullscreen
        if (videoFullscreen) {
            drawer.close()
        }
    }

    function addRecentVideo(url, name) {
        let list = appSettings.recentVideos.slice()
        const urlStr = url.toString()
        const idx = list.findIndex(function(v) { return v.url === urlStr })
        if (idx !== -1) list.splice(idx, 1)
        list.unshift({ url: urlStr, name: name })
        if (list.length > 10) list = list.slice(0, 10)
        appSettings.recentVideos = list
    }

    Settings {
        id: appSettings
        property string lastVideoPath: ""
        property string hostIp: ""
        property int wsPort: 9870
        property var recentVideos: []
        property bool muted: false
    }

    Component.onCompleted: {
        if (syncManager) {
            syncManager.role = role
            syncManager.updateLocalIp()
            if (appSettings.hostIp.length > 0)
                syncManager.hostIp = appSettings.hostIp
            if (appSettings.wsPort > 0)
                syncManager.wsPort = appSettings.wsPort
        }
        if (appSettings.lastVideoPath.length > 0)
            currentVideoSource = appSettings.lastVideoPath
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
        visible: !videoFullscreen
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
        height: app.height
        //y: toolBar.height
        property int marginLeft: 20

        background: Rectangle {
            anchors.fill:parent;
            color: Material.backgroundColor.lighter()
        }


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            visible: true

            MenuItem {
                text: qsTr("Load Video")
                onTriggered: fileDialog.open()
            }

            MenuItem {
                text: qsTr("Load Test Video")
                onTriggered: {
                    videoPlayer.stop()
                    currentVideoSource = testVideoSource
                    drawer.close()
                }
            }

            ComboBox {
                id: recentVideosCombo
                Layout.fillWidth: true
                visible: appSettings.recentVideos.length > 0
                displayText: qsTr("Recent Videos")
                model: appSettings.recentVideos
                textRole: "name"
                onActivated: function(index) {
                    const item = appSettings.recentVideos[index]
                    videoPlayer.stop()
                    currentVideoSource = item.url
                    appSettings.lastVideoPath = item.url
                    currentIndex = -1
                    drawer.close()
                }
            }

            MenuItem {
                text: qsTr("Clear Recent Videos")
                visible: appSettings.recentVideos.length > 0
                onTriggered: {
                    appSettings.recentVideos = []
                    appSettings.lastVideoPath = ""
                }
            }

            MenuItem {
                text: qsTr("Update IP")
                onTriggered: {
                    if (syncManager) {
                        syncManager.updateLocalIp()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
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
                        appSettings.wsPort = value
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: 300
                visible: role === "guest"

                Label {
                    text: qsTr("Host IP")
                    visible: role === "guest"
                }

                TextField {
                    id: hostIpField
                    Layout.fillWidth: true
                    visible: role === "guest"
                    placeholderText: qsTr("192.168.1.100")
                    text: syncManager ? syncManager.hostIp : ""
                    onEditingFinished: {
                        if (syncManager) {
                            syncManager.hostIp = text
                        }
                        appSettings.hostIp = text
                    }
                }

                ToolButton {
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
            }



            Label {
                text: syncManager ? syncManager.connectionStatus : qsTr("Sync unavailable")
                wrapMode: Text.Wrap
            }

            Item {Layout.fillHeight: true}

            MenuItem {
                text: qsTr("Info")
                onTriggered: {
                    infoDialog.open()
                    drawer.close()
                }
            }

        }

    }

    Dialog {
        id: infoDialog
        title: qsTr("About VideoSync")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Close

        ColumnLayout {
            spacing: 8
            width: Math.min(app.width - 40, 420)

            Label {
                text: qsTr("VideoSync %1").arg(version)
                font.bold: true
                font.pointSize: 16
            }

            Label {
                text: qsTr("Synchronize video playback over a local network.\n\n" +
                           "How to use:\n" +
                           "• One device switches to Host mode.\n" +
                           "• Other devices stay in Guest mode and connect to the host IP.\n" +
                           "• Load a video on each device (same file).\n" +
                           "• Play, pause and seek on any of the devices — others follow automatically.\n" +
                           "• Double-tap the video for fullscreen; single tap to play/pause.")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Label {
                text: qsTr("Based on Qt Framework — qt.io")
                font.italic: true
            }

            Label {
                text: qsTr("© Tarmo Johannes\ntrmjhnns@gmail.com")
                font.pointSize: 10
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10


        Flow {
            id: menuRow
            visible: !videoFullscreen
            spacing: 10
            Layout.fillWidth: true

            Label {
                text: qsTr("Guest")
                height: hostGuestSwitch.implicitHeight
                Layout.alignment: Qt.AlignRight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
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
                height: hostGuestSwitch.implicitHeight
                text: role === "host"
                      ? qsTr("Connections: %1").arg(syncManager ? syncManager.connectionCount : 0)
                      : qsTr("Status: %1").arg(syncManager && syncManager.connected ? qsTr("Connected") : qsTr("Disconnected"))
                verticalAlignment: Text.AlignVCenter
            }

            Label {
                id: ipLabel
                height: hostGuestSwitch.implicitHeight
                text: qsTr("IP: %1").arg(syncManager ? syncManager.localIp : "-")
                verticalAlignment: Text.AlignVCenter
            }

            Label {
                id: videoLabel
                height: hostGuestSwitch.implicitHeight
                text: currentVideoName || qsTr("No video")
                elide: Text.ElideMiddle
                Layout.maximumWidth: 150
                verticalAlignment: Text.AlignVCenter
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

            states: State {
                name: "fullscreen"
                when: app.videoFullscreen
                ParentChange {
                    target: videoArea
                    parent: app.contentItem
                }
                AnchorChanges {
                    target: videoArea
                    anchors.left: app.contentItem.left
                    anchors.right: app.contentItem.right
                    anchors.top: app.contentItem.top
                    anchors.bottom: app.contentItem.bottom
                }
                PropertyChanges {
                    target: videoArea
                    z: 999
                    color: "black"
                    border.width: 0
                    radius: 0
                }
            }

            Video {
                id: videoPlayer
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                source: currentVideoSource
                property bool isPlaying: playbackState===MediaPlayer.PlayingState
                volume: appSettings.muted ? 0.0 : 1.0

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

                onSourceChanged:  {
                    videoPlayer.pause() // to show the first frame
                    videoPlayer.seek(0)
                }

            }

            MouseArea {
                id: videoMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    singleClickTimer.restart()
                }
                onDoubleClicked: function(mouse) {
                    singleClickTimer.stop()
                    app.toggleVideoFullscreen()
                    mouse.accepted = true
                }
            }


        }

        RowLayout {
            id: controlRow
            visible: !videoFullscreen
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            ToolButton {
                id: playButton
                icon.source:  videoPlayer.isPlaying ? "qrc:/images/pause.svg" : "qrc:/images/play.svg"
                //text: videoPlayer.isPlaying ? qsTr("Pause") : qsTr("Play")
                onClicked: {
                    videoPlayer.isPlaying ?  videoPlayer.pause() : videoPlayer.play()
                }
            }

            ToolButton {
                id: stopButton
                //text: qsTr("Stop")
                icon.source:  "qrc:/images/stop.svg"
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
                text: formatVideoTime(videoPlayer.position) + " / " + formatVideoTime(videoPlayer.duration)
            }

            ToolButton {
                id: muteButton
                checkable: true
                checked: appSettings.muted
                icon.source: checked ? "qrc:/images/no_sound.svg" : "qrc:/images/sound.svg"
                onToggled: appSettings.muted = checked
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

    Timer {
        id: singleClickTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (videoPlayer.isPlaying) {
                videoPlayer.pause()
            } else {
                videoPlayer.play()
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
                appSettings.lastVideoPath = resolved.toString()
                const name = fileHelper ? fileHelper.videoFileName(resolved) : resolved.toString()
                addRecentVideo(resolved, name)
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
