#ifndef BEXT_SUPPLY_CHAIN_COMMANDS_HPP
#define BEXT_SUPPLY_CHAIN_COMMANDS_HPP

namespace bext {

int vex_capture(int argc, char **argv);
int vex_generate(int argc, char **argv);
int vex_scan(int argc, char **argv);
int dependency_updates(int argc, char **argv);
int release_build_command(int argc, char **argv);
int qt_attributions(int argc, char **argv);
int install_transform(int argc, char **argv);
int sbom_project(int argc, char **argv);
int sbom_validate(int argc, char **argv);

}

#endif
