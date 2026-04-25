#pragma once

#include <QObject>
#include <QUrl>

// Resolves a file URL returned by a file picker.
// On iOS: the picker gives a security-scoped URL valid only briefly; this
// class copies the file into the app sandbox so playback works indefinitely.
// On Android: Qt Multimedia accepts content:// URIs directly; no copy needed.
// On other platforms: the URL is returned as-is.
class FileHelper : public QObject
{
    Q_OBJECT

public:
    explicit FileHelper(QObject *parent = nullptr);

    // Call from QML after FileDialog.onAccepted to get a safe playback URL.
    Q_INVOKABLE QUrl resolveVideoUrl(const QUrl &picked);

    // Returns the display name (filename) extracted from any supported URL form.
    Q_INVOKABLE QString videoFileName(const QUrl &url);
};
