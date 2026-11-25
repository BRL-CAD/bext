#include <dlfcn.h>

#include <iostream>

int main(int argc, char **argv)
{
  if (argc != 2) {
    std::cerr << "usage: bext_plief_load_fixture <library>\n";
    return 2;
  }
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) {
    std::cerr << dlerror() << '\n';
    return 1;
  }
  dlerror();
  auto answer = reinterpret_cast<int (*)()>(dlsym(library, "answer"));
  const char *error = dlerror();
  const bool valid = !error && answer && answer() == 42;
  if (error) std::cerr << error << '\n';
  dlclose(library);
  return valid ? 0 : 1;
}
