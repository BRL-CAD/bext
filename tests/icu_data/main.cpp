#include <unicode/uclean.h>
#include <unicode/ucnv.h>
#include <unicode/unorm2.h>

#include <array>
#include <cstdlib>
#include <iostream>
#include <memory>

namespace {
struct Cleanup {
    ~Cleanup() { u_cleanup(); }
};

bool check_status(const UErrorCode status, const char *operation)
{
    if (U_SUCCESS(status))
        return true;
    std::cerr << operation << ": " << u_errorName(status) << '\n';
    return false;
}
}

int main()
{
    const Cleanup cleanup;
    UErrorCode status = U_ZERO_ERROR;
    u_init(&status);
    if (!check_status(status, "ICU initialization"))
        return EXIT_FAILURE;

    const std::unique_ptr<UConverter, decltype(&ucnv_close)> converter(
        ucnv_open("windows-1252", &status), ucnv_close);
    if (!check_status(status, "Character converter"))
        return EXIT_FAILURE;

    constexpr UChar EuroSign = 0x20ac;
    const char encoded_euro[] = {'\x80'};
    std::array<UChar, 2> decoded{};
    const int32_t decoded_size = ucnv_toUChars(
        converter.get(), decoded.data(), static_cast<int32_t>(decoded.size()), encoded_euro,
        static_cast<int32_t>(sizeof(encoded_euro)), &status);
    if (!check_status(status, "Character conversion"))
        return EXIT_FAILURE;
    if (decoded_size != 1 || decoded.front() != EuroSign) {
        std::cerr << "Incorrect Windows-1252 Euro sign conversion\n";
        return EXIT_FAILURE;
    }

    const UNormalizer2 *normalizer = unorm2_getNFCInstance(&status);
    if (!check_status(status, "NFC data lookup"))
        return EXIT_FAILURE;
    constexpr UChar CombiningRing = 0x030a;
    constexpr UChar CapitalARing = 0x00c5;
    const UChar decomposed[] = {u'A', CombiningRing};
    std::array<UChar, 2> normalized{};
    const int32_t normalized_size = unorm2_normalize(
        normalizer, decomposed, static_cast<int32_t>(sizeof(decomposed) / sizeof(decomposed[0])),
        normalized.data(), static_cast<int32_t>(normalized.size()), &status);
    if (!check_status(status, "NFC normalization"))
        return EXIT_FAILURE;
    if (normalized_size != 1 || normalized.front() != CapitalARing) {
        std::cerr << "Incorrect NFC normalization of A and combining ring\n";
        return EXIT_FAILURE;
    }

    std::cout << "ICU initialization, conversion, and normalization passed\n";
    return EXIT_SUCCESS;
}
