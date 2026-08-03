/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include <QApplication>
#include <QStandardPaths>

//! Shared entry point for every latte integration test.
//!
//! A real QApplication is created because the tested objects are real Latte objects and
//! some of them, e.g. the indicator factory, own QWidgets. The offscreen platform keeps
//! the suite usable on a build server, and the test mode of QStandardPaths makes sure the
//! tests never read or write the developer's own configuration.
int main(int argc, char **argv)
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QStandardPaths::setTestModeEnabled(true);

    QApplication app(argc, argv);
    Q_UNUSED(app)

    ::testing::InitGoogleTest(&argc, argv);

    return RUN_ALL_TESTS();
}
