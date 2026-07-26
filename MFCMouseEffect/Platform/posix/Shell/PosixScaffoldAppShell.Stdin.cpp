#include "pch.h"

#include "Platform/posix/Shell/PosixScaffoldAppShell.h"

#if MFX_PLATFORM_MACOS || MFX_PLATFORM_LINUX

namespace mousefx::platform {

void PosixScaffoldAppShell::StartStdinExitMonitor() {
    auto* eventLoop = services_.eventLoopService.get();
    stdinExitMonitor_.Start([eventLoop]() {
        if (eventLoop) {
            eventLoop->RequestExit();
        }
    });
}

} // namespace mousefx::platform

#endif
