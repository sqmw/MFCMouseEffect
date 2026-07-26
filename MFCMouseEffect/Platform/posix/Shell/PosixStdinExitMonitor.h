#pragma once

#include <functional>
#include <memory>
#include <mutex>

namespace mousefx::platform {

// Lifecycle seam between a blocking stdin reader thread and its consumer.
// std::getline on stdin cannot be interrupted portably, so the reader
// thread can outlive the consumer; it therefore only ever touches shared
// state owned via shared_ptr, never raw consumer pointers.
class PosixStdinExitMonitor {
public:
    using ExitRequestHandler = std::function<void()>;

    PosixStdinExitMonitor() = default;
    ~PosixStdinExitMonitor();

    PosixStdinExitMonitor(const PosixStdinExitMonitor&) = delete;
    PosixStdinExitMonitor& operator=(const PosixStdinExitMonitor&) = delete;

    // Starts the reader thread once. `onExitRequest` runs on the reader
    // thread when an exit command line or EOF is seen; it must be safe to
    // call off the main thread and must not call Detach() synchronously.
    void Start(ExitRequestHandler onExitRequest);

    // Clears the handler. After this returns the reader thread can no
    // longer invoke consumer code; it keeps only its own shared state.
    void Detach();

private:
    struct State;
    std::shared_ptr<State> state_{};
};

} // namespace mousefx::platform
