/*
    SPDX-FileCopyrightText: 2019 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "windowstracker.h"

// local
#include "currentscreentracker.h"
#include "allscreenstracker.h"
#include "../positioner.h"
#include "../view.h"
#include "../../lattecorona.h"
#include "../../wm/tracker/windowstracker.h"


namespace Latte {
namespace ViewPart {

WindowsTracker::WindowsTracker(Latte::View *parent)
    : QObject(parent),
      m_latteView(parent)
{
    qDebug() << "WindowsTracker creating...";

    auto corona = qobject_cast<Latte::Corona *>(m_latteView->corona());
    m_wm = corona->wm();

    m_allScreensTracker = new TrackerPart::AllScreensTracker(this);
    m_currentScreenTracker = new TrackerPart::CurrentScreenTracker(this);

    connect(m_wm->windowsTracker(), &WindowSystem::Tracker::Windows::enabledChanged, this, [&](const Latte::View *view) {
        if (m_latteView == view) {
            emit enabledChanged();
        }
    });

    m_wm->windowsTracker()->addView(m_latteView);
    emit allScreensChanged();
    emit currentScreenChanged();
}

WindowsTracker::~WindowsTracker()
{
    qDebug() << "WindowsTracker removing...";

    //! The view must be unregistered by the same object that registered it and at the
    //! same moment its own lifetime ends. Leaving this to CurrentScreenTracker's
    //! destructor made it run through deleteLater(), so a view that was recreated stayed
    //! in the tracker under its old pointer while the live one was never tracked and
    //! every window hint queried for it silently returned false.
    m_wm->windowsTracker()->removeView(m_latteView);

    if (m_allScreensTracker) {
        m_allScreensTracker->deleteLater();
    }

    if (m_currentScreenTracker) {
        m_currentScreenTracker->deleteLater();
    }
}

Latte::View *WindowsTracker::view() const
{
    return m_latteView;
}

WindowSystem::AbstractWindowInterface *WindowsTracker::wm() const
{
    return m_wm;
}

bool WindowsTracker::enabled() const
{
    return m_wm->windowsTracker()->enabled(m_latteView);
}

void WindowsTracker::setEnabled(bool active)
{
    m_wm->windowsTracker()->setEnabled(m_latteView, active);
}


TrackerPart::AllScreensTracker *WindowsTracker::allScreens() const
{
    return m_allScreensTracker;
}

TrackerPart::CurrentScreenTracker *WindowsTracker::currentScreen() const
{
    return m_currentScreenTracker;
}

//! Environment Functions
void WindowsTracker::switchToNextActivity()
{
    m_wm->switchToNextActivity();
}

void WindowsTracker::switchToPreviousActivity()
{
    m_wm->switchToPreviousActivity();
}

void WindowsTracker::switchToNextVirtualDesktop()
{
    m_wm->switchToNextVirtualDesktop();
}

void WindowsTracker::switchToPreviousVirtualDesktop()
{
    m_wm->switchToPreviousVirtualDesktop();
}

}
}
