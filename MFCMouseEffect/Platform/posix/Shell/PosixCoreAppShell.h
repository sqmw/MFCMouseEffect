#pragma once

#include "MouseFx/Core/Shell/IAppShellHost.h"
#include "MouseFx/Core/Shell/ShellPlatformServices.h"
#include "Platform/IPlatformAppShell.h"
#include "Platform/PlatformTarget.h"
#include "Platform/posix/Shell/PosixStdinExitMonitor.h"

#include <functional>
#include <memory>
#include <string>

namespace mousefx {
class AppController;
class WebSettingsLaunchCoordinator;
}

namespace mousefx::platform {

#if MFX_PLATFORM_MACOS || MFX_PLATFORM_LINUX
class PosixCoreAppShell final : public IPlatformAppShell, private IAppShellHost {
public:
    explicit PosixCoreAppShell(ShellPlatformServices services);
    ~PosixCoreAppShell() override;

    bool Initialize(const AppShellStartOptions& options) override;
    int RunMessageLoop() override;
    void Shutdown() override;

private:
    AppController* AppControllerForShell() noexcept override;
    bool PreferZhLabelsFromShell(bool fallbackPreferZh) override;
    void GetThemeMenuSnapshotFromShell(
        bool preferZhLabels,
        std::vector<ShellThemeMenuItem>* outItems,
        std::string* outSelectedTheme) override;
    void GetEffectMenuSnapshotFromShell(
        bool preferZhLabels,
        std::vector<ShellEffectMenuSection>* outSections) override;
    void OpenProjectRepositoryFromShell() override;
    void OpenSettingsFromShell() override;
    void ReloadConfigFromShell() override;
    void RequestExitFromShell() override;
    void SetThemeFromShell(const std::string& theme) override;
    void SetEffectFromShell(const std::string& category, const std::string& effectType) override;

    bool PostShellTask(std::function<void()> task);
    void RequestExitOnLoop();
    void ShowWebSettings();
    bool SetupRegressionWebSettingsProbe();
    void StartStdinExitMonitor();

private:
    ShellPlatformServices services_{};
    std::unique_ptr<AppController> appController_{};
    std::unique_ptr<WebSettingsLaunchCoordinator> webSettingsCoordinator_{};
    bool initialized_ = false;
    bool backgroundMode_ = false;
    // Declared after services_ so it is destroyed first: its destructor
    // detaches the reader thread before the event loop service goes away.
    PosixStdinExitMonitor stdinExitMonitor_{};
};
#endif

} // namespace mousefx::platform
