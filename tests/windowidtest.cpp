/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "wm/windowinfowrap.h"

#include <QUuid>

using Latte::WindowSystem::WindowId;
using Latte::WindowSystem::WindowInfoWrap;

//! WindowId is the identifier the whole window tracking is keyed on. X11 fills it with a
//! numeric window id while wayland fills it with a uuid, and the tracker used to decide
//! that an id was garbage through toInt()<=0 which silently discarded every wayland
//! window. These tests pin down the behaviour for both platforms.

TEST(WindowIdTest, DefaultConstructedIsNil)
{
    EXPECT_TRUE(WindowId().isNil());
    EXPECT_TRUE(WindowId::nil().isNil());
}

TEST(WindowIdTest, X11NumericIds)
{
    EXPECT_FALSE(WindowId(quint32(12345)).isNil());
    EXPECT_FALSE(WindowId(1).isNil());

    //! zero and negatives are the x11 way of saying "no window"
    EXPECT_TRUE(WindowId(0).isNil());
    EXPECT_TRUE(WindowId(-1).isNil());
}

TEST(WindowIdTest, WaylandUuidStringsAreNotNil)
{
    const WindowId wid = QStringLiteral("{cb214202-1daf-49bd-bd1e-520e6947219b}");

    EXPECT_FALSE(wid.isNil());
    EXPECT_EQ(wid.toString(), QStringLiteral("{cb214202-1daf-49bd-bd1e-520e6947219b}"));
}

TEST(WindowIdTest, WaylandUuidObjectsAreNotNil)
{
    //! kwayland hands the id over as a QUuid, a plain QString type check is not enough
    const QUuid uuid = QUuid::fromString(QStringLiteral("{e1b0eaf4-dbfa-4bb7-8ced-bd3a731cca3c}"));
    WindowId wid;
    wid.setValue(uuid);

    ASSERT_FALSE(uuid.isNull());
    EXPECT_FALSE(wid.isNil());
}

TEST(WindowIdTest, EmptyStringIsNil)
{
    EXPECT_TRUE(WindowId(QString()).isNil());
    EXPECT_TRUE(WindowId(QStringLiteral("")).isNil());
}

TEST(WindowIdTest, IdsRemainUsableAsHashKeys)
{
    //! the tracker stores windows in a QHash<WindowId, WindowInfoWrap>
    QHash<WindowId, int> windows;

    const WindowId waylandid = QStringLiteral("{cb214202-1daf-49bd-bd1e-520e6947219b}");
    const WindowId x11id = quint32(4242);

    windows[waylandid] = 1;
    windows[x11id] = 2;

    EXPECT_EQ(windows.count(), 2);
    EXPECT_EQ(windows.value(WindowId(QStringLiteral("{cb214202-1daf-49bd-bd1e-520e6947219b}"))), 1);
    EXPECT_EQ(windows.value(WindowId(quint32(4242))), 2);
}

TEST(WindowInfoWrapTest, CarriesWaylandIdAndGeometry)
{
    WindowInfoWrap info;
    info.setWid(QStringLiteral("{cb214202-1daf-49bd-bd1e-520e6947219b}"));
    info.setGeometry(QRect(0, 32, 1982, 1090));
    info.setIsValid(true);
    info.setIsActive(true);

    EXPECT_FALSE(info.wid().isNil());
    EXPECT_TRUE(info.isValid());
    EXPECT_TRUE(info.isActive());
    EXPECT_EQ(info.geometry(), QRect(0, 32, 1982, 1090));
}
