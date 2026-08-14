/*
    SPDX-FileCopyrightText: 2018 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.7
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid 2.0

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

    //! A Plasma button uses wider frame margins once it is checked, which makes the
    //! selected button of a group taller than its siblings. Pinning the height and the
    //! paddings of every button in this page to an unchecked reference keeps them equal.
    readonly property int checkableButtonsHeight: _buttonMetrics.implicitHeight
    readonly property real checkableButtonsTopPadding: _buttonMetrics.topPadding
    readonly property real checkableButtonsBottomPadding: _buttonMetrics.bottomPadding
    readonly property real checkableButtonsLeftPadding: _buttonMetrics.leftPadding
    readonly property real checkableButtonsRightPadding: _buttonMetrics.rightPadding

    PlasmaComponents.Button {
        id: _buttonMetrics
        visible: false
        checked: false
        checkable: false
        text: "reference"
    }

    LatteComponents.SubHeader {
        text: i18nc("indicator style","Style")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        property int indicatorType: root.latteIndicator.configuration.activeStyle

        readonly property int buttonsCount: 2
        readonly property int buttonSize: (dialog.optionsWidth - (spacing * buttonsCount-1)) / buttonsCount

        QQC2.ButtonGroup {
            id: activeIndicatorTypeGroup
        }

        PlasmaComponents.Button {
            Layout.minimumHeight: root.checkableButtonsHeight
            Layout.maximumHeight: Layout.minimumHeight
            topPadding: root.checkableButtonsTopPadding
            bottomPadding: root.checkableButtonsBottomPadding
            leftPadding: root.checkableButtonsLeftPadding
            rightPadding: root.checkableButtonsRightPadding
            Layout.minimumWidth: parent.buttonSize
            Layout.maximumWidth: Layout.minimumWidth
            text: i18nc("line indicator","Line")
            checked: parent.indicatorType === indicatorType
            checkable: false
            QQC2.ButtonGroup.group: activeIndicatorTypeGroup
            PlasmaComponents.ToolTip.text: i18n("Show a line indicator for active items")
            PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""

            readonly property int indicatorType: 0 /*Line*/

            onPressedChanged: {
                if (pressed) {
                    root.latteIndicator.configuration.activeStyle = indicatorType;
                }
            }
        }

        PlasmaComponents.Button {
            Layout.minimumHeight: root.checkableButtonsHeight
            Layout.maximumHeight: Layout.minimumHeight
            topPadding: root.checkableButtonsTopPadding
            bottomPadding: root.checkableButtonsBottomPadding
            leftPadding: root.checkableButtonsLeftPadding
            rightPadding: root.checkableButtonsRightPadding
            Layout.minimumWidth: parent.buttonSize
            Layout.maximumWidth: Layout.minimumWidth
            text: i18nc("dots indicator", "Dots")
            checked: parent.indicatorType === indicatorType
            checkable: false
            QQC2.ButtonGroup.group: activeIndicatorTypeGroup
            PlasmaComponents.ToolTip.text: i18n("Show a dot indicator for active items")
            PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""

            readonly property int indicatorType: 1 /*Dot*/

            onPressedChanged: {
                if (pressed) {
                    root.latteIndicator.configuration.activeStyle = indicatorType;
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            text: i18n("Thickness")
            horizontalAlignment: Text.AlignLeft
        }

        LatteComponents.Slider {
            id: sizeSlider
            Layout.fillWidth: true

            value: Math.round(root.latteIndicator.configuration.size * 100)
            from: 3
            to: 25
            stepSize: 1
            wheelEnabled: false

            onPressedChanged: {
                if (!pressed) {
                    root.latteIndicator.configuration.size = Number(value / 100).toFixed(2);
                }
            }
        }

        PlasmaComponents.Label {
            text: i18nc("number in percentage, e.g. 85 %","%1 %", currentValue)
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8

            readonly property int currentValue: sizeSlider.value
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            text: i18n("Position")
            horizontalAlignment: Text.AlignLeft
        }

        LatteComponents.Slider {
            id: thickMarginSlider
            Layout.fillWidth: true

            value: Math.round(root.latteIndicator.configuration.thickMargin * 100)
            from: 0
            to: 30
            stepSize: 1
            wheelEnabled: false

            onPressedChanged: {
                if (!pressed) {
                    root.latteIndicator.configuration.thickMargin = value / 100;
                }
            }
        }

        PlasmaComponents.Label {
            text: i18nc("number in percentage, e.g. 85 %","%1 %", currentValue)
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8

            readonly property int currentValue: thickMarginSlider.value
        }
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

    LatteComponents.HeaderSwitch {
        id: glowEnabled
        Layout.fillWidth: true
        Layout.minimumHeight: implicitHeight
        Layout.bottomMargin: Kirigami.Units.smallSpacing

        checked: root.latteIndicator.configuration.glowEnabled
        level: 2
        text: i18n("Glow")
        tooltip: i18n("Enable/disable indicator glow")

        onPressed: {
            root.latteIndicator.configuration.glowEnabled = !root.latteIndicator.configuration.glowEnabled;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 2
        enabled: root.latteIndicator.configuration.glowEnabled

        property int option: root.latteIndicator.configuration.glowApplyTo

        readonly property int buttonsCount: 2
        readonly property int buttonSize: (dialog.optionsWidth - (spacing * buttonsCount-1)) / buttonsCount

        QQC2.ButtonGroup {
            id: glowGroup
        }

        PlasmaComponents.Button {
            Layout.minimumHeight: root.checkableButtonsHeight
            Layout.maximumHeight: Layout.minimumHeight
            topPadding: root.checkableButtonsTopPadding
            bottomPadding: root.checkableButtonsBottomPadding
            leftPadding: root.checkableButtonsLeftPadding
            rightPadding: root.checkableButtonsRightPadding
            Layout.minimumWidth: parent.buttonSize
            Layout.maximumWidth: Layout.minimumWidth
            text: i18nc("glow only to active task/applet indicators","On Active")
            checked: parent.option === option
            checkable: false
            QQC2.ButtonGroup.group:  glowGroup
            PlasmaComponents.ToolTip.text: i18n("Add glow only to active task/applet indicator")
            PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""

            readonly property int option: 1 /*OnActive*/

            onPressedChanged: {
                if (pressed) {
                    root.latteIndicator.configuration.glowApplyTo = option;
                }
            }
        }

        PlasmaComponents.Button {
            Layout.minimumHeight: root.checkableButtonsHeight
            Layout.maximumHeight: Layout.minimumHeight
            topPadding: root.checkableButtonsTopPadding
            bottomPadding: root.checkableButtonsBottomPadding
            leftPadding: root.checkableButtonsLeftPadding
            rightPadding: root.checkableButtonsRightPadding
            Layout.minimumWidth: parent.buttonSize
            Layout.maximumWidth: Layout.minimumWidth
            text: i18nc("glow to all task/applet indicators","All")
            checked: parent.option === option
            checkable: false
            QQC2.ButtonGroup.group: glowGroup
            PlasmaComponents.ToolTip.text: i18n("Add glow to all task/applet indicators")
            PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""

            readonly property int option: 2 /*All*/

            onPressedChanged: {
                if (pressed) {
                    root.latteIndicator.configuration.glowApplyTo = option;
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        enabled: root.latteIndicator.configuration.glowEnabled

        PlasmaComponents.Label {
            Layout.minimumWidth: implicitWidth
            horizontalAlignment: Text.AlignLeft
            Layout.rightMargin: Kirigami.Units.smallSpacing
            text: i18n("Opacity")
        }

        LatteComponents.Slider {
            id: glowOpacitySlider
            Layout.fillWidth: true

            leftPadding: 0
            value: root.latteIndicator.configuration.glowOpacity * 100
            from: 0
            to: 100
            stepSize: 5
            wheelEnabled: false

            function updateGlowOpacity() {
                if (!pressed)
                    root.latteIndicator.configuration.glowOpacity = value/100;
            }

            onPressedChanged: {
                updateGlowOpacity();
            }

            Component.onCompleted: {
                valueChanged.connect(updateGlowOpacity);
            }

            Component.onDestruction: {
                valueChanged.disconnect(updateGlowOpacity);
            }
        }

        PlasmaComponents.Label {
            text: i18nc("number in percentage, e.g. 85 %","%1 %", glowOpacitySlider.value)
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8
        }
    }

    ColumnLayout {
        spacing: 0
        visible: root.latteIndicator.latteTasksArePresent

        LatteComponents.SubHeader {
            enabled: root.latteIndicator.configuration.glowApplyTo!==0/*None*/
            text: i18n("Tasks")
        }

        LatteComponents.CheckBoxesColumn {
            LatteComponents.CheckBox {
                Layout.maximumWidth: dialog.optionsWidth
                text: i18n("Different color for minimized windows")
                value: root.latteIndicator.configuration.minimizedTaskColoredDifferently

                onClicked: {
                    root.latteIndicator.configuration.minimizedTaskColoredDifferently = !root.latteIndicator.configuration.minimizedTaskColoredDifferently;
                }
            }

            LatteComponents.CheckBox {
                Layout.maximumWidth: dialog.optionsWidth
                text: i18n("Show an extra dot for grouped windows when active")
                tooltip: i18n("Grouped windows show both a line and a dot when one of them is active and the Line Active Indicator is enabled")
                enabled: root.latteIndicator.configuration.activeStyle === 0 /*Line*/
                value: root.latteIndicator.configuration.extraDotOnActive

                onClicked: {
                    root.latteIndicator.configuration.extraDotOnActive = !root.latteIndicator.configuration.extraDotOnActive;
                }
            }
        }
    }

    LatteComponents.SubHeader {
        enabled: root.latteIndicator.configuration.glowApplyTo!==0/*None*/
        text: i18n("Options")
    }

    LatteComponents.CheckBox {
        Layout.maximumWidth: dialog.optionsWidth
        text: i18n("Show indicators for applets")
        tooltip: i18n("Indicators are shown for applets")
        value: root.latteIndicator.configuration.enabledForApplets

        onClicked: {
            root.latteIndicator.configuration.enabledForApplets = !root.latteIndicator.configuration.enabledForApplets;
        }
    }

    LatteComponents.CheckBox {
        Layout.maximumWidth: dialog.optionsWidth
        text: i18n("Reverse indicator style")
        value: root.latteIndicator.configuration.reversed

        onClicked: {
            root.latteIndicator.configuration.reversed = !root.latteIndicator.configuration.reversed;
        }
    }
}
