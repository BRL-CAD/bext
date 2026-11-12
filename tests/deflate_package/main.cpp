#include <libdeflate.h>

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <vector>

int main()
{
    constexpr int CompressionLevel = 6;
    const std::unique_ptr<libdeflate_compressor, decltype(&libdeflate_free_compressor)> compressor(
        libdeflate_alloc_compressor(CompressionLevel), libdeflate_free_compressor);
    const std::unique_ptr<libdeflate_decompressor, decltype(&libdeflate_free_decompressor)> decompressor(
        libdeflate_alloc_decompressor(), libdeflate_free_decompressor);
    if (!compressor || !decompressor) {
        std::cerr << "Cannot allocate compression state\n";
        return EXIT_FAILURE;
    }

    const char input[] = "BRL-CAD renderer package compression round trip";
    std::vector<unsigned char> compressed(
        libdeflate_deflate_compress_bound(compressor.get(), sizeof(input)));
    const size_t compressed_size = libdeflate_deflate_compress(
        compressor.get(), input, sizeof(input), compressed.data(), compressed.size());
    if (!compressed_size) {
        std::cerr << "Compression failed\n";
        return EXIT_FAILURE;
    }

    std::vector<unsigned char> restored(sizeof(input));
    size_t restored_size = 0;
    const auto result = libdeflate_deflate_decompress(
        decompressor.get(), compressed.data(), compressed_size,
        restored.data(), restored.size(), &restored_size);
    if (result != LIBDEFLATE_SUCCESS || restored_size != sizeof(input)
        || std::memcmp(input, restored.data(), sizeof(input))) {
        std::cerr << "Decompressed data differs from the input\n";
        return EXIT_FAILURE;
    }
    std::cout << "Compression and decompression passed\n";
    return EXIT_SUCCESS;
}
