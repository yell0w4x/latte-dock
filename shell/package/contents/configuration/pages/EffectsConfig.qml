/*
    SPDX-FileCopyrightText: 2018 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.7
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import QtQuick.Dialogs
import QtQuick.Controls 2.12 as QtQuickControls212

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras

import org.kde.latte.core 0.2 as LatteCore
import org.kde.latte.components 1.0 as LatteComponents
import org.kde.latte.private.containment 0.1 as LatteContainment

import "../../controls" as LatteExtraControls
import org.kde.kirigami 2.20 as Kirigami

PlasmaComponents.Page {
    id: page

    //! Plasma6 buttons take their paddings from the frame of their current state and the
    //! "pressed" frame used by a checked button is thicker than "normal", every selected
    //! button would therefore become taller than the rest. This hidden unchecked button
    //! provides the smaller, normal state height that is applied to all of them.
    readonly property int checkableButtonsHeight: _buttonHeightReference.implicitHeight
    readonly property real checkableButtonsTopPadding: _buttonHeightReference.topPadding
    readonly property real checkableButtonsBottomPadding: _buttonHeightReference.bottomPadding
    readonly property real checkableButtonsLeftPadding: _buttonHeightReference.leftPadding
    readonly property real checkableButtonsRightPadding: _buttonHeightReference.rightPadding

    PlasmaComponents.Button {
        id: _buttonHeightReference
        visible: false
        checked: false
        text: "Ag"
        icon.name: "arrow-down"
    }
    width: content.width + content.Layout.leftMargin * 2
    height: content.height + Kirigami.Units.smallSpacing

    ColumnLayout {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        Layout.leftMargin: Kirigami.Units.smallSpacing * 2
        width: (dialog.appliedWidth - Kirigami.Units.smallSpacing * 2) - Layout.leftMargin * 2
        spacing: dialog.subGroupSpacing

        //! BEGIN: Shadows
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            spacing: Kirigami.Units.smallSpacing

            LatteComponents.HeaderSwitch {
                id: showAppletShadow
                Layout.fillWidth: true
                Layout.minimumHeight: implicitHeight
                Layout.topMargin: Kirigami.Units.smallSpacing

                checked: plasmoid.configuration.appletShadowsEnabled
                text: i18n("Shadows")
                tooltip: i18n("Enable/disable applet shadows")

                onPressed: plasmoid.configuration.appletShadowsEnabled = !plasmoid.configuration.appletShadowsEnabled;
            }

            ColumnLayout {
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                spacing: 0

                RowLayout{
                    enabled: showAppletShadow.checked

                    PlasmaComponents.Label {
                        enabled: showAppletShadow.checked
                        text: i18n("Size")
                        horizontalAlignment: Text.AlignLeft
                    }

                    LatteComponents.Slider {
                        id: shadowSizeSlider
                        Layout.fillWidth: true
                        enabled: showAppletShadow.checked

                        value: plasmoid.configuration.shadowSize
                        from: 0
                        to: 100
                        stepSize: 5
                        wheelEnabled: false

                        function updateShadowSize() {
                            if (!pressed)
                                plasmoid.configuration.shadowSize = value;
                        }

                        onPressedChanged: {
                            updateShadowSize();
                        }

                        Component.onCompleted: {
                            valueChanged.connect(updateShadowSize);
                        }

                        Component.onDestruction: {
                            valueChanged.disconnect(updateShadowSize);
                        }
                    }

                    PlasmaComponents.Label {
                        enabled: showAppletShadow.checked
                        text: i18nc("number in percentage, e.g. 85 %","%1 %", shadowSizeSlider.value)
                        horizontalAlignment: Text.AlignRight
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8
                    }
                }


                RowLayout{
                    enabled: showAppletShadow.checked

                    PlasmaComponents.Label {
                        enabled: showAppletShadow.checked
                        text: i18n("Opacity")
                        horizontalAlignment: Text.AlignLeft
                    }

                    LatteComponents.Slider {
                        id: shadowOpacitySlider
                        Layout.fillWidth: true

                        value: plasmoid.configuration.shadowOpacity
                        from: 0
                        to: 100
                        stepSize: 5
                        wheelEnabled: false

                        function updateShadowOpacity() {
                            if (!pressed)
                                plasmoid.configuration.shadowOpacity = value;
                        }

                        onPressedChanged: {
                            updateShadowOpacity();
                        }

                        Component.onCompleted: {
                            valueChanged.connect(updateShadowOpacity);
                        }

                        Component.onDestruction: {
                            valueChanged.disconnect(updateShadowOpacity);
                        }
                    }

                    PlasmaComponents.Label {
                        id: shadowOpacityLbl
                        enabled: showAppletShadow.checked
                        text: i18nc("number in percentage, e.g. 85 %","%1 %", shadowOpacitySlider.value)
                        horizontalAlignment: Text.AlignRight
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2.8
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 2.8
                    }
                }

                RowLayout {
                    id: shadowColorRow
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: 2
                    enabled: showAppletShadow.checked

                    readonly property string defaultShadow: "080808"
                    readonly property string themeShadow: {
                        var strC = String(Kirigami.Theme.textColor);

                        return strC.indexOf("#") === 0 ? strC.substr(1) : strC;
                    }

                    QQC2.ButtonGroup {
                        id: shadowColorGroup
                    }

                    PlasmaComponents.Button {
                        id: defaultShadowBtn
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        text: i18nc("default shadow", "Default Color")
                        checked: plasmoid.configuration.shadowColorType === type
                        Layout.minimumHeight: page.checkableButtonsHeight
                        Layout.maximumHeight: Layout.minimumHeight
                        topPadding: page.checkableButtonsTopPadding
                        bottomPadding: page.checkableButtonsBottomPadding
                        leftPadding: page.checkableButtonsLeftPadding
                        rightPadding: page.checkableButtonsRightPadding
                        checkable: false
                        QQC2.ButtonGroup.group: shadowColorGroup
                        PlasmaComponents.ToolTip.text: i18n("Default shadow for applets")
                        PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""

                        readonly property int type: LatteContainment.Types.DefaultColorShadow

                        onPressedChanged: {
                            if (pressed) {
                                plasmoid.configuration.shadowColorType = type;
                            }
                        }
                    }

                    PlasmaComponents.Button {
                        id: themeShadowBtn
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        text: i18nc("theme shadow", "Theme Color")
                        checked: plasmoid.configuration.shadowColorType === type
                        Layout.minimumHeight: page.checkableButtonsHeight
                        Layout.maximumHeight: Layout.minimumHeight
                        topPadding: page.checkableButtonsTopPadding
                        bottomPadding: page.checkableButtonsBottomPadding
                        leftPadding: page.checkableButtonsLeftPadding
                        rightPadding: page.checkableButtonsRightPadding
                        checkable: false
                        QQC2.ButtonGroup.group: shadowColorGroup
                        PlasmaComponents.ToolTip.text: i18n("Shadow from theme color palette")
                        PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""

                        readonly property int type: LatteContainment.Types.ThemeColorShadow

                        onPressedChanged: {
                            if (pressed) {
                                plasmoid.configuration.shadowColorType = type;
                            }
                        }
                    }

                    //overlayed button
                    PlasmaComponents.Button {
                        id: userShadowBtn
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: shadowOpacityLbl.width
                        height: parent.height
                        text: " "

                        Layout.minimumHeight: page.checkableButtonsHeight
                        Layout.maximumHeight: Layout.minimumHeight
                        topPadding: page.checkableButtonsTopPadding
                        bottomPadding: page.checkableButtonsBottomPadding
                        leftPadding: page.checkableButtonsLeftPadding
                        rightPadding: page.checkableButtonsRightPadding
                        checkable: false
                        checked: plasmoid.configuration.shadowColorType === type
                        PlasmaComponents.ToolTip.text: i18n("Use set shadow color")
                        PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""
                        QQC2.ButtonGroup.group: shadowColorGroup

                        readonly property int type: LatteContainment.Types.UserColorShadow

                        onPressedChanged: {
                            if (pressed) {
                                plasmoid.configuration.shadowColorType = type;
                            }
                        }

                        Rectangle{
                            anchors.fill: parent
                            anchors.margins: 1.5*Kirigami.Units.smallSpacing

                            color: "#" + plasmoid.configuration.shadowColor;

                            opacity: shadowColorRow.enabled ? 1 : 0.6

                            Rectangle{
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: Kirigami.Theme.textColor
                                opacity: parent.opacity - 0.4
                            }

                            MouseArea{
                                anchors.fill: parent
                                onClicked: {
                                    shadowColorGroup.current = userShadowBtn;
                                    viewConfig.setSticker(true);
                                    colorDialogLoader.showDialog = true;
                                }
                            }
                        }

                        Loader{
                            id:colorDialogLoader
                            property bool showDialog: false
                            active: showDialog

                            sourceComponent: ColorDialog {
                                title: i18n("Please choose shadow color")

                                onAccepted: {
                                    var strC = String(selectedColor);
                                    if (strC.indexOf("#") === 0) {
                                        plasmoid.configuration.shadowColor = strC.substr(1);
                                    }

                                    colorDialogLoader.showDialog = false;
                                    viewConfig.setSticker(false);
                                }
                                onRejected: {
                                    colorDialogLoader.showDialog = false;
                                    viewConfig.setSticker(false);
                                }
                                Component.onCompleted: {
                                    selectedColor = String("#" + plasmoid.configuration.shadowColor);
                                    visible = true;
                                }
                            }
                        }
                    }
                }
            }
        }
        //! END: Shadows

        //! BEGIN: Animations
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            LatteComponents.HeaderSwitch {
                id: animationsHeader
                Layout.fillWidth: true
                Layout.minimumHeight: implicitHeight
                Layout.topMargin: Kirigami.Units.smallSpacing

                checked: plasmoid.configuration.animationsEnabled
                text: i18n("Animations")
                tooltip: i18n("Enable/disable all animations")

                onPressed: {
                    plasmoid.configuration.animationsEnabled = !plasmoid.configuration.animationsEnabled;
                }
            }

            ColumnLayout {
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                spacing: 0
                enabled: plasmoid.configuration.animationsEnabled

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        property int duration: plasmoid.configuration.durationTime

                        QQC2.ButtonGroup {
                            id: animationsGroup
                        }

                        PlasmaComponents.Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: i18n("x1")
                            checked: parent.duration === duration
                            Layout.minimumHeight: page.checkableButtonsHeight
                            Layout.maximumHeight: Layout.minimumHeight
                            topPadding: page.checkableButtonsTopPadding
                            bottomPadding: page.checkableButtonsBottomPadding
                            leftPadding: page.checkableButtonsLeftPadding
                            rightPadding: page.checkableButtonsRightPadding
                            checkable: false
                            QQC2.ButtonGroup.group: animationsGroup

                            readonly property int duration: 3

                            onPressedChanged: {
                                if (pressed) {
                                    plasmoid.configuration.durationTime = duration;
                                }
                            }
                        }
                        PlasmaComponents.Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: i18n("x2")
                            checked: parent.duration === duration
                            Layout.minimumHeight: page.checkableButtonsHeight
                            Layout.maximumHeight: Layout.minimumHeight
                            topPadding: page.checkableButtonsTopPadding
                            bottomPadding: page.checkableButtonsBottomPadding
                            leftPadding: page.checkableButtonsLeftPadding
                            rightPadding: page.checkableButtonsRightPadding
                            checkable: false
                            QQC2.ButtonGroup.group: animationsGroup

                            readonly property int duration: 2

                            onPressedChanged: {
                                if (pressed) {
                                    plasmoid.configuration.durationTime = duration;
                                }
                            }
                        }
                        PlasmaComponents.Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: i18n("x3")
                            checked: parent.duration === duration
                            Layout.minimumHeight: page.checkableButtonsHeight
                            Layout.maximumHeight: Layout.minimumHeight
                            topPadding: page.checkableButtonsTopPadding
                            bottomPadding: page.checkableButtonsBottomPadding
                            leftPadding: page.checkableButtonsLeftPadding
                            rightPadding: page.checkableButtonsRightPadding
                            checkable: false
                            QQC2.ButtonGroup.group: animationsGroup

                            readonly property int duration: 1

                            onPressedChanged: {
                                if (pressed) {
                                    plasmoid.configuration.durationTime = duration;
                                }
                            }
                        }
                    }
                }
            }
        }
        //! END: Animations

        //! BEGIN: Active Indicator General Settings
        ColumnLayout{
            spacing: Kirigami.Units.smallSpacing

            LatteComponents.HeaderSwitch {
                id: indicatorsSwitch
                Layout.fillWidth: true
                Layout.minimumHeight: implicitHeight

                checked: latteView.indicator.enabled
                text: i18n("Indicators")
                tooltip: i18n("Enable/disable indicators")

                onPressed: {
                    latteView.indicator.enabled = !latteView.indicator.enabled;
                }
            }

            ColumnLayout {
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                spacing: Kirigami.Units.smallSpacing
                enabled: indicatorsSwitch.checked

                /*   LatteComponents.SubHeader {
                    text: i18n("Style")
                }*/

                Item {
                    Layout.fillWidth: true
                    Layout.minimumHeight: tabBar.height

                    PlasmaComponents.TabBar {
                        id: tabBar
                        width: parent.width

                        property string type: latteView.indicator.type

                        PlasmaComponents.TabButton {
                            id: latteBtn
                            text: i18nc("latte indicator style", "Latte")
                            readonly property string type: "org.kde.latte.default"

                            onCheckedChanged: {
                                if (checked) {
                                    latteView.indicator.type = type;
                                }
                            }
                        }
                        PlasmaComponents.TabButton {
                            id: plasmaBtn
                            text: i18nc("plasma indicator style", "Plasma")
                            readonly property string type: "org.kde.latte.plasma"

                            onCheckedChanged: {
                                if (checked) {
                                    latteView.indicator.type = type;
                                }
                            }
                        }

                        PlasmaComponents.TabButton {
                            id: customBtn

                            onCheckedChanged: {
                                if (checked) {
                                    customIndicator.onButtonIsPressed();
                                }
                            }

                            LatteExtraControls.CustomIndicatorButton {
                                id: customIndicator
                                anchors.fill: parent
                                implicitWidth: latteBtn.implicitWidth
                                implicitHeight: latteBtn.implicitHeight

                                checked: parent.checked
                                comboBoxMinimumPopUpWidth: 1.5 * customIndicator.width

                                onTypeChanged: {
                                    if (tabBar.type === type) {
                                        tabBar.selectTab(type);
                                    }
                                }
                            }
                        }

                        //! Plasma 6 TabBar is a QtQuick Controls 2 Container, the current tab
                        //! is chosen through its index and not through the button itself
                        function selectTabButton(button) {
                            for (var i=0; i<tabBar.count; ++i) {
                                if (tabBar.itemAt(i) === button) {
                                    tabBar.currentIndex = i;
                                    return;
                                }
                            }
                        }

                        function selectTab(type) {
                            if (type === latteBtn.type) {
                                selectTabButton(latteBtn);
                            } else if (type === plasmaBtn.type) {
                                selectTabButton(plasmaBtn);
                            } else if (type === customIndicator.type) {
                                selectTabButton(customBtn);
                            }
                        }

                        Connections {
                            target: indicatorsStackView
                            onCurrentItemChanged: {
                                if (!indicatorsStackView.currentItem || !viewConfig.isReady) {
                                    return;
                                }

                                tabBar.selectTab(indicatorsStackView.currentItem.type);
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: tabBar.bottom
                        anchors.left: tabBar.left
                        anchors.leftMargin: 2
                        width: tabBar.width - 2*2
                        height: 2
                        color: Kirigami.Theme.textColor
                        opacity: 0.25
                    }
                }

                //! BEGIN: Indicator specific sub-options
                QtQuickControls212.StackView {
                    id: indicatorsStackView
                    Layout.fillWidth: true
                    Layout.maximumHeight: Layout.minimumHeight
                    enabled: latteView.indicator.enabled

                    property bool forwardSliding: true

                    readonly property int optionsWidth: dialog.optionsWidth
                    readonly property bool deprecatedOptionsAreHidden: true // @since 0.10.0

                    replaceEnter: Transition {
                        ParallelAnimation {
                            PropertyAnimation {
                                property: "x"
                                from: indicatorsStackView.forwardSliding ? -indicatorsStackView.width : indicatorsStackView.width
                                to: 0
                                duration: 350
                            }

                            PropertyAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 350
                            }
                        }
                    }

                    replaceExit: Transition {
                        ParallelAnimation {
                            PropertyAnimation {
                                property: "x"
                                from: 0
                                to: indicatorsStackView.forwardSliding ? indicatorsStackView.width : -indicatorsStackView.width
                                duration: 350
                            }

                            PropertyAnimation {
                                property: "opacity"
                                from: 1
                                to: 0
                                duration: 350
                            }
                        }
                    }
                } //! END: Indicator specific sub-options
            } //! END: Active Indicator General Settings
        }
    } //! END of Dynamic content


    //! Manager / Handler of loading/showing/hiding indicator config uis
    LatteExtraControls.IndicatorConfigUiManager {
        id: indicatorUiManager
        visible: false
        stackView: indicatorsStackView
    }

}
