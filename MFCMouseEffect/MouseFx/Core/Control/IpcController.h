#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace mousefx
{
	class IpcController
	{
	public:
		using CommandCallback = std::function<void(const std::string&)>;
		using ClosedCallback = std::function<void()>;

		IpcController();
		~IpcController();

		// Start the listening thread.
		void Start(CommandCallback callback, ClosedCallback onClosed = {});

		// Stop dispatching and release thread ownership.
		// The reader thread may keep blocking on stdin, but after Stop()
		// returns it can only touch its own shared state: no callback can
		// run and no controller/shell memory is reachable from it.
		void Stop();

	private:
		// Shared between the controller and the reader thread. The thread
		// captures this by shared_ptr, never a raw `this`, so a lingering
		// blocked getline cannot dereference freed controller state.
		struct ListenerState
		{
			std::atomic<bool> running{ false };
			std::mutex callbackMutex;
			CommandCallback callback;
			ClosedCallback closedCallback;
		};

		static void ListenerLoop(std::shared_ptr<ListenerState> state);

		std::shared_ptr<ListenerState> state_{};
		std::thread worker_;
	};
}
