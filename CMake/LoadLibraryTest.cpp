/*             L O A D L I B R A R Y T E S T . C P P
 *
 * Published in 2024 by the United States Government.
 * This work is in the public domain.
 *
 */
/** @file LoadLibraryTest.cpp
 *
 * File to test if a Dll file can be successfully loaded
 * by the Windows LoadLibrary call.
 */

#include <windows.h>
#include <stdio.h>

int main(int argc, const char **argv)
{
    if (argc < 2) {
	printf("lltest <dllfile>\n");
	return -1;
    }
    HINSTANCE linst = LoadLibrary(TEXT(argv[1]));
    if (linst == NULL) {
	printf("LoadLibrary of %s failed\n", argv[1]);
	return 1;
    }
    BOOL flr = FreeLibrary(linst);
    if (!flr) {
	printf("FreeLibrary failed for %s\n", argv[1]);
	return 1;
    }
    printf("Success\n");
    return 0;
}

// Local Variables:
// tab-width: 8
// mode: C++
// c-basic-offset: 4
// indent-tabs-mode: t
// c-file-style: "stroustrup"
// End:
// ex: shiftwidth=4 tabstop=8
