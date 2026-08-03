/*
    SPDX-FileCopyrightText: 2019 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import org.kde.plasma.components 3.0 as PlasmaComponents

PlasmaComponents.CheckBox {
    property int value: 0

    //! Plasma Components 3 checkboxes do not provide a "tooltip" property, it is
    //! reintroduced here because it is used all over the latte configuration windows
    property string tooltip: ""

    onValueChanged: {
        //! QtQuick Controls 1 partiallyCheckedEnabled/checkedState became tristate/checkState
        if (tristate) {
            checkState = value;
        } else {
            checked = value;
        }
    }

    PlasmaComponents.ToolTip.text: tooltip
    PlasmaComponents.ToolTip.visible: hovered && tooltip !== ""
}
