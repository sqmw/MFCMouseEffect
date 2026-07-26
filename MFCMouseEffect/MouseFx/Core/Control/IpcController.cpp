#include "pch.h"
#include "IpcController.h"
#include <iostream>
#include <string>

namespace mousefx
{
	IpcController::IpcController() = default;

	IpcController::~IpcController()
	{
		Stop();
	}

	void IpcController::Start(CommandCallback callback, ClosedCallback onClosed)
	{
		if (state_ && state_->running.load()) return;
		Stop();

		auto state = std::make_shared<ListenerState>();
		{
			std::lock_guard<std::mutex> lock(state->callbackMutex);
			state->callback = std::move(callback);
			state->closedCallback = std::move(onClosed);
		}
		state->running.store(true);
		state_ = state;
		worker_ = std::thread(&IpcController::ListenerLoop, std::move(state));
	}

	void IpcController::Stop()
	{
		if (state_)
		{
			state_->running.store(false);
			// Clearing under the lock serializes with an in-flight callback:
			// once Stop() returns, no callback is running or can run again.
			// Callbacks must therefore never call Stop() synchronously; the
			// shell exit path posts to the event loop instead.
			std::lock_guard<std::mutex> lock(state_->callbackMutex);
			state_->callback = nullptr;
			state_->closedCallback = nullptr;
		}
		if (worker_.joinable())
		{
			// std::getline on stdin cannot be interrupted portably, so the
			// blocked reader cannot be joined here. Detaching is safe now:
			// the thread only owns ListenerState via shared_ptr and its
			// callbacks are already cleared above.
			worker_.detach();
		}
		state_.reset();
	}

	void IpcController::ListenerLoop(std::shared_ptr<ListenerState> state)
	{
		std::string line;
		while (state->running.load() && std::getline(std::cin, line))
		{
			if (line.empty()) continue;

			std::lock_guard<std::mutex> lock(state->callbackMutex);
			if (!state->running.load()) break;
			if (state->callback)
			{
				state->callback(line);
			}
		}

		// If cin closes (EOF), we also stop.
		state->running.store(false);
		std::lock_guard<std::mutex> lock(state->callbackMutex);
		if (state->closedCallback)
		{
			state->closedCallback();
		}
	}
}
