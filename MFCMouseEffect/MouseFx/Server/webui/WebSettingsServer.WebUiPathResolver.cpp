#include "pch.h"
#include "WebSettingsServer.WebUiPathResolver.h"

#include <cstdlib>
#include <filesystem>
#include <string_view>
#include <vector>

#include "Platform/PlatformRuntimeEnvironment.h"

namespace mousefx {
namespace {

std::string ReadEnvValue(const char* name) {
#if defined(_WIN32)
    char* raw = nullptr;
    size_t length = 0;
    if (_dupenv_s(&raw, &length, name) != 0 || raw == nullptr) {
        return {};
    }
    std::string value(raw);
    std::free(raw);
    return value;
#else
    const char* raw = std::getenv(name);
    return raw ? std::string(raw) : std::string();
#endif
}

bool PathExists(const std::filesystem::path& path) {
    std::error_code ec;
    return std::filesystem::exists(path, ec) && !ec;
}

bool IsDirectory(const std::filesystem::path& path) {
    std::error_code ec;
    return std::filesystem::is_directory(path, ec) && !ec;
}

bool HasRequiredAsset(const std::filesystem::path& baseDir, std::string_view fileName) {
    if (baseDir.empty()) {
        return false;
    }
    return PathExists(baseDir / std::filesystem::path(fileName));
}

// Required-asset probe: must stay a subset of the bundle manifest at
// WebUIWorkspace/scripts/webui-bundle-manifest.mjs. The retired
// cursor-decoration bundle is intentionally no longer required; it is not
// produced by any build target and only ever existed as a stale local file.
bool HasPreferredWebUiAssets(const std::filesystem::path& baseDir) {
    return HasRequiredAsset(baseDir, "index.html") &&
        HasRequiredAsset(baseDir, "app.js") &&
        HasRequiredAsset(baseDir, "app-core.js") &&
        HasRequiredAsset(baseDir, "app-actions.js") &&
        HasRequiredAsset(baseDir, "app-gesture-debug.js") &&
        HasRequiredAsset(baseDir, "settings-form-input-indicator.js") &&
        HasRequiredAsset(baseDir, "input-indicator-settings.svelte.js");
}

void AddWebUiDirIfExistsUnique(
    const std::filesystem::path& dir,
    std::vector<std::filesystem::path>* outDirs) {
    if (!outDirs || dir.empty()) {
        return;
    }
    if (!IsDirectory(dir)) {
        return;
    }
    for (const auto& existing : *outDirs) {
        if (existing == dir) {
            return;
        }
    }
    outDirs->push_back(dir);
}

void AddEnvWebUiDir(std::vector<std::filesystem::path>* outDirs) {
    const std::string envDir = ReadEnvValue("MFX_WEBUI_DIR");
    if (envDir.empty()) {
        return;
    }
    AddWebUiDirIfExistsUnique(std::filesystem::path(envDir), outDirs);
}

void AddExecutableWebUiDir(std::vector<std::filesystem::path>* outDirs) {
    const std::wstring exeDir = platform::GetExecutableDirectoryW();
    if (exeDir.empty()) {
        return;
    }
    AddWebUiDirIfExistsUnique(std::filesystem::path(exeDir) / L"webui", outDirs);
}

void AddBundleResourceWebUiDir(std::vector<std::filesystem::path>* outDirs) {
    const std::wstring exeDir = platform::GetExecutableDirectoryW();
    if (exeDir.empty()) {
        return;
    }
    const std::filesystem::path macosDir(exeDir);
    const std::filesystem::path resourcesDir = macosDir.parent_path() / L"Resources";
    AddWebUiDirIfExistsUnique(resourcesDir / L"MFCMouseEffect" / L"WebUI", outDirs);
}

void AddWorkingDirectoryWebUiDirs(std::vector<std::filesystem::path>* outDirs) {
    std::error_code ec;
    const std::filesystem::path cwd = std::filesystem::current_path(ec);
    if (ec || cwd.empty()) {
        return;
    }

    AddWebUiDirIfExistsUnique(cwd / "MFCMouseEffect" / "WebUI", outDirs);
    AddWebUiDirIfExistsUnique(cwd / "WebUI", outDirs);
    AddWebUiDirIfExistsUnique(cwd.parent_path() / "MFCMouseEffect" / "WebUI", outDirs);
}

void AddSourceTreeWebUiDir(std::vector<std::filesystem::path>* outDirs) {
    if (!outDirs) {
        return;
    }
    const std::filesystem::path sourcePath(__FILE__);
    if (!sourcePath.is_absolute()) {
        return;
    }

    std::filesystem::path cursor = sourcePath.parent_path();
    while (!cursor.empty()) {
        const std::filesystem::path candidate = cursor / "WebUI";
        if (IsDirectory(candidate) && HasRequiredAsset(candidate, "index.html")) {
            AddWebUiDirIfExistsUnique(candidate, outDirs);
            return;
        }
        if (!cursor.has_parent_path() || cursor.parent_path() == cursor) {
            break;
        }
        cursor = cursor.parent_path();
    }
}

} // namespace

std::wstring ResolveWebSettingsWebUiBaseDir() {
    std::vector<std::filesystem::path> candidates;
    candidates.reserve(8);
    AddEnvWebUiDir(&candidates);
    AddBundleResourceWebUiDir(&candidates);
    // Prefer source/dev tree assets before executable-side webui bundle so
    // local iteration picks up freshly built WebUIWorkspace output.
    AddSourceTreeWebUiDir(&candidates);
    AddWorkingDirectoryWebUiDirs(&candidates);
    AddExecutableWebUiDir(&candidates);
    if (candidates.empty()) {
        return {};
    }

    for (const auto& candidate : candidates) {
        if (HasPreferredWebUiAssets(candidate)) {
            return candidate.wstring();
        }
    }
    return candidates.front().wstring();
}

} // namespace mousefx
