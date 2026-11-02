#include <sys/stat.h>

int probe(void);

int
main(int argc, char **argv)
{
    if (argc == 2) {
        struct stat info;
        return stat(argv[1], &info) == 0 && !(info.st_mode & S_IWUSR) ? 0 : 1;
    }
    return probe() == 42 ? 0 : 1;
}
