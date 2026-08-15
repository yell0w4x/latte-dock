# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-License-Identifier: BSD-3-Clause
#
# Validates the installed appstream metadata, like the test ECM provides, except that a set
# of known and accepted issues does not fail the run. Everything else still does.
#
# appstreamcli reports "cid-rdns-contains-hyphen" for this application, because its component
# id is org.kde.latte-dock.desktop. That id is the one Latte is published under and matches
# the name of its desktop file, so it is kept and the report is accepted here.

set(ACCEPTED_ISSUE_TAGS "cid-rdns-contains-hyphen")

file(GLOB install_done "${INSTALL_FILES}")

if (install_done)
    file(READ "${INSTALL_FILES}" out)
    string(REPLACE "\n" ";" out "${out}")
else()
    message("Not installed yet, skipping")
    return()
endif()

set(metadatafiles)

foreach(file IN LISTS out)
    if(NOT (file MATCHES ".+\\.appdata.xml" OR file MATCHES ".+\\.metainfo.xml"))
        continue()
    endif()

    if(EXISTS ${file})
        list(APPEND metadatafiles ${file})
    else()
        message(WARNING "Could not find ${file}")
    endif()
endforeach()

if(NOT metadatafiles)
    return()
endif()

execute_process(COMMAND ${APPSTREAMCLI} validate ${metadatafiles}
    ERROR_VARIABLE appstreamcliout
    OUTPUT_VARIABLE appstreamcliout
    RESULT_VARIABLE result
)

if(result EQUAL 0)
    message(STATUS ${appstreamcliout})
    return()
endif()

#! validation did not pass, so every reported error and warning is examined and the run only
#! fails when one of them is not in the accepted list
string(REPLACE "\n" ";" reportedlines "${appstreamcliout}")
set(unexpectedissues)

foreach(line IN LISTS reportedlines)
    if(NOT line MATCHES "^[ \t]*[EW]:")
        continue()
    endif()

    set(isaccepted FALSE)

    foreach(tag IN LISTS ACCEPTED_ISSUE_TAGS)
        if(line MATCHES "${tag}")
            set(isaccepted TRUE)
            break()
        endif()
    endforeach()

    if(NOT isaccepted)
        list(APPEND unexpectedissues "${line}")
    endif()
endforeach()

if(unexpectedissues)
    string(REPLACE ";" "\n" unexpectedissues "${unexpectedissues}")
    message(FATAL_ERROR "appstream metadata reported issues that are not accepted:\n${unexpectedissues}\n\nfull report:\n${appstreamcliout}")
endif()

message(STATUS "appstream metadata validated, only accepted issues were reported:\n${appstreamcliout}")
