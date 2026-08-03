/*
    SPDX-FileCopyrightText: 2020 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later

*/

#ifndef ACTIVITYDATA_H
#define ACTIVITYDATA_H

//! local
#include "genericdata.h"
#include "generictable.h"

//! Qt
#include <QMetaType>
#include <QIcon>
#include <QString>

//! Plasma Activities
#include <PlasmaActivities/Info>

namespace Latte {
namespace Data {

class Activity : public Generic
{
public:
    Activity();
    Activity(Activity &&o);
    Activity(const Activity &o);

    //! Plasma 6 dropped KActivities::Info::State, because activities can not
    //! be stopped any longer. We keep a local enum in order to still be able
    //! to mark internal/virtual activities such as [All Activities] as
    //! non-running entries.
    enum State
    {
        Invalid = 0,
        Stopped,
        Running
    };

    //! Layout data
    bool isCurrent{false};
    QString icon;
    State state{Invalid};

    bool isValid() const;
    bool isRunning() const;

    //! Operators
    Activity &operator=(const Activity &rhs);
    Activity &operator=(Activity &&rhs);
};

//! This is an Activities map in the following structure:
//! #activityId -> activite_information
typedef GenericTable<Data::Activity> ActivitiesTable;

}
}

Q_DECLARE_METATYPE(Latte::Data::Activity)
Q_DECLARE_METATYPE(Latte::Data::ActivitiesTable)

#endif
