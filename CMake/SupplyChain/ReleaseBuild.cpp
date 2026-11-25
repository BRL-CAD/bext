#include "Commands.hpp"
#include "Maintenance.hpp"

#include <algorithm>
#include <array>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#ifdef _WIN32
#  define NOMINMAX
#  include <windows.h>
#endif

namespace bext {
namespace {

constexpr std::uintmax_t bytes_per_gibibyte = 1024ULL * 1024ULL * 1024ULL;

fs::path normalized_absolute(const fs::path &path)
{
  return fs::absolute(path).lexically_normal();
}

bool inside(const fs::path &path, const fs::path &root)
{
  auto path_part = path.begin();
  auto root_part = root.begin();
  for (; root_part != root.end(); ++root_part, ++path_part) {
    if (path_part == path.end() || *path_part != *root_part) return false;
  }
  return true;
}

bool overlaps(const fs::path &left, const fs::path &right)
{
  return inside(left, right) || inside(right, left);
}

std::vector<fs::path> work_paths(const Json &plan, const Json &project)
{
  const fs::path root = resolved_path(plan.at("build_root"));
  const fs::path logical_root = normalized_absolute(fs::u8path(plan.at("build_root").get<std::string>()));
  const fs::path source_root = resolved_path(plan.at("source_root"));
  std::vector<fs::path> protected_paths = {source_root, root / "CMakeFiles", root / "bext-release-logs"};
  for (const std::string &directory : plan.at("install_roots")) protected_paths.push_back(resolved_path(fs::u8path(directory)));
  for (const Json &item : plan.at("projects")) {
    for (const char *field : {"stamp_dir", "tmp_dir", "log_dir"}) {
      protected_paths.push_back(resolved_path(fs::u8path(item.at(field).get<std::string>())));
    }
    const fs::path upstream = fs::u8path(item.at("upstream").get<std::string>());
    if (fs::is_directory(upstream)) protected_paths.push_back(resolved_path(upstream));
  }
  std::vector<fs::path> result;
  for (const char *field : {"binary_dir", "source_dir"}) {
    const fs::path path = fs::u8path(project.at(field).get<std::string>());
    const fs::path absolute = normalized_absolute(path);
    const fs::path resolved = resolved_path(path);
    if (!inside(absolute, logical_root) && !inside(resolved, root)) continue;
    if (!inside(resolved, root) || resolved == root || fs::is_symlink(fs::symlink_status(path))) {
      throw std::runtime_error("Unsafe working directory: " + path.u8string());
    }
    for (const fs::path &retained : protected_paths) {
      const bool unsafe = retained == source_root ? inside(retained, resolved) : overlaps(resolved, retained);
      if (unsafe) throw std::runtime_error("Working directory overlaps retained files: " + path.u8string());
    }
    if (std::find(result.begin(), result.end(), resolved) == result.end()) result.push_back(resolved);
  }
  return result;
}

#ifdef _WIN32
void make_writable(const fs::path &path)
{
  const DWORD attributes = GetFileAttributesW(path.c_str());
  if (attributes != INVALID_FILE_ATTRIBUTES && attributes & FILE_ATTRIBUTE_READONLY) {
    if (!SetFileAttributesW(path.c_str(), attributes & ~FILE_ATTRIBUTE_READONLY)) {
      throw std::runtime_error("unable to clear read-only attribute: " + path.u8string());
    }
  }
}
#endif

void discard(const Json &plan, const Json &project)
{
  for (const fs::path &path : work_paths(plan, project)) {
    if (!fs::exists(path)) continue;
    std::cout << "Discarding " << path.u8string() << std::endl;
#ifdef _WIN32
    for (const fs::directory_entry &entry : fs::recursive_directory_iterator(path)) make_writable(entry.path());
    make_writable(path);
#endif
    remove_tree_with_retries(path);
  }
}

void replace_file(const fs::path &source, const fs::path &destination)
{
  std::error_code error;
  fs::remove(destination, error);
  fs::rename(source, destination);
}

void preserve_selector_caches(const Json &project)
{
  for (const Json &cache : project.value("selector_caches", Json::array())) {
    const fs::path source = fs::u8path(cache.at("cache").get<std::string>());
    const fs::path destination = fs::u8path(cache.at("preserved_cache").get<std::string>());
    if (!fs::is_regular_file(source)) {
      throw std::runtime_error("Installed SBOM selector cache is unavailable: " + source.u8string());
    }
    fs::create_directories(destination.parent_path());
    fs::path temporary = destination;
    temporary += ".tmp";
    fs::copy_file(source, temporary, fs::copy_options::overwrite_existing);
    replace_file(temporary, destination);
  }
}

void preserve_install_manifest(const Json &project)
{
  const fs::path binary = fs::u8path(project.at("binary_dir").get<std::string>());
  if (!fs::is_directory(binary)) return;
  std::vector<fs::path> manifests;
  for (const fs::directory_entry &entry : fs::recursive_directory_iterator(binary)) {
    if (entry.is_regular_file() && entry.path().filename() == "install_manifest.txt") manifests.push_back(entry.path());
  }
  if (manifests.empty()) return;
  std::sort(manifests.begin(), manifests.end());
  std::set<std::string> installed;
  for (const fs::path &manifest : manifests) {
    for (const std::string &line : text_lines(read_text(manifest))) installed.insert(line);
  }
  std::string contents;
  for (const std::string &path : installed) contents += path + '\n';
  write_text_atomic(fs::u8path(project.at("preserved_install_manifest").get<std::string>()), contents);
}

std::string python_json(const Json &value)
{
  if (value.is_object()) {
    std::string result = "{", separator;
    for (auto item = value.begin(); item != value.end(); ++item) {
      result += separator + Json(item.key()).dump(-1, ' ', true) + ": " + python_json(item.value());
      separator = ", ";
    }
    return result + '}';
  }
  if (value.is_array()) {
    std::string result = "[", separator;
    for (const Json &item : value) {
      result += separator + python_json(item);
      separator = ", ";
    }
    return result + ']';
  }
  return value.dump(-1, ' ', true);
}

void hash_value(Sha256 &hash, const std::string &value)
{
  hash.update(reinterpret_cast<const unsigned char *>(value.data()), value.size());
}

void hash_file(Sha256 &hash, const fs::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("unable to open " + path.u8string());
  std::vector<unsigned char> buffer(1024 * 1024);
  while (input) {
    input.read(reinterpret_cast<char *>(buffer.data()), static_cast<std::streamsize>(buffer.size()));
    hash.update(buffer.data(), static_cast<std::size_t>(input.gcount()));
  }
  if (input.bad()) throw std::runtime_error("unable to read " + path.u8string());
}

std::vector<fs::path> recursive_paths(const fs::path &root)
{
  std::vector<fs::path> result;
  if (fs::exists(root)) for (const fs::directory_entry &entry : fs::recursive_directory_iterator(root)) {
    result.push_back(entry.path());
  }
  std::sort(result.begin(), result.end());
  return result;
}

std::vector<fs::path> null_separated_paths(const std::string &value, const fs::path &root)
{
  std::vector<fs::path> result;
  std::size_t begin = 0;
  while (begin < value.size()) {
    const std::size_t end = value.find('\0', begin);
    const std::size_t length = (end == std::string::npos ? value.size() : end) - begin;
    if (length) result.push_back(root / fs::u8path(value.substr(begin, length)));
    if (end == std::string::npos) break;
    begin = end + 1;
  }
  return result;
}

std::string signature(const Json &plan)
{
  Sha256 hash;
  hash_value(hash, python_json(plan));
  const fs::path cache = fs::u8path(plan.at("build_root").get<std::string>()) / "CMakeCache.txt";
  for (const std::string &line : text_lines(read_text(cache))) {
    if (!line.empty() && line[0] != '#' && line.rfind("//", 0) && line.find(":INTERNAL=") == std::string::npos) {
      hash_value(hash, line + '\n');
    }
  }
  for (const char *name : {"CC", "CXX", "CFLAGS", "CXXFLAGS", "CPPFLAGS", "LDFLAGS", "INCLUDE", "LIB",
                            "LIBPATH", "SDKROOT", "MACOSX_DEPLOYMENT_TARGET"}) {
    const char *value = std::getenv(name);
    hash_value(hash, std::string(name) + '=' + (value ? value : "") + '\n');
  }
  for (const std::string &input : plan.at("inputs")) hash_file(hash, fs::u8path(input));
  std::set<fs::path> upstreams;
  for (const Json &project : plan.at("projects")) {
    const fs::path upstream = fs::u8path(project.at("upstream").get<std::string>());
    if (fs::is_directory(upstream)) upstreams.insert(resolved_path(upstream));
  }
  for (const fs::path &upstream : upstreams) {
    const ProcessResult revision = run_process({"git", "-C", upstream.u8string(), "rev-parse", "HEAD"});
    const ProcessResult tracked = run_process({"git", "-C", upstream.u8string(), "ls-files", "-z", "--", "."});
    std::vector<fs::path> files;
    if (!revision.exit_code && !tracked.exit_code && !tracked.standard_output.empty()) {
      hash_value(hash, revision.standard_output);
      const ProcessResult edits = run_process({"git", "-C", upstream.u8string(), "diff", "--no-ext-diff", "--binary", "HEAD", "--", "."});
      if (edits.exit_code) throw std::runtime_error("unable to inspect local changes in " + upstream.u8string());
      hash_value(hash, edits.standard_output);
      const ProcessResult untracked = run_process({"git", "-C", upstream.u8string(), "ls-files", "--others", "--exclude-standard", "-z", "--", "."});
      if (untracked.exit_code) throw std::runtime_error("unable to inspect untracked files in " + upstream.u8string());
      files = null_separated_paths(untracked.standard_output, upstream);
    } else {
      files = recursive_paths(upstream);
    }
    for (const fs::path &path : files) {
      if (fs::is_symlink(fs::symlink_status(path))) {
        hash_value(hash, path.u8string() + fs::read_symlink(path).u8string());
      } else if (fs::is_regular_file(path)) {
        hash_value(hash, path.u8string());
        hash_file(hash, path);
      }
    }
  }
  return hash.finish();
}

Json inventory(const Json &plan)
{
  Json result = Json::array();
  for (const std::string &directory : plan.at("install_roots")) {
    for (const fs::path &path : recursive_paths(fs::u8path(directory))) {
      if (fs::is_symlink(fs::symlink_status(path))) {
        result.push_back({path.u8string(), "symlink", fs::read_symlink(path).u8string()});
      } else if (fs::is_regular_file(path)) {
        result.push_back({path.u8string(), "file", fs::file_size(path)});
      }
    }
  }
  return result;
}

std::string random_identifier()
{
  std::random_device source;
  std::array<unsigned char, 16> bytes{};
  for (unsigned char &byte : bytes) byte = static_cast<unsigned char>(source());
  bytes[6] = static_cast<unsigned char>((bytes[6] & 0x0f) | 0x40);
  bytes[8] = static_cast<unsigned char>((bytes[8] & 0x3f) | 0x80);
  std::ostringstream output;
  output << std::hex << std::setfill('0');
  for (unsigned char byte : bytes) output << std::setw(2) << static_cast<unsigned int>(byte);
  return output.str();
}

bool path_environment_inside(const fs::path &root, const char *name)
{
  const char *value = std::getenv(name);
  return value && *value && inside(resolved_path(fs::u8path(value)), resolved_path(root));
}

void run_target(const Json &plan, const fs::path &logs, const std::string &target,
  const std::string &build_target = {})
{
  const std::string cmake = plan.at("cmake");
  std::vector<std::string> command = {cmake, "--build", plan.at("build_root"), "--target",
    build_target.empty() ? target : build_target, "--parallel", "1"};
  const std::string config = plan.value("config", "");
  if (!config.empty()) command.insert(command.end(), {"--config", config});
  if (plan.value("uses_msbuild", false) && build_target.empty()) {
    command.insert(command.end(), {"--", "/p:BuildProjectReferences=false"});
  }
  const Json &jobs = plan.at("jobs");
  std::map<std::string, std::string> environment = {{"CMAKE_BUILD_PARALLEL_LEVEL",
    jobs.is_string() ? jobs.get<std::string>() : std::to_string(jobs.get<int>())}};
  const fs::path root = fs::u8path(plan.at("build_root").get<std::string>());
  if (plan.value("uses_msbuild", false) &&
      (path_environment_inside(root, "TEMP") || path_environment_inside(root, "TMP"))) {
    const fs::path scratch = root / "CMakeFiles" / "bext-msbuild-temp";
    fs::create_directories(scratch);
    environment["TEMP"] = scratch.u8string();
    environment["TMP"] = scratch.u8string();
  }
  command = sanitized_environment_command(cmake, {"MAKEFLAGS", "MFLAGS"}, environment, command);
  std::cout << "Building " << target << std::endl;
  std::ofstream log(logs / (target + ".log"), std::ios::binary | std::ios::app);
  if (!log) throw std::runtime_error("unable to open the build log for " + target);
  const ProcessResult process = run_process(command, {}, std::chrono::seconds::zero(),
    [&log](std::string_view chunk) {
      log.write(chunk.data(), static_cast<std::streamsize>(chunk.size()));
      log.flush();
      std::cout.write(chunk.data(), static_cast<std::streamsize>(chunk.size()));
      std::cout.flush();
    }, true);
  if (process.exit_code) throw std::runtime_error(target + " failed; working files and logs were retained");
}

void release_build(const Json &plan)
{
  const fs::path root = fs::u8path(plan.at("build_root").get<std::string>());
  const fs::path state_file = root / "bext-release-state.json";
  const fs::path receipt = fs::u8path(plan.at("prefix").get<std::string>()) / "bext-discard-receipt.json";
  for (const Json &project : plan.at("projects")) work_paths(plan, project);
  const std::string identity = signature(plan);
  Json state;
  if (fs::is_regular_file(state_file)) {
    state = read_json(state_file);
    if (state.at("signature") != identity) {
      throw std::runtime_error("Build inputs changed; use a fresh build directory with BEXT_DISCARD_WORK");
    }
    const Json owner = {{"build_root", resolved_path(root).u8string()}, {"id", state.at("id")}};
    if (!fs::is_regular_file(receipt) || read_json(receipt) != owner) {
      throw std::runtime_error("Installed dependency prefix was removed or replaced; use a fresh build directory");
    }
    if (state.value("finalized", false)) {
      if (inventory(plan) != state.at("inventory")) {
        throw std::runtime_error("Installed dependency files changed; use a fresh build directory");
      }
      std::cout << "Finalized dependencies are up to date." << std::endl;
      return;
    }
  } else {
    if (fs::is_regular_file(receipt) && read_json(receipt).at("build_root") != resolved_path(root).u8string()) {
      throw std::runtime_error("Install prefix belongs to another build; use a fresh install prefix");
    }
    state = {{"signature", identity}, {"id", random_identifier()}, {"completed", Json::array()}, {"finalized", false}};
    fs::create_directories(receipt.parent_path());
    write_json_atomic(receipt, {{"build_root", resolved_path(root).u8string()}, {"id", state.at("id")}});
    write_json_atomic(state_file, state);
  }
  const fs::path logs = root / "bext-release-logs";
  fs::create_directories(logs);
  const std::set<std::string> completed(state.at("completed").begin(), state.at("completed").end());
  for (const Json &project : plan.at("projects")) {
    const std::string name = project.at("name");
    if (completed.count(name)) continue;
    run_target(plan, logs, name, project.value("build_target", ""));
    preserve_selector_caches(project);
    preserve_install_manifest(project);
    if (!project.value("deferred", false)) discard(plan, project);
    state["completed"].push_back(name);
    write_json_atomic(state_file, state);
    const double available = static_cast<double>(fs::space(root).available) /
      static_cast<double>(bytes_per_gibibyte);
    std::cout << "Available disk: " << std::fixed << std::setprecision(2)
              << available << " GiB" << std::endl;
  }
  run_target(plan, logs, "bext_finalize");
  for (const Json &project : plan.at("projects")) {
    if (project.value("deferred", false)) discard(plan, project);
  }
  state["inventory"] = inventory(plan);
  state["finalized"] = true;
  write_json_atomic(state_file, state);
}

}

int release_build_command(int argc, char **argv)
{
  release_build(read_json(fs::u8path(required_option(argc, argv, "--plan"))));
  return 0;
}

}
