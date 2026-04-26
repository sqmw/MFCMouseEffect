#include "pch.h"

#include "WasmExecutionBudgetGuard.h"

#include <sstream>
#include <atomic>

namespace mousefx::wasm {

// 连续超时计数器，用于检测频繁超时的插件
static std::atomic<uint32_t> g_consecutiveTimeoutCount = 0;
// 连续超时阈值，超过此值将暂时禁用插件
static constexpr uint32_t kConsecutiveTimeoutThreshold = 3;
// 临时禁用计数，用于控制禁用时间
static std::atomic<uint32_t> g_temporaryDisableCount = 0;
// 临时禁用阈值，达到此值后恢复插件
static constexpr uint32_t kTemporaryDisableThreshold = 10;

BudgetCheckResult WasmExecutionBudgetGuard::Evaluate(const BudgetCheckInput& input) {
    BudgetCheckResult result{};
    result.outputTruncated = input.returnedBytes > input.outputBudgetBytes;
    result.commandTruncated =
        input.commandLimitTruncated || (input.parsedCommandCount > input.commandBudgetCount);

    // 检查是否处于临时禁用状态
    if (g_temporaryDisableCount > 0) {
        g_temporaryDisableCount--;
        result.accepted = false;
        result.reason = "plugin temporarily disabled due to consecutive timeouts";
        return result;
    }

    if (input.maxExecutionMs > 0.0 && input.executionMs > input.maxExecutionMs) {
        // 增加连续超时计数
        uint32_t currentCount = ++g_consecutiveTimeoutCount;
        
        // 检查是否达到连续超时阈值
        if (currentCount >= kConsecutiveTimeoutThreshold) {
            g_temporaryDisableCount = kTemporaryDisableThreshold;
            g_consecutiveTimeoutCount = 0;
            result.accepted = false;
            std::ostringstream ss;
            ss << "execution time exceeded budget, plugin temporarily disabled: actual=" << input.executionMs
               << "ms budget=" << input.maxExecutionMs << "ms";
            result.reason = ss.str();
            return result;
        }
        
        result.accepted = false;
        std::ostringstream ss;
        ss << "execution time exceeded budget: actual=" << input.executionMs
           << "ms budget=" << input.maxExecutionMs << "ms";
        result.reason = ss.str();
        return result;
    }

    // 执行时间正常，重置连续超时计数
    g_consecutiveTimeoutCount = 0;

    if (result.outputTruncated || result.commandTruncated) {
        std::ostringstream ss;
        ss << "budget truncation: output_truncated=" << (result.outputTruncated ? "true" : "false")
           << " command_truncated=" << (result.commandTruncated ? "true" : "false");
        result.reason = ss.str();
    }
    return result;
}

} // namespace mousefx::wasm

