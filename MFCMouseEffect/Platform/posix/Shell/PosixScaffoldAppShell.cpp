#include "pch.h"

#include "Platform/posix/Shell/PosixScaffoldAppShell.h"

#if MFX_PLATFORM_MACOS || MFX_PLATFORM_LINUX

#include <utility>

namespace mousefx::platform {

PosixScaffoldAppShell::PosixScaffoldAppShell(ShellPlatformServices services)
    : services_(std::move(services)) {
}

bool PosixScaffoldAppShell::Initialize(const AppShellStartOptions& options) {
    if (initialized_) {
        return true;
    }
    if (!services_.settingsLauncher || !services_.singleInstanceGuard || !services_.eventLoopService) {
        return false;
    }
    if (!services_.singleInstanceGuard->Acquire(options.singleInstanceKey)) {
        return false;
    }

    if (services_.dpiAwarenessService) {
        services_.dpiAwarenessService->EnableForScreenCoords();
    }

    backgroundMode_ = !options.showTrayIcon || !services_.trayService;
    scaffoldRuntime_.SetRuntimeMode(static_cast<bool>(services_.trayService), backgroundMode_);
    scaffoldRuntime_.Start([this](const std::string& title, const std::string& message) {
        if (services_.notifier) {
            services_.notifier->ShowWarning(title, message);
        }
    });

    if (!backgroundMode_ && services_.trayService) {
        if (!services_.trayService->Start(this, options.showTrayIcon)) {
            scaffoldRuntime_.Stop();
            services_.singleInstanceGuard->Release();
            return false;
        }
    } else {
        StartStdinExitMonitor();
    }

    initialized_ = true;
    return true;
}

int PosixScaffoldAppShell::RunMessageLoop() {
    if (!services_.eventLoopService) {
        return -1;
    }
    return services_.eventLoopService->Run();
}

void PosixScaffoldAppShell::Shutdown() {
    if (!initialized_) {
        return;
    }
    stdinExitMonitor_.Detach();
    if (services_.trayService) {
        services_.trayService->Stop();
    }
    if (services_.singleInstanceGuard) {
        services_.singleInstanceGuard->Release();
    }
    scaffoldRuntime_.Stop();
    initialized_ = false;
}

AppController* PosixScaffoldAppShell::AppControllerForShell() noexcept {
    return nullptr;
}

} // namespace mousefx::platform

#endif
