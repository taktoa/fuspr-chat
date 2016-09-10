#include <iostream>
#include <boost/algorithm/hex.hpp>
#include <vector>
#include <tox/tox.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <signal.h>

#include <giomm/init.h>
#include <gstreamermm.h>
#include <glibmm.h>

#include <QApplication>
#include <QDebug>
#include <QCommandLineParser>
#include <Qt5GStreamer/QGst/Init>

#include "options.hpp"
#include "core.hpp"
#include "utils.hpp"
#include "friend.hpp"
#include "mainwindow.hpp"
#include "version.hpp"

void handler(int signum) {
    std::cout << "Quitting...\n";
    QCoreApplication::quit();
}

int main(int argc, char** argv) {
    QGst::init(&argc, &argv);
    Gio::init();

    QApplication app(argc, argv);

    using qca = QCoreApplication;

    QCoreApplication::setApplicationName("arcane-chat-client");
    QCoreApplication::setApplicationVersion(ARCANE_CHAT_VERSION);

    QCommandLineParser parser;

    parser.setApplicationDescription("The client for Arcane Chat.");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption sendFriendRequestOption = {
        QStringList() << "r" << "request",
        qca::translate("main", "Send a friend request to <toxid>."),
        qca::translate("main", "toxid")
    };
    parser.addOption(sendFriendRequestOption);

    QCommandLineOption tracerOption = {
        QStringList() << "t" << "tracer",
        qca::translate("main", "Verbosely output a trace of some Qt signals.")
    };
    parser.addOption(tracerOption);

    QCommandLineOption headlessOption = {
        QStringList() << "h" << "headless",
        qca::translate("main", "Run the client headlessly."),
    };
    parser.addOption(headlessOption);

    parser.process(app);

    // EXAMPLES OF PARSER USE:
    //     https://gist.github.com/taktoa/d8b33c1aa81d97a15fb0dff43ba22b98

    int ret = 1;

    {
        chat::Core core { "/tmp/client_savedata" };

        if(parser.isSet(sendFriendRequestOption)) {
            QByteArray hex;
            hex.append(parser.value(sendFriendRequestOption));
            core.friend_add(QByteArray::fromHex(hex), "placeholder");
        }

        if(parser.isSet(tracerOption)) {
            new Tracer(&core);
        }

        if(!parser.isSet(headlessOption)) {
            MainWindow* mw = new MainWindow(&core);
            mw->show();
        }

        struct sigaction interrupt;
        memset(&interrupt, 0, sizeof(interrupt));
        interrupt.sa_handler = &handler;
        sigaction(SIGINT, &interrupt, nullptr);
        sigaction(SIGTERM, &interrupt, nullptr);

        ret = app.exec();
    }

    std::cout << "clean shutdown\n";
    return ret;
}
