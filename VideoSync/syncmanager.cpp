#include "syncmanager.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QNetworkDatagram>
#include <QUdpSocket>
#include <QWebSocket>
#include <QWebSocketServer>

Q_LOGGING_CATEGORY(syncLog, "videosync.sync")

SyncManager::SyncManager(QObject *parent)
    : QObject(parent)
{
    m_udpListener = new QUdpSocket(this);
    m_udpSender = new QUdpSocket(this);
    m_client = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);

    connect(m_udpListener, &QUdpSocket::readyRead, this, &SyncManager::onUdpReadyRead);
    connect(&m_announceTimer, &QTimer::timeout, this, &SyncManager::onAnnounceTimeout);

    connectClientSignals();

    m_announceTimer.setInterval(1000);
    updateLocalIp();
    startGuestMode();
}

SyncManager::~SyncManager()
{
    resetNetwork();
}

QString SyncManager::role() const
{
    return m_role;
}

QString SyncManager::localIp() const
{
    return m_localIp;
}

QString SyncManager::hostIp() const
{
    return m_hostIp;
}

int SyncManager::wsPort() const
{
    return m_wsPort;
}

QString SyncManager::connectionStatus() const
{
    return m_connectionStatus;
}

int SyncManager::connectionCount() const
{
    return m_clients.size();
}

bool SyncManager::connected() const
{
    return m_connected;
}

void SyncManager::setRole(const QString &newRole)
{
    const QString normalized = newRole.trimmed().toLower();
    const QString targetRole = (normalized == QStringLiteral("host")) ? QStringLiteral("host") : QStringLiteral("guest");

    if (m_role == targetRole) {
        return;
    }

    resetNetwork();
    m_role = targetRole;
    emit roleChanged();

    if (m_role == QStringLiteral("host")) {
        startHostMode();
    } else {
        startGuestMode();
    }
}

void SyncManager::setHostIp(const QString &newHostIp)
{
    const QString trimmed = newHostIp.trimmed();
    if (m_hostIp == trimmed) {
        return;
    }

    m_hostIp = trimmed;
    emit hostIpChanged();
}

void SyncManager::setWsPort(int newWsPort)
{
    const int clamped = qBound(1024, newWsPort, 65535);
    if (m_wsPort == clamped) {
        return;
    }

    m_wsPort = clamped;
    emit wsPortChanged();

    if (m_role == QStringLiteral("host")) {
        startWebSocketServer();
        sendAnnounce();
        setConnectionStatus(QStringLiteral("Host listening on %1:%2").arg(m_localIp, QString::number(m_wsPort)));
    }
}

void SyncManager::updateLocalIp()
{
    const QString detected = detectLocalIp();
    if (m_localIp != detected) {
        m_localIp = detected;
        emit localIpChanged();
    }

    if (m_role == QStringLiteral("host")) {
        sendAnnounce();
    }
}

void SyncManager::connectToHost()
{
    if (m_role != QStringLiteral("guest")) {
        return;
    }

    if (m_hostIp.isEmpty()) {
        setConnectionStatus(QStringLiteral("Host IP is empty"));
        return;
    }

    if (m_client->state() == QAbstractSocket::ConnectedState || m_client->state() == QAbstractSocket::ConnectingState) {
        m_client->close();
    }

    m_clientState = ClientState::Connecting;
    updateConnectedState();
    setConnectionStatus(QStringLiteral("Connecting to %1:%2").arg(m_hostIp, QString::number(m_wsPort)));
    m_client->open(QUrl(QStringLiteral("ws://%1:%2").arg(m_hostIp, QString::number(m_wsPort))));
}

void SyncManager::disconnectFromHost()
{
    if (m_role == QStringLiteral("guest")) {
        m_client->close();
        m_clientState = ClientState::Disconnected;
        updateConnectedState();
        setConnectionStatus(QStringLiteral("Disconnected"));
    }
}

void SyncManager::sendCommand(const QString &action, qint64 position, bool playing)
{
    QJsonObject obj;
    obj.insert(QStringLiteral("type"), QStringLiteral("command"));
    obj.insert(QStringLiteral("action"), action);
    obj.insert(QStringLiteral("position"), static_cast<double>(position));
    obj.insert(QStringLiteral("playing"), playing);
    const QByteArray payload = QJsonDocument(obj).toJson(QJsonDocument::Compact);

    if (m_role == QStringLiteral("host")) {
        broadcastMessage(payload);
    } else if (m_client->state() == QAbstractSocket::ConnectedState) {
        m_client->sendTextMessage(QString::fromUtf8(payload));
    }
}

void SyncManager::sendState(qint64 position, bool playing)
{
    if (m_role != QStringLiteral("host")) {
        return;
    }

    QJsonObject obj;
    obj.insert(QStringLiteral("type"), QStringLiteral("state"));
    obj.insert(QStringLiteral("position"), static_cast<double>(position));
    obj.insert(QStringLiteral("playing"), playing);
    const QByteArray payload = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    broadcastMessage(payload);
}

void SyncManager::onUdpReadyRead()
{
    while (m_udpListener->hasPendingDatagrams()) {
        const QNetworkDatagram datagram = m_udpListener->receiveDatagram();
        const QJsonDocument doc = QJsonDocument::fromJson(datagram.data());
        if (!doc.isObject()) {
            continue;
        }

        const QJsonObject obj = doc.object();
        if (obj.value(QStringLiteral("type")).toString() != QStringLiteral("announce")) {
            continue;
        }

        if (m_role != QStringLiteral("guest")) {
            continue;
        }

        const QString announcedIp = obj.value(QStringLiteral("ip")).toString();
        const int announcedPort = obj.value(QStringLiteral("port")).toInt(m_wsPort);

        if (announcedIp.isEmpty()) {
            continue;
        }

        const bool ipChanged = (m_hostIp != announcedIp);
        if (ipChanged) {
            m_hostIp = announcedIp;
            emit hostIpChanged();
        }

        if (m_wsPort != announcedPort) {
            m_wsPort = qBound(1024, announcedPort, 65535);
            emit wsPortChanged();
        }

        if (m_client->state() == QAbstractSocket::UnconnectedState) {
            connectToHost();
        }
    }
}

void SyncManager::onAnnounceTimeout()
{
    if (m_role == QStringLiteral("host")) {
        sendAnnounce();
    }
}

void SyncManager::onServerNewConnection()
{
    while (m_server && m_server->hasPendingConnections()) {
        QWebSocket *socket = m_server->nextPendingConnection();
        m_clients.append(socket);
        emit connectionCountChanged();
        updateConnectedState();
        setConnectionStatus(QStringLiteral("Connections: %1").arg(QString::number(m_clients.size())));

        connect(socket, &QWebSocket::textMessageReceived, this, [this, socket](const QString &message) {
            handleIncomingMessage(message.toUtf8(), socket);
        });

        connect(socket, &QWebSocket::disconnected, this, [this, socket]() {
            m_clients.removeAll(socket);
            socket->deleteLater();
            emit connectionCountChanged();
            updateConnectedState();
            setConnectionStatus(QStringLiteral("Connections: %1").arg(QString::number(m_clients.size())));
        });
    }
}

QString SyncManager::detectLocalIp() const
{
    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const QNetworkInterface &iface : interfaces) {
        if (!(iface.flags() & QNetworkInterface::IsUp) || !(iface.flags() & QNetworkInterface::IsRunning)) {
            continue;
        }
        if (iface.flags() & QNetworkInterface::IsLoopBack) {
            continue;
        }

        for (const QNetworkAddressEntry &entry : iface.addressEntries()) {
            const QHostAddress addr = entry.ip();
            if (addr.protocol() == QAbstractSocket::IPv4Protocol) {
                return addr.toString();
            }
        }
    }

    return QStringLiteral("127.0.0.1");
}

void SyncManager::setConnectionStatus(const QString &status)
{
    if (m_connectionStatus == status) {
        return;
    }
    m_connectionStatus = status;
    emit connectionStatusChanged();
}

void SyncManager::updateConnectedState()
{
    const bool newConnected = (m_role == QStringLiteral("host")) ? !m_clients.isEmpty() : (m_clientState == ClientState::Connected);
    if (newConnected == m_connected) {
        return;
    }
    m_connected = newConnected;
    emit connectedChanged();
}

void SyncManager::resetNetwork()
{
    stopHostMode();
    stopGuestMode();
}

void SyncManager::startHostMode()
{
    updateLocalIp();
    startUdpListener();
    startWebSocketServer();
    m_announceTimer.start();
    sendAnnounce();
    setConnectionStatus(QStringLiteral("Host listening on %1:%2").arg(m_localIp, QString::number(m_wsPort)));
    updateConnectedState();
}

void SyncManager::stopHostMode()
{
    m_announceTimer.stop();
    stopWebSocketServer();
}

void SyncManager::startGuestMode()
{
    startUdpListener();
    m_clientState = ClientState::Disconnected;
    updateConnectedState();
    setConnectionStatus(QStringLiteral("Disconnected"));
}

void SyncManager::stopGuestMode()
{
    if (m_client->state() != QAbstractSocket::UnconnectedState) {
        m_client->close();
    }
    m_clientState = ClientState::Disconnected;
    updateConnectedState();
}

void SyncManager::startUdpListener()
{
    if (m_udpListener->state() == QAbstractSocket::BoundState) {
        return;
    }

    const bool bound = m_udpListener->bind(QHostAddress::AnyIPv4,
                                           DiscoveryPort,
                                           QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint);
    if (!bound) {
        qCWarning(syncLog) << "Unable to bind UDP discovery socket:" << m_udpListener->errorString();
    }
}

void SyncManager::stopUdpListener()
{
    if (m_udpListener->state() == QAbstractSocket::BoundState) {
        m_udpListener->close();
    }
}

void SyncManager::sendAnnounce()
{
    if (m_role != QStringLiteral("host")) {
        return;
    }

    QJsonObject obj;
    obj.insert(QStringLiteral("type"), QStringLiteral("announce"));
    obj.insert(QStringLiteral("ip"), m_localIp);
    obj.insert(QStringLiteral("port"), m_wsPort);

    const QByteArray payload = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    m_udpSender->writeDatagram(payload, QHostAddress::Broadcast, DiscoveryPort);
}

void SyncManager::startWebSocketServer()
{
    stopWebSocketServer();

    m_server = new QWebSocketServer(QStringLiteral("VideoSyncServer"), QWebSocketServer::NonSecureMode, this);
    if (!m_server->listen(QHostAddress::AnyIPv4, static_cast<quint16>(m_wsPort))) {
        setConnectionStatus(QStringLiteral("Host listen failed: %1").arg(m_server->errorString()));
        m_server->deleteLater();
        m_server = nullptr;
        return;
    }

    connect(m_server, &QWebSocketServer::newConnection, this, &SyncManager::onServerNewConnection);
}

void SyncManager::stopWebSocketServer()
{
    for (QWebSocket *socket : m_clients) {
        if (!socket) {
            continue;
        }
        socket->close();
        socket->deleteLater();
    }
    m_clients.clear();
    emit connectionCountChanged();

    if (m_server) {
        m_server->close();
        m_server->deleteLater();
        m_server = nullptr;
    }

    updateConnectedState();
}

void SyncManager::connectClientSignals()
{
    connect(m_client, &QWebSocket::connected, this, [this]() {
        m_clientState = ClientState::Connected;
        updateConnectedState();
        setConnectionStatus(QStringLiteral("Connected"));
    });

    connect(m_client, &QWebSocket::disconnected, this, [this]() {
        m_clientState = ClientState::Disconnected;
        updateConnectedState();
        if (m_role == QStringLiteral("guest")) {
            setConnectionStatus(QStringLiteral("Disconnected"));
        }
    });

    connect(m_client, &QWebSocket::textMessageReceived, this, [this](const QString &message) {
        handleIncomingMessage(message.toUtf8(), nullptr);
    });

    connect(m_client, &QWebSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        if (m_role == QStringLiteral("guest")) {
            m_clientState = ClientState::Disconnected;
            updateConnectedState();
            setConnectionStatus(QStringLiteral("Connection error"));
        }
    });
}

void SyncManager::handleIncomingMessage(const QByteArray &payload, QWebSocket *originSocket)
{
    const QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) {
        return;
    }

    const QJsonObject obj = doc.object();
    const QString type = obj.value(QStringLiteral("type")).toString();

    if (type == QStringLiteral("command")) {
        const QString action = obj.value(QStringLiteral("action")).toString();
        const qint64 position = static_cast<qint64>(obj.value(QStringLiteral("position")).toDouble());
        const bool playing = obj.value(QStringLiteral("playing")).toBool();

        emit remoteCommandReceived(action, position, playing);

        if (m_role == QStringLiteral("host") && originSocket) {
            broadcastMessage(payload);
        }
        return;
    }

    if (type == QStringLiteral("state")) {
        const qint64 position = static_cast<qint64>(obj.value(QStringLiteral("position")).toDouble());
        const bool playing = obj.value(QStringLiteral("playing")).toBool();
        emit remoteStateReceived(position, playing);
        return;
    }
}

void SyncManager::broadcastMessage(const QByteArray &payload, QWebSocket *excludeSocket)
{
    const QString message = QString::fromUtf8(payload);
    for (QWebSocket *socket : m_clients) {
        if (!socket || socket == excludeSocket) {
            continue;
        }
        socket->sendTextMessage(message);
    }
}
