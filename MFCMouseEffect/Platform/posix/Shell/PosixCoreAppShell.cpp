#include "pch.h"

#include "Platform/posix/Shell/PosixCoreAppShell.h"

#if MFX_PLATFORM_MACOS || MFX_PLATFORM_LINUX

#include "MouseFx/Core/Control/AppController.h"
#include "MouseFx/Core/Shell/WebSettingsLaunchCoordinator.h"

#include <string>
#include <utility>

namespace mousefx::platform {
namespace {

std::string BuildInputCaptureDegradedWarning(const AppController::InputCaptureRuntimeStatus& status) {
    using Reason = AppController::InputCaptureFailureReason;
    switch (status.reason) {
    case Reason::PermissionDenied:
        return "Global input capture is degraded. Grant Accessibility and Input Monitoring permissions to recover.";
    case Reason::Unsupported:
        return "Global input capture is not supported on this platform. Running with available features only.";
    case Reason::StartFailed:
    default:
        return std::string("Global input capture failed to start. Running in degraded mode. Error code: ") +
               std::to_string(status.error) + ".";
    }
}

} // namespace

PosixCoreAppShell::PosixCoreAppShell(ShellPlatformServices services)
    : services_(std::move(services)) {
}

PosixCoreAppShell::~PosixCoreAppShell() = default;

bool PosixCoreAppShell::Initialize(const AppShellStartOptions& options) {
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

    appController_ = std::make_unique<AppController>();
    webSettingsCoordinator_ = std::make_unique<WebSettingsLaunchCoordinator>(appController_.get());
    appController_->SetRuntimeDiagnosticsEnabled(options.enableRuntimeDiagnostics);
    appController_->SetAutomationOpenUrlHandler([this](const std::string& url) {
        return services_.settingsLauncher && services_.settingsLauncher->OpenUrlUtf8(url);
    });
    appController_->SetAutomationLaunchAppHandler([this](const std::string& appPath) {
        return services_.settingsLauncher && services_.settingsLauncher->OpenApplicationPathUtf8(appPath);
    });
    if (!appController_ || !appController_->Start()) {
        if (services_.notifier) {
            services_.notifier->ShowWarning(
                "MFCMouseEffect",
                "Core runtime failed to start. Check permissions and logs.");
        }
        appController_.reset();
        services_.singleInstanceGuard->Release();
        return false;
    }

    if (!backgroundMode_ && services_.trayService) {
        if (!services_.trayService->Start(this, options.showTrayIcon)) {
            appController_->SetInputCaptureStatusCallback(nullptr);
            appController_->Stop();
            appController_.reset();
            services_.singleInstanceGuard->Release();
            return false;
        }
    } else {
        StartStdinExitMonitor();
    }

    if (services_.notifier) {
        auto* notifier = services_.notifier.get();
        appController_->SetInputCaptureStatusCallback(
            [notifier](const AppController::InputCaptureRuntimeStatus& status) {
                if (!notifier || status.active) {
                    return;
                }
                notifier->ShowWarning(
                    "MFCMouseEffect",
                    BuildInputCaptureDegradedWarning(status));
            });
    }

    const AppController::InputCaptureRuntimeStatus inputCaptureStatus = appController_->InputCaptureStatus();
    if (!inputCaptureStatus.active && services_.notifier) {
        services_.notifier->ShowWarning(
            "MFCMouseEffect",
            BuildInputCaptureDegradedWarning(inputCaptureStatus));
    }

    if (!SetupRegressionWebSettingsProbe() && services_.notifier) {
        services_.notifier->ShowWarning(
            "MFCMouseEffect",
            "Core WebSettings probe output failed. Check MFX_CORE_WEB_SETTINGS_PROBE_FILE.");
    }

    initialized_ = true;
    return true;
}

int PosixCoreAppShell::RunMessageLoop() {
    if (!services_.eventLoopService) {
        return -1;
    }
    return services_.eventLoopService->Run();
}

void PosixCoreAppShell::Shutdown() {
    if (!initialized_) {
        return;
    }
    stdinExitMonitor_.Detach();
    if (webSettingsCoordinator_) {
        webSettingsCoordinator_->Stop();
    }
    if (appController_) {
        appController_->SetInputCaptureStatusCallback(nullptr);
        appController_->Stop();
        appController_.reset();
    }
    if (services_.trayService) {
        services_.trayService->Stop();
    }
    if (services_.singleInstanceGuard) {
        services_.singleInstanceGuard->Release();
    }
    initialized_ = false;
}

AppController* PosixCoreAppShell::AppControllerForShell() noexcept {
    return appController_.get();
}

} // namespace mousefx::platform

#endif
