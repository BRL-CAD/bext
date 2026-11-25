/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#ifndef BEXT_PROCESS_HPP
#define BEXT_PROCESS_HPP

#include <chrono>
#include <filesystem>
#include <functional>
#include <string>
#include <string_view>
#include <vector>

namespace bext {

struct ProcessResult {
  int exit_code;
  std::string standard_output;
  std::string standard_error;
};

using ProcessOutput = std::function<void(std::string_view)>;

ProcessResult run_process(const std::vector<std::string> &arguments,
  const std::filesystem::path &working_directory = {},
  std::chrono::seconds timeout = std::chrono::seconds::zero(),
  const ProcessOutput &output = {}, bool merge_error = false);

}

#endif
