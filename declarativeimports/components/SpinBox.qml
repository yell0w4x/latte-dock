/*
    SPDX-FileCopyrightText: 2019 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

//! Plasma 6 dropped QtQuick Controls 1 along with its styling api, meaning that the
//! hand drawn svg increment/decrement controls are gone. The Plasma Components 3
//! spinbox already draws itself through the plasma theme.
PlasmaComponents.SpinBox {
    implicitWidth: Kirigami.Units.gridUnit * 7
}
