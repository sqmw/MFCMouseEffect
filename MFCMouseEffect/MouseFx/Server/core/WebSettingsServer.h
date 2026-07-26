#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace mousefx {

class AppController;
class HttpServer;
class WebUiAssets;
struct HttpRequest;
struct HttpResponse;

class WebSettingsServer final {
public:
    explicit WebSettingsServer(AppController* controller);
    ~WebSettingsServer();

    WebSettingsServer(const WebSettingsServer&) = delete;
    WebSettingsServer& operator=(const WebSettingsServer&) = delete;

    bool Start();
    void Stop();

    bool IsRunning() const;
    uint16_t Port() const;
    std::string Token() const;
    std::string Url() const;
    void RotateToken();
    int LastStartErrorStage() const;
    int LastStartErrorCode() const;

private:
    void HandleRequest(const HttpRequest& req, HttpResponse& resp);
    bool HandleApiRoute(const HttpRequest& req, const std::string& path, HttpResponse& resp);
    bool HandleStaticAssetRoute(const HttpRequest& req, HttpResponse& resp);

    static std::string MakeToken();
    std::string TokenCopy() const;
    bool IsTokenValid(const std::string& token) const;
    void Touch();
    void StartMonitor();
    void StopMonitor();
    void StopAsync();
    void JoinDeferredStop();

    AppController* controller_ = nullptr;
    std::unique_ptr<HttpServer> http_{};
    std::unique_ptr<WebUiAssets> assets_{};
    mutable std::mutex tokenMutex_{};
    std::string token_{};
    std::atomic<uint64_t> lastRequestMs_{0};
    std::atomic<bool> monitorRunning_{false};
    std::thread monitorThread_{};
    // Deferred stop is an owned, joinable thread instead of a detached
    // lambda holding `this`; the destructor joins it before teardown.
    std::atomic<bool> deferredStopPending_{false};
    std::thread deferredStopThread_{};
    std::mutex deferredStopMutex_{};
    int idleTimeoutMs_ = 5 * 60 * 1000;
};

} // namespace mousefx
