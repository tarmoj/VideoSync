#include "filehelper.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLoggingCategory>
#include <QStandardPaths>

Q_LOGGING_CATEGORY(fileLog, "videosync.file")

FileHelper::FileHelper(QObject *parent)
    : QObject(parent)
{
}

QUrl FileHelper::resolveVideoUrl(const QUrl &picked)
{
    if (!picked.isValid() || picked.isEmpty()) {
        return picked;
    }

#if defined(Q_OS_IOS)
    // On iOS the file picker returns a security-scoped URL. Qt has already
    // called startAccessingSecurityScopedResource() on our behalf, but access
    // is maintained only while we are in this call frame. Copy to the app
    // sandbox immediately so the file is always readable for playback.
    const QString sourcePath = picked.toLocalFile();
    if (sourcePath.isEmpty()) {
        qCWarning(fileLog) << "iOS: picked URL has no local file path:" << picked;
        return picked;
    }

    const QString destDir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QLatin1String("/videos");
    if (!QDir().mkpath(destDir)) {
        qCWarning(fileLog) << "iOS: failed to create videos directory:" << destDir;
        return picked;
    }

    const QString fileName = QFileInfo(sourcePath).fileName();
    const QString destPath = destDir + QLatin1Char('/') + fileName;

    // Remove stale copy so the file reflects the latest version.
    if (QFile::exists(destPath)) {
        QFile::remove(destPath);
    }

    if (!QFile::copy(sourcePath, destPath)) {
        qCWarning(fileLog) << "iOS: failed to copy" << sourcePath << "to" << destPath;
        return picked; // Fall back to original; may fail after scope expires.
    }

    qCDebug(fileLog) << "iOS: copied to sandbox:" << destPath;
    return QUrl::fromLocalFile(destPath);

#else
    // Desktop and Android: Qt Multimedia accepts file:// and content:// URIs directly.
    return picked;
#endif
}

QString FileHelper::videoFileName(const QUrl &url)
{
    if (url.isEmpty()) {
        return QString();
    }

    const QString localPath = url.toLocalFile();
    if (!localPath.isEmpty()) {
        return QFileInfo(localPath).fileName();
    }

    // For content:// (Android) or other schemes, use the last path segment.
    const QString path = url.path();
    const int slash = path.lastIndexOf(QLatin1Char('/'));
    return (slash >= 0) ? path.mid(slash + 1) : path;
}
