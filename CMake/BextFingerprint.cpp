#include <algorithm>
#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {

namespace fs = std::filesystem;

constexpr std::size_t block_size = 64;
constexpr std::size_t digest_size = 32;
constexpr std::size_t read_buffer_size = 1024 * 1024;
constexpr std::size_t progress_interval = 2000;
constexpr unsigned int maximum_worker_count = 16;

constexpr std::array<std::uint32_t, 64> round_constants = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

std::uint32_t rotate_right(std::uint32_t value, unsigned int count)
{
  return (value >> count) | (value << (32 - count));
}

class Sha256 {
public:
  void update(const unsigned char *data, std::size_t size)
  {
    total_size_ += size;
    while (size > 0) {
      const std::size_t copy_size = std::min(size, block_size - buffer_size_);
      std::copy_n(data, copy_size, buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_));
      buffer_size_ += copy_size;
      data += copy_size;
      size -= copy_size;
      if (buffer_size_ == block_size) {
        transform(buffer_.data());
        buffer_size_ = 0;
      }
    }
  }

  std::array<unsigned char, digest_size> finish()
  {
    const std::uint64_t bit_count = total_size_ * 8;
    buffer_[buffer_size_++] = 0x80;
    if (buffer_size_ > 56) {
      std::fill(buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_), buffer_.end(), 0);
      transform(buffer_.data());
      buffer_size_ = 0;
    }
    std::fill(buffer_.begin() + static_cast<std::ptrdiff_t>(buffer_size_), buffer_.begin() + 56, 0);
    for (std::size_t index = 0; index < 8; ++index) {
      buffer_[63 - index] = static_cast<unsigned char>(bit_count >> (index * 8));
    }
    transform(buffer_.data());

    std::array<unsigned char, digest_size> digest{};
    for (std::size_t index = 0; index < state_.size(); ++index) {
      digest[index * 4] = static_cast<unsigned char>(state_[index] >> 24);
      digest[index * 4 + 1] = static_cast<unsigned char>(state_[index] >> 16);
      digest[index * 4 + 2] = static_cast<unsigned char>(state_[index] >> 8);
      digest[index * 4 + 3] = static_cast<unsigned char>(state_[index]);
    }
    return digest;
  }

private:
  void transform(const unsigned char *block);

  std::array<std::uint32_t, 8> state_ = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  };
  std::array<unsigned char, block_size> buffer_{};
  std::size_t buffer_size_ = 0;
  std::uint64_t total_size_ = 0;
};

void Sha256::transform(const unsigned char *block)
{
  std::array<std::uint32_t, 64> words{};
  for (std::size_t index = 0; index < 16; ++index) {
    words[index] = (static_cast<std::uint32_t>(block[index * 4]) << 24) |
      (static_cast<std::uint32_t>(block[index * 4 + 1]) << 16) |
      (static_cast<std::uint32_t>(block[index * 4 + 2]) << 8) |
      static_cast<std::uint32_t>(block[index * 4 + 3]);
  }
  for (std::size_t index = 16; index < words.size(); ++index) {
    const std::uint32_t first = rotate_right(words[index - 15], 7) ^
      rotate_right(words[index - 15], 18) ^ (words[index - 15] >> 3);
    const std::uint32_t second = rotate_right(words[index - 2], 17) ^
      rotate_right(words[index - 2], 19) ^ (words[index - 2] >> 10);
    words[index] = words[index - 16] + first + words[index - 7] + second;
  }

  std::uint32_t a = state_[0];
  std::uint32_t b = state_[1];
  std::uint32_t c = state_[2];
  std::uint32_t d = state_[3];
  std::uint32_t e = state_[4];
  std::uint32_t f = state_[5];
  std::uint32_t g = state_[6];
  std::uint32_t h = state_[7];
  for (std::size_t index = 0; index < words.size(); ++index) {
    const std::uint32_t choose = (e & f) ^ (~e & g);
    const std::uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
    const std::uint32_t first = rotate_right(e, 6) ^ rotate_right(e, 11) ^ rotate_right(e, 25);
    const std::uint32_t second = rotate_right(a, 2) ^ rotate_right(a, 13) ^ rotate_right(a, 22);
    const std::uint32_t temporary_one = h + first + choose + round_constants[index] + words[index];
    const std::uint32_t temporary_two = second + majority;
    h = g;
    g = f;
    f = e;
    e = d + temporary_one;
    d = c;
    c = b;
    b = a;
    a = temporary_one + temporary_two;
  }
  state_[0] += a;
  state_[1] += b;
  state_[2] += c;
  state_[3] += d;
  state_[4] += e;
  state_[5] += f;
  state_[6] += g;
  state_[7] += h;
}

std::string digest_file(const fs::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    throw std::runtime_error("unable to open " + path.string());
  }
  Sha256 hash;
  std::vector<unsigned char> buffer(read_buffer_size);
  while (input) {
    input.read(reinterpret_cast<char *>(buffer.data()), static_cast<std::streamsize>(buffer.size()));
    hash.update(buffer.data(), static_cast<std::size_t>(input.gcount()));
  }
  if (!input.eof()) {
    throw std::runtime_error("unable to read " + path.string());
  }
  std::ostringstream output;
  output << std::hex << std::setfill('0');
  for (const unsigned char byte : hash.finish()) {
    output << std::setw(2) << static_cast<unsigned int>(byte);
  }
  return output.str();
}

std::vector<std::string> read_file_list(const fs::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    throw std::runtime_error("unable to open file list " + path.string());
  }
  std::vector<std::string> files;
  std::string line;
  while (std::getline(input, line)) {
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    if (!line.empty()) {
      files.push_back(line);
    }
  }
  if (!input.eof()) {
    throw std::runtime_error("unable to read file list " + path.string());
  }
  return files;
}

std::string require_argument(int argc, char **argv, const std::string &name)
{
  for (int index = 1; index + 1 < argc; ++index) {
    if (argv[index] == name) {
      return argv[index + 1];
    }
  }
  throw std::runtime_error("missing required argument " + name);
}

unsigned int worker_count(std::size_t file_count)
{
  const unsigned int available = std::max(1U, std::thread::hardware_concurrency());
  const std::size_t bounded = std::min<std::size_t>(available, maximum_worker_count);
  return static_cast<unsigned int>(std::max<std::size_t>(1, std::min(file_count, bounded)));
}

std::string fingerprint(const fs::path &root, const std::string &label, const std::string &relative)
{
  const fs::path path = root / fs::u8path(relative);
  if (fs::is_symlink(fs::symlink_status(path))) {
    return "L " + label + "/" + relative + " " + fs::read_symlink(path).u8string() + "\n";
  }
  return "F " + label + "/" + relative + " " + digest_file(path) + "\n";
}

void write_fingerprints(const fs::path &root, const std::string &label,
  const std::vector<std::string> &files, const fs::path &output_path)
{
  std::vector<std::string> records(files.size());
  std::atomic<std::size_t> next_index{0};
  std::atomic<std::size_t> completed_count{0};
  std::atomic<std::size_t> next_progress{progress_interval};
  std::atomic<bool> failed{false};
  std::mutex output_mutex;
  std::string error;
  const unsigned int workers = worker_count(files.size());

  std::cout << "Fingerprinting " << files.size() << ' ' << label << " files with "
            << workers << " workers" << std::endl;
  auto worker = [&]() {
    while (!failed.load()) {
      const std::size_t index = next_index.fetch_add(1);
      if (index >= files.size()) {
        return;
      }
      try {
        records[index] = fingerprint(root, label, files[index]);
      } catch (const std::exception &exception) {
        std::lock_guard<std::mutex> lock(output_mutex);
        if (!failed.exchange(true)) {
          error = exception.what();
        }
        return;
      }
      const std::size_t completed = completed_count.fetch_add(1) + 1;
      if (completed >= next_progress.load()) {
        std::lock_guard<std::mutex> lock(output_mutex);
        std::size_t milestone = next_progress.load();
        while (completed >= milestone && milestone < files.size()) {
          std::cout << "Fingerprinting " << label << " files: " << milestone << '/'
                    << files.size() << std::endl;
          milestone += progress_interval;
        }
        next_progress.store(milestone);
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
    throw std::runtime_error("unable to open output " + output_path.string());
  }
  for (const std::string &record : records) {
    output << record;
  }
  if (!output) {
    throw std::runtime_error("unable to write output " + output_path.string());
  }
  std::cout << "Fingerprinting " << label << " files: " << files.size() << '/'
            << files.size() << std::endl;
}

}

int main(int argc, char **argv)
{
  try {
    const fs::path root = fs::u8path(require_argument(argc, argv, "--root"));
    const std::string label = require_argument(argc, argv, "--label");
    const fs::path files_path = fs::u8path(require_argument(argc, argv, "--files"));
    const fs::path output_path = fs::u8path(require_argument(argc, argv, "--output"));
    write_fingerprints(root, label, read_file_list(files_path), output_path);
    return 0;
  } catch (const std::exception &exception) {
    std::cerr << "bext fingerprint failed: " << exception.what() << '\n';
    return 1;
  }
}
