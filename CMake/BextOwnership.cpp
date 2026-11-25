#include <algorithm>
#include <atomic>
#include <fstream>
#include <iostream>
#include <mutex>
#include <regex>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_set>
#include <vector>

namespace {

constexpr unsigned int maximum_worker_count = 16;

struct Rule {
  std::string component;
  std::regex pattern;
};

std::string require_argument(int argc, char **argv, const std::string &name)
{
  for (int index = 1; index + 1 < argc; ++index) {
    if (argv[index] == name) {
      return argv[index + 1];
    }
  }
  throw std::runtime_error("missing required argument " + name);
}

std::vector<std::string> read_lines(const std::string &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    throw std::runtime_error("unable to open " + path);
  }
  std::vector<std::string> lines;
  std::string line;
  while (std::getline(input, line)) {
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    if (!line.empty()) {
      lines.push_back(line);
    }
  }
  if (!input.eof()) {
    throw std::runtime_error("unable to read " + path);
  }
  return lines;
}

std::vector<Rule> read_rules(const std::string &path,
  const std::unordered_set<std::string> &active_components)
{
  std::vector<Rule> rules;
  for (const std::string &line : read_lines(path)) {
    const std::size_t separator = line.find('|');
    if (separator == std::string::npos || separator == 0 || separator + 1 == line.size()) {
      throw std::runtime_error("invalid ownership rule: " + line);
    }
    const std::string component = line.substr(0, separator);
    if (active_components.count(component) == 0) {
      continue;
    }
    try {
      rules.push_back({component, std::regex(line.substr(separator + 1),
        std::regex_constants::extended | std::regex_constants::optimize)});
    } catch (const std::regex_error &error) {
      throw std::runtime_error("invalid ownership pattern for " + component + ": " + error.what());
    }
  }
  return rules;
}

unsigned int worker_count(std::size_t rule_count)
{
  const unsigned int available = std::max(1U, std::thread::hardware_concurrency());
  const std::size_t bounded = std::min<std::size_t>(available, maximum_worker_count);
  return static_cast<unsigned int>(std::max<std::size_t>(1, std::min(rule_count, bounded)));
}

void write_matches(const std::vector<std::string> &files, const std::vector<Rule> &rules,
  const std::string &output_path)
{
  std::vector<std::vector<std::string>> matches(rules.size());
  std::atomic<std::size_t> next_rule{0};
  std::atomic<bool> failed{false};
  std::mutex error_mutex;
  std::string error;
  const unsigned int workers = worker_count(rules.size());

  std::cout << "Matching " << rules.size() << " ownership rules against " << files.size()
            << " files with " << workers << " workers" << std::endl;
  auto worker = [&]() {
    while (!failed.load()) {
      const std::size_t rule_index = next_rule.fetch_add(1);
      if (rule_index >= rules.size()) {
        return;
      }
      try {
        const Rule &rule = rules[rule_index];
        std::vector<std::string> &rule_matches = matches[rule_index];
        for (const std::string &file : files) {
          if (std::regex_search(file, rule.pattern)) {
            rule_matches.push_back(rule.component + '|' + file);
          }
        }
      } catch (const std::exception &exception) {
        std::lock_guard<std::mutex> lock(error_mutex);
        if (!failed.exchange(true)) {
          error = exception.what();
        }
        return;
      }
    }
  };

  std::vector<std::thread> threads;
  threads.reserve(workers);
  for (unsigned int index = 0; index < workers; ++index) {
    threads.emplace_back(worker);
  }
  for (std::thread &thread : threads) {
    thread.join();
  }
  if (failed.load()) {
    throw std::runtime_error(error);
  }

  std::ofstream output(output_path, std::ios::binary | std::ios::trunc);
  if (!output) {
    throw std::runtime_error("unable to open output " + output_path);
  }
  std::size_t match_count = 0;
  for (const std::vector<std::string> &rule_matches : matches) {
    for (const std::string &match : rule_matches) {
      output << match << '\n';
      ++match_count;
    }
  }
  if (!output) {
    throw std::runtime_error("unable to write output " + output_path);
  }
  std::cout << "Matched " << match_count << " explicit ownership records" << std::endl;
}

}

int main(int argc, char **argv)
{
  try {
    const std::vector<std::string> files = read_lines(require_argument(argc, argv, "--files"));
    const std::vector<std::string> active = read_lines(require_argument(argc, argv, "--active"));
    const std::unordered_set<std::string> active_components(active.begin(), active.end());
    const std::vector<Rule> rules = read_rules(require_argument(argc, argv, "--rules"), active_components);
    write_matches(files, rules, require_argument(argc, argv, "--output"));
    return 0;
  } catch (const std::exception &exception) {
    std::cerr << "bext ownership matching failed: " << exception.what() << '\n';
    return 1;
  }
}
