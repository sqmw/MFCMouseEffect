#include "pch.h"

#include "Platform/posix/Shell/PosixStdinExitMonitor.h"

#include "Platform/PlatformTarget.h"

#if MFX_PLATFORM_MACOS || MFX_PLATFORM_LINUX

#include "Platform/posix/Shell/PosixShellExitCommand.h"

#include <iostream>
#include <string>
#include <thread>

namespace mousefx::platform {

struct PosixStdinExitMonitor::State {
    std::mutex mutex;
    ExitRequestHandler onExitRequest;
};

PosixStdinExitMonitor::~PosixStdinExitMonitor() {
    Detach();
}

void PosixStdinExitMonitor::Start(ExitRequestHandler onExitRequest) {
    if (state_) {
        return;
    }

    auto state = std::make_shared<State>();
    {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->onExitRequest = std::move(onExitRequest);
    }
    state_ = state;

    // The thread captures only the shared state. Invoking the handler under
    // the lock serializes with Detach(): once Detach() returns, no handler
    // is running or can run again.
    std::thread([state]() {
        const auto requestExit = [&state]() {
            std::lock_guard<std::mutex> lock(state->mutex);
            if (state->onExitRequest) {
                state->onExitRequest();
            }
        };

        std::string line;
        while (std::getline(std::cin, line)) {
            if (IsPosixShellExitCommandLine(line)) {
                requestExit();
                return;
            }
        }
        requestExit();
    }).detach();
}

void PosixStdinExitMonitor::Detach() {
    if (!state_) {
        return;
    }
    std::lock_guard<std::mutex> lock(state_->mutex);
    state_->onExitRequest = nullptr;
}

} // namespace mousefx::platform

#endif
