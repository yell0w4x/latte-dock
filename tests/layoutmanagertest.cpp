/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "plugin/layoutmanager.h"
#include "plugin/lattetypes.h"

#include <QQuickItem>
#include <QVariant>

#include <KConfigPropertyMap>
#include <KCoreConfigSkeleton>

#include <Plasma/Applet>

using Latte::Containment::LayoutManager;

//! A real containment root item. The layout manager reaches back into the containment
//! through these invokables to materialise applet and splitter items, so the test
//! provides real QQuickItems rather than intercepting the calls.
class ContainmentRootItem : public QQuickItem
{
    Q_OBJECT

public:
    Q_INVOKABLE QVariant createAppletItem(QVariant applet)
    {
        Q_UNUSED(applet)
        auto *item = new QQuickItem(this);
        m_appletItems << item;
        return QVariant::fromValue(item);
    }

    Q_INVOKABLE QVariant createJustifySplitter()
    {
        auto *item = new QQuickItem(this);
        item->setProperty("isInternalViewSplitter", true);
        m_splitterItems << item;
        return QVariant::fromValue(item);
    }

    Q_INVOKABLE void initAppletContainer(QVariant container, QVariant applet)
    {
        Q_UNUSED(container)
        Q_UNUSED(applet)
    }

    QList<QQuickItem *> m_appletItems;
    QList<QQuickItem *> m_splitterItems;
};

//! The containment settings the layout manager reads. A real KConfigPropertyMap over a
//! real KCoreConfigSkeleton is used, which is exactly what Plasma hands to the applet.
class ContainmentSettings : public KCoreConfigSkeleton
{
    Q_OBJECT

public:
    explicit ContainmentSettings(QObject *parent = nullptr)
        : KCoreConfigSkeleton(QStringLiteral("lattelayoutmanagertestrc"), parent)
    {
        setCurrentGroup(QStringLiteral("General"));
        addItemInt(QStringLiteral("alignment"), m_alignment, 0);
        addItemInt(QStringLiteral("splitterPosition"), m_splitterPosition, -1);
        addItemInt(QStringLiteral("splitterPosition2"), m_splitterPosition2, -1);
        addItemString(QStringLiteral("appletOrder"), m_appletOrder, QString());
        addItemString(QStringLiteral("lockedZoomApplets"), m_lockedZoomApplets, QString());
        addItemString(QStringLiteral("userBlocksColorizingApplets"), m_userBlocksColorizing, QString());
    }

    int m_alignment{0};
    int m_splitterPosition{-1};
    int m_splitterPosition2{-1};
    QString m_appletOrder;
    QString m_lockedZoomApplets;
    QString m_userBlocksColorizing;
};

//! Stands in for the Plasma::Applet the layout manager is attached to. Plasma applets can
//! not be constructed outside of a corona, so this exposes the two properties the layout
//! manager actually reads, backed by the real configuration object.
class ContainmentObject : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *configuration READ configuration CONSTANT)
    Q_PROPERTY(QList<Plasma::Applet *> applets READ applets CONSTANT)

public:
    explicit ContainmentObject(QObject *parent = nullptr)
        : QObject(parent)
        , m_settings(new ContainmentSettings(this))
        , m_configuration(new KConfigPropertyMap(m_settings, this))
    {
    }

    QObject *configuration() const { return m_configuration; }
    QList<Plasma::Applet *> applets() const { return {}; }

    ContainmentSettings *settings() const { return m_settings; }
    KConfigPropertyMap *propertyMap() const { return m_configuration; }

private:
    ContainmentSettings *m_settings{nullptr};
    KConfigPropertyMap *m_configuration{nullptr};
};

class LayoutManagerTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        m_containment = new ContainmentObject();
        m_root = new ContainmentRootItem();

        m_manager = new LayoutManager();
        m_manager->setPlasmoid(m_containment);
        m_manager->setRootItem(m_root);
        m_manager->setMainLayout(new QQuickItem(m_root));
        m_manager->setStartLayout(new QQuickItem(m_root));
        m_manager->setEndLayout(new QQuickItem(m_root));
    }

    void TearDown() override
    {
        delete m_manager;
        delete m_root;
        delete m_containment;
    }

    void setConfiguration(int alignment, int splitter, int splitter2, const QString &appletorder)
    {
        KConfigPropertyMap *map = m_containment->propertyMap();
        map->insert(QStringLiteral("alignment"), alignment);
        map->insert(QStringLiteral("splitterPosition"), splitter);
        map->insert(QStringLiteral("splitterPosition2"), splitter2);
        map->insert(QStringLiteral("appletOrder"), appletorder);
    }

    ContainmentObject *m_containment{nullptr};
    ContainmentRootItem *m_root{nullptr};
    LayoutManager *m_manager{nullptr};
};

TEST_F(LayoutManagerTest, RestoresANonJustifiedLayout)
{
    setConfiguration(int(Latte::Types::Center), -1, -1, QString());

    m_manager->restore();

    //! no applets and no justify splitters are expected for a centered layout
    EXPECT_TRUE(m_root->m_splitterItems.isEmpty());
    EXPECT_TRUE(m_manager->order().isEmpty());
}

TEST_F(LayoutManagerTest, JustifyWithoutStoredSplittersWrapsTheOrder)
{
    setConfiguration(int(Latte::Types::Justify), -1, -1, QString());

    m_manager->restore();

    //! a justified layout always owns two splitters, one at each end
    EXPECT_EQ(m_root->m_splitterItems.count(), 2);
}

TEST_F(LayoutManagerTest, JustifySurvivesSplitterPositionsBeyondTheAppletOrder)
{
    //! A freshly created view gets splitter positions out of a template while its applet
    //! order is still empty. QList::insert() asserts on an out of range index, which used
    //! to abort the whole application as soon as a panel was added.
    setConfiguration(int(Latte::Types::Justify), 7, 9, QString());

    ASSERT_NO_FATAL_FAILURE(m_manager->restore());

    EXPECT_EQ(m_root->m_splitterItems.count(), 2);
}

TEST_F(LayoutManagerTest, JustifySurvivesNegativeSplitterPositions)
{
    setConfiguration(int(Latte::Types::Justify), -5, -3, QString());

    ASSERT_NO_FATAL_FAILURE(m_manager->restore());

    EXPECT_EQ(m_root->m_splitterItems.count(), 2);
}

TEST_F(LayoutManagerTest, OrderKeepsSplittersOutOfTheAppletOrder)
{
    setConfiguration(int(Latte::Types::Justify), 1, 1, QString());

    m_manager->restore();

    //! appletOrder never contains the splitter marker, order() does
    EXPECT_FALSE(m_manager->appletOrder().contains(LayoutManager::JUSTIFYSPLITTERID));
}

TEST_F(LayoutManagerTest, SplitterIdIsNotAValidAppletId)
{
    //! the splitter marker must never collide with a real applet id
    EXPECT_LT(LayoutManager::JUSTIFYSPLITTERID, 0);
}

TEST_F(LayoutManagerTest, HasNotRestoredAppletsImmediately)
{
    setConfiguration(int(Latte::Types::Center), -1, -1, QString());

    EXPECT_FALSE(m_manager->hasRestoredApplets());
    m_manager->restore();

    //! the flag is raised by a timer once the applets had a chance to settle
    EXPECT_FALSE(m_manager->hasRestoredApplets());
}

#include "layoutmanagertest.moc"
