#include "Process.hpp"
#include "Commands.hpp"
#include "Support.hpp"
#include "VexCatalog.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <iostream>
#include <cctype>
#include <map>
#include <mutex>
#include <regex>
#include <set>
#include <tuple>
#include <thread>
#include <utility>
#include <vector>

namespace bext {
namespace {

constexpr int schema_version = 1;
constexpr const char *build_qualifier = "bext_build";

std::string compact_json(const Json &value)
{
  if (value.is_object()) {
    std::string result = "{";
    std::string separator;
    for (auto item = value.begin(); item != value.end(); ++item) {
      result += separator + Json(item.key()).dump() + ": " + compact_json(item.value());
      separator = ", ";
    }
    return result + '}';
  }
  if (value.is_array()) {
    std::string result = "[";
    std::string separator;
    for (const Json &item : value) { result += separator + compact_json(item); separator = ", "; }
    return result + ']';
  }
  return value.dump();
}

int hex_value(char value)
{
  if (value >= '0' && value <= '9') return value - '0';
  value = static_cast<char>(std::tolower(static_cast<unsigned char>(value)));
  if (value >= 'a' && value <= 'f') return value - 'a' + 10;
  throw std::runtime_error("invalid URL escape");
}

std::string url_decode(const std::string &value)
{
  std::string result;
  for (std::size_t index = 0; index < value.size(); ++index) {
    if (value[index] == '%' && index + 2 < value.size()) {
      result += static_cast<char>(hex_value(value[index + 1]) * 16 + hex_value(value[index + 2]));
      index += 2;
    } else result += value[index] == '+' ? ' ' : value[index];
  }
  return result;
}

std::string url_encode(const std::string &value)
{
  static constexpr char digits[] = "0123456789ABCDEF";
  std::string result;
  for (unsigned char character : value) {
    if (std::isalnum(character) || character == '-' || character == '.' || character == '_' || character == '~') result += static_cast<char>(character);
    else { result += '%'; result += digits[character >> 4]; result += digits[character & 15]; }
  }
  return result;
}

using Query = std::vector<std::pair<std::string, std::string>>;

Query parse_query(const std::string &query)
{
  Query result;
  std::size_t start = 0;
  while (start <= query.size() && !query.empty()) {
    const std::size_t end = query.find('&', start);
    const std::string field = query.substr(start, end - start);
    const std::size_t equals = field.find('=');
    result.emplace_back(url_decode(field.substr(0, equals)),
      equals == std::string::npos ? std::string() : url_decode(field.substr(equals + 1)));
    if (end == std::string::npos) break;
    start = end + 1;
  }
  return result;
}

std::string encode_query(const Query &query)
{
  std::string result, separator;
  for (const auto &[name, value] : query) {
    result += separator + url_encode(name) + '=' + url_encode(value);
    separator = "&";
  }
  return result;
}

std::pair<std::string, std::optional<std::string>> split_build_purl(const std::string &purl)
{
  if (purl.rfind("pkg:", 0) || purl.find('@') == std::string::npos) throw std::runtime_error("expected a versioned PURL: " + purl);
  const std::size_t fragment_at = purl.find('#');
  const std::string body = purl.substr(0, fragment_at);
  const std::string fragment = fragment_at == std::string::npos ? std::string() : purl.substr(fragment_at);
  const std::size_t query_at = body.find('?');
  const std::string base = body.substr(0, query_at);
  Query query = parse_query(query_at == std::string::npos ? std::string() : body.substr(query_at + 1));
  std::optional<std::string> build;
  Query remaining;
  for (const auto &field : query) {
    if (field.first == build_qualifier) {
      if (build || field.second.empty()) throw std::runtime_error("ambiguous or empty build qualifier");
      build = field.second;
    } else remaining.push_back(field);
  }
  std::string source = base;
  if (!remaining.empty()) source += '?' + encode_query(remaining);
  return {source + fragment, build};
}

std::string build_purl(const std::string &purl, const std::string &build_id)
{
  const auto [source, previous] = split_build_purl(purl);
  if (previous) throw std::runtime_error("cannot qualify an already qualified PURL");
  const std::size_t fragment_at = source.find('#');
  const std::string body = source.substr(0, fragment_at);
  const std::string fragment = fragment_at == std::string::npos ? std::string() : source.substr(fragment_at);
  const std::size_t query_at = body.find('?');
  const std::string base = body.substr(0, query_at);
  Query query = parse_query(query_at == std::string::npos ? std::string() : body.substr(query_at + 1));
  query.emplace_back(build_qualifier, build_id);
  std::sort(query.begin(), query.end());
  return base + '?' + encode_query(query) + fragment;
}

std::vector<std::string> package_purls(const Json &package)
{
  std::vector<std::string> result;
  for (const Json &reference : package.value("externalRefs", Json::array())) {
    if (reference.at("referenceType") == "purl") result.push_back(reference.at("referenceLocator"));
  }
  return result;
}

Json package_view(Json source)
{
  std::set<std::string> identifiers = {"SPDXRef-DOCUMENT"};
  for (Json &package : source.at("packages")) {
    identifiers.insert(package.at("SPDXID"));
    package["filesAnalyzed"] = false;
    package.erase("packageVerificationCode"); package.erase("hasFiles");
  }
  source.erase("files"); source.erase("snippets");
  Json relationships = Json::array();
  for (const Json &relationship : source.at("relationships")) {
    if (identifiers.count(relationship.at("spdxElementId")) && identifiers.count(relationship.at("relatedSpdxElement"))) relationships.push_back(relationship);
  }
  source["relationships"] = relationships;
  return source;
}

std::map<std::string, std::vector<Json>> installed_files(const Json &manifest, const fs::path &root)
{
  if (manifest.value("schema", "") != "https://brlcad.org/schema/bext-component-manifest-v2") {
    throw std::runtime_error("expected a finalized component manifest v2");
  }
  std::vector<Json> entries = manifest.at("files").get<std::vector<Json>>();
  std::sort(entries.begin(), entries.end(), [](const Json &left, const Json &right) { return left.at("path") < right.at("path"); });
  struct Work { std::string name; std::string component; fs::path path; bool symlink; };
  const fs::path resolved_root = resolved_path(root);
  std::set<std::string> names;
  std::vector<Work> work;
  work.reserve(entries.size());
  for (const Json &entry : entries) {
    const std::string name = relative_name(entry.at("path"));
    if (!names.insert(name).second) throw std::runtime_error("duplicate installed artifact: " + name);
    const fs::path path = resolved_root / fs::u8path(name);
    const fs::file_status status = fs::symlink_status(path);
    const bool symlink = fs::is_symlink(status);
    if ((!symlink && !fs::is_regular_file(status)) || (symlink && !fs::exists(path))) {
      throw std::runtime_error("finalized artifact is missing: " + name);
    }
    const fs::path target = resolved_path(path);
    if (!is_within(resolved_root, target)) throw std::runtime_error("finalized artifact escapes its root: " + name);
    if (symlink && !fs::is_regular_file(target) && !fs::is_directory(target)) {
      throw std::runtime_error("finalized artifact has an unsupported symlink target: " + name);
    }
    work.push_back({name, entry.at("component"), path, symlink});
  }
  std::vector<Json> records(work.size());
  std::atomic<std::size_t> next{0};
  std::atomic<bool> failed{false};
  std::mutex error_mutex;
  std::string error_message;
  const unsigned int workers = static_cast<unsigned int>(std::max<std::size_t>(1,
    std::min<std::size_t>({work.size(), 16, std::max(1U, std::thread::hardware_concurrency())})));
  const auto worker = [&] {
    while (!failed.load()) {
      const std::size_t index = next.fetch_add(1);
      if (index >= work.size()) return;
      try {
        const Work &item = work[index];
        Json record = {{"path", item.name},
          {"sha256", item.symlink ? sha256(fs::read_symlink(item.path).u8string()) : file_sha256(item.path)}};
        if (item.symlink) record["linkTarget"] = fs::relative(resolved_path(item.path), resolved_root).generic_string();
        records[index] = record;
      } catch (const std::exception &exception) {
        std::lock_guard<std::mutex> lock(error_mutex);
        if (!failed.exchange(true)) error_message = exception.what();
      }
    }
  };
  std::vector<std::thread> threads;
  for (unsigned int index = 0; index < workers; ++index) threads.emplace_back(worker);
  for (std::thread &thread : threads) thread.join();
  if (failed) throw std::runtime_error(error_message);
  std::map<std::string, std::vector<Json>> files;
  for (std::size_t index = 0; index < work.size(); ++index) files[work[index].component].push_back(records[index]);
  return files;
}

struct Inventory {
  Json document;
  std::map<std::string, std::string> selected;
  std::map<std::pair<std::string, std::string>, std::string> original_ids;
  Json builds;
  std::string identity;
  std::string context;
};

Inventory build_inventory(const Json &source, const Json &manifest,
  const std::map<std::string, std::vector<Json>> &files, const std::string &product)
{
  Inventory inventory{source, {}, {}, Json::object(), {}, {}};
  std::map<std::string, Json *> packages;
  for (Json &package : inventory.document.at("packages")) packages[package.at("SPDXID")] = &package;
  inventory.context = digest({{"product", product}, {"platform", manifest.at("platform")}, {"files", files}});
  for (const Json &record : manifest.at("packages")) {
    const std::string component = record.at("component"), identifier = record.at("spdx_id");
    const std::string output = record.value("output", "");
    if (output != "install" && output != "noinstall") throw std::runtime_error("component manifest lacks output scope; re-finalize the build");
    if (!packages.count(identifier)) throw std::runtime_error("unknown package in component manifest: " + identifier);
    if (output != "install" || !files.count(component) || files.at(component).empty()) continue;
    if (inventory.selected.count(identifier)) throw std::runtime_error("duplicate selected package: " + identifier);
    Json &package = *packages.at(identifier);
    const std::vector<std::string> upstream = package_purls(package);
    if (upstream.size() != 1 || split_build_purl(upstream.front()).second) throw std::runtime_error(identifier + ": expected one unqualified source PURL");
    const std::string original = record.value("source_spdx_id", identifier);
    const Json source_info = package.contains("packageSourceInfo") ? package.at("packageSourceInfo") : Json(nullptr);
    const std::string build_id = digest({{"component", component}, {"package", original},
      {"productContext", inventory.context}, {"sourcePurl", upstream.front()},
      {"version", package.at("versionInfo")}, {"source", source_info},
      {"platform", manifest.at("platform")}, {"files", files.at(component)}});
    const std::string qualified = build_purl(upstream.front(), build_id);
    for (Json &reference : package.at("externalRefs")) if (reference.at("referenceType") == "purl") reference["referenceLocator"] = qualified;
    package["annotations"].push_back({{"annotationDate", source.at("creationInfo").at("created")},
      {"annotationType", "OTHER"}, {"annotator", "Tool: bext_supply_chain"},
      {"comment", compact_json({{"bext:source:purl", upstream.front()}, {"bext:build:id", build_id}})}});
    inventory.selected[identifier] = component;
    const auto original_key = std::make_pair(component, original);
    if (inventory.original_ids.count(original_key)) throw std::runtime_error("duplicate imported package identity: " + original);
    inventory.original_ids[original_key] = identifier;
    inventory.builds[identifier] = {{"id", build_id}, {"sourcePurl", upstream.front()}, {"purl", qualified}};
  }
  inventory.identity = digest({{"product", product}, {"platform", manifest.at("platform")},
    {"packages", inventory.builds}, {"sourceDocument", source.at("documentNamespace")}});
  inventory.document["name"] = product + "-build";
  inventory.document["documentNamespace"] = "https://brlcad.org/sbom/build/" + inventory.identity;
  inventory.document["comment"] = "Finalized installed-product inventory. Qualified PURLs identify built variants; annotations retain upstream identities.";
  Json selected_packages = Json::array();
  for (const Json &package : inventory.document.at("packages")) if (inventory.selected.count(package.at("SPDXID"))) selected_packages.push_back(package);
  inventory.document["packages"] = selected_packages;
  Json relationships = Json::array();
  std::set<std::string> described;
  for (const Json &relation : inventory.document.at("relationships")) {
    const std::string left = relation.at("spdxElementId"), right = relation.at("relatedSpdxElement");
    if (inventory.selected.count(right) && (inventory.selected.count(left) ||
        (left == "SPDXRef-DOCUMENT" && relation.at("relationshipType") == "DESCRIBES"))) {
      relationships.push_back(relation);
      if (relation.at("relationshipType") == "DESCRIBES") described.insert(right);
    }
  }
  for (const auto &selected : inventory.selected) if (!described.count(selected.first)) relationships.push_back(
    {{"spdxElementId", "SPDXRef-DOCUMENT"}, {"relationshipType", "DESCRIBES"}, {"relatedSpdxElement", selected.first}});
  std::sort(relationships.begin(), relationships.end(), [](const Json &left, const Json &right) {
    return std::make_tuple(left.at("spdxElementId").get<std::string>(), left.at("relationshipType").get<std::string>(), left.at("relatedSpdxElement").get<std::string>()) <
      std::make_tuple(right.at("spdxElementId").get<std::string>(), right.at("relationshipType").get<std::string>(), right.at("relatedSpdxElement").get<std::string>());
  });
  inventory.document["relationships"] = relationships;
  return inventory;
}


struct Aliases {
  std::map<std::string, Json> records;
  std::string identity;
};

using Transformations = std::map<std::pair<std::string, std::string>, Json>;

struct Generated {
  Json inventory;
  std::optional<Json> vex;
  Json evidence;
  Json report;
};

std::map<std::string, Json *> component_index(Json &bom)
{
  std::map<std::string, Json *> result;
  const auto visit = [&](auto &&self, Json &items) -> void {
    for (Json &component : items) {
      const std::string identifier = component.at("bom-ref");
      if (!result.emplace(identifier, &component).second) throw std::runtime_error("duplicate CycloneDX component " + identifier);
      if (component.contains("components")) self(self, component.at("components"));
    }
  };
  visit(visit, bom.at("components"));
  return result;
}

Json cyclonedx_inventory(const Json &inventory)
{
  const std::string name = inventory.at("name"), namespace_name = inventory.at("documentNamespace");
  Json bom = {{"$schema", "https://cyclonedx.org/schema/bom-1.6.schema.json"},
    {"bomFormat", "CycloneDX"}, {"specVersion", "1.6"},
    {"serialNumber", "urn:uuid:" + uuid_v5_url(namespace_name)}, {"version", 1}};
  bom["metadata"] = {{"timestamp", inventory.at("creationInfo").at("created")},
    {"lifecycles", Json::array({{{"phase", "pre-build"}}})},
    {"component", {{"type", "application"}, {"bom-ref", namespace_name}, {"name", name}}},
    {"tools", {{"components", Json::array({{{"type", "application"}, {"name", "bext_supply_chain"}}})}}},
    {"licenses", Json::array({{{"license", {{"id", "CC0-1.0"}}}}})}};
  std::map<std::string, Json> licenses;
  for (const Json &license : inventory.value("hasExtractedLicensingInfos", Json::array())) {
    licenses[license.at("licenseId")] = {{"license", {{"name", license.at("name")},
      {"text", {{"contentType", "text/plain"}, {"content", license.at("extractedText")}}},
      {"licensing", {{"altIds", Json::array({license.at("licenseId")})}}}}}};
  }
  std::vector<std::string> identifiers;
  std::map<std::string, Json> components;
  for (const Json &package : inventory.at("packages")) {
    const std::string identifier = package.at("SPDXID");
    if (components.count(identifier)) throw std::runtime_error("duplicate SBOM package " + identifier);
    identifiers.push_back(identifier);
    std::string type = package.at("primaryPackagePurpose");
    std::transform(type.begin(), type.end(), type.begin(), [](unsigned char value) { return static_cast<char>(std::tolower(value)); });
    if (type == "container" || type == "source" || type == "other") type = "library";
    else if (type == "archive") type = "file";
    else if (type == "install") type = "application";
    Json component = {{"type", type}, {"bom-ref", identifier}};
    for (const auto &[source, target] : std::vector<std::pair<std::string, std::string>>{{"name", "name"}, {"versionInfo", "version"}, {"copyrightText", "copyright"}}) {
      if (package.at(source) != "NOASSERTION") component[target] = package.at(source);
    }
    Json properties = Json::array();
    for (const Json &annotation : package.value("annotations", Json::array())) if (annotation.at("annotator") == "Tool: bext:membership") {
      properties.push_back({{"name", "bext:membership"}, {"value", annotation.at("comment")}});
    }
    for (const std::string field : {"primaryPackagePurpose", "packageSourceInfo", "comment", "licenseDeclared", "licenseConcluded", "copyrightText"}) {
      properties.push_back({{"name", "bext:spdx:" + field}, {"value", package.at(field)}});
    }
    component["properties"] = properties;
    const std::string download = package.at("downloadLocation");
    if (download != "NONE" && download != "NOASSERTION") component["externalReferences"] = Json::array({{{"type", "distribution"}, {"url", download}}});
    for (const Json &reference : package.value("externalRefs", Json::array())) {
      const std::string type_name = reference.at("referenceType");
      if (type_name == "purl") component["purl"] = reference.at("referenceLocator");
      else if (type_name == "cpe23Type") component["cpe"] = reference.at("referenceLocator");
      else throw std::runtime_error("unsupported source inventory reference " + type_name);
    }
    const std::string declared = package.at("licenseDeclared"), concluded = package.at("licenseConcluded");
    const std::string expression = concluded == "NOASSERTION" ? declared : concluded;
    if (expression != "NONE" && expression != "NOASSERTION") component["licenses"] = Json::array({{{"expression", expression}, {"acknowledgement", concluded == "NOASSERTION" ? "declared" : "concluded"}}});
    Json evidence = Json::array();
    const std::regex license_pattern("LicenseRef-[A-Za-z0-9.-]+");
    const std::string combined = declared + ' ' + concluded;
    for (std::sregex_iterator item(combined.begin(), combined.end(), license_pattern), end; item != end; ++item) {
      const std::string license_id = item->str();
      if (!licenses.count(license_id)) throw std::runtime_error("undefined custom license " + license_id);
      if (std::find(evidence.begin(), evidence.end(), licenses.at(license_id)) == evidence.end()) evidence.push_back(licenses.at(license_id));
    }
    if (!evidence.empty()) component["evidence"] = {{"licenses", evidence}};
    components[identifier] = component;
  }
  const std::set<std::string> known(identifiers.begin(), identifiers.end());
  std::map<std::string, std::string> parents;
  std::map<std::string, std::vector<std::string>> children, dependencies;
  for (const Json &relationship : inventory.at("relationships")) {
    const std::string source = relationship.at("spdxElementId"), target = relationship.at("relatedSpdxElement"), type = relationship.at("relationshipType");
    if (type == "DESCRIBES") continue;
    if (!known.count(source) || !known.count(target)) throw std::runtime_error("unknown SBOM relationship endpoint");
    if (type == "CONTAINS") {
      if (parents.count(target) && parents.at(target) != source) throw std::runtime_error("multiple containment parents for " + target);
      parents[target] = source; children[source].push_back(target);
    } else if (type == "DEPENDS_ON") dependencies[source].push_back(target);
    else throw std::runtime_error("unsupported SBOM relationship " + type);
  }
  const auto tree = [&](auto &&self, const std::string &identifier) -> Json {
    Json component = components.at(identifier);
    Json nested = Json::array();
    for (const std::string &child : children[identifier]) nested.push_back(self(self, child));
    if (!nested.empty()) component["components"] = nested;
    return component;
  };
  Json roots = Json::array(), dependency_nodes = Json::array(), root_dependencies = Json::array();
  for (const std::string &identifier : identifiers) {
    std::set<std::string> ancestors;
    std::string ancestor = identifier;
    while (parents.count(ancestor)) {
      if (!ancestors.insert(ancestor).second) throw std::runtime_error("cyclic SBOM containment at " + ancestor);
      ancestor = parents.at(ancestor);
    }
    if (!parents.count(identifier)) { roots.push_back(tree(tree, identifier)); root_dependencies.push_back(identifier); }
    std::vector<std::string> targets = dependencies[identifier];
    std::vector<std::string> unique;
    for (const std::string &target : targets) if (std::find(unique.begin(), unique.end(), target) == unique.end()) unique.push_back(target);
    dependency_nodes.push_back({{"ref", identifier}, {"dependsOn", unique}});
  }
  dependency_nodes.push_back({{"ref", namespace_name}, {"dependsOn", root_dependencies}});
  bom["components"] = roots;
  bom["dependencies"] = dependency_nodes;
  return bom;
}

struct Projection {
  Json document;
  Json coverage;
};

Projection project_inventory(Json result, const Aliases &aliases, const std::string &profile)
{
  static const std::string comment = "Vulnerability-matching projection of the bext source inventory. Aliases identify upstream advisory candidates; they do not assert that ecosystem artifacts were installed or that findings apply to patched sources.";
  const bool spdx = result.value("spdxVersion", "") == "SPDX-2.3";
  if (!spdx && result.value("bomFormat", "") != "CycloneDX") throw std::runtime_error("expected SPDX 2.3 or CycloneDX JSON");
  std::string source_document;
  Json *packages = nullptr;
  if (spdx) {
    source_document = result.at("documentNamespace");
    if (source_document.find("/scan-projection/") != std::string::npos) throw std::runtime_error("input is already a scanner projection");
    result["documentNamespace"] = source_document + "/scan-projection/" + profile + '/' + aliases.identity;
    result["name"] = result.at("name").get<std::string>() + "-scan-" + profile;
    result["comment"] = comment;
    packages = &result.at("packages");
  } else {
    Json &properties = result["metadata"]["properties"];
    if (std::any_of(properties.begin(), properties.end(), [](const Json &item) { return item.at("name") == "bext:scan:profile"; })) throw std::runtime_error("input is already a scanner projection");
    const std::string source_serial = result.at("serialNumber");
    source_document = result.at("metadata").at("component").at("bom-ref");
    const std::string projected = source_document + "/scan-projection/" + profile + '/' + aliases.identity;
    result["metadata"]["component"]["bom-ref"] = projected;
    result["metadata"]["component"]["name"] = result.at("metadata").at("component").at("name").get<std::string>() + "-scan-" + profile;
    for (Json &dependency : result.at("dependencies")) if (dependency.at("ref") == source_document) dependency["ref"] = projected;
    result["serialNumber"] = "urn:uuid:" + uuid_v5_url(projected);
    properties.push_back({{"name", "bext:scan:profile"}, {"value", profile}});
    properties.push_back({{"name", "bext:scan:sourceSerialNumber"}, {"value", source_serial}});
    properties.push_back({{"name", "bext:scan:componentLayout"}, {"value", "flat"}});
    properties.push_back({{"name", "bext:scan:comment"}, {"value", comment}});
    Json flattened = Json::array();
    const auto flatten = [&](auto &&self, const Json &items, const std::optional<std::string> &parent) -> void {
      for (Json component : items) {
        const std::string identifier = component.at("bom-ref");
        const Json children = component.value("components", Json::array());
        component.erase("components");
        if (parent) component["properties"].push_back({{"name", "bext:source:parent"}, {"value", *parent}});
        flattened.push_back(component);
        self(self, children, identifier);
      }
    };
    flatten(flatten, result.at("components"), std::nullopt);
    result["components"] = flattened;
    packages = &result.at("components");
  }
  Json report = {{"profile", profile}, {"sourceDocument", source_document},
    {"aliasTableSha256", aliases.identity}, {"totalPackages", packages->size()},
    {"mapped", Json::array()}, {"unmapped", Json::array()}};
  for (Json &package : *packages) {
    std::vector<std::string> purls;
    std::string identifier, version;
    if (spdx) {
      purls = package_purls(package); identifier = package.at("SPDXID"); version = package.at("versionInfo");
    } else {
      if (package.contains("purl")) purls.push_back(package.at("purl"));
      identifier = package.at("bom-ref"); version = package.at("version");
    }
    std::vector<std::pair<Json, std::optional<std::string>>> matches;
    for (const std::string &purl : purls) {
      const auto [source, build] = split_build_purl(purl);
      const auto alias = aliases.records.find(source);
      if (alias != aliases.records.end()) matches.emplace_back(alias->second, build);
    }
    if (matches.empty()) {
      report["unmapped"].push_back({{"id", identifier}, {"purls", purls}, {"reason", "No reviewed alias for this profile"}});
      continue;
    }
    if (matches.size() != 1) throw std::runtime_error("multiple applicable aliases for " + identifier);
    Json alias = matches.front().first;
    std::string target = alias.at("targetPurl");
    if (target.substr(target.rfind('@') + 1) != version) throw std::runtime_error(identifier + ": alias version differs from source version");
    if (matches.front().second) target = build_purl(target, *matches.front().second);
    Json provenance = alias;
    provenance["id"] = identifier; provenance["sourceName"] = package.at("name"); provenance["targetPurl"] = target;
    report["mapped"].push_back(provenance);
    const std::string lookup = target.substr(0, target.rfind('@'));
    package["name"] = url_decode(lookup.substr(lookup.rfind('/') + 1));
    if (spdx) {
      Json references = package.value("externalRefs", Json::array());
      const Json alias_reference = {{"referenceCategory", "PACKAGE-MANAGER"},
        {"referenceType", "purl"}, {"referenceLocator", target}};
      references.insert(references.begin(), alias_reference);
      package["externalRefs"] = references;
      package["annotations"].push_back({{"annotationDate", result.at("creationInfo").at("created")},
        {"annotationType", "OTHER"}, {"annotator", "Tool: bext_supply_chain"}, {"comment", compact_json(provenance)}});
    } else {
      package["purl"] = target;
      for (const Json &property : Json::array({{{"name", "bext:source:name"}, {"value", provenance.at("sourceName")}},
             {{"name", "bext:source:purl"}, {"value", alias.at("sourcePurl")}},
             {{"name", "bext:scan:alias"}, {"value", compact_json(provenance)}}})) {
        if (std::find(package["properties"].begin(), package["properties"].end(), property) == package["properties"].end()) package["properties"].push_back(property);
      }
    }
  }
  report["mappedPackages"] = report.at("mapped").size(); report["unmappedPackages"] = report.at("unmapped").size();
  std::set<std::string> targets;
  for (const Json &mapped : report.at("mapped")) targets.insert(mapped.at("targetPurl"));
  report["distinctMappedPurls"] = targets.size();
  return {result, report};
}

void write_base_outputs(const fs::path &directory, const std::string &product,
  Generated generated, const Aliases &aliases, const std::string &profile)
{
  const fs::path spdx = directory / (product + ".build.spdx.json");
  const fs::path cdx = directory / (product + ".build.cdx.json");
  write_json_atomic(spdx, generated.inventory);
  Json cyclonedx = cyclonedx_inventory(generated.inventory);
  cyclonedx["metadata"]["lifecycles"] = Json::array({{{"phase", "post-build"}}});
  const auto components = component_index(cyclonedx);
  for (const auto &[identifier, component] : components) {
    const Json &identity = generated.evidence.at("packageIdentities").at(identifier);
    (*component)["properties"].push_back({{"name", "bext:source:purl"}, {"value", identity.at("sourcePurl")}});
    (*component)["properties"].push_back({{"name", "bext:build:id"}, {"value", identity.at("id")}});
  }
  write_json_atomic(cdx, cyclonedx);
  for (const auto &[format, document] : std::vector<std::pair<std::string, Json>>{{"spdx", generated.inventory}, {"cdx", cyclonedx}}) {
    const Projection projection = project_inventory(document, aliases, profile);
    const std::string base = product + ".build." + profile + '.' + format;
    write_json_atomic(directory / (base + ".json"), projection.document);
    write_json_atomic(directory / (base + ".coverage.json"), projection.coverage);
  }
  write_json_atomic(directory / (product + "-vex-evidence.json"), generated.evidence);
  generated.report["vexGenerated"] = generated.vex.has_value();
  write_json_atomic(directory / (product + "-vex-report.json"), generated.report);
  if (generated.vex) write_json_atomic(directory / (product + ".openvex.json"), *generated.vex);
}

std::vector<std::string> output_names(const std::string &product, const std::string &profile)
{
  return {product + ".openvex.json", product + "-vex-evidence.json", product + "-vex-report.json",
    product + ".build.spdx.json", product + ".build.cdx.json",
    product + ".build." + profile + ".spdx.json", product + ".build." + profile + ".spdx.coverage.json",
    product + ".build." + profile + ".cdx.json", product + ".build." + profile + ".cdx.coverage.json"};
}

void publish_outputs(const fs::path &staged, const fs::path &directory,
  const std::vector<std::string> &names, const fs::path &backup)
{
  if (!fs::create_directory(backup)) throw std::runtime_error("publication backup already exists: " + backup.string());
  std::vector<std::string> preserved_names;
  std::vector<std::string> published_names;
  try {
    for (const std::string &name : names) {
      const fs::path destination = directory / name;
      if (fs::exists(destination)) {
        fs::rename(destination, backup / name);
        preserved_names.push_back(name);
      }
    }
    for (const std::string &name : names) {
      const fs::path publication = staged / name;
      if (fs::exists(publication)) {
        fs::rename(publication, directory / name);
        published_names.push_back(name);
      }
    }
    fs::remove_all(backup);
    fs::remove(staged);
  } catch (...) {
    std::error_code error;
    for (const std::string &name : published_names) fs::remove(directory / name, error);
    std::string restore_error;
    for (const std::string &name : preserved_names) {
      const fs::path preserved_path = backup / name;
      fs::rename(preserved_path, directory / name, error);
      if (error && restore_error.empty()) restore_error = error.message();
    }
    fs::remove_all(staged, error);
    if (!restore_error.empty()) {
      throw std::runtime_error("unable to restore the previous publication set from " +
        backup.string() + ": " + restore_error);
    }
    fs::remove_all(backup, error);
    throw;
  }
}


std::vector<std::string> review_failures(const Json &, const Json &,
  const std::vector<Json> &, const Json *);
std::map<std::string, std::string> import_bindings(const std::vector<Json> &,
  const std::vector<Json> &, const Transformations &, const std::string &);

Generated generate(Json source, const Json &manifest, const fs::path &install_root,
  const Json &evidence, const Aliases &aliases, const std::string &product,
  const std::string &author, bool imported, const Json *proof,
  const Transformations &transformations)
{
  const auto files = installed_files(manifest, install_root);
  Inventory inventory = build_inventory(source, manifest, files, product);
  Json statements = Json::array(), exported = Json::array(), decisions = Json::array();
  std::set<std::tuple<std::string, std::string, std::string>> reviewed;
  std::vector<std::string> dates = {source.at("creationInfo").at("created")};
  for (auto entry = evidence.begin(); entry != evidence.end(); ++entry) {
    const std::string component = entry.key();
    const Json capture = entry.value().at("capture");
    if (!capture.is_null()) dates.push_back(capture.at("capturedAt"));
    const std::vector<Json> artifacts = files.count(component) ? files.at(component) : std::vector<Json>{};
    const std::vector<Json> previous_files = entry.value().value("files", Json::array()).get<std::vector<Json>>();
    const std::map<std::string, std::string> bindings = imported ? import_bindings(previous_files, artifacts, transformations, component) : std::map<std::string, std::string>{};
    std::vector<std::string> inherited;
    if (imported) for (const Json &artifact : artifacts) if (!bindings.count(artifact.at("path"))) inherited.push_back("Imported component artifact differs: " + artifact.at("path").get<std::string>());
    Json applied = Json::array();
    for (const Json &review : entry.value().at("reviews")) {
      const auto review_key = std::make_tuple(component, review.at("package").get<std::string>(), review.at("vulnerability").get<std::string>());
      if (!reviewed.insert(review_key).second) throw std::runtime_error("duplicate VEX decision");
      const auto package_key = std::make_pair(component, review.at("package").get<std::string>());
      const auto identifier = inventory.original_ids.find(package_key);
      Json decision = {{"review", review.at("id")}, {"component", component},
        {"package", identifier == inventory.original_ids.end() ? Json(review.at("package")) : Json(identifier->second)},
        {"vulnerability", review.at("vulnerability")}};
      if (identifier == inventory.original_ids.end()) {
        decision["result"] = "not_installed"; decision["reasons"] = Json::array(); decisions.push_back(decision); continue;
      }
      Json current_capture = capture;
      if (imported && !current_capture.is_null()) {
        current_capture["installedArtifacts"] = Json::object();
        for (const auto &binding : bindings) current_capture["installedArtifacts"][binding.first] = binding.second;
      }
      const Json *component_proof = proof && proof->contains(component) ? &proof->at(component) : nullptr;
      std::vector<std::string> reasons = review_failures(review, current_capture, artifacts, component_proof);
      reasons.insert(reasons.end(), inherited.begin(), inherited.end());
      if (review.at("scope") == "product" && (imported || review.value("product", "") != product || review.at("conditions").value("productContext", "") != inventory.context)) reasons.push_back("Product context requires local applicability review");
      const Json &build = inventory.builds.at(identifier->second);
      if (build.at("sourcePurl") != review.at("sourcePurl")) reasons.push_back("Selected package upstream identity differs from the review");
      const std::vector<std::string> previous_applied = entry.value().value("appliedReviews", std::vector<std::string>{});
      if (imported && std::find(previous_applied.begin(), previous_applied.end(), review.at("id")) == previous_applied.end()) reasons.push_back("Imported evidence did not establish this review");
      if (reasons.empty()) {
        decision["result"] = "applied"; decision["status"] = review.at("status"); decision["reasons"] = Json::array(); applied.push_back(review.at("id"));
      } else { decision["result"] = "review_needed"; decision["reasons"] = reasons; }
      decisions.push_back(decision);
      dates.push_back(review.at("reviewedAt"));
      Json products = Json::array({{{"@id", build.at("purl")}}});
      const auto alias = aliases.records.find(build.at("sourcePurl"));
      if (alias != aliases.records.end()) products.push_back({{"@id", build_purl(alias->second.at("targetPurl"), build.at("id"))}});
      const std::string captured_at =
        capture.is_null() ? dates.front() : capture.at("capturedAt").get<std::string>();
      Json statement = {{"vulnerability", {{"name", review.at("vulnerability")}}}, {"products", products},
        {"status", reasons.empty() ? review.at("status") : Json("under_investigation")},
        {"timestamp", std::max(captured_at, review.at("reviewedAt").get<std::string>())},
        {"impact_statement", reasons.empty() ? review.at("impactStatement") : Json("Review conditions require investigation: " + [&] { std::string value, separator; for (const std::string &reason : reasons) { value += separator + reason; separator = "; "; } return value; }())},
        {"status_notes", "Evidence: " + [&] { std::string value, separator; for (const std::string reference : review.at("references")) { value += separator + reference; separator = "; "; } return value; }()}};
      if (reasons.empty() && review.at("status") == "not_affected") statement["justification"] = review.at("justification");
      if (reasons.empty() && review.at("status") == "affected") statement["action_statement"] = review.at("actionStatement");
      statements.push_back(statement);
    }
    exported.push_back({{"component", component}, {"capture", capture}, {"reviews", entry.value().at("reviews")}, {"files", artifacts}, {"appliedReviews", applied}});
  }
  std::sort(statements.begin(), statements.end(), [](const Json &left, const Json &right) {
    return std::make_pair(left.at("vulnerability").at("name").get<std::string>(), left.at("products").front().at("@id").get<std::string>()) <
      std::make_pair(right.at("vulnerability").at("name").get<std::string>(), right.at("products").front().at("@id").get<std::string>());
  });
  const std::string latest = *std::max_element(dates.begin(), dates.end());
  Json vex = {{"@context", "https://openvex.dev/ns/v0.2.0"}, {"author", author}, {"timestamp", latest}, {"version", 1}, {"statements", statements}};
  vex["@id"] = "https://brlcad.org/vex/" + digest(vex);
  inventory.document["creationInfo"]["created"] = latest;
  Json envelope = {{"schemaVersion", schema_version}, {"product", product}, {"buildId", inventory.identity},
    {"productContext", inventory.context}, {"sourceDocument", source.at("documentNamespace")},
    {"components", exported}, {"packageIdentities", inventory.builds}};
  Json unreviewed = Json::array();
  for (const auto &selected : inventory.selected) {
    const bool found = std::any_of(decisions.begin(), decisions.end(), [&](const Json &decision) { return decision.at("package") == selected.first; });
    if (!found) unreviewed.push_back(selected.first);
  }
  Json report = {{"schemaVersion", schema_version}, {"buildId", inventory.identity},
    {"productContext", inventory.context}, {"decisions", decisions}, {"unreviewedPackages", unreviewed}};
  return {inventory.document, statements.empty() ? std::nullopt : std::optional<Json>(vex), envelope, report};
}


std::vector<fs::path> alias_sources(const fs::path &path)
{
  if (!fs::is_directory(path)) return {path};
  std::vector<fs::path> result = {path / "CMake" / "SbomScanProfiles.json"};
  for (const fs::directory_entry &entry : fs::directory_iterator(path)) {
    const fs::path catalog = entry.path() / "SbomScanAliases.json";
    if (entry.is_directory() && fs::is_regular_file(catalog)) result.push_back(catalog);
  }
  std::sort(result.begin() + 1, result.end());
  return result;
}

Aliases read_aliases(const fs::path &path, const std::string &profile)
{
  const std::vector<fs::path> sources = alias_sources(path);
  const Json profiles = read_json(sources.front());
  if (profiles.value("schemaVersion", 0) != schema_version || !profiles.at("profiles").contains(profile)) throw std::runtime_error("unknown alias profile " + profile);
  const std::vector<std::string> types = profiles.at("profiles").at(profile);
  const std::set<std::string> allowed(types.begin(), types.end());
  const std::size_t first_catalog = fs::is_directory(path) ? 1 : 0;
  if (sources.size() == first_catalog) throw std::runtime_error("no dependency advisory alias catalogs were found");
  Aliases result;
  for (std::size_t index = first_catalog; index < sources.size(); ++index) {
    const Json catalog = read_json(sources[index]);
    if (catalog.value("schemaVersion", 0) != schema_version || !catalog.at("aliases").is_array()) throw std::runtime_error("invalid advisory alias catalog");
    std::set<std::string> local;
    for (const Json &alias : catalog.at("aliases")) {
      const std::string source = alias.at("sourcePurl"), target = alias.at("targetPurl");
      const std::size_t type_end = target.find('/', 4);
      const std::string type = target.substr(4, type_end - 4);
      if (!allowed.count(type)) continue;
      if (!local.insert(source).second || (result.records.count(source) && result.records.at(source) != alias)) throw std::runtime_error("ambiguous alias for " + source);
      result.records[source] = alias;
    }
  }
  Json ordered = Json::array();
  for (const auto &record : result.records) ordered.push_back(record.second);
  result.identity = digest({{"profile", profile}, {"types", types}, {"aliases", ordered}});
  return result;
}

Transformations read_transformations(const fs::path &path, const std::string &evidence_hash)
{
  const Json document = read_json(path);
  if (document.value("schemaVersion", 0) != schema_version || document.value("sourceEvidenceSha256", "") != evidence_hash) throw std::runtime_error("install transformations belong to different source evidence");
  Transformations result;
  for (const Json &record : document.at("files")) {
    const auto key = std::make_pair(record.at("component").get<std::string>(), relative_name(record.at("path")));
    if (!result.emplace(key, record).second) throw std::runtime_error("duplicate install transformation");
  }
  return result;
}

std::map<std::string, std::string> import_bindings(const std::vector<Json> &previous,
  const std::vector<Json> &current, const Transformations &transformations, const std::string &component)
{
  std::set<std::string> originals;
  for (const Json &item : previous) originals.insert(item.at("sha256"));
  std::map<std::string, std::string> result;
  for (const Json &item : current) {
    const std::string path = item.at("path"), hash = item.at("sha256");
    const auto receipt = transformations.find({component, path});
    if (originals.count(hash) || (receipt != transformations.end() && originals.count(receipt->second.at("sourceSha256")) && receipt->second.at("sha256") == hash)) result[path] = hash;
  }
  return result;
}


std::string wildcard_regex(const std::string &pattern)
{
  std::string result = "^";
  for (char character : pattern) {
    if (character == '*') result += ".*";
    else if (character == '?') result += '.';
    else { if (std::string(".^$|(){}+\\").find(character) != std::string::npos) result += static_cast<char>(92); result += character; }
  }
  return result + '$';
}

bool wildcard_match(const std::string &pattern, const std::string &value)
{
  return std::regex_match(value, std::regex(wildcard_regex(pattern)));
}

std::vector<std::string> review_failures(const Json &review, const Json &capture,
  const std::vector<Json> &artifacts, const Json *proof)
{
  if (capture.is_null()) return {"Build evidence is missing; rebuild this component"};
  std::vector<std::string> reasons = capture.at("errors").get<std::vector<std::string>>();
  const Json &conditions = review.at("conditions");
  for (auto item = conditions.at("sources").begin(); item != conditions.at("sources").end(); ++item) {
    const Json actual = capture.at("sources").value(item.key(), Json::object());
    if (actual.value("revision", "") != item.value() || !actual.value("clean", false)) reasons.push_back("Source revision or cleanliness changed: " + item.key());
  }
  for (auto item = capture.at("inputs").begin(); item != capture.at("inputs").end(); ++item) {
    if (!conditions.at("inputs").contains(item.key()) || conditions.at("inputs").at(item.key()) != item.value()) reasons.push_back("Unreviewed or changed source input: " + item.key());
  }
  for (const std::string name : conditions.at("requiredInputs")) if (!capture.at("inputs").contains(name)) reasons.push_back("Required source input was not used: " + name);
  for (auto item = conditions.at("stagedFiles").begin(); item != conditions.at("stagedFiles").end(); ++item) {
    if (!capture.at("stagedFiles").contains(item.key()) || capture.at("stagedFiles").at(item.key()) != item.value()) reasons.push_back("Staged source is missing or differs: " + item.key());
  }
  for (const std::string pattern : conditions.value("forbiddenArtifacts", Json::array())) {
    if (std::any_of(artifacts.begin(), artifacts.end(), [&](const Json &artifact) { return wildcard_match(pattern, artifact.at("path")); })) reasons.push_back("Forbidden artifact was included: " + pattern);
  }
  for (const Json &alternatives : conditions.at("requiredArtifacts")) {
    bool found = false;
    for (const Json &artifact : artifacts) for (const std::string pattern : alternatives) found = found || wildcard_match(pattern, artifact.at("path"));
    if (!found) {
      std::string reason = "Required artifact is missing: ", separator;
      for (const std::string pattern : alternatives) { reason += separator + pattern; separator = " or "; }
      reasons.push_back(reason);
    }
  }
  if (proof && proof->value("captureDigest", "") != digest(capture)) reasons.push_back("Finalization proof belongs to different captured evidence");
  Json observed = Json::object();
  if (proof) observed = proof->at("artifacts");
  else for (const Json &artifact : artifacts) observed[artifact.at("path")] = artifact.at("sha256");
  for (const Json &artifact : artifacts) {
    bool protected_artifact = false;
    for (const Json &alternatives : conditions.at("requiredArtifacts")) for (const std::string pattern : alternatives) protected_artifact = protected_artifact || wildcard_match(pattern, artifact.at("path"));
    if (!protected_artifact) continue;
    const std::string name = artifact.at("path");
    const Json previous = proof ? proof->value("previous", Json::object()) : Json::object();
    const Json previous_artifacts = previous.value("artifacts", Json::object());
    const std::vector<std::string> applied = previous.value("appliedReviews", std::vector<std::string>{});
    const bool preserved = previous_artifacts.contains(name) && std::find(applied.begin(), applied.end(), review.at("id")) != applied.end() &&
      observed.contains(name) && observed.at(name) == previous_artifacts.at(name);
    const bool captured = capture.at("installedArtifacts").contains(name);
    if (!captured || ((!observed.contains(name) || observed.at(name) != capture.at("installedArtifacts").at(name)) && !preserved)) reasons.push_back("Artifact differs from the captured installation: " + name);
  }
  return reasons;
}

Json load_registry(const Json &registry)
{
  if (registry.value("schemaVersion", 0) != schema_version || !registry.at("components").is_array()) throw std::runtime_error("unsupported VEX evidence registry");
  Json result = Json::object();
  for (const Json &registration : registry.at("components")) {
    const std::string component = registration.at("component");
    if (result.contains(component)) throw std::runtime_error("duplicate VEX evidence component: " + component);
    const Json catalog = read_json(fs::u8path(registration.at("reviews").get<std::string>()));
    validate_vex_catalog(catalog, component);
    const fs::path receipt = fs::u8path(registration.at("evidence").get<std::string>());
    result[component] = {{"component", component}, {"capture", fs::is_regular_file(receipt) ? read_json(receipt) : Json(nullptr)}, {"reviews", catalog.at("reviews")}};
  }
  return result;
}

Json exported_evidence(const Json &document)
{
  if (document.value("schemaVersion", 0) != schema_version || !document.at("components").is_array()) throw std::runtime_error("unsupported exported VEX evidence");
  Json result = Json::object();
  for (const Json &entry : document.at("components")) {
    const std::string component = entry.at("component");
    if (result.contains(component)) throw std::runtime_error("duplicate exported component: " + component);
    result[component] = entry;
  }
  return result;
}


}

int vex_generate(int argc, char **argv)
{
  const fs::path sbom = fs::u8path(required_option(argc, argv, "--sbom"));
  const fs::path manifest = fs::u8path(required_option(argc, argv, "--manifest"));
  const fs::path install_root = fs::u8path(required_option(argc, argv, "--install-root"));
  const fs::path output = fs::u8path(required_option(argc, argv, "--output-dir"));
  const std::optional<std::string> registry_name = option(argc, argv, "--registry");
  const std::optional<std::string> imported_name = option(argc, argv, "--import-evidence");
  if (registry_name.has_value() == imported_name.has_value()) throw std::runtime_error("exactly one of --registry and --import-evidence is required");
  const std::string product = option(argc, argv, "--product").value_or("bext");
  const std::string author = option(argc, argv, "--author").value_or("https://brlcad.org/");
  const std::string profile = option(argc, argv, "--profile").value_or("conan");
  if (!std::regex_match(product, std::regex("[a-z][a-z0-9_-]*")) || !std::regex_match(profile, std::regex("[a-z][a-z0-9_-]*"))) throw std::runtime_error("invalid product or profile name");
  if (author.rfind("https://", 0)) throw std::runtime_error("author must be an HTTPS URL");
  if (is_within(resolved_path(install_root), resolved_path(output))) throw std::runtime_error("VEX outputs must live outside the installed content tree");
  fs::create_directories(output);
  const std::vector<std::string> names = output_names(product, profile);
  Json source = read_json(sbom);
  if (source.value("spdxVersion", "") != "SPDX-2.3") throw std::runtime_error("a canonical SPDX 2.3 source inventory is required");
  std::optional<Json> file_inventory;
  const bool has_files = source.contains("files") && !source.at("files").empty();
  const bool analyzed = std::any_of(source.at("packages").begin(), source.at("packages").end(), [](const Json &package) { return package.value("filesAnalyzed", false); });
  if (flag(argc, argv, "--package-view")) {
    file_inventory = Json{{"document", source.at("documentNamespace")}, {"sha256", file_sha256(sbom)}};
    source = package_view(source);
  } else if (has_files || analyzed) throw std::runtime_error("use --package-view with an installed file-level inventory; keep the original document");
  const fs::path aliases_path = fs::u8path(option(argc, argv, "--aliases").value_or(fs::current_path().u8string()));
  const Aliases aliases = read_aliases(aliases_path, profile);
  const Json evidence = registry_name ? load_registry(read_json(fs::u8path(*registry_name))) : exported_evidence(read_json(fs::u8path(*imported_name)));
  Transformations transformations;
  const std::optional<std::string> transformation_name = option(argc, argv, "--import-transformations");
  if (transformation_name) {
    if (!imported_name) throw std::runtime_error("--import-transformations requires --import-evidence");
    transformations = read_transformations(fs::u8path(*transformation_name), file_sha256(fs::u8path(*imported_name)));
  }
  std::optional<Json> proof;
  if (const std::optional<std::string> proof_name = option(argc, argv, "--proof")) {
    if (imported_name) throw std::runtime_error("imported evidence must be checked against finalized bytes directly");
    const Json document = read_json(fs::u8path(*proof_name));
    if (document.value("schemaVersion", 0) != schema_version) throw std::runtime_error("unsupported finalization proof");
    proof = document.at("components");
  }
  Generated generated = generate(source, read_json(manifest), install_root, evidence, aliases,
    product, author, imported_name.has_value(), proof ? &*proof : nullptr, transformations);
  if (transformation_name) generated.report["installTransformations"] = {
    {"file", fs::u8path(*transformation_name).filename().u8string()}, {"sha256", file_sha256(fs::u8path(*transformation_name))}, {"files", transformations.size()}};
  if (file_inventory) {
    generated.report["fileInventory"] = *file_inventory;
    generated.inventory["comment"] = generated.inventory.at("comment").get<std::string>() + " This package view retains file-level checksums and ownership in its original inventory and companion ownership manifest.";
  }
  const std::string nonce = std::to_string(std::chrono::high_resolution_clock::now().time_since_epoch().count());
  const std::string transaction = sha256(product + nonce).substr(0, 16);
  const fs::path temporary = output / ("vex-native-" + transaction);
  const fs::path backup = output / ("vex-backup-" + transaction);
  fs::create_directories(temporary);
  try {
    write_base_outputs(temporary, product, generated, aliases, profile);
    publish_outputs(temporary, output, names, backup);
  } catch (...) {
    std::error_code error;
    fs::remove_all(temporary, error);
    throw;
  }
  std::map<std::string, std::size_t> counts = {{"applied", 0}, {"review_needed", 0}, {"not_installed", 0}};
  for (const Json &decision : generated.report.at("decisions")) ++counts.at(decision.at("result"));
  std::cout << "VEX reviews: " << counts["applied"] << " applied, " << counts["review_needed"]
            << " review_needed, " << counts["not_installed"] << " not_installed\n";
  if (!generated.vex) std::cout << "No installed reviewed packages; no OpenVEX document was emitted\n";
  return 0;
}

int sbom_project(int argc, char **argv)
{
  const fs::path input = fs::u8path(required_option(argc, argv, "--input"));
  const fs::path output = fs::u8path(required_option(argc, argv, "--output"));
  const fs::path report = fs::u8path(required_option(argc, argv, "--report"));
  if (resolved_path(input) == resolved_path(output) || resolved_path(input) == resolved_path(report) || resolved_path(output) == resolved_path(report)) {
    throw std::runtime_error("projection input, output, and report must be separate");
  }
  const std::string profile = option(argc, argv, "--profile").value_or("conan");
  const fs::path aliases_path = fs::u8path(option(argc, argv, "--aliases").value_or(fs::current_path().u8string()));
  const Projection projection = project_inventory(read_json(input), read_aliases(aliases_path, profile), profile);
  write_json_atomic(output, projection.document);
  write_json_atomic(report, projection.coverage);
  std::cout << "Projected " << projection.coverage.at("mappedPackages") << '/' << projection.coverage.at("totalPackages")
            << " packages for " << profile << " scanning\n";
  return 0;
}

}
