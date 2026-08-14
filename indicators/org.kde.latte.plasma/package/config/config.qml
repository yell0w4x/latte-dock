/*
    SPDX-FileCopyrightText: 2018 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.7
import QtQuick.Layouts 1.3

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

import org.kde.latte.components 1.0 as LatteComponents
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root

    //! QtQuick Controls buttons and checkboxes declare an "indicator" property of
    //! their own, which shadows the context property of the same name inside their
    //! scope. Reading it through the root item makes sure the Latte indicator object
    //! is used everywhere instead of a button's own (null) indicator item.
    readonly property QtObject latteIndicator: indicator
    Layout.fillWidth: true

    LatteComponents.SubHeader {
        text: i18n("Style")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            text: i18n("Padding")
            horizontalAlignment: Text.AlignLeft
        }

        LatteComponents.Slider {
            id: lengthIntMarginSlider
            Layout.fillWidth: true

            value: Math.round(root.latteIndicator.configuration.lengthPadding * 100)
            from: 0
            to: maxMargin
            stepSize: 1
            wheelEnabled: false

            readonly property int maxMargin: 80

            onPressedChanged: {
                if (!pressed) {
                    root.latteIndicator.configuration.lengthPadding = value / 100;
                }
            }
        }

        PlasmaComponents.Label {
            text: i18nc("number in percentage, e.g. 85 %","%1 %", currentValue)
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8

            readonly property int currentValue: lengthIntMarginSlider.value
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            text: i18n("Corner Margin")
            horizontalAlignment: Text.AlignLeft
        }

        LatteComponents.Slider {
            id: backgroundCornerMarginSlider
            Layout.fillWidth: true

            value: Math.round(root.latteIndicator.configuration.backgroundCornerMargin * 100)
            from: 0
            to: 100
            stepSize: 1
            wheelEnabled: false

            onPressedChanged: {
                if (!pressed) {
                    root.latteIndicator.configuration.backgroundCornerMargin = value / 100;
                }
            }
        }

        PlasmaComponents.Label {
            text: i18nc("number in percentage, e.g. 85 %","%1 %", currentValue)
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8

            readonly property int currentValue: backgroundCornerMarginSlider.value
        }
    }

    LatteComponents.SubHeader {
        text: i18n("Options")
    }

    LatteComponents.CheckBoxesColumn {
        Layout.topMargin: 1.5 * Kirigami.Units.smallSpacing

       /* LatteComponents.CheckBox {
            Layout.maximumWidth: dialog.optionsWidth
            text: i18n("Reverse indicator style")
            value: root.latteIndicator.configuration.reversed

            onClicked: {
                root.latteIndicator.configuration.reversed = !root.latteIndicator.configuration.reversed;
            }
        }*/

        LatteComponents.CheckBox {
            Layout.maximumWidth: dialog.optionsWidth
            text: i18n("Growing circle animation when clicked")
            value: root.latteIndicator.configuration.clickedAnimationEnabled

            onClicked: {
                root.latteIndicator.configuration.clickedAnimationEnabled = !root.latteIndicator.configuration.clickedAnimationEnabled;
            }
        }

      /*  LatteComponents.CheckBox {
            Layout.maximumWidth: dialog.optionsWidth
            text: i18n("Show indicators for applets")
            tooltip: i18n("Indicators are shown for applets")
            value: root.latteIndicator.configuration.enabledForApplets

            onClicked: {
                root.latteIndicator.configuration.enabledForApplets = !root.latteIndicator.configuration.enabledForApplets;
            }
        }*/
    }
}
