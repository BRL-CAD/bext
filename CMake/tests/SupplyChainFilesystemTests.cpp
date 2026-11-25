/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "SupplyChainTests.hpp"

#include "../SupplyChain/Maintenance.hpp"

#include <chrono>
#include <thread>

namespace bext::tests {

void run_filesystem_test(const std::string &name, Context &context)
{
  if (name == "process-timeout-tree") {
    const fs::path marker = context.root / "descendant-survived";
    bool timed_out = false;
    try {
      context.run({context.process_tree_fixture, "--parent", marker.u8string()}, {},
        std::chrono::seconds(1));
    } catch (const std::runtime_error &error) {
      timed_out = contains(error.what(), "exceeded its timeout");
    }
    require(timed_out, "process tree fixture did not time out");
    std::this_thread::sleep_for(std::chrono::seconds(2));
    require(!fs::exists(marker), "timed-out descendant survived");
    return;
  }
  if (name != "remove-retry") throw std::runtime_error("unknown filesystem test " + name);
  const fs::path directory = context.root / "remove-retry";
  const fs::path file = directory / "locked.txt";
  write_text(file, "locked");
#ifdef _WIN32
  constexpr std::size_t extended_path_test_length = 300;
  fs::path deep_directory = directory;
  while (deep_directory.native().size() <= extended_path_test_length) {
    deep_directory /= "extended-length-directory-component";
  }
  fs::create_directories(windows_extended_path(deep_directory));
  const HANDLE handle = CreateFileW(file.c_str(), GENERIC_READ,
    FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  require(handle != INVALID_HANDLE_VALUE, "unable to lock removal fixture");
  std::thread unlocker([handle] {
    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    CloseHandle(handle);
  });
  try {
    remove_tree_with_retries(directory);
  } catch (...) {
    unlocker.join();
    throw;
  }
  unlocker.join();
#else
  remove_tree_with_retries(directory);
#endif
  require(!fs::exists(directory), "retried directory removal left content behind");
}

}
