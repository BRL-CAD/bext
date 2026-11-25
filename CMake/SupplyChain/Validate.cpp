/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "Commands.hpp"
#include "Support.hpp"

#include <iostream>
#include <map>
#include <regex>
#include <set>
#include <string>

namespace bext {
namespace {

using Edge = std::pair<std::string, std::string>;

void require_object_fields(const Json &value, const std::set<std::string> &required,
  const std::set<std::string> &optional, const std::string &description)
{
  if (!value.is_object()) throw std::runtime_error(description + " must be an object");
  std::set<std::string> actual;
  for (const auto &item : value.items()) actual.insert(item.key());
  for (const std::string &field : required) if (!actual.count(field)) {
    throw std::runtime_error(description + " is missing " + field);
  }
  for (const std::string &field : actual) if (!required.count(field) && !optional.count(field)) {
    throw std::runtime_error(description + " has unknown field " + field);
  }
}

void require_nonempty_string(const Json &value, const std::string &description)
{
  if (!value.is_string() || value.get_ref<const std::string &>().empty()) {
    throw std::runtime_error(description + " must be a nonempty string");
  }
}

void validate_component_manifest(const Json &manifest)
{
  require_object_fields(manifest,
    {"schema", "platform", "install_root", "generated_by", "files", "packages"}, {},
    "component manifest");
  if (manifest.at("schema") != "https://brlcad.org/schema/bext-component-manifest-v2") {
    throw std::runtime_error("unsupported component manifest schema");
  }
  require_nonempty_string(manifest.at("platform"), "component manifest platform");
  if (manifest.at("install_root") != "install" && manifest.at("install_root") != ".") {
    throw std::runtime_error("component manifest install_root must be install or .");
  }
  if (manifest.at("generated_by") != "bext" && manifest.at("generated_by") != "brlcad") {
    throw std::runtime_error("component manifest generated_by must be bext or brlcad");
  }
  if (!manifest.at("files").is_array() || !manifest.at("packages").is_array()) {
    throw std::runtime_error("component manifest files and packages must be arrays");
  }
  for (const Json &file : manifest.at("files")) {
    require_object_fields(file, {"path", "component"}, {}, "component manifest file");
    require_nonempty_string(file.at("path"), "component manifest file path");
    require_nonempty_string(file.at("component"), "component manifest file component");
  }
  static const std::regex spdx_identifier("SPDXRef-[A-Za-z0-9.-]+");
  for (const Json &package : manifest.at("packages")) {
    require_object_fields(package, {"component", "id", "spdx_id", "primary", "output"},
      {"source_spdx_id"}, "component manifest package");
    require_nonempty_string(package.at("component"), "component manifest package component");
    require_nonempty_string(package.at("id"), "component manifest package id");
    if (!package.at("spdx_id").is_string() ||
        !std::regex_match(package.at("spdx_id").get<std::string>(), spdx_identifier)) {
      throw std::runtime_error("component manifest package has invalid spdx_id");
    }
    if (!package.at("primary").is_boolean()) {
      throw std::runtime_error("component manifest package primary must be boolean");
    }
    if (package.at("output") != "install" && package.at("output") != "noinstall") {
      throw std::runtime_error("component manifest package output must be install or noinstall");
    }
    if (package.contains("source_spdx_id") &&
        (!package.at("source_spdx_id").is_string() ||
         !std::regex_match(package.at("source_spdx_id").get<std::string>(), spdx_identifier))) {
      throw std::runtime_error("component manifest package has invalid source_spdx_id");
    }
  }
  std::cout << "Validated component manifest\n";
}

void index_components(const Json &items, const std::optional<std::string> &parent,
  std::map<std::string, Json> &components, std::set<Edge> &containment)
{
  for (const Json &component : items) {
    const std::string identifier = component.at("bom-ref");
    if (!components.emplace(identifier, component).second) throw std::runtime_error("duplicate CycloneDX component " + identifier);
    if (parent) containment.emplace(*parent, identifier);
    for (const Json &property : component.value("properties", Json::array())) if (property.at("name") == "bext:source:parent") containment.emplace(property.at("value"), identifier);
    index_components(component.value("components", Json::array()), identifier, components, containment);
  }
}

void check_parity(const Json &spdx, const Json &cyclonedx)
{
  std::map<std::string, Json> packages, components;
  std::set<Edge> containment;
  for (const Json &package : spdx.at("packages")) packages.emplace(package.at("SPDXID"), package);
  index_components(cyclonedx.value("components", Json::array()), std::nullopt, components, containment);
  for (const Edge &edge : containment) if (!components.count(edge.first)) throw std::runtime_error("unknown CycloneDX containment parent " + edge.first);
  std::set<std::string> package_ids, component_ids;
  for (const auto &item : packages) package_ids.insert(item.first);
  for (const auto &item : components) component_ids.insert(item.first);
  if (package_ids != component_ids) throw std::runtime_error("SPDX and CycloneDX package identifiers differ");
  const Json &metadata = cyclonedx.at("metadata");
  if (metadata.at("timestamp") != spdx.at("creationInfo").at("created") || metadata.at("component").at("name") != spdx.at("name") || metadata.at("component").at("bom-ref") != spdx.at("documentNamespace")) throw std::runtime_error("SPDX and CycloneDX document provenance differs");
  for (const auto &[identifier, package] : packages) {
    const Json &component = components.at(identifier);
    std::map<std::string, std::string> properties;
    for (const Json &property : component.value("properties", Json::array())) properties[property.at("name")] = property.at("value");
    std::vector<std::string> memberships;
    for (const Json &annotation : package.value("annotations", Json::array())) if (annotation.at("annotator") == "Tool: bext:membership") memberships.push_back(annotation.at("comment"));
    const std::optional<std::string> actual_membership = properties.count("bext:membership") ? std::optional<std::string>(properties.at("bext:membership")) : std::nullopt;
    const std::optional<std::string> expected_membership = memberships.empty() ? std::nullopt : std::optional<std::string>(memberships.front());
    if (memberships.size() > 1 || actual_membership != expected_membership) throw std::runtime_error(identifier + ": consumer-group membership differs");
    for (const std::string field : {"primaryPackagePurpose", "packageSourceInfo", "comment", "licenseDeclared", "licenseConcluded", "copyrightText"}) if (properties["bext:spdx:" + field] != package.at(field)) throw std::runtime_error(identifier + ": " + field + " differs");
    if (component.value("name", "") != package.at("name") || component.value("version", "") != package.at("versionInfo")) throw std::runtime_error(identifier + ": identity differs");
    const Json expected_copyright = package.at("copyrightText") == "NOASSERTION" ? Json(nullptr) : package.at("copyrightText");
    if (component.value("copyright", Json(nullptr)) != expected_copyright) throw std::runtime_error(identifier + ": copyright differs");
    std::map<std::string, std::string> references;
    for (const Json &reference : package.value("externalRefs", Json::array())) references.emplace(reference.at("referenceType"), reference.at("referenceLocator"));
    if ((references.count("purl") ? references.at("purl") : "") != component.value("purl", "") || (references.count("cpe23Type") ? references.at("cpe23Type") : "") != component.value("cpe", "")) throw std::runtime_error(identifier + ": external references differ");
    Json distributions = Json::array();
    for (const Json &reference : component.value("externalReferences", Json::array())) if (reference.at("type") == "distribution") distributions.push_back(reference.at("url"));
    Json expected_distributions = Json::array();
    if (package.at("downloadLocation") != "NONE" && package.at("downloadLocation") != "NOASSERTION") expected_distributions.push_back(package.at("downloadLocation"));
    if (distributions != expected_distributions) throw std::runtime_error(identifier + ": source download differs");
    std::string expression = package.at("licenseConcluded"), acknowledgement = "concluded";
    if (expression == "NOASSERTION") { expression = package.at("licenseDeclared"); acknowledgement = "declared"; }
    Json licenses = Json::array();
    if (expression != "NONE" && expression != "NOASSERTION") licenses.push_back({{"expression", expression}, {"acknowledgement", acknowledgement}});
    if (component.value("licenses", Json::array()) != licenses) throw std::runtime_error(identifier + ": effective license differs");
  }
  std::set<Edge> expected_containment, expected_dependencies;
  for (const Json &relationship : spdx.at("relationships")) {
    const Edge edge = {relationship.at("spdxElementId"), relationship.at("relatedSpdxElement")};
    if (relationship.at("relationshipType") == "CONTAINS") expected_containment.insert(edge);
    if (relationship.at("relationshipType") == "DEPENDS_ON") expected_dependencies.insert(edge);
  }
  if (containment != expected_containment) throw std::runtime_error("SPDX and CycloneDX containment differs");
  const std::string root = metadata.at("component").at("bom-ref");
  std::set<Edge> dependencies;
  std::set<std::string> nodes, roots;
  for (const Json &entry : cyclonedx.at("dependencies")) {
    const std::string source = entry.at("ref");
    if (!nodes.insert(source).second) throw std::runtime_error("duplicate CycloneDX dependency node");
    std::set<std::string> targets;
    for (const std::string target : entry.value("dependsOn", std::vector<std::string>{})) {
      if (!targets.insert(target).second || !components.count(target)) throw std::runtime_error("invalid CycloneDX dependency");
      if (source == root) roots.insert(target); else dependencies.emplace(source, target);
    }
  }
  if (nodes != [&] { std::set<std::string> expected = component_ids; expected.insert(root); return expected; }()) throw std::runtime_error("CycloneDX dependency nodes are incomplete");
  std::set<std::string> expected_roots = component_ids;
  for (const Edge &edge : containment) expected_roots.erase(edge.second);
  if (roots != expected_roots || dependencies != expected_dependencies) throw std::runtime_error("SPDX and CycloneDX dependency edges differ");
  std::cout << "Parity verified: " << packages.size() << " packages, " << dependencies.size()
            << " dependency edges, " << containment.size() << " containment edges\n";
}

}

int sbom_validate(int argc, char **argv)
{
  const std::optional<std::string> spdx = option(argc, argv, "--spdx");
  const std::optional<std::string> cyclonedx = option(argc, argv, "--cyclonedx");
  const std::optional<std::string> component_manifest = option(argc, argv, "--component-manifest");
  if (spdx.has_value() != cyclonedx.has_value()) {
    throw std::runtime_error("--spdx and --cyclonedx must be specified together for parity validation");
  }
  if (!spdx && !component_manifest) {
    throw std::runtime_error("provide an SPDX/CycloneDX pair or --component-manifest");
  }
  if (spdx) check_parity(read_json(fs::u8path(*spdx)), read_json(fs::u8path(*cyclonedx)));
  if (component_manifest) validate_component_manifest(read_json(fs::u8path(*component_manifest)));
  return 0;
}

}
