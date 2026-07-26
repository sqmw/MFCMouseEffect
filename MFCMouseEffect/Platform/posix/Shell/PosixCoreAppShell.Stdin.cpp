#include "pch.h"

#include "Platform/posix/Shell/PosixCoreAppShell.h"

#if MFX_PLATFORM_MACOS || MFX_PLATFORM_LINUX

namespace mousefx::platform {

void PosixCoreAppShell::StartStdinExitMonitor() {
    auto* eventLoop = services_.eventLoopService.get();
    stdinExitMonitor_.Start([eventLoop]() {
        if (eventLoop) {
            eventLoop->RequestExit();
        }
    });
}

} // namespace mousefx::platform

#endif
