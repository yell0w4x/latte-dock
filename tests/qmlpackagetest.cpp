/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <gtest/gtest.h>

#include <config-latte.h>

#include "apptypes.h"
#include "declarativeimports/contextmenulayerquickitem.h"
#include "declarativeimports/interfaces.h"
#include "plasma/extended/backgroundtracker.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QString>
#include <QStringList>

//! Compiles every qml file Latte ships through a real QQmlEngine.
//!
//! Most of what a dock is made of lives in qml, and the failures that hurt most are the ones
//! that only appear once the file is loaded at runtime: a handler declared twice, a type that
//! no longer exists, an import that moved. A file that does not compile takes its whole
//! containment down with it, so every one of them is compiled here.
//!
//! Compiling resolves the syntax, the imports and every type a file names. It does not
//! instantiate anything, so the context properties the shipped files expect from the running
//! dock, e.g. "root" or "latteView", are not needed and their absence is not reported.

namespace {

//! The app registers these types itself while it starts, they are not an installed qml
//! module, so the files importing them can only be compiled once the very same registration
//! has been made here as well.
void registerLattePrivateAppTypes()
{
    static bool registered{false};

    if (registered) {
        return;
    }

    registered = true;

    qmlRegisterUncreatableMetaObject(Latte::Settings::staticMetaObject,
                                     "org.kde.latte.private.app",
                                     0, 1,
                                     "Settings",
                                     QStringLiteral("Error: only enums of latte app settings"));

    qmlRegisterType<Latte::BackgroundTracker>("org.kde.latte.private.app", 0, 1, "BackgroundTracker");
    qmlRegisterType<Latte::Interfaces>("org.kde.latte.private.app", 0, 1, "Interfaces");
    qmlRegisterType<Latte::ContextMenuLayerQuickItem>("org.kde.latte.private.app", 0, 1, "ContextMenuLayer");
}


//! The qml modules Latte installs, e.g. org.kde.latte.core. Without them the files that
//! import those modules can not be compiled, so the test says so instead of failing.
bool lattePluginsAreInstalled()
{
    return QFileInfo::exists(QStringLiteral(LATTE_QMLDIR) + QStringLiteral("/org/kde/latte/core/qmldir"));
}

//! The modules a running plasma shell brings with it. Some distributions ship them as files
//! that any engine can resolve, others register them from c++ while the shell runs and then
//! nothing of them exists on disk. Where they can not be resolved, the files importing them
//! are out of reach of this test and are reported as skipped instead of failing it.
const QStringList &shellProvidedModules()
{
    static const QStringList modules {
        QStringLiteral("org.kde.plasma.plasmoid"),
    };

    return modules;
}

//! asks the engine itself whether a module can be resolved, rather than guessing from paths
bool moduleIsResolvable(QQmlEngine *engine, const QString &module)
{
    QQmlComponent probe(engine);
    probe.setData(QStringLiteral("import QtQml\nimport %1\nQtObject{}").arg(module).toUtf8(), QUrl());

    return !probe.isError();
}

bool importsAnyOf(const QString &file, const QStringList &modules)
{
    QFile source(file);

    if (!source.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    const QString contents = QString::fromUtf8(source.readAll());

    for (const QString &module : modules) {
        if (contents.contains(QStringLiteral("import ") + module)) {
            return true;
        }
    }

    return false;
}

//! Files that can not be compiled outside of a running plasma shell.
//!
//! The tasks applet builds on the qml of the plasma task manager, which is published as a
//! module private to that applet and only exists while it runs, so anything importing it is
//! out of reach here. The thumbnail files carrying a plasma version in their name are the
//! older variants, kept for those releases and never loaded on this one.
bool needsARunningShell(const QString &file, const QStringList &unresolvableModules)
{
    const QString name = QFileInfo(file).fileName();

    if (name.startsWith(QStringLiteral("PipeWireThumbnail.5.2"))
            && !name.startsWith(QStringLiteral("PipeWireThumbnail.5.26"))) {
        return true;
    }

    if (!unresolvableModules.isEmpty() && importsAnyOf(file, unresolvableModules)) {
        return true;
    }

    return importsAnyOf(file, QStringList() << QStringLiteral("plasma.applet."));
}

QStringList qmlFilesOf(const QString &directory)
{
    QStringList files;

    if (!QFileInfo::exists(directory)) {
        return files;
    }

    QDirIterator iterator(directory, QStringList() << QStringLiteral("*.qml"), QDir::Files, QDirIterator::Subdirectories);

    while (iterator.hasNext()) {
        files << iterator.next();
    }

    files.sort();
    return files;
}

QString sourceDirectory()
{
    //! the tests are built inside the source tree, so the packages are found relative to it
    return QStringLiteral(LATTE_SOURCE_DIR);
}

} // namespace

class QmlPackageTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        if (!lattePluginsAreInstalled()) {
            GTEST_SKIP() << "the latte qml modules are not installed under " << LATTE_QMLDIR
                         << ", so the shipped qml files can not be compiled";
        }

        registerLattePrivateAppTypes();

        m_engine = new QQmlEngine();
        m_engine->addImportPath(QStringLiteral(LATTE_QMLDIR));

        //! a package looks up its own files through this, e.g. "../code/tools.js"
        m_engine->addImportPath(sourceDirectory() + QStringLiteral("/declarativeimports"));

        for (const QString &module : shellProvidedModules()) {
            if (!moduleIsResolvable(m_engine, module)) {
                m_unresolvableModules << module;
            }
        }
    }

    void TearDown() override
    {
        delete m_engine;
        m_engine = nullptr;
    }

    //! compiles every qml file of a package and reports the ones that did not make it
    void expectPackageCompiles(const QString &packagePath)
    {
        const QStringList files = qmlFilesOf(sourceDirectory() + packagePath);

        ASSERT_FALSE(files.isEmpty()) << "no qml files were found under " << packagePath.toStdString()
                                      << ", the package layout must have changed";

        for (const QString &module : m_unresolvableModules) {
            for (const QString &file : files) {
                if (importsAnyOf(file, QStringList() << module)) {
                    GTEST_SKIP() << packagePath.toStdString() << " builds on " << module.toStdString()
                                 << ", which this system does not carry. It is registered by the"
                                    " plasma shell while it runs on some distributions and shipped"
                                    " as files on others, and only the latter can be compiled here";
                }
            }
        }

        QStringList failures;

        int compiled{0};

        for (const QString &file : files) {
            if (needsARunningShell(file, m_unresolvableModules)) {
                continue;
            }

            ++compiled;
            QQmlComponent component(m_engine, QUrl::fromLocalFile(file));

            if (component.isError()) {
                QStringList messages;

                for (const QQmlError &error : component.errors()) {
                    messages << error.toString();
                }

                failures << messages.join(QStringLiteral("\n"));
            }
        }

        EXPECT_GT(compiled, 0) << "every file of " << packagePath.toStdString()
                               << " was skipped, the exclusions must have grown too wide";

        EXPECT_TRUE(failures.isEmpty()) << "qml files that do not compile:\n"
                                        << failures.join(QStringLiteral("\n")).toStdString();
    }

    QQmlEngine *m_engine{nullptr};

    //! shell modules this environment can not resolve, empty on a system with plasma
    QStringList m_unresolvableModules;
};

TEST_F(QmlPackageTest, TheContainmentPackageCompiles)
{
    //! the containment carries the dock itself, a file of it failing to compile leaves the
    //! user without any dock at all
    expectPackageCompiles(QStringLiteral("/containment/package/contents/ui"));
}

TEST_F(QmlPackageTest, TheTasksPackageCompiles)
{
    expectPackageCompiles(QStringLiteral("/plasmoid/package/contents/ui"));
}

TEST_F(QmlPackageTest, TheShellPackageCompiles)
{
    //! the settings windows and the widget explorer
    expectPackageCompiles(QStringLiteral("/shell/package/contents"));
}

TEST_F(QmlPackageTest, TheSharedComponentsCompile)
{
    expectPackageCompiles(QStringLiteral("/declarativeimports/components"));
}

TEST_F(QmlPackageTest, TheAbilitiesCompile)
{
    expectPackageCompiles(QStringLiteral("/declarativeimports/abilities"));
}

TEST_F(QmlPackageTest, TheShippedIndicatorsCompile)
{
    //! both the indicator drawn on the dock and the page it adds to the settings window
    expectPackageCompiles(QStringLiteral("/indicators"));
}
