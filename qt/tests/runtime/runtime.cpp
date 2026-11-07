#include <QCoreApplication>
#include <QDebug>
#include <QProcessEnvironment>
#include <QVariant>
#include <QtCore/qfloat16.h>

#include <cmath>

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    if (QProcessEnvironment::systemEnvironment().value("BEXT_QT_RUNTIME_TEST") != "present") {
        qCritical("QtCore could not read the process environment");
        return 1;
    }

    // Exactly representable in binary16; exercise both public conversions and
    // the QtCore metatype conversion that first exposed the missing helpers.
    constexpr float expected = 1.5f;
    constexpr double tolerance = 0.0001;
    volatile float input = expected;
    const qfloat16 half(input);
    if (std::abs(double(half) - expected) > tolerance) {
        qCritical("The float16 round trip changed the value");
        return 1;
    }
    bool converted = false;
    const double result = QVariant::fromValue(half).toDouble(&converted);
    if (!converted || std::abs(result - expected) > tolerance) {
        qCritical("QtCore could not convert the float16 metatype");
        return 1;
    }
    return 0;
}
