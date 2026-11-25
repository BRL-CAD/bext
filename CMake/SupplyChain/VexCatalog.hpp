/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#ifndef BEXT_SUPPLY_CHAIN_VEX_CATALOG_HPP
#define BEXT_SUPPLY_CHAIN_VEX_CATALOG_HPP

#include "Support.hpp"

#include <initializer_list>
#include <regex>
#include <set>
#include <string>

namespace bext {

inline void require_fields(const Json &value, std::initializer_list<const char *> required,
  std::initializer_list<const char *> optional, const std::string &label)
{
  if (!value.is_object()) throw std::runtime_error(label + " must be an object");
  std::set<std::string> allowed;
  for (const char *field : required) {
    allowed.insert(field);
    if (!value.contains(field)) throw std::runtime_error(label + " is missing " + field);
  }
  for (const char *field : optional) allowed.insert(field);
  for (auto field = value.begin(); field != value.end(); ++field) {
    if (!allowed.count(field.key())) throw std::runtime_error(label + " has unknown field " + field.key());
  }
}

inline bool matches(const Json &value, const char *pattern)
{
  return value.is_string() && std::regex_match(value.get<std::string>(), std::regex(pattern));
}

inline void validate_relative_name(const Json &value)
{
  if (!value.is_string()) throw std::runtime_error("expected a relative POSIX path");
  const std::string name = value;
  if (name.empty() || name.front() == '/' || name.back() == '/' ||
      name.find(static_cast<char>(92)) != std::string::npos || name.find(':') != std::string::npos) {
    throw std::runtime_error("expected a relative POSIX path: " + name);
  }
  std::size_t begin = 0;
  while (begin < name.size()) {
    const std::size_t end = name.find('/', begin);
    const std::string part = name.substr(begin, end - begin);
    if (part.empty() || part == "." || part == "..") {
      throw std::runtime_error("unsafe or non-normalized relative path: " + name);
    }
    if (end == std::string::npos) break;
    begin = end + 1;
  }
}

inline bool leap_year(int year)
{
  return !(year % 4) && ((year % 100) || !(year % 400));
}

inline void validate_timestamp(const Json &value)
{
  if (!matches(value, "[0-9]{4}(-[0-9]{2}){2}T[0-9]{2}(:[0-9]{2}){2}Z")) {
    throw std::runtime_error("VEX timestamps must use UTC seconds with a Z suffix");
  }
  const std::string timestamp = value;
  const int year = std::stoi(timestamp.substr(0, 4));
  const int month = std::stoi(timestamp.substr(5, 2));
  const int day = std::stoi(timestamp.substr(8, 2));
  const int hour = std::stoi(timestamp.substr(11, 2));
  const int minute = std::stoi(timestamp.substr(14, 2));
  const int second = std::stoi(timestamp.substr(17, 2));
  const int month_days[] = {0, 31, 28 + static_cast<int>(leap_year(year)), 31, 30, 31, 30,
                            31, 31, 30, 31, 30, 31};
  if (month < 1 || month > 12 || day < 1 || day > month_days[month] ||
      hour > 23 || minute > 59 || second > 59) {
    throw std::runtime_error("invalid VEX timestamp");
  }
}

inline void validate_digest_map(const Json &conditions, const char *field,
  std::size_t length, const std::string &identifier)
{
  const Json &values = conditions.at(field);
  if (!values.is_object() || values.empty()) {
    throw std::runtime_error(identifier + ": " + field + " must be a nonempty map");
  }
  const std::regex digest("[0-9a-f]{" + std::to_string(length) + "}");
  for (auto item = values.begin(); item != values.end(); ++item) {
    validate_relative_name(item.key());
    if (!item.value().is_string() || !std::regex_match(item.value().get<std::string>(), digest)) {
      throw std::runtime_error(identifier + ": invalid " + field + " digest for " + item.key());
    }
  }
}

inline void validate_vex_catalog(const Json &catalog, const std::string &expected_component = {})
{
  constexpr int schema_version = 1;
  const std::set<std::string> statuses = {
    "not_affected", "fixed", "affected", "under_investigation"};
  const std::set<std::string> justifications = {
    "component_not_present", "vulnerable_code_not_present",
    "vulnerable_code_not_in_execute_path",
    "vulnerable_code_cannot_be_controlled_by_adversary",
    "inline_mitigations_already_exist"};
  require_fields(catalog, {"schemaVersion", "component", "target", "reviews"}, {}, "VEX catalog");
  if (catalog.at("schemaVersion") != schema_version) throw std::runtime_error("unsupported VEX review schemaVersion");
  if (!matches(catalog.at("component"), "[a-z0-9][a-z0-9_-]*")) throw std::runtime_error("invalid VEX component");
  const std::string component = catalog.at("component");
  if (!expected_component.empty() && component != expected_component) {
    throw std::runtime_error("capture configuration and review catalog differ");
  }
  if (!matches(catalog.at("target"), "[A-Za-z0-9_]+")) throw std::runtime_error("invalid VEX build target");
  const Json &reviews = catalog.at("reviews");
  if (!reviews.is_array() || reviews.empty()) throw std::runtime_error("a VEX catalog requires reviews");
  std::set<std::string> identifiers;
  for (const Json &review : reviews) {
    require_fields(review,
      {"id", "package", "sourcePurl", "vulnerability", "status", "scope",
       "impactStatement", "reviewedAt", "references", "conditions"},
      {"product", "justification", "actionStatement"}, "VEX review");
    if (!matches(review.at("id"), "[a-z0-9][a-z0-9._-]*")) throw std::runtime_error("invalid VEX review ID");
    const std::string identifier = review.at("id");
    if (!identifiers.insert(identifier).second) throw std::runtime_error("repeated VEX review ID: " + identifier);
    if (!matches(review.at("vulnerability"), "CVE-[0-9]{4}-[0-9]{4,}")) throw std::runtime_error(identifier + ": expected a CVE identifier");
    if (!matches(review.at("package"), "SPDXRef-[A-Za-z0-9.-]+")) throw std::runtime_error(identifier + ": expected a source package ID");
    if (!review.at("sourcePurl").is_string()) throw std::runtime_error(identifier + ": expected a versioned PURL");
    const std::string purl = review.at("sourcePurl");
    if (purl.rfind("pkg:", 0) || purl.find('@') == std::string::npos) throw std::runtime_error(identifier + ": expected a versioned PURL");
    if (std::regex_search(purl, std::regex("[?&]bext_build="))) throw std::runtime_error(identifier + ": reviews must name an upstream PURL");
    if (!review.at("status").is_string() || !statuses.count(review.at("status"))) throw std::runtime_error(identifier + ": invalid status");
    const std::string status = review.at("status");
    if (!review.at("scope").is_string() || (review.at("scope") != "component" && review.at("scope") != "product")) {
      throw std::runtime_error(identifier + ": scope must be component or product");
    }
    const std::string scope = review.at("scope");
    if (status == "not_affected" && (!review.contains("justification") ||
        !review.at("justification").is_string() || !justifications.count(review.at("justification")))) {
      throw std::runtime_error(identifier + ": a not_affected review requires justification");
    }
    if (status == "not_affected" && scope == "component" && review.at("justification") != "vulnerable_code_not_present" &&
        review.at("justification") != "component_not_present") {
      throw std::runtime_error(identifier + ": execution-context conclusions require product scope");
    }
    if (!review.at("impactStatement").is_string() || review.at("impactStatement").get<std::string>().find_first_not_of(" \t\r\n") == std::string::npos) {
      throw std::runtime_error(identifier + ": an impact statement is required");
    }
    if (status == "affected" && (!review.contains("actionStatement") || !review.at("actionStatement").is_string() ||
        review.at("actionStatement").get<std::string>().find_first_not_of(" \t\r\n") == std::string::npos)) {
      throw std::runtime_error(identifier + ": an affected review requires an action statement");
    }
    validate_timestamp(review.at("reviewedAt"));
    const Json &references = review.at("references");
    if (!references.is_array() || references.empty()) throw std::runtime_error(identifier + ": HTTPS evidence references are required");
    for (const Json &reference : references) {
      if (!reference.is_string() || reference.get<std::string>().rfind("https://", 0)) throw std::runtime_error(identifier + ": HTTPS evidence references are required");
    }
    const Json &conditions = review.at("conditions");
    require_fields(conditions, {"sources", "inputs", "requiredInputs", "stagedFiles", "requiredArtifacts"},
      {"forbiddenArtifacts", "productContext"}, identifier + " conditions");
    if (scope == "product" && (!review.contains("product") || !review.at("product").is_string() || review.at("product").get<std::string>().empty() ||
        !conditions.contains("productContext") || !matches(conditions.at("productContext"), "[0-9a-f]{64}"))) {
      throw std::runtime_error(identifier + ": product scope requires a product and context digest");
    }
    if (scope == "component" && (review.contains("product") || conditions.contains("productContext"))) {
      throw std::runtime_error(identifier + ": component scope cannot declare a product context");
    }
    validate_digest_map(conditions, "sources", 40, identifier);
    validate_digest_map(conditions, "inputs", 64, identifier);
    validate_digest_map(conditions, "stagedFiles", 64, identifier);
    const Json &required_inputs = conditions.at("requiredInputs");
    if (!required_inputs.is_array() || required_inputs.empty()) throw std::runtime_error(identifier + ": requiredInputs must name reviewed inputs");
    std::set<std::string> input_names;
    for (auto input = conditions.at("inputs").begin(); input != conditions.at("inputs").end(); ++input) input_names.insert(input.key());
    for (const Json &name : required_inputs) {
      if (!name.is_string() || !input_names.count(name.get<std::string>())) throw std::runtime_error(identifier + ": requiredInputs must name reviewed inputs");
    }
    const Json forbidden = conditions.value("forbiddenArtifacts", Json::array());
    if (!forbidden.is_array()) throw std::runtime_error(identifier + ": forbiddenArtifacts must be a list");
    for (const Json &pattern : forbidden) validate_relative_name(pattern);
    const Json &required_artifacts = conditions.at("requiredArtifacts");
    if (!required_artifacts.is_array() || required_artifacts.empty()) throw std::runtime_error(identifier + ": installed artifact requirements are required");
    for (const Json &alternatives : required_artifacts) {
      if (!alternatives.is_array() || alternatives.empty()) throw std::runtime_error(identifier + ": artifact requirements need alternatives");
      for (const Json &pattern : alternatives) validate_relative_name(pattern);
    }
  }
}

}

#endif
