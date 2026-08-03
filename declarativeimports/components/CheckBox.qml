/*
    SPDX-FileCopyrightText: 2019 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.7

import org.kde.ksvg 1.0 as KSvg
//! importing PlasmaCore is necessary in order to make KSvg load the current plasma theme,
//! without it the svg has no image set and dereferencing it crashes
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

PlasmaComponents.CheckBox {
    id: checkbox

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

    //! The plasma indicator draws the unchecked box with the generic "widgets/button" frame
    //! of the theme, which does not necessarily match the shape of the checkmark graphic
    //! drawn when checked, e.g. a round frame against a square checkmark. Keep the themed
    //! checkmark for the checked states and pair it with an empty box of the same shape.
    indicator: Item {
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: Kirigami.Units.iconSizes.small

        x: checkbox.text.length > 0
           ? (checkbox.mirrored ? checkbox.width - width - checkbox.rightPadding : checkbox.leftPadding)
           : checkbox.leftPadding + (checkbox.availableWidth - width) / 2
        y: checkbox.topPadding + (checkbox.availableHeight - height) / 2

        opacity: checkbox.enabled ? 1 : 0.6

        Rectangle {
            anchors.fill: parent
            radius: Math.max(1, Math.round(width * 0.2))
            color: "transparent"
            border.width: Math.max(1, Math.round(width / 16))
            border.color: Kirigami.Theme.textColor
            opacity: checkbox.hovered ? 0.9 : 0.6
            visible: checkbox.checkState === Qt.Unchecked
        }

        KSvg.SvgItem {
            anchors.fill: parent
            svg: KSvg.Svg {
                imagePath: "widgets/checkmarks"
            }
            elementId: "checkbox"
            visible: checkbox.checkState !== Qt.Unchecked
            opacity: checkbox.checkState === Qt.PartiallyChecked ? 0.5 : 1
        }
    }
}
