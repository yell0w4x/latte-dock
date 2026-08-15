/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef LATTETASKSWINDOWVIEW_H
#define LATTETASKSWINDOWVIEW_H

// Qt
#include <QObject>
#include <QVariantList>

class QDBusServiceWatcher;

namespace Latte {
namespace Tasks {

//! Shows the windows of a task through the window selection of kwin, the effect that
//! presents them side by side and lets the user pick one of them.
//!
//! Plasma5 offered this through the backend of its own task manager applet, which Plasma6
//! does not carry any longer, so the effect is asked directly. It is the same request the
//! rest of the workspace makes, so the layout the user chose for it, e.g. a grid or the
//! scattered arrangement, is the one that appears.

class WindowView : public QObject
{
    Q_OBJECT
    //! whether kwin is running the effect at all, e.g. it is not while compositing is off
    Q_PROPERTY(bool available READ isAvailable NOTIFY availableChanged)

public:
    explicit WindowView(QObject *parent = nullptr);
    ~WindowView() override;

    bool isAvailable() const;

    //! presents the given windows, the ids are used as the task model provides them,
    //! numeric under x11 and uuids under wayland, both of which kwin accepts
    Q_INVOKABLE void activate(const QVariantList &windows);

signals:
    void availableChanged();

private:
    void setAvailable(bool available);

    bool m_available{false};

    QDBusServiceWatcher *m_watcher{nullptr};
};

}
}

#endif
