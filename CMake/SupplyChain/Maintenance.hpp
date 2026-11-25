/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#ifndef BEXT_SUPPLY_CHAIN_MAINTENANCE_HPP
#define BEXT_SUPPLY_CHAIN_MAINTENANCE_HPP

#include "Process.hpp"
#include "Support.hpp"

#include <array>
#include <chrono>
#include <cwchar>
#include <ctime>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <system_error>
#include <thread>
#include <vector>

#ifdef _WIN32
#  define NOMINMAX
#  include <windows.h>
#else
extern char **environ;
#endif

namespace bext {

#ifdef _WIN32
inline fs::path windows_extended_path(const fs::path &path)
{
  const std::wstring unc_prefix(2, fs::path::preferred_separator);
  const std::wstring extended_prefix = unc_prefix + LR"(?\)";
  const std::wstring extended_unc_prefix = extended_prefix + LR"(UNC\)";
  const std::wstring value = fs::absolute(path).native();
  if (value.rfind(extended_prefix, 0) == 0) return fs::path(value);
  if (value.rfind(unc_prefix, 0) == 0) return fs::path(extended_unc_prefix + value.substr(2));
  return fs::path(extended_prefix + value);
}

inline void report_remaining_tree_entries(const fs::path &path)
{
  constexpr std::size_t entry_limit = 20;
  std::error_code error;
  fs::recursive_directory_iterator entry(path, fs::directory_options::skip_permission_denied, error);
  const fs::recursive_directory_iterator end;
  if (error) {
    std::cout << "  Unable to inspect remaining entries: " << error.message() << std::endl;
    return;
  }
  std::size_t reported = 0;
  while (entry != end && reported < entry_limit) {
    std::cout << "  Remaining: " << entry->path().u8string() << std::endl;
    ++reported;
    entry.increment(error);
    if (error) {
      std::cout << "  Unable to continue inspecting entries: " << error.message() << std::endl;
      return;
    }
  }
  if (entry != end) std::cout << "  Additional remaining entries omitted" << std::endl;
  if (!reported) std::cout << "  No child entries were visible" << std::endl;
}
#endif

inline void remove_tree_with_retries(const fs::path &path)
{
#ifdef _WIN32
  constexpr auto retry_timeout = std::chrono::seconds(30);
  constexpr auto retry_interval = std::chrono::milliseconds(100);
  constexpr auto progress_interval = std::chrono::seconds(10);
  const auto started = std::chrono::steady_clock::now();
  const auto deadline = started + retry_timeout;
  auto next_progress = started + progress_interval;
  const auto transient_error = [](const std::error_code &error) {
    return error == std::errc::permission_denied ||
      error == std::errc::operation_not_permitted ||
      error == std::errc::directory_not_empty ||
      error == std::errc::device_or_resource_busy ||
      error.value() == ERROR_ACCESS_DENIED ||
      error.value() == ERROR_DIR_NOT_EMPTY ||
      error.value() == ERROR_SHARING_VIOLATION ||
      error.value() == ERROR_LOCK_VIOLATION;
  };
#endif
  std::error_code error;
  fs::path removal_path = path;
#ifdef _WIN32
  removal_path = windows_extended_path(path);
#endif
  while (true) {
    error.clear();
    fs::remove_all(removal_path, error);
    if (!error) return;
#ifdef _WIN32
    if (transient_error(error) && std::chrono::steady_clock::now() < deadline) {
      const auto now = std::chrono::steady_clock::now();
      if (now >= next_progress) {
        const auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - started);
        std::cout << "Waiting to discard " << path.u8string() << " after " << elapsed.count()
                  << " seconds: " << error.message() << std::endl;
        report_remaining_tree_entries(path);
        next_progress = now + progress_interval;
      }
      std::this_thread::sleep_for(retry_interval);
      continue;
    }
#endif
    throw fs::filesystem_error("remove_all", path, error);
  }
}

inline std::string utc_now()
{
  const std::time_t now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  std::tm utc{};
#ifdef _WIN32
  gmtime_s(&utc, &now);
#else
  gmtime_r(&now, &utc);
#endif
  std::array<char, 21> value{};
  std::strftime(value.data(), value.size(), "%Y-%m-%dT%H:%M:%SZ", &utc);
  return value.data();
}

inline std::vector<std::string> option_values(int argc, char **argv, const std::string &name)
{
  std::vector<std::string> result;
  for (int index = 1; index + 1 < argc; ++index) {
    if (argv[index] == name) result.push_back(argv[index + 1]);
  }
  return result;
}

inline std::vector<std::string> nonempty_lines(const std::string &value)
{
  std::istringstream input(value);
  std::vector<std::string> result;
  std::string line;
  while (std::getline(input, line)) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    if (!line.empty()) result.push_back(line);
  }
  return result;
}

inline std::string join_strings(const std::vector<std::string> &values, const std::string &separator)
{
  std::string result;
  for (const std::string &value : values) {
    if (!result.empty()) result += separator;
    result += value;
  }
  return result;
}

inline std::vector<std::string> text_lines(const std::string &value)
{
  std::vector<std::string> result;
  std::istringstream input(value);
  std::string line;
  while (std::getline(input, line)) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    result.push_back(line);
  }
  return result;
}

inline std::vector<std::string> tool_command(const fs::path &executable)
{
  if (executable.extension() != ".cmd") return {executable.u8string()};
  const std::array<fs::path, 2> candidates = {
    executable.parent_path().parent_path() / "renovate" / "dist" / "renovate.js",
    executable.parent_path() / "node_modules" / "renovate" / "dist" / "renovate.js"};
  for (const fs::path &entry : candidates) if (fs::is_regular_file(entry)) {
    return {"node", entry.u8string()};
  }
  throw std::runtime_error("cannot find the Renovate entry point beside its npm launcher");
}

inline std::string tool_version(const fs::path &executable)
{
  std::vector<std::string> command = tool_command(executable);
  command.push_back("--version");
  const ProcessResult result = run_process(command, {}, std::chrono::seconds(30));
  if (result.exit_code) throw std::runtime_error("cannot launch " + executable.u8string());
  const std::size_t last = result.standard_output.find_last_not_of(" \t\r\n");
  if (last == std::string::npos) throw std::runtime_error("the tool did not report its version");
  return result.standard_output.substr(0, last + 1);
}

inline void publish_files(const fs::path &directory,
  const std::map<std::string, std::string> &documents, const std::string &completion)
{
  const fs::path staged = directory / ("report-native-" + sha256(utc_now() + completion).substr(0, 16));
  fs::create_directories(staged);
  try {
    for (const auto &document : documents) write_text_atomic(staged / document.first, document.second);
    for (const auto &document : documents) if (document.first != completion) {
      std::error_code error;
      fs::remove(directory / document.first, error);
      fs::rename(staged / document.first, directory / document.first);
    }
    const auto final_document = documents.find(completion);
    if (final_document == documents.end()) throw std::runtime_error("completion document was not staged");
    std::error_code error;
    fs::remove(directory / completion, error);
    fs::rename(staged / completion, directory / completion);
    fs::remove_all(staged);
  } catch (...) {
    std::error_code error;
    fs::remove_all(staged, error);
    throw;
  }
}

inline std::vector<std::string> sanitized_environment_command(const std::string &cmake,
  const std::vector<std::string> &unset, const std::map<std::string, std::string> &set,
  const std::vector<std::string> &command)
{
  std::vector<std::string> result = {cmake, "-E", "env"};
  for (const std::string &name : unset) result.push_back("--unset=" + name);
  for (const auto &entry : set) result.push_back(entry.first + '=' + entry.second);
  result.push_back("--");
  result.insert(result.end(), command.begin(), command.end());
  return result;
}

inline std::vector<std::string> environment_names()
{
  std::vector<std::string> result;
#ifdef _WIN32
  LPWCH block = GetEnvironmentStringsW();
  if (!block) throw std::runtime_error("unable to read the process environment");
  for (const wchar_t *entry = block; *entry; entry += std::wcslen(entry) + 1) {
    if (*entry == L'=') continue;
    const wchar_t *separator = std::wcschr(entry, L'=');
    const int length = WideCharToMultiByte(CP_UTF8, 0, entry, static_cast<int>(separator - entry), nullptr, 0, nullptr, nullptr);
    std::string name(static_cast<std::size_t>(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, entry, static_cast<int>(separator - entry), name.data(), length, nullptr, nullptr);
    result.push_back(name);
  }
  FreeEnvironmentStringsW(block);
#else
  for (char **entry = environ; *entry; ++entry) {
    const std::string value = *entry;
    result.push_back(value.substr(0, value.find('=')));
  }
#endif
  return result;
}

}

#endif
