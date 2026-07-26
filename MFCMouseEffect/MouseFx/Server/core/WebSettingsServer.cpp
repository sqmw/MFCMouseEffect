#include "pch.h"
#include "WebSettingsServer.h"

#include <random>
#include <sstream>

#include "MouseFx/Server/http/HttpServer.h"
#include "MouseFx/Server/webui/WebSettingsServer.WebUiPathResolver.h"
#include "MouseFx/Server/webui/WebUiAssets.h"

namespace mousefx {

WebSettingsServer::WebSettingsServer(AppController* controller) : controller_(controller) {
    RotateToken();
    http_ = std::make_unique<HttpServer>();
    assets_ = std::make_unique<WebUiAssets>(ResolveWebSettingsWebUiBaseDir());
}

WebSettingsServer::~WebSettingsServer() {
    // Join the deferred stop worker first so no thread can reach `this`
    // while members are being destroyed.
    JoinDeferredStop();
    Stop();
}

bool WebSettingsServer::Start() {
    if (!http_) return false;
    if (http_->IsRunning()) return true;

    const bool started = http_->StartLoopback([this](const HttpRequest& req, HttpResponse& resp) {
        HandleRequest(req, resp);
    });
    if (started) {
        Touch();
        StartMonitor();
    }
    return started;
}

void WebSettingsServer::Stop() {
    if (http_) http_->Stop();
    StopMonitor();
}

bool WebSettingsServer::IsRunning() const {
    return http_ && http_->IsRunning();
}

uint16_t WebSettingsServer::Port() const {
    return http_ ? http_->Port() : 0;
}

std::string WebSettingsServer::Url() const {
    std::ostringstream ss;
    ss << "http://127.0.0.1:" << (int)Port() << "/?token=" << TokenCopy();
    return ss.str();
}

std::string WebSettingsServer::MakeToken() {
    std::random_device rd;
    std::mt19937 rng(rd());
    std::uniform_int_distribution<int> dist(0, 15);
    std::string s;
    s.reserve(32);
    for (int i = 0; i < 32; ++i) {
        int v = dist(rng);
        s.push_back(v < 10 ? (char)('0' + v) : (char)('a' + (v - 10)));
    }
    return s;
}

std::string WebSettingsServer::Token() const {
    return TokenCopy();
}

std::string WebSettingsServer::TokenCopy() const {
    std::lock_guard<std::mutex> lock(tokenMutex_);
    return token_;
}

int WebSettingsServer::LastStartErrorStage() const {
    return http_ ? http_->LastStartErrorStage() : 0;
}

int WebSettingsServer::LastStartErrorCode() const {
    return http_ ? http_->LastStartErrorCode() : 0;
}

} // namespace mousefx
