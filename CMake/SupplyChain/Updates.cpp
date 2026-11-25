#include "Commands.hpp"
#include "Maintenance.hpp"

#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <vector>

namespace bext {
namespace {

constexpr int schema_version = 1;
constexpr int default_lookup_timeout = 1800;
constexpr int default_ancestry_timeout = 300;
constexpr const char *tested_renovate_version = "44.221.6";
constexpr const char *membership_annotator = "Tool: bext:membership";
constexpr const char *ungrouped = "UNGROUPED";

std::string package_id(const std::string &source)
{
  return "SPDXRef-Package-" + std::regex_replace(source, std::regex("[^A-Za-z0-9.-]"), "-");
}

std::vector<std::string> package_purls(const Json &package)
{
  std::vector<std::string> result;
  for (const Json &reference : package.value("externalRefs", Json::array())) {
    if (reference.value("referenceType", "") == "purl") result.push_back(reference.at("referenceLocator"));
  }
  return result;
}

std::string url_decode(const std::string &value)
{
  std::string result;
  for (std::size_t index = 0; index < value.size(); ++index) {
    if (value[index] == '%' && index + 2 < value.size()) {
      unsigned int character = 0;
      std::istringstream(value.substr(index + 1, 2)) >> std::hex >> character;
      result += static_cast<char>(character);
      index += 2;
    } else {
      result += value[index];
    }
  }
  return result;
}

std::pair<std::string, std::string> upstream_git(const std::string &purl)
{
  std::string body = purl.substr(0, purl.find_first_of("?#"));
  const std::size_t separator = body.rfind('@');
  if (separator == std::string::npos) return {};
  const std::string base = body.substr(0, separator);
  const std::string revision = url_decode(body.substr(separator + 1));
  if (!base.rfind("pkg:github/", 0)) return {"https://github.com/" + url_decode(base.substr(11)) + ".git", revision};
  if (!base.rfind("pkg:git/", 0)) return {"https://" + url_decode(base.substr(8)), revision};
  return {};
}

std::pair<std::string, std::vector<std::string>> package_membership(const Json &package)
{
  std::vector<Json> annotations;
  for (const Json &annotation : package.value("annotations", Json::array())) {
    if (annotation.value("annotator", "") == membership_annotator) annotations.push_back(annotation);
  }
  if (annotations.size() != 1) throw std::runtime_error(package.at("SPDXID").get<std::string>() + ": expected one membership annotation; regenerate the source SBOM");
  const Json membership = Json::parse(annotations.front().at("comment").get<std::string>());
  if (membership.value("schemaVersion", 0) != schema_version || !membership.value("component", Json()).is_string() ||
      !std::regex_match(membership.at("component").get<std::string>(), std::regex("[a-z0-9][a-z0-9_-]*")) ||
      !membership.value("groups", Json()).is_array()) throw std::runtime_error(package.at("SPDXID").get<std::string>() + ": invalid consumer-group metadata");
  std::vector<std::string> groups;
  for (const Json &group : membership.at("groups")) {
    if (!group.is_string() || !std::regex_match(group.get<std::string>(), std::regex("[A-Za-z_][A-Za-z0-9_]*")) || group == ungrouped) {
      throw std::runtime_error(package.at("SPDXID").get<std::string>() + ": invalid consumer-group metadata");
    }
    groups.push_back(group);
  }
  std::sort(groups.begin(), groups.end());
  if (std::adjacent_find(groups.begin(), groups.end()) != groups.end()) throw std::runtime_error("duplicate consumer group");
  return {membership.at("component"), groups};
}

std::map<std::string, Json> release_rules(const fs::path &root)
{
  std::map<std::string, Json> result;
  for (const fs::directory_entry &directory : fs::directory_iterator(root)) {
    const fs::path path = directory.path() / "UpdateChecks.json";
    if (!fs::is_regular_file(path)) continue;
    const Json document = read_json(path);
    if (document.value("schemaVersion", 0) != schema_version || !document.value("rules", Json()).is_array()) {
      throw std::runtime_error("invalid release-check catalog: " + directory.path().filename().u8string());
    }
    for (const Json &rule : document.at("rules")) {
      const std::string source = relative_name(rule.at("source"));
      if (source.substr(0, source.find('/')) != directory.path().filename().u8string()) throw std::runtime_error("a release rule must belong to its dependency folder");
      const std::string kind = rule.value("kind", "release");
      if (kind != "release" && kind != "commit" && kind != "parent" && kind != "manual") throw std::runtime_error("unknown update-check kind: " + source);
      if (kind == "manual" && rule.value("reason", "").empty()) throw std::runtime_error("manual checks require a reason: " + source);
      if (kind == "commit" && rule.value("branch", "").empty()) throw std::runtime_error("commit checks require an explicit branch: " + source);
      if (kind == "parent" && (!rule.value("coveredBy", Json()).is_array() || rule.at("coveredBy").empty())) throw std::runtime_error("parent checks require coveredBy source paths: " + source);
      const std::string identifier = package_id(source);
      if (!result.emplace(identifier, rule).second) throw std::runtime_error("duplicate release-check rule: " + source);
    }
  }
  return result;
}

std::set<std::string> wrapper_names(const fs::path &root)
{
  std::set<std::string> result;
  for (const fs::directory_entry &directory : fs::directory_iterator(root)) {
    if (fs::is_regular_file(directory.path() / "BextPackage.cmake")) result.insert(directory.path().filename().u8string());
  }
  return result;
}

std::string owning_wrapper(const std::string &identifier, const std::set<std::string> &wrappers)
{
  std::vector<std::string> owners;
  for (const std::string &wrapper : wrappers) if (!identifier.rfind("SPDXRef-Package-" + wrapper + '-', 0)) owners.push_back(wrapper);
  if (owners.size() != 1) throw std::runtime_error(identifier + ": expected one owning dependency folder");
  return owners.front();
}

std::map<std::string, Json> source_repositories(const fs::path &root)
{
  const ProcessResult paths = run_process({"git", "-C", root.u8string(), "config", "--file", ".gitmodules", "--get-regexp", R"(^submodule\..*\.path$)"});
  if (paths.exit_code) throw std::runtime_error("cannot read committed submodule paths");
  std::map<std::string, Json> result;
  for (const std::string &line : nonempty_lines(paths.standard_output)) {
    const std::size_t space = line.find(' ');
    const std::string section = line.substr(0, space - 5);
    const std::string path = line.substr(space + 1);
    const ProcessResult url = run_process({"git", "-C", root.u8string(), "config", "--file", ".gitmodules", "--get", section + ".url"});
    const ProcessResult tree = run_process({"git", "-C", root.u8string(), "ls-tree", "HEAD", "--", path});
    if (url.exit_code || tree.exit_code || tree.standard_output.empty()) continue;
    std::istringstream metadata(tree.standard_output);
    std::string mode, type, commit, repository = url.standard_output;
    metadata >> mode >> type >> commit;
    repository.erase(repository.find_last_not_of("\r\n") + 1);
    if (mode == "160000") result[path] = {{"repository", repository}, {"commit", commit}};
  }
  return result;
}

Json renovate_config()
{
  return {{"enabledManagers", Json::array({"custom.jsonata"})}, {"dependencyDashboard", false}, {"automerge", false},
    {"customManagers", Json::array({{{"customType", "jsonata"}, {"fileFormat", "json"},
      {"managerFilePatterns", Json::array({R"(/^dependency-updates\.json$/)"})},
      {"matchStrings", Json::array({"dependencies.{\"depName\": depName, \"packageName\": packageName, \"datasource\": datasource, \"currentValue\": currentValue, \"versioning\": versioning, \"extractVersion\": extractVersion, \"depType\": depType, \"currentDigest\": currentDigest}"})}}})}};
}

void add_release_query(Json &record, const Json &rule, const std::string &repository,
  const std::string &revision, Json &dependencies)
{
  const std::string package = rule.value("packageName", repository);
  const std::string current = rule.value("currentValueFrom", "ref") == "version" ? record.at("version").get<std::string>() : revision;
  const std::regex commit("[0-9a-f]{40}");
  const std::regex release(R"(v?[0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9.-]+)?)");
  if (package.empty() || current.empty()) {
    record.update({{"checkKind", "unconfigured"}, {"status", "not_checked"}, {"reason", "An upstream release rule is needed"}});
  } else if (std::regex_match(current, commit)) {
    record.update({{"checkKind", "unconfigured"}, {"status", "not_checked"}, {"reason", "A commit is not a release baseline; use a reviewed version or a commit check"}});
  } else if (rule.empty() && !std::regex_match(current, release)) {
    record.update({{"checkKind", "unconfigured"}, {"status", "not_checked"}, {"reason", "A revision or nonstandard tag needs a release rule"}});
  } else {
    Json query = {{"depName", record.at("package")}, {"depType", record.at("component")},
      {"packageName", package}, {"datasource", "git-tags"}, {"currentValue", current},
      {"versioning", rule.value("versioning", "semver-coerced")}};
    if (rule.contains("extractVersion")) query["extractVersion"] = rule.at("extractVersion");
    dependencies.push_back(query);
    record.update({{"status", "pending"}, {"query", query}, {"baseline", rule.value("baseline", "release")}});
  }
}

std::pair<Json, Json> release_queries(const Json &source, const fs::path &root,
  const std::set<std::string> &only, const std::set<std::string> &selected_groups)
{
  if (source.value("spdxVersion", "") != "SPDX-2.3") throw std::runtime_error("a canonical SPDX 2.3 source inventory is required");
  const auto rules = release_rules(root);
  const auto wrappers = wrapper_names(root);
  std::map<std::string, std::string> parents;
  std::set<std::string> identifiers, known_groups, found;
  for (const Json &package : source.at("packages")) {
    identifiers.insert(package.at("SPDXID"));
    const auto membership = package_membership(package);
    if (membership.second.empty()) known_groups.insert(ungrouped);
    known_groups.insert(membership.second.begin(), membership.second.end());
  }
  for (const std::string &group : selected_groups) if (!known_groups.count(group)) throw std::runtime_error("unknown consumer group: " + group);
  for (const Json &relation : source.value("relationships", Json::array())) if (relation.value("relationshipType", "") == "CONTAINS") {
    const std::string child = relation.at("relatedSpdxElement");
    if (!parents.emplace(child, relation.at("spdxElementId")).second) throw std::runtime_error("multiple containing packages: " + child);
  }
  for (const auto &rule : rules) if (!identifiers.count(rule.first)) throw std::runtime_error("release rules name absent source package: " + rule.first);
  const bool needs_repositories = std::any_of(rules.begin(), rules.end(), [](const auto &rule) { return rule.second.value("kind", "release") == "commit"; });
  const auto repositories = needs_repositories ? source_repositories(root) : std::map<std::string, Json>();
  Json dependencies = Json::array(), coverage = Json::array();
  for (const Json &package : source.at("packages")) {
    const std::string identifier = package.at("SPDXID");
    const auto identities = package_purls(package);
    if (identities.size() != 1 || identities.front().find("bext_build=") != std::string::npos) throw std::runtime_error(identifier + ": expected one canonical source PURL");
    const std::string owner = owning_wrapper(identifier, wrappers);
    const auto membership = package_membership(package);
    if (membership.first != owner) throw std::runtime_error(identifier + ": consumer-group metadata names a different component");
    if (!only.empty() && !only.count(owner)) continue;
    found.insert(owner);
    std::set<std::string> tags(membership.second.begin(), membership.second.end());
    if (tags.empty()) tags.insert(ungrouped);
    bool selected = selected_groups.empty();
    for (const std::string &group : selected_groups) selected = selected || tags.count(group);
    if (!selected) continue;
    Json record = {{"package", identifier}, {"component", owner}, {"name", package.at("name")},
      {"version", package.at("versionInfo")}, {"sourcePurl", identities.front()}, {"groups", membership.second}};
    if (parents.count(identifier)) record["managedBy"] = parents.at(identifier);
    const auto identity = upstream_git(identities.front());
    const Json rule = rules.count(identifier) ? rules.at(identifier) : Json::object();
    const std::string kind = rule.value("kind", "release");
    record["checkKind"] = kind;
    if (rule.contains("reason")) record["reason"] = rule.at("reason");
    if (kind == "manual") record["status"] = "manual_import";
    else if (kind == "parent") {
      record["status"] = "parent_managed"; record["coveredBy"] = Json::array();
      for (const std::string &target : rule.at("coveredBy")) record["coveredBy"].push_back(package_id(target));
    } else if (kind == "commit") {
      const std::string source_path = rule.at("source");
      if (!repositories.count(source_path)) throw std::runtime_error(identifier + ": commit checks require a gitlink repository");
      const Json origin = repositories.at(source_path);
      if (identity.second != origin.at("commit")) throw std::runtime_error(identifier + ": source PURL does not match committed gitlink");
      Json query = {{"depName", identifier}, {"depType", owner}, {"packageName", origin.at("repository")},
        {"datasource", "git-refs"}, {"currentValue", rule.at("branch")}, {"currentDigest", origin.at("commit")}, {"versioning", "git"}};
      dependencies.push_back(query); record.update({{"status", "pending"}, {"query", query}});
    } else {
      add_release_query(record, rule, identity.first, identity.second, dependencies);
      if (record.at("status") == "not_checked" && parents.count(identifier)) record.update({{"checkKind", "parent"}, {"status", "parent_managed"},
        {"coveredBy", Json::array({parents.at(identifier)})}, {"reason", "Update through the containing source package"}});
    }
    coverage.push_back(record);
  }
  for (const std::string &component : only) if (!found.count(component)) throw std::runtime_error("unknown dependency selection: " + component);
  if (!selected_groups.empty() && coverage.empty()) throw std::runtime_error("selected dependencies and consumer groups do not overlap");
  return {dependencies, coverage};
}

Json summarize(const Json &records)
{
  Json counts = Json::object(), kinds = Json::object();
  std::size_t top = 0, embedded = 0, commits = 0;
  for (const Json &record : records) {
    const std::string status = record.at("status"), kind = record.at("checkKind");
    counts[status] = counts.value(status, 0) + 1;
    kinds[kind] = kinds.value(kind, 0) + 1;
    if (status == "updates_available" || status == "commit_changed") {
      if (kind == "commit") ++commits;
      else if (kind == "release" && record.contains("managedBy")) ++embedded;
      else if (kind == "release") ++top;
    }
  }
  return {{"packageCount", records.size()}, {"counts", counts}, {"checkKinds", kinds},
    {"candidates", {{"topLevelReleases", top}, {"embeddedReleases", embedded}, {"commitChanges", commits}}}};
}

std::map<std::string, std::string> coverage_leaves(const std::string &identifier,
  const std::map<std::string, Json *> &records, std::set<std::string> pending = {})
{
  if (pending.count(identifier)) throw std::runtime_error("cyclic parent coverage: " + identifier);
  const auto record = records.find(identifier);
  if (record == records.end()) return {{identifier, "outside_selection"}};
  if (record->second->at("checkKind") != "parent") return {{identifier, record->second->at("status")}};
  pending.insert(identifier);
  std::map<std::string, std::string> result;
  for (const std::string &target : record->second->at("coveredBy")) {
    const auto leaves = coverage_leaves(target, records, pending);
    result.insert(leaves.begin(), leaves.end());
  }
  return result;
}

void finish_report(Json &report)
{
  std::map<std::string, Json *> records;
  for (Json &record : report.at("packages")) records[record.at("package")] = &record;
  for (Json &record : report.at("packages")) if (record.at("checkKind") == "parent") {
    record["coveredChecks"] = coverage_leaves(record.at("package"), records);
  }
  const Json total = summarize(report.at("packages"));
  for (auto field = total.begin(); field != total.end(); ++field) report[field.key()] = field.value();
  std::set<std::string> groups;
  for (const Json &record : report.at("packages")) {
    if (record.at("groups").empty()) groups.insert(ungrouped);
    for (const std::string &group : record.at("groups")) groups.insert(group);
  }
  report["byGroup"] = Json::object();
  const std::set<std::string> selected(report.at("selection").at("groups").begin(), report.at("selection").at("groups").end());
  for (const std::string &group : groups) if (selected.empty() || selected.count(group)) {
    Json members = Json::array();
    for (const Json &record : report.at("packages")) {
      const bool member = record.at("groups").empty() ? group == ungrouped : std::find(record.at("groups").begin(), record.at("groups").end(), group) != record.at("groups").end();
      if (member) members.push_back(record);
    }
    report["byGroup"][group] = summarize(members);
  }
}

std::vector<std::string> group_tags(const Json &record)
{
  if (record.at("groups").empty()) return {ungrouped};
  return record.at("groups").get<std::vector<std::string>>();
}

std::vector<std::string> candidate_values(const Json &record)
{
  if (record.at("status") == "commit_changed") return {record.at("commitCandidate")};
  if (record.at("status") != "updates_available") return {};
  std::vector<std::string> values;
  for (const Json &update : record.value("updates", Json::array())) {
    values.push_back(update.value("newValue", update.value("newVersion", "?")));
  }
  return values;
}

std::string report_text(const Json &report)
{
  std::ostringstream output;
  output << "Dependency update lookup: " << report.at("status").get<std::string>() << "\nCoverage:";
  std::string separator = " ";
  for (auto count = report.at("counts").begin(); count != report.at("counts").end(); ++count) {
    output << separator << count.value() << ' ' << count.key();
    separator = ", ";
  }
  output << "\nChecks:";
  separator = " ";
  for (auto count = report.at("checkKinds").begin(); count != report.at("checkKinds").end(); ++count) {
    output << separator << count.value() << ' ' << count.key();
    separator = ", ";
  }
  output << "\nSource inventory includes embedded packages that a build may exclude.\n"
            "Candidates require mirror verification, integration tests, and review.\n"
            "Groups are declared memberships, overlap, and do not imply a complete build profile.\n"
            "Include supporting groups when reviewing a build; UNGROUPED denotes no declared consumer group.\n"
            "\nCandidates by consumer group:\n";
  for (auto group = report.at("byGroup").begin(); group != report.at("byGroup").end(); ++group) {
    const Json &candidates = group.value().at("candidates");
    output << "  " << group.key() << ": " << candidates.at("topLevelReleases")
           << " top-level releases, " << candidates.at("embeddedReleases")
           << " embedded releases, " << candidates.at("commitChanges") << " commit changes\n";
  }
  output << "\nPackage details:\n";
  for (const Json &record : report.at("packages")) {
    std::string detail = join_strings(candidate_values(record), ", ");
    if (detail.empty()) detail = record.value("reason", "");
    if (record.at("checkKind") == "commit") {
      const Json &query = record.at("query");
      detail = query.at("currentValue").get<std::string>() + ": " + query.at("currentDigest").get<std::string>();
      if (record.contains("commitCandidate")) {
        detail += " -> " + record.at("commitCandidate").get<std::string>() + " (" +
          record.at("ancestry").at("relation").get<std::string>() + ')';
      }
      if (record.contains("reason")) detail += "; " + record.at("reason").get<std::string>();
    } else if (record.at("checkKind") == "parent") {
      detail.clear();
      for (auto covered = record.at("coveredChecks").begin(); covered != record.at("coveredChecks").end(); ++covered) {
        if (!detail.empty()) detail += "; ";
        detail += covered.key() + ": " + covered.value().get<std::string>();
      }
    }
    std::vector<std::string> notes;
    if (!detail.empty()) notes.push_back(detail);
    if (record.value("baseline", "") == "snapshot") {
      notes.push_back("comparison baseline is a development snapshot");
    }
    if (record.contains("managedBy")) notes.push_back("update through " + record.at("managedBy").get<std::string>());
    output << '[' << join_strings(group_tags(record), ", ") << "] " << record.at("component").get<std::string>()
           << ": " << record.at("name").get<std::string>() << ' ' << record.at("version").get<std::string>()
           << ": " << record.at("checkKind").get<std::string>() << '/' << record.at("status").get<std::string>();
    if (!notes.empty()) output << ": " << join_strings(notes, "; ");
    output << '\n';
  }
  return output.str();
}

std::string csv_quote(const std::string &value)
{
  if (value.find_first_of(",\"\r\n") == std::string::npos) return value;
  return '"' + std::regex_replace(value, std::regex("\""), "\"\"") + '"';
}

std::string report_csv(const Json &report)
{
  std::ostringstream output;
  output << "groups,component,package,kind,status,scope,current,candidates,sourcePurl,managedBy,reason\r\n";
  for (const Json &record : report.at("packages")) {
    const std::string current = record.at("checkKind") == "commit"
      ? record.at("query").at("currentDigest").get<std::string>() : record.at("version").get<std::string>();
    const std::vector<std::string> values = {join_strings(group_tags(record), ";"), record.at("component").get<std::string>(), record.at("name").get<std::string>(),
      record.at("checkKind").get<std::string>(), record.at("status").get<std::string>(),
      record.contains("managedBy") ? "embedded" : "top-level", current, join_strings(candidate_values(record), ", "), record.at("sourcePurl").get<std::string>(),
      record.value("managedBy", ""), record.value("reason", "")};
    for (std::size_t index = 0; index < values.size(); ++index) output << (index ? "," : "") << csv_quote(values[index]);
    output << "\r\n";
  }
  return output.str();
}

ProcessResult ancestry_git(const fs::path &cache, const fs::path &log,
  const std::vector<std::string> &arguments, int timeout)
{
  std::vector<std::string> command = {"git", "--git-dir=" + cache.u8string()};
  command.insert(command.end(), arguments.begin(), arguments.end());
  const ProcessResult result = run_process(command, {}, std::chrono::seconds(timeout));
  if (result.exit_code && !result.standard_error.empty()) {
    std::ofstream output(log, std::ios::binary | std::ios::app);
    output << result.standard_error;
  }
  return result;
}

Json compare_commits(const std::string &repository, const std::string &current,
  const std::string &candidate, const fs::path &directory, int timeout)
{
  if (current == candidate) return {{"relation", "same"}, {"ahead", 0}, {"behind", 0}};
  const fs::path cache = directory / sha256(repository);
  const fs::path log = directory / "ancestry.log";
  fs::create_directories(directory);
  if (!fs::exists(cache)) {
    if (ancestry_git(cache, log, {"init", "--bare", "--quiet"}, timeout).exit_code) {
      return {{"relation", "unknown"}, {"reason", "Cannot initialize the private ancestry cache"}};
    }
  } else {
    ProcessResult bare = ancestry_git(cache, log, {"rev-parse", "--is-bare-repository"}, timeout);
    if (bare.exit_code || bare.standard_output.find("true") == std::string::npos) {
      return {{"relation", "unknown"}, {"reason", "The private ancestry cache is not a bare repository"}};
    }
  }
  if (ancestry_git(cache, log, {"fetch", "--quiet", "--no-tags", "--filter=tree:0", repository, current, candidate}, timeout).exit_code) {
    return {{"relation", "unknown"}, {"reason", "Cannot fetch history; see ancestry.log"}};
  }
  const ProcessResult counts = ancestry_git(cache, log, {"rev-list", "--left-right", "--count", current + "..." + candidate}, timeout);
  if (counts.exit_code) return {{"relation", "unknown"}, {"reason", "Cannot compare history; see ancestry.log"}};
  std::size_t behind = 0, ahead = 0;
  std::istringstream(counts.standard_output) >> behind >> ahead;
  std::string relation;
  if (!behind) relation = "ahead";
  else if (!ahead) relation = "behind";
  else {
    const ProcessResult common = ancestry_git(cache, log, {"merge-base", current, candidate}, timeout);
    if (common.exit_code != 0 && common.exit_code != 1) return {{"relation", "unknown"}, {"reason", "Cannot establish ancestry; see ancestry.log"}};
    relation = common.exit_code ? "unrelated" : "diverged";
  }
  return {{"relation", relation}, {"ahead", ahead}, {"behind", behind}};
}

void collect_logged_dependencies(const Json &value, std::map<std::string, Json> &latest)
{
  if (value.is_object()) {
    if (value.value("deps", Json()).is_array()) for (const Json &dependency : value.at("deps")) {
      if (dependency.is_object() && dependency.contains("depName") && (dependency.contains("updates") || dependency.contains("skipReason"))) {
        latest[dependency.at("depName")] = dependency;
      }
    }
    for (auto child = value.begin(); child != value.end(); ++child) collect_logged_dependencies(child.value(), latest);
  } else if (value.is_array()) {
    for (const Json &child : value) collect_logged_dependencies(child, latest);
  }
}

void commit_result(Json &record, const Json &updates, const fs::path &directory, int timeout)
{
  const Json &query = record.at("query");
  std::set<std::string> candidates;
  if (updates.empty()) candidates.insert(query.at("currentDigest"));
  else for (const Json &update : updates) if (update.value("newDigest", Json()).is_string()) candidates.insert(update.at("newDigest"));
  if (candidates.size() != 1 || !std::regex_match(*candidates.begin(), std::regex("[0-9a-f]{40}"))) {
    record.update({{"status", "lookup_failed"}, {"reason", "Renovate did not report one full candidate commit"}});
    return;
  }
  const std::string candidate = *candidates.begin();
  if (candidate == query.at("currentDigest")) {
    record.update({{"status", "commit_current"}, {"commitCandidate", candidate},
      {"ancestry", {{"relation", "same"}, {"ahead", 0}, {"behind", 0}}}});
    return;
  }
  record.update({{"status", "commit_changed"}, {"commitCandidate", candidate},
    {"ancestry", compare_commits(query.at("packageName"), query.at("currentDigest"), candidate, directory, timeout)}});
}

Json collect_results(const fs::path &log, Json &coverage, const fs::path &ancestry_directory, int ancestry_timeout)
{
  std::map<std::string, Json> latest;
  std::set<std::string> log_errors, empty_repositories;
  Json diagnostics = Json::array();
  for (const std::string &line : nonempty_lines(read_text(log))) {
    Json entry;
    try { entry = Json::parse(line); }
    catch (...) { log_errors.insert("Malformed JSON in the Renovate result log"); continue; }
    if (!entry.is_object()) continue;
    collect_logged_dependencies(entry, latest);
    if (entry.value("level", 0) >= 40) diagnostics.push_back(entry.value("msg", "Renovate diagnostic"));
    if (entry.value("level", 0) >= 50) log_errors.insert(entry.value("msg", "Renovate error"));
    if (entry.value("msg", "") == "Found no results from datasource that look like a version") empty_repositories.insert(entry.value("dependency", ""));
  }
  for (Json &record : coverage) {
    if (record.at("status") != "pending") continue;
    const std::string identifier = record.at("package");
    const auto result = latest.find(identifier);
    if (!log_errors.empty()) {
      std::string reason, separator;
      for (const std::string &error : log_errors) { reason += separator + error; separator = "; "; }
      record.update({{"status", "lookup_failed"}, {"reason", reason}});
    } else if (result == latest.end()) {
      record.update({{"status", "not_reported"}, {"reason", "Renovate did not report a lookup result"}});
    } else if (result->second.contains("skipReason") || result->second.contains("warnings") || result->second.contains("errors")) {
      record.update({{"status", "lookup_failed"}, {"reason", result->second.value("skipReason", "Lookup warning")}, {"details", result->second}});
    } else if (!result->second.value("updates", Json()).is_array()) {
      record.update({{"status", "lookup_failed"}, {"reason", "Renovate returned malformed updates"}, {"details", result->second}});
    } else if (empty_repositories.count(record.at("query").at("packageName"))) {
      record.update({{"status", "lookup_failed"}, {"reason", "No releases matched the configured version rule"}});
    } else {
      const Json updates = result->second.at("updates");
      record["updates"] = updates;
      if (record.at("checkKind") == "commit") commit_result(record, updates, ancestry_directory, ancestry_timeout);
      else {
        bool valid = true;
        for (const Json &update : updates) valid = valid &&
          ((update.value("newValue", Json()).is_string() && !update.at("newValue").get<std::string>().empty()) ||
           (update.value("newVersion", Json()).is_string() && !update.at("newVersion").get<std::string>().empty()));
        if (!valid) record.update({{"status", "lookup_failed"}, {"reason", "Release candidates have no version"}, {"details", result->second}});
        else record["status"] = updates.empty() ? (record.value("baseline", "release") == "snapshot" ? "snapshot_no_newer_release" : "current") : "updates_available";
      }
    }
  }
  return diagnostics;
}

int run_lookup(const std::string &cmake, const fs::path &executable, const fs::path &directory,
  const Json &dependencies, const Json &config, int timeout)
{
  const fs::path work = fs::temp_directory_path() / ("bext-release-lookup-" + sha256(directory.u8string() + utc_now()).substr(0, 16));
  fs::create_directories(work);
  write_json_atomic(work / "dependency-updates.json", {{"dependencies", dependencies}});
  write_json_atomic(work / "renovate.json", config);
  std::vector<std::string> unset;
  for (const std::string &name : environment_names()) {
    if (!name.rfind("RENOVATE_", 0) || !name.rfind("LOG_", 0) || name == "GITHUB_TOKEN" ||
        name == "GITHUB_COM_TOKEN" || name == "GH_TOKEN" || name == "GITLAB_TOKEN" || name == "GITEA_TOKEN") unset.push_back(name);
  }
  std::vector<std::string> command = tool_command(executable);
  command.insert(command.end(), {"--platform=local", "--dry-run=lookup", "--onboarding=false",
    "--require-config=required", "--autodiscover=false", "--allow-scripts=false", "--allow-plugins=false",
    "--binary-source=global", "--cache-dir=" + (directory / "cache").u8string()});
  const ProcessResult result = run_process(sanitized_environment_command(cmake, unset,
    {{"LOG_LEVEL", "debug"}, {"LOG_FORMAT", "json"}}, command), work, std::chrono::seconds(timeout));
  write_text_atomic(directory / "renovate.log.jsonl", result.standard_output);
  write_text_atomic(directory / "renovate.stderr.log", result.standard_error);
  std::error_code error;
  fs::remove_all(work, error);
  return result.exit_code;
}

std::string installation_help()
{
#ifdef _WIN32
  const std::string platform = "Windows: extract a supported Node.js Windows ZIP into a user-owned directory and add it to PATH in PowerShell. Use the renovate.cmd npm launcher.";
  const std::string launcher = "renovate.cmd";
#else
  const std::string platform = "Linux/Unix: install a supported Node.js release in a user-owned directory and add its bin directory to PATH.";
  const std::string launcher = "renovate";
#endif
  return platform + "\nRenovate 44.221.6 supports Node ^24.11.0 or ^26.13.0.\n"
    "Download Node: https://nodejs.org/en/download\n"
    "From the bext checkout, install the optional CLI without administrator access:\n"
    "  npm install --prefix build/renovate-tools --ignore-scripts --omit=optional --no-audit --no-fund renovate@44.221.6\n"
    "Then reconfigure with -DBEXT_RENOVATE_EXECUTABLE=build/renovate-tools/node_modules/.bin/" + launcher + "\n"
    "Retry the dependency_update_report target.\n"
    "Setup guide: MAINTAINING.md#setting-up-the-external-supply-chain-tools\n"
    "Offline alternative: use the dependency_update_inputs target\n";
}

}

int dependency_updates(int argc, char **argv)
{
  const fs::path sbom = fs::u8path(required_option(argc, argv, "--sbom"));
  const fs::path source_root = fs::u8path(required_option(argc, argv, "--source-root"));
  const fs::path output = fs::u8path(required_option(argc, argv, "--output-dir"));
  const std::vector<std::string> only_values = option_values(argc, argv, "--only");
  const std::set<std::string> only(only_values.begin(), only_values.end());
  const std::vector<std::string> group_values = option_values(argc, argv, "--group");
  const std::set<std::string> groups(group_values.begin(), group_values.end());
  const int lookup_timeout = std::stoi(option(argc, argv, "--lookup-timeout").value_or(std::to_string(default_lookup_timeout)));
  const int ancestry_timeout = std::stoi(option(argc, argv, "--ancestry-timeout").value_or(std::to_string(default_ancestry_timeout)));
  if (lookup_timeout <= 0 || ancestry_timeout <= 0) throw std::runtime_error("timeouts must be positive seconds");
  fs::create_directories(output);
  const std::vector<std::string> names = {"dependency-updates.json", "renovate.json", "dependency-update-report.json",
    "dependency-update-report.txt", "dependency-update-report.csv", "renovate.log.jsonl", "renovate.stderr.log"};
  if (resolved_path(sbom).parent_path() == resolved_path(output) && std::find(names.begin(), names.end(), sbom.filename().u8string()) != names.end()) {
    throw std::runtime_error("the source inventory must be separate from generated outputs");
  }
  for (const std::string &name : names) { std::error_code error; fs::remove(output / name, error); }
  const Json source = read_json(sbom);
  auto generated = release_queries(source, source_root, only, groups);
  const Json config = renovate_config();
  write_json_atomic(output / "dependency-updates.json", {{"dependencies", generated.first}});
  write_json_atomic(output / "renovate.json", config);
  Json selection = {{"components", Json::array()}, {"groups", Json::array()}};
  for (const std::string &component : only) selection["components"].push_back(component);
  for (const std::string &group : groups) selection["groups"].push_back(group);
  Json report = {{"schemaVersion", schema_version}, {"sourceDocument", source.at("documentNamespace")},
    {"selection", selection}, {"checkedAt", utc_now()}, {"sourceSha256", file_sha256(sbom)},
    {"policySha256", digest({{"queries", generated.first}, {"coverage", generated.second}, {"config", config}})},
    {"tool", {{"name", "renovate"}, {"version", nullptr}, {"testedVersion", tested_renovate_version}}},
    {"packages", generated.second}, {"status", "generated"}, {"diagnostics", Json::array()}, {"finishedAt", utc_now()}};
  int result = 0;
  if (!flag(argc, argv, "--generate-only")) {
    const fs::path renovate = fs::u8path(option(argc, argv, "--renovate").value_or("renovate"));
    const std::string cmake = option(argc, argv, "--cmake").value_or("cmake");
    try {
      report["tool"]["version"] = tool_version(renovate);
      if (!generated.first.empty()) result = run_lookup(cmake, renovate, output, generated.first, config, lookup_timeout);
    } catch (const std::exception &exception) {
      result = 1;
      report["diagnostics"].push_back("Renovate failed: " + std::string(exception.what()));
      report["status"] = "tool_unavailable";
    }
    if (fs::is_regular_file(output / "renovate.log.jsonl")) {
      const Json diagnostics = collect_results(output / "renovate.log.jsonl", report["packages"], output / "cache" / "ancestry", ancestry_timeout);
      for (const Json &diagnostic : diagnostics) report["diagnostics"].push_back(diagnostic);
    } else for (Json &record : report["packages"]) if (record.at("status") == "pending") {
      record.update({{"status", "not_reported"}, {"reason", "Renovate did not produce a result log"}});
    }
    bool incomplete = false;
    for (const Json &record : report["packages"]) incomplete = incomplete || record.at("status") == "not_reported" ||
      record.at("status") == "lookup_failed" || (record.contains("ancestry") && record.at("ancestry").value("relation", "") == "unknown");
    if (report.at("status") != "tool_unavailable") report["status"] = result ? "failed" : incomplete ? "incomplete" : "complete";
    result = result || static_cast<int>(incomplete);
  }
  report["finishedAt"] = utc_now();
  finish_report(report);
  publish_files(output, {{"dependency-update-report.json", json_text(report)},
    {"dependency-update-report.txt", report_text(report)}, {"dependency-update-report.csv", report_csv(report)}},
    "dependency-update-report.json");
  std::cout << "Dependency update lookup: " << report.at("status").get<std::string>()
            << "\nReport: " << (output / "dependency-update-report.txt").u8string() << '\n';
  if (report.at("status") == "tool_unavailable") std::cerr << installation_help();
  return result;
}

}
