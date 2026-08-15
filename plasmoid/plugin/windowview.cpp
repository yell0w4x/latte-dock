/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "windowview.h"

// Qt
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QStringList>

namespace {
const QLatin1String s_service{"org.kde.KWin.Effect.WindowView1"};
const QLatin1String s_path{"/org/kde/KWin/Effect/WindowView1"};
const QLatin1String s_interface{"org.kde.KWin.Effect.WindowView1"};
}

namespace Latte {
namespace Tasks {

WindowView::WindowView(QObject *parent)
    : QObject(parent)
{
    //! kwin publishes the service while the effect is loaded and drops it when it is not,
    //! e.g. when compositing is turned off, so it is followed instead of asked once
    m_watcher = new QDBusServiceWatcher(s_service,
                                        QDBusConnection::sessionBus(),
                                        QDBusServiceWatcher::WatchForOwnerChange,
                                        this);

    connect(m_watcher, &QDBusServiceWatcher::serviceRegistered, this, [this]() {
        setAvailable(true);
    });

    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this]() {
        setAvailable(false);
    });

    auto bus = QDBusConnection::sessionBus().interface();
    setAvailable(bus && bus->isServiceRegistered(s_service).value());
}

WindowView::~WindowView() = default;

bool WindowView::isAvailable() const
{
    return m_available;
}

void WindowView::setAvailable(bool available)
{
    if (m_available == available) {
        return;
    }

    m_available = available;
    emit availableChanged();
}

void WindowView::activate(const QVariantList &windows)
{
    if (!m_available || windows.isEmpty()) {
        return;
    }

    QStringList handles;

    for (const QVariant &window : windows) {
        const QString handle = window.toString();

        if (!handle.isEmpty()) {
            handles << handle;
        }
    }

    if (handles.isEmpty()) {
        return;
    }

    QDBusMessage request = QDBusMessage::createMethodCall(s_service,
                                                          s_path,
                                                          s_interface,
                                                          QStringLiteral("activate"));
    request.setArguments({handles});

    //! kwin toggles on this request, so pressing the same task again closes the selection
    QDBusConnection::sessionBus().asyncCall(request);
}

}
}
