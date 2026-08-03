/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "wm/schemecolors.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTextStream>

using Latte::WindowSystem::SchemeColors;

//! SchemeColors parses a real KDE colour scheme file. The tests below hand it an actual
//! file on disk and read the values back, no parsing is reimplemented here.
class SchemeColorsTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        ASSERT_TRUE(m_dir.isValid());

        m_schemeFile = m_dir.path() + QStringLiteral("/LatteTest.colors");

        QFile file(m_schemeFile);
        ASSERT_TRUE(file.open(QIODevice::WriteOnly | QIODevice::Text));

        QTextStream out(&file);
        out << "[General]\n"
               "Name=Latte Test\n"
               "\n"
               "[WM]\n"
               "activeBackground=10,20,30\n"
               "activeForeground=40,50,60\n"
               "inactiveBackground=70,80,90\n"
               "inactiveForeground=100,110,120\n"
               "\n"
               "[Colors:Selection]\n"
               "BackgroundNormal=1,2,3\n"
               "ForegroundNormal=4,5,6\n"
               "\n"
               "[Colors:Window]\n"
               "BackgroundNormal=11,12,13\n"
               "ForegroundNormal=14,15,16\n"
               "BackgroundAlternate=17,18,19\n"
               "ForegroundInactive=20,21,22\n"
               "ForegroundPositive=0,255,0\n"
               "ForegroundNeutral=255,255,0\n"
               "ForegroundNegative=255,0,0\n"
               "\n"
               "[Colors:Button]\n"
               "ForegroundNormal=31,32,33\n"
               "BackgroundNormal=34,35,36\n"
               "DecorationHover=37,38,39\n"
               "DecorationFocus=61,174,233\n";
        file.close();
    }

    QTemporaryDir m_dir;
    QString m_schemeFile;
};

TEST_F(SchemeColorsTest, ReadsWindowManagerColors)
{
    SchemeColors scheme(nullptr, m_schemeFile);

    EXPECT_EQ(scheme.backgroundColor(), QColor(10, 20, 30));
    EXPECT_EQ(scheme.textColor(), QColor(40, 50, 60));
    EXPECT_EQ(scheme.inactiveBackgroundColor(), QColor(70, 80, 90));
    EXPECT_EQ(scheme.inactiveTextColor(), QColor(100, 110, 120));
}

TEST_F(SchemeColorsTest, ReadsSelectionAndWindowColors)
{
    SchemeColors scheme(nullptr, m_schemeFile);

    EXPECT_EQ(scheme.highlightColor(), QColor(1, 2, 3));
    EXPECT_EQ(scheme.highlightedTextColor(), QColor(4, 5, 6));
    EXPECT_EQ(scheme.positiveTextColor(), QColor(0, 255, 0));
    EXPECT_EQ(scheme.neutralTextColor(), QColor(255, 255, 0));
    EXPECT_EQ(scheme.negativeTextColor(), QColor(255, 0, 0));
}

TEST_F(SchemeColorsTest, ReadsButtonColors)
{
    SchemeColors scheme(nullptr, m_schemeFile);

    EXPECT_EQ(scheme.buttonTextColor(), QColor(31, 32, 33));
    EXPECT_EQ(scheme.buttonBackgroundColor(), QColor(34, 35, 36));
    EXPECT_EQ(scheme.buttonHoverColor(), QColor(37, 38, 39));
    EXPECT_EQ(scheme.buttonFocusColor(), QColor(61, 174, 233));
}

TEST_F(SchemeColorsTest, ExposesFocusColorUnderTheKirigamiName)
{
    //! Latte indicators read the palette generically, it may be a SchemeColors or a
    //! Kirigami::Theme. Kirigami spells the colour focusColor, so SchemeColors has to
    //! answer to that name as well or the indicators end up painted black.
    SchemeColors scheme(nullptr, m_schemeFile);

    const QVariant focus = scheme.property("focusColor");
    const QVariant buttonfocus = scheme.property("buttonFocusColor");

    ASSERT_TRUE(focus.isValid());
    EXPECT_EQ(focus.value<QColor>(), QColor(61, 174, 233));
    EXPECT_EQ(focus.value<QColor>(), buttonfocus.value<QColor>());
}

TEST_F(SchemeColorsTest, PlasmaThemeFlagUsesWindowGroup)
{
    //! when based on a plasma theme the window group provides the active/inactive colours
    SchemeColors scheme(nullptr, m_schemeFile, true);

    EXPECT_EQ(scheme.backgroundColor(), QColor(11, 12, 13));
    EXPECT_EQ(scheme.textColor(), QColor(14, 15, 16));
    EXPECT_EQ(scheme.inactiveBackgroundColor(), QColor(17, 18, 19));
    EXPECT_EQ(scheme.inactiveTextColor(), QColor(20, 21, 22));
}

TEST_F(SchemeColorsTest, SchemeNameIsDerivedFromTheFile)
{
    SchemeColors scheme(nullptr, m_schemeFile);

    EXPECT_EQ(scheme.schemeFile(), m_schemeFile);
    EXPECT_EQ(scheme.schemeName(), QStringLiteral("Latte Test"));
}
