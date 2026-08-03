add_definitions(-DTRANSLATION_DOMAIN=\"plasma_containmentactions_lattecontextmenu\")

set(contextmenu_SRCS
    generictools.cpp
    layoutmenuitemwidget.cpp
    menu.cpp
)

add_library(plasma_containmentactions_lattecontextmenu MODULE ${contextmenu_SRCS})

#! KF6 KPluginMetaData::pluginId() is the plugin FILE NAME, the "Id" entry of the
#! embedded json metadata is ignored. The library must be named after the plugin id
#! in order for Plasma::PluginLoader to find it through "org.kde.latte.contextmenu".
set_target_properties(plasma_containmentactions_lattecontextmenu PROPERTIES
                        PREFIX ""
                        OUTPUT_NAME "org.kde.latte.contextmenu"
                      )

target_link_libraries(plasma_containmentactions_lattecontextmenu
                        Qt::DBus
                        Qt::Widgets
                        KF6::I18n
                        KF6::XmlGui
                        Plasma::Plasma
                      )

install(TARGETS plasma_containmentactions_lattecontextmenu DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/containmentactions)
