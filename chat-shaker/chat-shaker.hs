module Main where

import Control.Applicative
import Control.Arrow

import Development.Shake
import Development.Shake.Command
import Development.Shake.FilePath
import Development.Shake.Util
import Development.Shake.Language.C.PkgConfig
import Development.Shake.Language.C.ToolChain
import Development.Shake.Language.C.Host
import Development.Shake.Language.C

import Debug.Trace
import Data.Maybe

composeBAMutators :: [Action (BuildFlags -> BuildFlags)] -> Action (BuildFlags -> BuildFlags)
composeBAMutators = fmap (foldl (>>>) id) . sequence

main :: IO ()
main = shakeArgs shakeOptions{
        shakeFiles="_build",
        shakeReport = [ "shakeReport" ],
        shakeProgress = progressSimple
    } $ do
    let
        (_, toolchain) = Development.Shake.Language.C.Host.defaultToolChain
        qtCore = pkgConfig defaultOptions "Qt5Core"
        qtWidgets = pkgConfig defaultOptions "Qt5Widgets"
        qtNetwork = pkgConfig defaultOptions "Qt5Network"
        qtScript = pkgConfig defaultOptions "Qt5Script"
        gst = pkgConfig defaultOptions "gstreamer-1.0"
        toxcore = pkgConfig defaultOptions "libtoxcore"
        cxx14 = return $ append compilerFlags [(Nothing, [ "-std=c++14" ])]
        includeDirs = return $ append userIncludes ["_build"]
        glib = pkgConfig defaultOptions "glib-2.0"
        glibmm = pkgConfig defaultOptions "glibmm-2.4"
        glibmmDir = do
            storePath <- getEnv "glibmm"
            return $ fromMaybe "/usr/include" storePath
        glibmmdev = pkgConfig defaultOptions "glibmm-2.4"
        glibmmdevDir = do
            storePath <- getEnv "glibmmdev"
            return $ fromMaybe "/usr/lib" storePath
        loadPkgConfig = \pkgname -> pkgConfig defaultOptions pkgname
        customInclude = \envvar postfix -> do
            storePath <- getEnv envvar
            let dir = fromMaybe "ERR" storePath
            return $ append systemIncludes [ dir </> postfix ]
        extraIncludeDirs = do
            dir2 <- glibmmDir
            composeBAMutators [
                    return $ append systemIncludes [ dir2 </> "lib/glibmm-2.4/include"]
                    , return $ append defines [("QT_NO_DEBUG",Nothing)]
                    ,customInclude "libsigcxx" "include/sigc++-2.0"
                    ,customInclude "libsigcxx" "lib/sigc++-2.0/include"
                    ,customInclude "glibmmdev" "include/giomm-2.4"
                    ,customInclude "glibmmdev" "include/glibmm-2.4"
                    ,customInclude "glibmm" "lib/giomm-2.4/include"
                    ,customInclude "gstreamermmdev" "include/gstreamermm-1.0"
                    ,customInclude "gstreamermm" "lib/gstreamermm-1.0/include"
                ]
        qObject name = [ "src" </> name <.> "cpp", "_build/moc_" ++ name <.> "cpp" ]
        client_cs = do-- dirFiles <- getDirectoryFiles "" ["src//*.cpp"]
                let
                    cs = [
                            "src/client.cpp", "src/db.cpp" ,"src/stats.cpp"
                            ,"src/core_db.cpp", "src/options.cpp"
                            ,"_build/network.pb.cc"
                        ] ++ qObject "audiocall" ++ qObject "core"
                            ++ qObject "friend" ++ qObject "utils"
                            ++ qObject "channel" ++ qObject "kisscache"
                            ++ qObject "kiss" ++ qObject "toxsink"
                            ++ qObject "channelmodel" ++ qObject "mainwindow"
                            ++ qObject "chatwidget" ++ qObject "infowidget"
                            ++ qObject "callcontrol"
                need $ [
                    "_build/network.pb.h",
                    "_build/ui_mainwindow.h", "_build/ui_infowidget.h"
                    ,"_build/ui_chatwidget.h"
                    ] ++ cs
                return $ cs
        --generateUiFile = \name -> do
            --let
                --src = "src" </> name <.> "ui"
                --out = "_build" </> "ui_" ++ name <.> "h"
            --need [ src ]
            --unit $ cmd "uic -o" out src
            --return $ action out

    "_build//ui_*.h" %> \out -> do
        let
            name = drop 3 (dropDirectory1 out) -<.> "ui"
            src = "src" </> name
        need [ src ]
        cmd "uic -o" out src

    phony "clean" $ do
        putNormal "Cleaning files in _build"
        removeFilesAfter "_build" ["//*"]

    phony "install" $ do
        maybeDest <- getEnv "out"
        let dest = fromMaybe "/ERR" maybeDest
        copyFile' ("_build/arcane-chat" <.> exe) (dest </> "bin/arcane-chat" <.> exe)
        copyFile' "shakeReport" $ dest </> "shake/report.html"

    ["_build/network.pb.h", "_build/network.pb.cc"] |%> \out -> do
        need ["network.proto"]
        cmd "protoc --cpp_out=_build network.proto"

    "_build//*.moc" %> \out -> do
        let
            name = dropDirectory1 $ out -<.> "cpp"
            src = "src" </> name
        need [ src ]
        cmd "moc " src "-o" out

    "_build//moc_*.cpp" %> \out -> do
        let
            name = drop 4 $ dropDirectory1 $ out -<.> "hpp"
            src = "src" </> name
        need [ src ]
        cmd "moc " src "-o" out

    --"_build/arcane-chat" <.> exe %> \out -> do
    arcaneChat <- executable toolchain ("_build/arcane-chat" <.> exe)
        (composeBAMutators [
            fmap (>>> traceShowId) glibmm
            ,qtCore, qtWidgets, qtNetwork, qtScript
            ,glib
            ,gst
            ,toxcore
            ,includeDirs, cxx14
            ,loadPkgConfig "gstreamermm-1.0"
            ,loadPkgConfig "gstreamer-audio-1.0"
            ,loadPkgConfig "sqlite3"
            ,loadPkgConfig "protobuf"
            ,loadPkgConfig "Qt5GLib-2.0"
            ,loadPkgConfig "Qt5GStreamer-1.0"
            ,loadPkgConfig "Qt5GStreamerUtils-1.0"
            ,loadPkgConfig "libsodium"
            ,extraIncludeDirs
            ,return $ append defines [("ARCANE_CHAT_VERSION",Just "0")]
        ])
        client_cs
    want [ arcaneChat ]
