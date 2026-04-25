#include <QGuiApplication>
#include <QFile>
#include <QDir>
#include <QQmlContext>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QUrl>

static QUrl resolveTestVideoUrl()
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    // Mobile backends may not support playback from qrc directly.
    const QString appDataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const QString localPath = appDataDir + "/test.mp4";

    QDir().mkpath(appDataDir);

    if (!QFile::exists(localPath)) {
        QFile sourceFile(":/test.mp4");
        if (sourceFile.open(QIODevice::ReadOnly)) {
            QFile targetFile(localPath);
            if (targetFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                targetFile.write(sourceFile.readAll());
                targetFile.close();
            }
            sourceFile.close();
        }
    }

    if (QFile::exists(localPath)) {
        return QUrl::fromLocalFile(localPath);
    }

    return QUrl(QStringLiteral("qrc:/test.mp4"));
#else
    return QUrl(QStringLiteral("qrc:/test.mp4"));
#endif
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("testVideoSource", resolveTestVideoUrl());
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("VideoSync", "Main");

    return app.exec();
}
