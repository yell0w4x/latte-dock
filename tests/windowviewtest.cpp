/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "plugin/windowview.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QEventLoop>
#include <QObject>
#include <QSignalSpy>
#include <QStringList>
#include <QTimer>
#include <QVariantList>

using Latte::Tasks::WindowView;

namespace {

const QString s_service{QStringLiteral("org.kde.KWin.Effect.WindowView1")};
const QString s_path{QStringLiteral("/org/kde/KWin/Effect/WindowView1")};

//! Stands in for the effect of kwin, on the very same bus name it uses.
//!
//! Nothing about the tested object is replaced here, it makes its real call over the real
//! session bus; what is substituted is only the window manager at the other end of it,
//! which can not be run from a test.
class WindowViewEffect : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.KWin.Effect.WindowView1")

public:
    QStringList received;
    int calls{0};

public slots:
    void activate(const QStringList &handles)
    {
        received = handles;
        ++calls;
    }
};

//! lets the bus deliver what is pending, the calls are asynchronous on both sides
void processBus(int milliseconds = 250)
{
    QEventLoop loop;
    QTimer::singleShot(milliseconds, &loop, &QEventLoop::quit);
    loop.exec();
}

bool sessionBusIsUsable()
{
    return QDBusConnection::sessionBus().isConnected();
}

bool effectIsAlreadyRunning()
{
    auto bus = QDBusConnection::sessionBus().interface();
    return bus && bus->isServiceRegistered(s_service).value();
}

} // namespace

class WindowViewTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        if (!sessionBusIsUsable()) {
            GTEST_SKIP() << "there is no session bus to talk to, the window view is reached over it";
        }
    }

    //! publishes the stand in effect, which is possible whenever the tests do not run inside
    //! a session that has a kwin of its own holding the name
    bool publishEffect()
    {
        if (effectIsAlreadyRunning()) {
            return false;
        }

        QDBusConnection::sessionBus().registerObject(s_path, &m_effect, QDBusConnection::ExportAllSlots);
        return QDBusConnection::sessionBus().registerService(s_service);
    }

    void unpublishEffect()
    {
        QDBusConnection::sessionBus().unregisterService(s_service);
        QDBusConnection::sessionBus().unregisterObject(s_path);
    }

    WindowViewEffect m_effect;
};

TEST_F(WindowViewTest, AvailabilityFollowsWhetherTheEffectIsOnTheBus)
{
    //! read from the bus itself, so the expectation does not come from the tested object
    const bool running = effectIsAlreadyRunning();

    WindowView view;

    EXPECT_EQ(view.isAvailable(), running);
}

TEST_F(WindowViewTest, AnEffectAppearingIsNoticed)
{
    if (effectIsAlreadyRunning()) {
        GTEST_SKIP() << "a window manager already owns " << s_service.toStdString();
    }

    WindowView view;
    ASSERT_FALSE(view.isAvailable());

    QSignalSpy spy(&view, &WindowView::availableChanged);

    ASSERT_TRUE(publishEffect());
    processBus();

    EXPECT_TRUE(view.isAvailable());
    EXPECT_EQ(spy.count(), 1);

    //! and the dock stops offering it once the effect goes away again
    unpublishEffect();
    processBus();

    EXPECT_FALSE(view.isAvailable());
}

TEST_F(WindowViewTest, TheWindowsOfATaskReachTheEffect)
{
    if (!publishEffect()) {
        GTEST_SKIP() << "a window manager already owns " << s_service.toStdString();
    }

    WindowView view;
    processBus();
    ASSERT_TRUE(view.isAvailable());

    //! the ids arrive from the task model as they are, numeric under x11 and uuids under
    //! wayland, and kwin accepts both of them as strings
    view.activate(QVariantList() << QVariant(quint32(71303176))
                                 << QVariant(QStringLiteral("{6b0d40b5-4d8f-4c0b-b0a2-6a6a6b5c1f00}")));
    processBus();

    EXPECT_EQ(m_effect.calls, 1);
    EXPECT_EQ(m_effect.received,
              QStringList() << QStringLiteral("71303176")
                            << QStringLiteral("{6b0d40b5-4d8f-4c0b-b0a2-6a6a6b5c1f00}"));

    unpublishEffect();
}

TEST_F(WindowViewTest, ATaskWithoutWindowsAsksForNothing)
{
    if (!publishEffect()) {
        GTEST_SKIP() << "a window manager already owns " << s_service.toStdString();
    }

    WindowView view;
    processBus();
    ASSERT_TRUE(view.isAvailable());

    //! a launcher has no windows, presenting them would show an empty selection
    view.activate(QVariantList());
    processBus();

    EXPECT_EQ(m_effect.calls, 0);

    unpublishEffect();
}

TEST_F(WindowViewTest, NothingIsSentWhileTheEffectIsMissing)
{
    if (effectIsAlreadyRunning()) {
        GTEST_SKIP() << "a window manager already owns " << s_service.toStdString();
    }

    WindowView view;
    ASSERT_FALSE(view.isAvailable());

    //! compositing off means no selection to show, the click has to fall back to the
    //! previews instead of being sent into a service that is not there
    view.activate(QVariantList() << QVariant(quint32(71303176)));
    processBus();

    EXPECT_EQ(m_effect.calls, 0);
}

#include "windowviewtest.moc"
