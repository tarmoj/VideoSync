#include "filehelper.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLoggingCategory>
#include <QStandardPaths>

#if defined(Q_OS_ANDROID)
#include <QJniEnvironment>
#include <QJniObject>
#endif

Q_LOGGING_CATEGORY(fileLog, "videosync.file")

#if defined(Q_OS_ANDROID)
static QString androidDisplayName(const QUrl &url)
{
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");
    if (!activity.isValid())
        return {};

    QJniObject contentResolver = activity.callObjectMethod(
        "getContentResolver",
        "()Landroid/content/ContentResolver;");
    if (!contentResolver.isValid())
        return {};

    QJniObject uri = QJniObject::callStaticObjectMethod(
        "android/net/Uri", "parse",
        "(Ljava/lang/String;)Landroid/net/Uri;",
        QJniObject::fromString(url.toString()).object<jstring>());
    if (!uri.isValid())
        return {};

    QJniEnvironment env;
    jclass stringClass = env->FindClass("java/lang/String");
    QJniObject colName = QJniObject::fromString(QStringLiteral("_display_name"));
    jobjectArray projection = env->NewObjectArray(1, stringClass, colName.object<jstring>());
    env->DeleteLocalRef(stringClass);

    QJniObject cursor = contentResolver.callObjectMethod(
        "query",
        "(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;",
        uri.object<jobject>(),
        projection,
        nullptr, nullptr, nullptr);
    env->DeleteLocalRef(projection);

    if (!cursor.isValid())
        return {};

    QString result;
    if (cursor.callMethod<jboolean>("moveToFirst")) {
        QJniObject name = cursor.callObjectMethod("getString", "(I)Ljava/lang/String;", jint(0));
        if (name.isValid())
            result = name.toString();
    }
    cursor.callMethod<void>("close");
    return result;
}
#endif

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

#if defined(Q_OS_ANDROID)
    if (url.scheme() == QLatin1String("content")) {
        const QString name = androidDisplayName(url);
        if (!name.isEmpty())
            return name;
    }
#endif

    const QString localPath = url.toLocalFile();
    if (!localPath.isEmpty()) {
        return QFileInfo(localPath).fileName();
    }

    // For content:// (Android) or other schemes, use the last path segment.
    const QString path = url.path();
    const int slash = path.lastIndexOf(QLatin1Char('/'));
    return (slash >= 0) ? path.mid(slash + 1) : path;
}
