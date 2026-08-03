/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Window 2.15

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.pipewire as PipeWire
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.kirigami 2.20 as Kirigami

// opacity doesn't work in the root item
Item {
    anchors.fill: parent

    readonly property bool hasThumbnail: pipeWireSourceItem.ready

    PipeWire.PipeWireSourceItem {
        id: pipeWireSourceItem

        anchors.fill: parent

        //! The plasma5 version kept the item disabled and faded it in from
        //! pipewiresourceitem.cpp once the stream produced frames. Plasma6 does not touch
        //! "enabled" any longer, it exposes "ready" instead, so the old approach left
        //! every window preview fully transparent.
        nodeId: waylandItem.nodeId

        TaskManager.ScreencastingRequest {
            id: waylandItem
            uuid: !windowsPreviewDlg.visible ? "" : thumbnailSourceItem.winId
        }
    }
}
