#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <signal.h>
#include <stdint.h>
#include <unistd.h>
#include <cxxabi.h>
#include <math.h>
#include <assert.h>
#include <time.h>
#include <sys/ptrace.h>
#include <sys/stat.h>
#include <string>
#include <vector>
#include <algorithm>
#include <memory>
#include <iostream>
#include <fstream>
#include <dlfcn.h>
#include <time.h>
#include <iomanip>
#include <map>
#include <unordered_map>
#include <deque>
#include <list>
#include <GL/gl.h>
#ifdef __linux__
#include <GL/glx.h>
#include <X11/Xlib.h>
#endif 

#define DLSYM_RTLD_NEXT(func) (PFN_ ## func)dlsym(RTLD_NEXT, #func)

extern "C" {
    void signal_handler(int sig) {
        if (sig == SIGUSR1) {
            fprintf(stderr, "SIGUSR1 is received\n");
        }
    }

      __attribute__((constructor)) void init() {
        struct sigaction sa;
        sa.sa_handler = signal_handler;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;
        sigaction(SIGUSR1, &sa, NULL);
        fprintf(stderr, "The capture signal is registered as SIGUSR1(%d)\n", SIGUSR1);
    }

    typedef void (*PFN_glXSwapBuffers)(Display* dpy, GLXDrawable drawable);
    PFN_glXSwapBuffers pfn_glXSwapBuffers = NULL;
    uint64_t frames = 0;

    void __attribute__((visibility("default"))) glXSwapBuffers(Display* dpy, GLXDrawable drawable) {
        if (pfn_glXSwapBuffers == NULL) {
            pfn_glXSwapBuffers = DLSYM_RTLD_NEXT(glXSwapBuffers);
        }

        if (frames % 100 == 0) {
            struct timespec start, end;
            clock_gettime(CLOCK_MONOTONIC_RAW, &start);
            pfn_glXSwapBuffers(dpy, drawable);
            clock_gettime(CLOCK_MONOTONIC_RAW, &end);
            int elapsed = int(end.tv_sec - start.tv_sec) * 1e6 + int(end.tv_nsec - start.tv_nsec) / 1e3; // in microseconds
            fprintf(stderr, "Overhead of glXSwapBuffers: %d usec\n", elapsed);
        } else {
            pfn_glXSwapBuffers(dpy, drawable);
        }

        frames += 1;
    }
}