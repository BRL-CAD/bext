#ifndef BEXT_SUPPLY_CHAIN_SUPPORT_HPP
#define BEXT_SUPPLY_CHAIN_SUPPORT_HPP

#include "../json.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <optional>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace bext {

namespace fs = std::filesystem;
using Json = nlohmann::json;

class Sha256 {
public:
  void update(const unsigned char *data, std::size_t size)
  {
    total_size_ += size;
    while (size) {
      const std::size_t count = std::min(size, buffer_.size() - buffer_size_);
      std::copy_n(data, count, buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_));
      buffer_size_ += count;
      data += count;
      size -= count;
      if (buffer_size_ == buffer_.size()) {
        transform(buffer_.data());
        buffer_size_ = 0;
      }
    }
  }

  std::string finish()
  {
    const std::uint64_t bit_count = total_size_ * 8;
    buffer_[buffer_size_++] = 0x80;
    if (buffer_size_ > 56) {
      std::fill(buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_), buffer_.end(), 0);
      transform(buffer_.data());
      buffer_size_ = 0;
    }
    std::fill(buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_), buffer_.begin() + 56, 0);
    for (std::size_t index = 0; index != 8; ++index) buffer_[63 - index] = static_cast<unsigned char>(bit_count >> (index * 8));
    transform(buffer_.data());
    std::ostringstream output;
    output << std::hex << std::setfill('0');
    for (std::uint32_t value : state_) output << std::setw(8) << value;
    return output.str();
  }

private:
  static std::uint32_t rotate(std::uint32_t value, unsigned int count)
  {
    return (value >> count) | (value << (32 - count));
  }

  void transform(const unsigned char *block)
  {
    static constexpr std::array<std::uint32_t, 64> constants = {
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    };
    std::array<std::uint32_t, 64> words{};
    for (std::size_t index = 0; index != 16; ++index) {
      words[index] = static_cast<std::uint32_t>(block[index * 4]) << 24 |
        static_cast<std::uint32_t>(block[index * 4 + 1]) << 16 |
        static_cast<std::uint32_t>(block[index * 4 + 2]) << 8 |
        static_cast<std::uint32_t>(block[index * 4 + 3]);
    }
    for (std::size_t index = 16; index != words.size(); ++index) {
      const std::uint32_t first = rotate(words[index - 15], 7) ^ rotate(words[index - 15], 18) ^ (words[index - 15] >> 3);
      const std::uint32_t second = rotate(words[index - 2], 17) ^ rotate(words[index - 2], 19) ^ (words[index - 2] >> 10);
      words[index] = words[index - 16] + first + words[index - 7] + second;
    }
    std::uint32_t a = state_[0], b = state_[1], c = state_[2], d = state_[3];
    std::uint32_t e = state_[4], f = state_[5], g = state_[6], h = state_[7];
    for (std::size_t index = 0; index != words.size(); ++index) {
      const std::uint32_t choose = (e & f) ^ (~e & g);
      const std::uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
      const std::uint32_t first = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25);
      const std::uint32_t second = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22);
      const std::uint32_t temporary = h + first + choose + constants[index] + words[index];
      h = g; g = f; f = e; e = d + temporary; d = c; c = b; b = a; a = temporary + second + majority;
    }
    state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d;
    state_[4] += e; state_[5] += f; state_[6] += g; state_[7] += h;
  }

  std::array<std::uint32_t, 8> state_ = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  };
  std::array<unsigned char, 64> buffer_{};
  std::size_t buffer_size_ = 0;
  std::uint64_t total_size_ = 0;
};

class Sha1 {
public:
  void update(const unsigned char *data, std::size_t size)
  {
    total_size_ += size;
    while (size) {
      const std::size_t count = std::min(size, buffer_.size() - buffer_size_);
      std::copy_n(data, count, buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_));
      buffer_size_ += count; data += count; size -= count;
      if (buffer_size_ == buffer_.size()) { transform(buffer_.data()); buffer_size_ = 0; }
    }
  }

  std::array<unsigned char, 20> finish()
  {
    const std::uint64_t bit_count = total_size_ * 8;
    buffer_[buffer_size_++] = 0x80;
    if (buffer_size_ > 56) { std::fill(buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_), buffer_.end(), 0); transform(buffer_.data()); buffer_size_ = 0; }
    std::fill(buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_), buffer_.begin() + 56, 0);
    for (std::size_t index = 0; index != 8; ++index) buffer_[63 - index] = static_cast<unsigned char>(bit_count >> (index * 8));
    transform(buffer_.data());
    std::array<unsigned char, 20> result{};
    for (std::size_t index = 0; index != state_.size(); ++index) {
      result[index * 4] = static_cast<unsigned char>(state_[index] >> 24);
      result[index * 4 + 1] = static_cast<unsigned char>(state_[index] >> 16);
      result[index * 4 + 2] = static_cast<unsigned char>(state_[index] >> 8);
      result[index * 4 + 3] = static_cast<unsigned char>(state_[index]);
    }
    return result;
  }

private:
  static std::uint32_t rotate(std::uint32_t value, unsigned int count) { return value << count | value >> (32 - count); }
  void transform(const unsigned char *block)
  {
    std::array<std::uint32_t, 80> words{};
    for (std::size_t index = 0; index != 16; ++index) words[index] = static_cast<std::uint32_t>(block[index * 4]) << 24 |
      static_cast<std::uint32_t>(block[index * 4 + 1]) << 16 | static_cast<std::uint32_t>(block[index * 4 + 2]) << 8 | block[index * 4 + 3];
    for (std::size_t index = 16; index != words.size(); ++index) words[index] = rotate(words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16], 1);
    std::uint32_t a = state_[0], b = state_[1], c = state_[2], d = state_[3], e = state_[4];
    for (std::size_t index = 0; index != words.size(); ++index) {
      std::uint32_t function, constant;
      if (index < 20) { function = (b & c) | (~b & d); constant = 0x5a827999; }
      else if (index < 40) { function = b ^ c ^ d; constant = 0x6ed9eba1; }
      else if (index < 60) { function = (b & c) | (b & d) | (c & d); constant = 0x8f1bbcdc; }
      else { function = b ^ c ^ d; constant = 0xca62c1d6; }
      const std::uint32_t temporary = rotate(a, 5) + function + e + constant + words[index];
      e = d; d = c; c = rotate(b, 30); b = a; a = temporary;
    }
    state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d; state_[4] += e;
  }
  std::array<std::uint32_t, 5> state_ = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0};
  std::array<unsigned char, 64> buffer_{};
  std::size_t buffer_size_ = 0;
  std::uint64_t total_size_ = 0;
};

inline std::string uuid_v5_url(const std::string &name)
{
  static constexpr std::array<unsigned char, 16> url_namespace = {
    0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8};
  Sha1 hash;
  hash.update(url_namespace.data(), url_namespace.size());
  hash.update(reinterpret_cast<const unsigned char *>(name.data()), name.size());
  std::array<unsigned char, 20> bytes = hash.finish();
  bytes[6] = static_cast<unsigned char>((bytes[6] & 0x0f) | 0x50);
  bytes[8] = static_cast<unsigned char>((bytes[8] & 0x3f) | 0x80);
  std::ostringstream result;
  result << std::hex << std::setfill('0');
  for (std::size_t index = 0; index != 16; ++index) {
    if (index == 4 || index == 6 || index == 8 || index == 10) result << '-';
    result << std::setw(2) << static_cast<unsigned int>(bytes[index]);
  }
  return result.str();
}

inline std::string sha256(const std::string &value)
{
  Sha256 hash;
  hash.update(reinterpret_cast<const unsigned char *>(value.data()), value.size());
  return hash.finish();
}

inline std::string file_sha256(const fs::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("unable to open " + path.string());
  Sha256 hash;
  std::vector<unsigned char> buffer(1024 * 1024);
  while (input) {
    input.read(reinterpret_cast<char *>(buffer.data()), static_cast<std::streamsize>(buffer.size()));
    hash.update(buffer.data(), static_cast<std::size_t>(input.gcount()));
  }
  if (input.bad()) throw std::runtime_error("unable to read " + path.string());
  return hash.finish();
}

inline std::string read_text(const fs::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("unable to open " + path.string());
  std::ostringstream contents;
  contents << input.rdbuf();
  if (input.bad()) throw std::runtime_error("unable to read " + path.string());
  return contents.str();
}

inline Json read_json(const fs::path &path)
{
  std::vector<std::set<std::string>> keys;
  const auto callback = [&keys](int depth, Json::parse_event_t event, Json &value) {
    if (event == Json::parse_event_t::object_start) {
      const std::size_t first_child_depth = static_cast<std::size_t>(depth) + 1;
      if (keys.size() <= first_child_depth) keys.resize(first_child_depth + 1);
      for (std::size_t index = first_child_depth; index < keys.size(); ++index) keys[index].clear();
    } else if (event == Json::parse_event_t::key) {
      if (keys.size() <= static_cast<std::size_t>(depth)) keys.resize(static_cast<std::size_t>(depth) + 1);
      auto &object = keys.at(static_cast<std::size_t>(depth));
      const std::string key = value.get<std::string>();
      if (!object.insert(key).second) throw std::runtime_error("duplicate JSON field: " + key);
    }
    return true;
  };
  return Json::parse(read_text(path), callback, true, false);
}

inline std::string json_text(const Json &value)
{
  return value.dump(2, ' ', false, Json::error_handler_t::strict) + '\n';
}

inline std::string digest(const Json &value) { return sha256(json_text(value)); }

inline void write_text_atomic(const fs::path &path, const std::string &contents)
{
  if (!path.parent_path().empty()) fs::create_directories(path.parent_path());
  fs::path temporary = path;
  temporary += ".tmp";
  {
    std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
    if (!output || !(output << contents)) throw std::runtime_error("unable to write " + temporary.string());
  }
  std::error_code error;
  fs::remove(path, error);
  fs::rename(temporary, path);
}

inline void write_json_atomic(const fs::path &path, const Json &value)
{
  write_text_atomic(path, json_text(value));
}

inline fs::path resolved_path(const fs::path &path)
{
  std::error_code error;
  fs::path result = fs::weakly_canonical(path, error);
  if (error) throw std::runtime_error("unable to resolve " + path.string());
  return result;
}

inline bool is_within(const fs::path &root, const fs::path &path)
{
  auto root_part = root.begin();
  auto path_part = path.begin();
  while (root_part != root.end() && path_part != path.end() && *root_part == *path_part) {
    ++root_part;
    ++path_part;
  }
  return root_part == root.end();
}

inline std::string relative_name(const std::string &value)
{
  if (value.empty() || value.find(static_cast<char>(92)) != std::string::npos ||
      value.find(':') != std::string::npos) {
    throw std::runtime_error("expected a relative POSIX path: " + value);
  }
  const fs::path path = fs::u8path(value);
  if (path.is_absolute() || path.lexically_normal().generic_string() != value) {
    throw std::runtime_error("unsafe or non-normalized relative path: " + value);
  }
  for (const fs::path &part : path) if (part == "..") {
    throw std::runtime_error("unsafe or non-normalized relative path: " + value);
  }
  return value;
}

inline fs::path inside(const fs::path &root_value, const std::string &relative)
{
  const fs::path root = resolved_path(root_value);
  const fs::path candidate = resolved_path(root / fs::u8path(relative_name(relative)));
  if (!is_within(root, candidate)) throw std::runtime_error("path escapes its root: " + relative);
  return candidate;
}

inline std::optional<std::string> option(int argc, char **argv, const std::string &name)
{
  for (int index = 1; index + 1 < argc; ++index) if (argv[index] == name) return argv[index + 1];
  return std::nullopt;
}

inline bool flag(int argc, char **argv, const std::string &name)
{
  for (int index = 1; index < argc; ++index) if (argv[index] == name) return true;
  return false;
}

inline std::string required_option(int argc, char **argv, const std::string &name)
{
  const std::optional<std::string> value = option(argc, argv, name);
  if (!value) throw std::runtime_error("missing required argument " + name);
  return *value;
}

}

#endif
