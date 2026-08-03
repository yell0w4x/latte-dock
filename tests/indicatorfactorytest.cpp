/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "indicator/factory.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QTextStream>

#include <KPluginMetaData>

using Latte::Indicator::Factory;

//! The indicator factory discovers indicator packages on disk and reads their
//! metadata.json through KPluginMetaData. It is driven here with real packages written
//! into the test data location, so the whole discovery path runs for real.
class IndicatorFactoryTest : public ::testing::Test
{
protected:
    static void writeIndicator(const QString &dirpath, const QString &pluginid,
                               const QString &name, const QString &category)
    {
        QDir().mkpath(dirpath + QStringLiteral("/package/ui"));

        QFile metadata(dirpath + QStringLiteral("/metadata.json"));
        ASSERT_TRUE(metadata.open(QIODevice::WriteOnly | QIODevice::Text));

        QTextStream out(&metadata);
        out << "{\n"
               "    \"KPlugin\": {\n"
               "        \"Id\": \"" << pluginid << "\",\n"
               "        \"Name\": \"" << name << "\",\n"
               "        \"Category\": \"" << category << "\",\n"
               "        \"Description\": \"latte integration test indicator\",\n"
               "        \"License\": \"GPL\",\n"
               "        \"Version\": \"1.0\"\n"
               "    },\n"
               "    \"X-Latte-MainScript\": \"ui/main.qml\",\n"
               "    \"X-Plasma-API\": \"declarativeappletscript\"\n"
               "}\n";
        metadata.close();

        QFile ui(dirpath + QStringLiteral("/package/ui/main.qml"));
        ASSERT_TRUE(ui.open(QIODevice::WriteOnly | QIODevice::Text));
        QTextStream uiout(&ui);
        uiout << "import QtQuick\nItem {}\n";
        ui.close();
    }

    void SetUp() override
    {
        //! QStandardPaths test mode points the generic data location into a throwaway
        //! directory, the factory therefore only ever sees the packages written here
        m_indicatorsPath = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                + QStringLiteral("/latte/indicators");

        QDir(m_indicatorsPath).removeRecursively();

        writeIndicator(m_indicatorsPath + QStringLiteral("/default"),
                       QStringLiteral("org.kde.latte.default"),
                       QStringLiteral("Latte"),
                       QStringLiteral("Latte Indicator"));

        writeIndicator(m_indicatorsPath + QStringLiteral("/org.kde.latte.plasma"),
                       QStringLiteral("org.kde.latte.plasma"),
                       QStringLiteral("Plasma"),
                       QStringLiteral("Latte Indicator"));

        //! a package that is not a latte indicator at all, it must be ignored
        writeIndicator(m_indicatorsPath + QStringLiteral("/org.kde.foreign"),
                       QStringLiteral("org.kde.foreign"),
                       QStringLiteral("Foreign"),
                       QStringLiteral("Plasma Applet"));
    }

    void TearDown() override
    {
        QDir(m_indicatorsPath).removeRecursively();
    }

    QString m_indicatorsPath;
};

TEST_F(IndicatorFactoryTest, DiscoversIndicatorPackagesFromDisk)
{
    Factory factory(nullptr);

    EXPECT_TRUE(factory.pluginExists(QStringLiteral("org.kde.latte.default")));
    EXPECT_TRUE(factory.pluginExists(QStringLiteral("org.kde.latte.plasma")));
}

TEST_F(IndicatorFactoryTest, MetadataIsReadFromTheJsonFile)
{
    //! KPluginMetaData's single string constructor resolves plugin libraries, a
    //! metadata.json has to go through fromJsonFile(). Getting this wrong left every
    //! indicator invalid and nothing was ever drawn.
    Factory factory(nullptr);

    const KPluginMetaData metadata = factory.metadata(QStringLiteral("org.kde.latte.default"));

    ASSERT_TRUE(metadata.isValid());
    EXPECT_EQ(metadata.pluginId(), QStringLiteral("org.kde.latte.default"));
    EXPECT_EQ(metadata.name(), QStringLiteral("Latte"));
    EXPECT_EQ(metadata.value(QStringLiteral("X-Latte-MainScript")), QStringLiteral("ui/main.qml"));
}

TEST_F(IndicatorFactoryTest, RejectsPackagesOfAnotherCategory)
{
    Factory factory(nullptr);

    EXPECT_FALSE(factory.pluginExists(QStringLiteral("org.kde.foreign")));
    EXPECT_FALSE(factory.metadata(QStringLiteral("org.kde.foreign")).isValid());
}

TEST_F(IndicatorFactoryTest, UnknownPluginYieldsInvalidMetadata)
{
    Factory factory(nullptr);

    EXPECT_FALSE(factory.pluginExists(QStringLiteral("org.kde.latte.doesnotexist")));
    EXPECT_FALSE(factory.metadata(QStringLiteral("org.kde.latte.doesnotexist")).isValid());
}

TEST_F(IndicatorFactoryTest, ShippedIndicatorsAreNotReportedAsCustom)
{
    Factory factory(nullptr);

    //! default and plasma are the built in ones, they must not show up in the
    //! "custom indicators" list presented in the effects page
    EXPECT_FALSE(factory.customPluginIds().contains(QStringLiteral("org.kde.latte.default")));
    EXPECT_FALSE(factory.customPluginIds().contains(QStringLiteral("org.kde.latte.plasma")));
}

TEST_F(IndicatorFactoryTest, UiPathPointsAtTheMainScriptDirectory)
{
    Factory factory(nullptr);

    const QString uipath = factory.uiPath(QStringLiteral("org.kde.latte.default"));

    ASSERT_FALSE(uipath.isEmpty());
    EXPECT_TRUE(QDir(uipath).exists());
    EXPECT_TRUE(QFile::exists(uipath + QStringLiteral("/main.qml")));
}
