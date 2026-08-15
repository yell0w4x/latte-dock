/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include "data/generictable.h"
#include "data/layoutdata.h"
#include "data/viewdata.h"
#include "data/viewstable.h"

#include <QString>

using Latte::Data::Generic;
using Latte::Data::GenericTable;
using Latte::Data::View;
using Latte::Data::ViewsTable;

//! The data records the settings dialogs are built on. They are plain value types, so the
//! real ones are used throughout and nothing is substituted here.

class ViewDataTest : public ::testing::Test
{
protected:
    View createdView(const QString &id, const QString &name) const
    {
        View view(id, name);
        view.setState(View::IsCreated);
        return view;
    }
};

TEST_F(ViewDataTest, ADefaultViewIsNeitherValidNorCreated)
{
    View view;

    EXPECT_FALSE(view.isValid());
    EXPECT_FALSE(view.isCreated());
}

TEST_F(ViewDataTest, ValidityFollowsTheStateAndNotTheId)
{
    View view(QStringLiteral("12"), QStringLiteral("Default Dock"));

    EXPECT_EQ(view.id, QStringLiteral("12"));
    EXPECT_EQ(view.name, QStringLiteral("Default Dock"));

    //! carrying an id is not enough, a view becomes valid once it has been given a state,
    //! which is what tells a created view apart from one that is only being described
    EXPECT_FALSE(view.isValid());

    view.setState(View::IsCreated);

    EXPECT_TRUE(view.isValid());
    EXPECT_TRUE(view.isCreated());
}

TEST_F(ViewDataTest, AViewFromATemplateRemembersItsOriginFile)
{
    View view(QStringLiteral("13"), QStringLiteral("New Panel"));
    view.setState(View::OriginFromViewTemplate, QStringLiteral("/tmp/Empty Panel.view.latte"));

    EXPECT_TRUE(view.hasViewTemplateOrigin());
    EXPECT_FALSE(view.hasLayoutOrigin());
    EXPECT_FALSE(view.isCreated());
    EXPECT_EQ(view.originFile(), QStringLiteral("/tmp/Empty Panel.view.latte"));
}

TEST_F(ViewDataTest, AViewCopiedFromALayoutRemembersWhereItCameFrom)
{
    View view(QStringLiteral("14"), QStringLiteral("Copied Dock"));
    view.setState(View::OriginFromLayout,
                  QStringLiteral("/tmp/My Layout.layout.latte"),
                  QStringLiteral("My Layout"),
                  QStringLiteral("12"));

    EXPECT_TRUE(view.hasLayoutOrigin());
    EXPECT_FALSE(view.hasViewTemplateOrigin());
    EXPECT_EQ(view.originLayout(), QStringLiteral("My Layout"));
    EXPECT_EQ(view.originView(), QStringLiteral("12"));
}

TEST_F(ViewDataTest, EdgesDecideWhetherAViewIsHorizontalOrVertical)
{
    View view(QStringLiteral("12"), QStringLiteral("Dock"));

    view.edge = Plasma::Types::BottomEdge;
    EXPECT_TRUE(view.isHorizontal());
    EXPECT_FALSE(view.isVertical());

    view.edge = Plasma::Types::TopEdge;
    EXPECT_TRUE(view.isHorizontal());

    view.edge = Plasma::Types::LeftEdge;
    EXPECT_TRUE(view.isVertical());
    EXPECT_FALSE(view.isHorizontal());

    view.edge = Plasma::Types::RightEdge;
    EXPECT_TRUE(view.isVertical());
}

TEST_F(ViewDataTest, AClonedViewKnowsItIsNotOriginal)
{
    View original(QStringLiteral("12"), QStringLiteral("Dock"));
    View clone(QStringLiteral("13"), QStringLiteral("Dock"));
    clone.isClonedFrom = 12;

    EXPECT_TRUE(original.isOriginal());
    EXPECT_FALSE(original.isCloned());

    EXPECT_TRUE(clone.isCloned());
    EXPECT_FALSE(clone.isOriginal());
}

TEST_F(ViewDataTest, SubContainmentsAreFoundById)
{
    View view(QStringLiteral("12"), QStringLiteral("Dock"));
    view.subcontainments << Generic(QStringLiteral("40"), QStringLiteral("Applet"));

    EXPECT_TRUE(view.hasSubContainment(QStringLiteral("40")));
    EXPECT_FALSE(view.hasSubContainment(QStringLiteral("41")));
}

TEST_F(ViewDataTest, ErrorsAndWarningsAreReportedSeparately)
{
    View view(QStringLiteral("12"), QStringLiteral("Dock"));

    EXPECT_FALSE(view.hasErrors());
    EXPECT_FALSE(view.hasWarnings());

    view.warnings = 2;
    EXPECT_TRUE(view.hasWarnings());
    EXPECT_FALSE(view.hasErrors());

    view.errors = 1;
    EXPECT_TRUE(view.hasErrors());
}

TEST_F(ViewDataTest, CopiedViewsCompareEqual)
{
    View view = createdView(QStringLiteral("12"), QStringLiteral("Dock"));
    view.edge = Plasma::Types::TopEdge;
    view.alignment = Latte::Types::Justify;

    View copy = view;

    EXPECT_TRUE(copy == view);

    copy.alignment = Latte::Types::Center;
    EXPECT_FALSE(copy == view);
}

//! GenericTable is the container every settings model is built on, so its bookkeeping is
//! exercised through the views table the docks and panels dialog uses.

TEST_F(ViewDataTest, TableTracksRowsById)
{
    ViewsTable views;
    views << createdView(QStringLiteral("12"), QStringLiteral("Dock"));
    views << createdView(QStringLiteral("13"), QStringLiteral("Panel"));

    EXPECT_EQ(views.rowCount(), 2);
    EXPECT_TRUE(views.containsId(QStringLiteral("12")));
    EXPECT_TRUE(views.containsId(QStringLiteral("13")));
    EXPECT_FALSE(views.containsId(QStringLiteral("99")));

    EXPECT_EQ(views.indexOf(QStringLiteral("13")), 1);
    EXPECT_EQ(views.indexOf(QStringLiteral("99")), -1);
}

TEST_F(ViewDataTest, TableLooksRowsUpByIdAndByRow)
{
    ViewsTable views;
    views << createdView(QStringLiteral("12"), QStringLiteral("Dock"));
    views << createdView(QStringLiteral("13"), QStringLiteral("Panel"));

    EXPECT_EQ(views[QStringLiteral("13")].name, QStringLiteral("Panel"));
    EXPECT_EQ(views[1].name, QStringLiteral("Panel"));
}

TEST_F(ViewDataTest, RemovingARowLeavesTheRestInOrder)
{
    ViewsTable views;
    views << createdView(QStringLiteral("12"), QStringLiteral("Dock"));
    views << createdView(QStringLiteral("13"), QStringLiteral("Panel"));
    views << createdView(QStringLiteral("14"), QStringLiteral("Sidebar"));

    views.remove(QStringLiteral("13"));

    EXPECT_EQ(views.rowCount(), 2);
    EXPECT_FALSE(views.containsId(QStringLiteral("13")));
    EXPECT_EQ(views[0].id, QStringLiteral("12"));
    EXPECT_EQ(views[1].id, QStringLiteral("14"));
}

TEST_F(ViewDataTest, ClearingATableEmptiesIt)
{
    ViewsTable views;
    views << createdView(QStringLiteral("12"), QStringLiteral("Dock"));
    views.clear();

    EXPECT_EQ(views.rowCount(), 0);
    EXPECT_TRUE(views.isEmpty());
}

TEST_F(ViewDataTest, TablesCompareByContent)
{
    ViewsTable one;
    ViewsTable other;

    one << createdView(QStringLiteral("12"), QStringLiteral("Dock"));
    other << createdView(QStringLiteral("12"), QStringLiteral("Dock"));

    EXPECT_TRUE(one == other);

    other << createdView(QStringLiteral("13"), QStringLiteral("Panel"));
    EXPECT_FALSE(one == other);
}
