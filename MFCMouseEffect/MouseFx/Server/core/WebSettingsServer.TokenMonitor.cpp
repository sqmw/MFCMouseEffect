#include "pch.h"
#include "WebSettingsServer.h"

#include <chrono>

#include "MouseFx/Server/http/HttpServer.h"
#include "MouseFx/Utils/TimeUtils.h"

namespace mousefx {

bool WebSettingsServer::IsTokenValid(const std::string& token) const {
    std::lock_guard<std::mutex> lock(tokenMutex_);
    return token == token_;
}

void WebSettingsServer::RotateToken() {
    std::lock_guard<std::mutex> lock(tokenMutex_);
    token_ = MakeToken();
}

void WebSettingsServer::Touch() {
    lastRequestMs_.store(NowMs());
}

void WebSettingsServer::StartMonitor() {
    if (idleTimeoutMs_ <= 0) return;
    if (monitorRunning_.load()) return;
    if (monitorThread_.joinable() && std::this_thread::get_id() != monitorThread_.get_id()) {
        monitorThread_.join();
    }

    monitorRunning_.store(true);
    monitorThread_ = std::thread([this]() {
        while (monitorRunning_.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1000));
            if (!http_ || !http_->IsRunning()) continue;

            const uint64_t last = lastRequestMs_.load();
            if (last == 0) continue;

            const uint64_t now = NowMs();
            if (now > last && (now - last) > static_cast<uint64_t>(idleTimeoutMs_)) {
                http_->Stop();
                monitorRunning_.store(false);
                break;
            }
        }
    });
}

void WebSettingsServer::StopMonitor() {
    monitorRunning_.store(false);
    if (monitorThread_.joinable() && std::this_thread::get_id() != monitorThread_.get_id()) {
        monitorThread_.join();
    }
}

void WebSettingsServer::StopAsync() {
    // Runs on an HTTP handler thread: defer the stop so the handler can
    // finish its response, but keep the worker owned and joinable instead
    // of detaching a lambda that captures `this`.
    std::lock_guard<std::mutex> lock(deferredStopMutex_);
    if (deferredStopPending_.load()) {
        return;
    }
    if (deferredStopThread_.joinable()) {
        // A previous deferred stop already ran to completion.
        deferredStopThread_.join();
    }
    deferredStopPending_.store(true);
    deferredStopThread_ = std::thread([this]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        Stop();
        deferredStopPending_.store(false);
    });
}

void WebSettingsServer::JoinDeferredStop() {
    std::thread pending;
    {
        std::lock_guard<std::mutex> lock(deferredStopMutex_);
        pending = std::move(deferredStopThread_);
    }
    if (!pending.joinable()) {
        return;
    }
    if (std::this_thread::get_id() == pending.get_id()) {
        // Destruction from the deferred thread itself is not a supported
        // path; detach as a last resort instead of self-joining.
        pending.detach();
        return;
    }
    pending.join();
}

} // namespace mousefx
