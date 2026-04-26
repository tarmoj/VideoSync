cmake_minimum_required(VERSION 3.16)

project(VideoSync VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Network WebSockets)

qt_standard_project_setup(REQUIRES 6.8)


set(CMAKE_AUTORCC ON) #NB! without this resources are not included

qt_add_executable(appVideoSync
    main.cpp
    syncmanager.h
    syncmanager.cpp
    filehelper.h
    filehelper.cpp
)

if(APPLE AND NOT IOS)
    target_sources(appVideoSync PRIVATE images/VS.png)
    set_source_files_properties(images/VS.png PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
endif()

qt_add_resources(appVideoSync "conf"
    PREFIX "/"
    FILES qtquickcontrols2.conf
)

qt_add_qml_module(appVideoSync
    URI VideoSync
    VERSION 1.0
    QML_FILES
        Main.qml
        RESOURCES resources.qrc
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appVideoSync PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER org.tarmoj.videosync
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

if(APPLE AND NOT IOS)
    set_target_properties(appVideoSync PROPERTIES
        MACOSX_BUNDLE_ICON_FILE VS.png
    )
endif()

target_link_libraries(appVideoSync
    PRIVATE Qt6::Quick Qt6::Multimedia Qt6::Network Qt6::WebSockets
)

if(IOS)
    target_sources(appVideoSync PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )

    # This command handles embedding and code signing of FFmpeg libraries
    qt_add_ios_ffmpeg_libraries(appVideoSync)

    set_target_properties(appVideoSync PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER org.tarmoj.videosync
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon
    )
endif()

if(ANDROID)
    set_property(TARGET appVideoSync PROPERTY QT_ANDROID_PACKAGE_NAME org.tarmoj.videosync)
    set_property(TARGET appVideoSync PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android)
endif()

include(GNUInstallDirs)
install(TARGETS appVideoSync
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
