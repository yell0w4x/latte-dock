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

//! Stands in for the Plasma::Applet a layout item carries. Real applets can not be built
//! outside of a corona, and this only needs to answer the id the layout manager reads.
class AppletObject : public QObject
{
    Q_OBJECT
    Q_PROPERTY(uint id READ id CONSTANT)

public:
    explicit AppletObject(uint id, QObject *parent = nullptr)
        : QObject(parent)
        , m_id(id)
    {
    }

    uint id() const { return m_id; }

private:
    uint m_id{0};
};

//! Stands in for the applet graphic item. PlasmaQuick::AppletQuickItem has no way of being
//! given an applet outside of a plasma shell, so this mirrors the part of its API the layout
//! manager depends on: the applet is reached through "plasmoid" and the item itself carries
//! no id of its own.
class AppletItemObject : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *plasmoid READ plasmoid CONSTANT)

public:
    explicit AppletItemObject(uint appletid, QObject *parent = nullptr)
        : QObject(parent)
        , m_applet(new AppletObject(appletid, this))
    {
    }

    QObject *plasmoid() const { return m_applet; }

private:
    AppletObject *m_applet{nullptr};
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

    //! creates the item a layout holds for an applet, carrying its applet like the
    //! containment does
    QQuickItem *addAppletItem(QQuickItem *layout, uint appletid)
    {
        auto *item = new QQuickItem(layout);
        auto *appletitem = new AppletItemObject(appletid, item);
        item->setProperty("applet", QVariant::fromValue<QObject *>(appletitem));
        return item;
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

TEST_F(LayoutManagerTest, AppletIdsAreReadThroughTheGraphicItem)
{
    setConfiguration(int(Latte::Types::Center), -1, -1, QString());

    //! The item of a layout carries the applet graphic item, not the applet, and only the
    //! applet knows its id. Reading the id from the item answers with nothing, which used to
    //! leave every applet out of the stored order.
    addAppletItem(m_manager->mainLayout(), 40);

    m_manager->save();

    EXPECT_EQ(m_manager->appletOrder(), QList<int>({40}));
}

TEST_F(LayoutManagerTest, SavingWritesTheAppletOrder)
{
    setConfiguration(int(Latte::Types::Center), -1, -1, QString());

    addAppletItem(m_manager->mainLayout(), 40);
    addAppletItem(m_manager->mainLayout(), 41);

    m_manager->save();

    //! the order is what places the applets again on the next start, an empty one leaves
    //! the view to be rebuilt from whatever its template happened to provide
    EXPECT_EQ(m_containment->propertyMap()->value(QStringLiteral("appletOrder")).toString(),
              QStringLiteral("40;41"));
    EXPECT_EQ(m_manager->appletOrder(), QList<int>({40, 41}));
}

TEST_F(LayoutManagerTest, SavingKeepsTheOrderOfTheThreeLayouts)
{
    setConfiguration(int(Latte::Types::Justify), -1, -1, QString());

    addAppletItem(m_manager->startLayout(), 40);
    addAppletItem(m_manager->mainLayout(), 41);
    addAppletItem(m_manager->endLayout(), 42);

    m_manager->save();

    //! start, main and end are stored as one sequence
    EXPECT_EQ(m_containment->propertyMap()->value(QStringLiteral("appletOrder")).toString(),
              QStringLiteral("40;41;42"));
}

TEST_F(LayoutManagerTest, SavingAJustifiedLayoutWritesTheSplitterPositions)
{
    setConfiguration(int(Latte::Types::Justify), 0, 2, QString());

    addAppletItem(m_manager->startLayout(), 40);
    addAppletItem(m_manager->mainLayout(), 41);

    m_manager->save();

    //! the positions say how the applets are shared between the three layouts. Leaving them
    //! at what the view template provided put every applet into the end layout, which moved
    //! them to the far side of the view.
    EXPECT_EQ(m_containment->propertyMap()->value(QStringLiteral("splitterPosition")).toInt(), 2);
    EXPECT_EQ(m_containment->propertyMap()->value(QStringLiteral("splitterPosition2")).toInt(), 4);

    EXPECT_EQ(m_manager->splitterPosition(), 2);
    EXPECT_EQ(m_manager->splitterPosition2(), 4);
}

TEST_F(LayoutManagerTest, SavedSplitterPositionsRestoreTheSameArrangement)
{
    setConfiguration(int(Latte::Types::Justify), -1, -1, QString());

    addAppletItem(m_manager->startLayout(), 40);
    addAppletItem(m_manager->mainLayout(), 41);
    m_manager->save();

    const QString order = m_containment->propertyMap()->value(QStringLiteral("appletOrder")).toString();
    const int splitter = m_containment->propertyMap()->value(QStringLiteral("splitterPosition")).toInt();
    const int splitter2 = m_containment->propertyMap()->value(QStringLiteral("splitterPosition2")).toInt();

    //! feeding the stored values back is what happens on the next start
    setConfiguration(int(Latte::Types::Justify), splitter, splitter2, order);
    m_manager->restore();

    //! the first applet stays ahead of the first splitter, so it belongs to the start layout
    const QList<int> restored = m_manager->order();
    ASSERT_GE(restored.count(), 2);
    EXPECT_EQ(restored[0], 40);
    EXPECT_EQ(restored[1], LayoutManager::JUSTIFYSPLITTERID);
}

TEST_F(LayoutManagerTest, SavingANonJustifiedLayoutKeepsTheStoredSplitters)
{
    //! a centered view has no splitters of its own, the stored ones belong to the justified
    //! arrangement it had before and have to survive
    setConfiguration(int(Latte::Types::Center), 3, 5, QString());

    addAppletItem(m_manager->mainLayout(), 40);
    m_manager->save();

    EXPECT_EQ(m_containment->propertyMap()->value(QStringLiteral("splitterPosition")).toInt(), 3);
    EXPECT_EQ(m_containment->propertyMap()->value(QStringLiteral("splitterPosition2")).toInt(), 5);
}

#include "layoutmanagertest.moc"
