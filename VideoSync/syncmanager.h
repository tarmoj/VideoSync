#pragma once

#include <QObject>
#include <QList>
#include <QNetworkInterface>
#include <QTimer>

class QWebSocket;
class QWebSocketServer;
class QUdpSocket;

class SyncManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString role READ role WRITE setRole NOTIFY roleChanged)
    Q_PROPERTY(QString localIp READ localIp NOTIFY localIpChanged)
    Q_PROPERTY(QString hostIp READ hostIp WRITE setHostIp NOTIFY hostIpChanged)
    Q_PROPERTY(int wsPort READ wsPort WRITE setWsPort NOTIFY wsPortChanged)
    Q_PROPERTY(QString connectionStatus READ connectionStatus NOTIFY connectionStatusChanged)
    Q_PROPERTY(int connectionCount READ connectionCount NOTIFY connectionCountChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit SyncManager(QObject *parent = nullptr);
    ~SyncManager() override;

    QString role() const;
    QString localIp() const;
    QString hostIp() const;
    int wsPort() const;
    QString connectionStatus() const;
    int connectionCount() const;
    bool connected() const;

    void setRole(const QString &newRole);
    void setHostIp(const QString &newHostIp);
    void setWsPort(int newWsPort);

    Q_INVOKABLE void updateLocalIp();
    Q_INVOKABLE void connectToHost();
    Q_INVOKABLE void disconnectFromHost();
    Q_INVOKABLE void sendCommand(const QString &action, qint64 position, bool playing);
    Q_INVOKABLE void sendState(qint64 position, bool playing);

signals:
    void roleChanged();
    void localIpChanged();
    void hostIpChanged();
    void wsPortChanged();
    void connectionStatusChanged();
    void connectionCountChanged();
    void connectedChanged();

    void remoteCommandReceived(const QString &action, qint64 position, bool playing);
    void remoteStateReceived(qint64 position, bool playing);

private slots:
    void onUdpReadyRead();
    void onAnnounceTimeout();
    void onServerNewConnection();

private:
    static constexpr quint16 DiscoveryPort = 45454;

    enum class ClientState {
        Disconnected,
        Connecting,
        Connected
    };

    QString detectLocalIp() const;
    void setConnectionStatus(const QString &status);
    void updateConnectedState();
    void resetNetwork();

    void startHostMode();
    void stopHostMode();
    void startGuestMode();
    void stopGuestMode();

    void startUdpListener();
    void stopUdpListener();
    void sendAnnounce();

    void startWebSocketServer();
    void stopWebSocketServer();
    void connectClientSignals();

    void handleIncomingMessage(const QByteArray &payload, QWebSocket *originSocket);
    void broadcastMessage(const QByteArray &payload, QWebSocket *excludeSocket = nullptr);

    QString m_role = QStringLiteral("guest");
    QString m_localIp;
    QString m_hostIp;
    int m_wsPort = 9870;

    QString m_connectionStatus = QStringLiteral("Disconnected");
    bool m_connected = false;
    ClientState m_clientState = ClientState::Disconnected;

    QUdpSocket *m_udpListener = nullptr;
    QUdpSocket *m_udpSender = nullptr;
    QTimer m_announceTimer;

    QWebSocketServer *m_server = nullptr;
    QList<QWebSocket *> m_clients;
    QWebSocket *m_client = nullptr;
};
