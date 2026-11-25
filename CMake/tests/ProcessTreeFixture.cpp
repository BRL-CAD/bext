/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>

#ifdef _WIN32
#  define NOMINMAX
#  include <windows.h>
#else
#  include <unistd.h>
#endif

namespace fs = std::filesystem;

int main(int argc, char **argv)
{
  if (argc == 2 && std::string(argv[1]) == "--child") {
    std::this_thread::sleep_for(std::chrono::seconds(2));
    const char *marker = std::getenv("BEXT_PROCESS_TREE_MARKER");
    if (!marker) return 2;
    std::ofstream(fs::u8path(marker)) << "survived\n";
    std::this_thread::sleep_for(std::chrono::seconds(30));
    return 0;
  }
  if (argc != 3 || std::string(argv[1]) != "--parent") return 2;
#ifdef _WIN32
  if (_putenv_s("BEXT_PROCESS_TREE_MARKER", argv[2])) return 2;
  std::wstring command = L'"' + fs::u8path(argv[0]).wstring() + L"\" --child";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(nullptr, command.data(), nullptr, nullptr, TRUE, 0, nullptr, nullptr,
      &startup, &process)) return 2;
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
#else
  if (setenv("BEXT_PROCESS_TREE_MARKER", argv[2], 1)) return 2;
  const pid_t child = fork();
  if (child < 0) return 2;
  if (!child) {
    execl(argv[0], argv[0], "--child", static_cast<char *>(nullptr));
    _exit(127);
  }
#endif
  std::this_thread::sleep_for(std::chrono::seconds(30));
  return 0;
}
