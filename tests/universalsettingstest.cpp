/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "settings/universalsettings.h"

#include <QSignalSpy>
#include <QTemporaryDir>

#include <KConfigGroup>
#include <KSharedConfig>

using Latte::UniversalSettings;

//! UniversalSettings is driven for real here, on a throwaway configuration file rather than
//! the one of the running session. It is created without a corona, which is the only part
//! of its collaborators that can not exist outside of a plasma shell; every setting reached
//! from these tests is served from the configuration itself.

class UniversalSettingsTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        m_dir = new QTemporaryDir();
        ASSERT_TRUE(m_dir->isValid());

        m_config = KSharedConfig::openConfig(configFilePath());
        m_settings = new UniversalSettings(m_config);
    }

    void TearDown() override
    {
        delete m_settings;
        m_settings = nullptr;
        m_config = KSharedConfig::Ptr();
        delete m_dir;
    }

    QString configFilePath() const
    {
        return m_dir->filePath(QStringLiteral("lattedocktestrc"));
    }

    //! reads what actually reached the file, so the assertions do not merely observe the
    //! in memory state of the object under test
    QString storedScales(const QString &screenName)
    {
        m_config->reparseConfiguration();
        KConfigGroup universal(m_config, QStringLiteral("UniversalSettings"));
        KConfigGroup scales = universal.group(QStringLiteral("ScreenScales"));
        return scales.readEntry(screenName, QString());
    }

    QTemporaryDir *m_dir{nullptr};
    KSharedConfig::Ptr m_config;
    UniversalSettings *m_settings{nullptr};
};

TEST_F(UniversalSettingsTest, AnUnknownScreenScalesAtOne)
{
    //! the settings window of a screen that was never resized opens at its proposed size
    EXPECT_FLOAT_EQ(m_settings->screenWidthScale(QStringLiteral("Virtual-1")), 1.0);
    EXPECT_FLOAT_EQ(m_settings->screenHeightScale(QStringLiteral("Virtual-1")), 1.0);
}

TEST_F(UniversalSettingsTest, ScreenScalesAreKeptPerScreen)
{
    m_settings->setScreenScales(QStringLiteral("Virtual-1"), 1.35, 0.80);
    m_settings->setScreenScales(QStringLiteral("HDMI-1"), 0.50, 1.90);

    EXPECT_FLOAT_EQ(m_settings->screenWidthScale(QStringLiteral("Virtual-1")), 1.35);
    EXPECT_FLOAT_EQ(m_settings->screenHeightScale(QStringLiteral("Virtual-1")), 0.80);

    EXPECT_FLOAT_EQ(m_settings->screenWidthScale(QStringLiteral("HDMI-1")), 0.50);
    EXPECT_FLOAT_EQ(m_settings->screenHeightScale(QStringLiteral("HDMI-1")), 1.90);
}

TEST_F(UniversalSettingsTest, ChangingAScaleReachesTheConfigurationFile)
{
    m_settings->setScreenScales(QStringLiteral("Virtual-1"), 1.25, 0.75);

    //! the settings window resize writes through this path, so it has to survive a restart
    EXPECT_EQ(storedScales(QStringLiteral("Virtual-1")), QStringLiteral("1.25;0.75"));
}

TEST_F(UniversalSettingsTest, StoredScalesAreReadBackByANewInstance)
{
    m_settings->setScreenScales(QStringLiteral("Virtual-1"), 1.40, 0.60);

    //! a second instance over the same file stands in for the next start of the application
    UniversalSettings reloaded(m_config);
    reloaded.load();

    EXPECT_FLOAT_EQ(reloaded.screenWidthScale(QStringLiteral("Virtual-1")), 1.40);
    EXPECT_FLOAT_EQ(reloaded.screenHeightScale(QStringLiteral("Virtual-1")), 0.60);
}

TEST_F(UniversalSettingsTest, SettingTheSameScaleTwiceIsNotReportedAsAChange)
{
    m_settings->setScreenScales(QStringLiteral("Virtual-1"), 1.10, 1.10);

    QSignalSpy spy(m_settings, &UniversalSettings::screenScalesChanged);
    m_settings->setScreenScales(QStringLiteral("Virtual-1"), 1.10, 1.10);

    EXPECT_EQ(spy.count(), 0);
}

TEST_F(UniversalSettingsTest, ChangingAScaleIsAnnounced)
{
    QSignalSpy spy(m_settings, &UniversalSettings::screenScalesChanged);

    m_settings->setScreenScales(QStringLiteral("Virtual-1"), 1.10, 1.10);

    EXPECT_EQ(spy.count(), 1);
}

TEST_F(UniversalSettingsTest, ParabolicSpreadIsRememberedAcrossInstances)
{
    m_settings->setParabolicSpread(5);

    EXPECT_EQ(m_settings->parabolicSpread(), 5);

    //! a second instance over the same file stands in for the next start of the application
    UniversalSettings reloaded(m_config);
    reloaded.load();

    EXPECT_EQ(reloaded.parabolicSpread(), 5);
}

TEST_F(UniversalSettingsTest, ThicknessMarginInfluenceIsRememberedAcrossInstances)
{
    //! the three buttons of the preferences page write through this setting
    m_settings->setThicknessMarginInfluence(0.5);

    UniversalSettings reloaded(m_config);
    reloaded.load();

    EXPECT_FLOAT_EQ(reloaded.thicknessMarginInfluence(), 0.5);
}
