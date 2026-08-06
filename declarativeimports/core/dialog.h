/*
    SPDX-FileCopyrightText: 2020 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef LATTEDIALOG_H
#define LATTEDIALOG_H

// Qt
#include <QEvent>
#include <QObject>
#include <QPoint>
#include <QTimer>

#include <QMetaObject>

#include <array>

// Plasma
#include <Plasma/Plasma>
#include <PlasmaQuick/Dialog>

namespace Latte {
namespace Quick {

class Dialog : public PlasmaQuick::Dialog {
    Q_OBJECT
    Q_PROPERTY (bool containsMouse READ containsMouse NOTIFY containsMouseChanged)

    //! it is used instead of location property in order to not break borders drawing
    Q_PROPERTY(Plasma::Types::Location edge READ edge WRITE setEdge NOTIFY edgeChanged)

public:
    explicit Dialog(QQuickItem *parent = nullptr);

    bool containsMouse() const;

    Plasma::Types::Location edge() const;
    void setEdge(const Plasma::Types::Location &edge);

    QPoint popupPosition(QQuickItem *item, const QSize &size) override;

signals:
    void containsMouseChanged();
    void edgeChanged();

protected:
  //  void adjustGeometry(const QRect &geom) override;

    bool event(QEvent *e) override;

private slots:
    void setContainsMouse(bool contains);
    void updatePopUpEnabledBorders();

    void onVisualParentChanged();
    void onSizeChanged();
    void applyPendingPosition();
    void updateGeometry();

private:
    bool isRespectingAppletsLayoutGeometry() const;
    QRect appletsLayoutGeometryFromContainment() const;

    int appletsPopUpMargin() const;

private:
    void requestReposition();

private:
    bool m_containsMouse{false};

    QTimer m_repositionTimer;

    //! position the wayland surface was last mapped at, invalid while it is not mapped
    QPoint m_mappedPosition{-1, -1};

    Plasma::Types::Location m_edge{Plasma::Types::BottomEdge};

    std::array<QMetaObject::Connection, 2> m_visualParentConnections;

};

}
}

#endif
