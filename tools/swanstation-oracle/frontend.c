// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// A headless libretro frontend that runs SwanStation — built unmodified, its source never read — and
// records what any frontend can see: guest RAM after each frame, as the frame records of iStation's
// trace format (documentation/istation/reference/trace-formats.md). Written only against libretro's
// public API (libretro.h from libretro-common, MIT). Every option key the core declares or asks for is
// logged; an option offering "Interpreter" or "Software" is answered with it, a memory card option
// with "None", every other option with its default — never with OpenBIOS. No controller is plugged in,
// as on the Swift console it is compared with. When the core asks for a file name ending in .bin (its
// BIOS choices), the user's BIOS is linked into the system folder under that name.
//
//   oracle <core.dylib> --bios <file> [--exe <file>] [--frames <n>] [--frame-trace <out>] [--log <out>]
//
// The BIOS is the user's own dump: it is linked into a temporary system folder, never copied.

#include <dirent.h>
#include <dlfcn.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libgen.h>
#include "libretro.h"

static FILE *logFile;
static char systemDirectory[PATH_MAX];
static char biosPath[PATH_MAX];
static bool supportsNoGame;

/// The links made in the system folder, for a signal handler to remove without allocating.
static char links[16][PATH_MAX];
static int linkCount;
static void remember(const char *link) {
    if (linkCount < 16) snprintf(links[linkCount++], PATH_MAX, "%s", link);
}

#define MAX_OPTIONS 512
static struct { char key[128]; char value[128]; } options[MAX_OPTIONS];
static int optionCount;

static void note(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    if (logFile) {
        va_start(args, format);
        vfprintf(logFile, format, args);
        va_end(args);
    }
}

static void coreLog(enum retro_log_level level, const char *format, ...) {
    static const char *levels[] = { "debug", "info", "warn", "error" };
    char message[4096];
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof message, format, args);
    va_end(args);
    note("[core %s] %s%s", level <= RETRO_LOG_ERROR ? levels[level] : "?", message,
         message[0] && message[strlen(message) - 1] == '\n' ? "" : "\n");
}

/// A legacy option definition, "Description; first|second|…": its default is the first value; a
/// value spelled "Interpreter" or "Software" wins over it, and so does "None" for a memory card, as the
/// Swift console has none; OpenBIOS is never chosen.
static void declare(const char *key, const char *definition) {
    if (optionCount == MAX_OPTIONS) return;
    const char *values = strstr(definition, "; ");
    values = values ? values + 2 : definition;
    char chosen[128] = "";
    const char *cursor = values;
    bool first = true;
    bool memoryCard = strcasestr(key, "MemoryCard") != NULL;
    while (*cursor) {
        const char *bar = strchr(cursor, '|');
        size_t length = bar ? (size_t)(bar - cursor) : strlen(cursor);
        char value[128];
        snprintf(value, sizeof value, "%.*s", (int)length, cursor);
        bool openBIOS = strcasestr(value, "openbios") != NULL;
        bool preferred = strcasecmp(value, "Interpreter") == 0 || strcasecmp(value, "Software") == 0 ||
                         (memoryCard && strcasecmp(value, "None") == 0);
        if ((first || !chosen[0] || preferred) && !openBIOS) {
            snprintf(chosen, sizeof chosen, "%s", value);
        }
        if (!openBIOS) first = false;
        if (!bar) break;
        cursor = bar + 1;
    }
    snprintf(options[optionCount].key, sizeof options[optionCount].key, "%s", key);
    snprintf(options[optionCount].value, sizeof options[optionCount].value, "%s", chosen);
    optionCount++;
    note("[option] %s = %s  (declared: %s)\n", key, chosen, definition);
}

static bool environment(unsigned command, void *data) {
    switch (command & ~(RETRO_ENVIRONMENT_EXPERIMENTAL | RETRO_ENVIRONMENT_PRIVATE)) {
    case RETRO_ENVIRONMENT_GET_CAN_DUPE:
        *(bool *)data = true;
        return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
        return true;
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        *(const char **)data = systemDirectory;
        return true;
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
        ((struct retro_log_callback *)data)->log = coreLog;
        return true;
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
        *(unsigned *)data = 0; // legacy SET_VARIABLES: each definition names its values
        return true;
    case RETRO_ENVIRONMENT_SET_VARIABLES:
        for (const struct retro_variable *variable = data; variable && variable->key; variable++) {
            declare(variable->key, variable->value);
        }
        return true;
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        struct retro_variable *variable = data;
        if (!variable) return true; // a probe: variables are supported
        variable->value = NULL;
        for (int i = 0; i < optionCount; i++) {
            if (strcmp(options[i].key, variable->key) == 0) variable->value = options[i].value;
        }
        note("[option asked] %s -> %s\n", variable->key, variable->value ? variable->value : "(unknown)");
        // A BIOS file name: the user's BIOS answers to it.
        size_t length = variable->value ? strlen(variable->value) : 0;
        if (length > 4 && strcasecmp(variable->value + length - 4, ".bin") == 0 && !strchr(variable->value, '/')) {
            char link[PATH_MAX];
            snprintf(link, sizeof link, "%s/%s", systemDirectory, variable->value);
            if (symlink(biosPath, link) == 0) {
                remember(link);
                note("[bios] linked as %s\n", variable->value);
            }
        }
        return true; // libretro.h: an unknown key answers true, its value left NULL
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        *(bool *)data = false;
        return true;
    case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
        supportsNoGame = *(const bool *)data;
        return true;
    default:
        note("[environment] %u not handled\n", command);
        return false;
    }
}

static void videoRefresh(const void *data, unsigned width, unsigned height, size_t pitch) {}
static void audioSample(int16_t left, int16_t right) {}
static size_t audioSampleBatch(const int16_t *data, size_t frames) { return frames; }
static void inputPoll(void) {}
static int16_t inputState(unsigned port, unsigned device, unsigned index, unsigned id) { return 0; }

static void put(FILE *file, uint64_t value, int bytes) {
    for (int i = 0; i < bytes; i++) fputc((int)((value >> (8 * i)) & 0xFF), file);
}

static uint64_t fnv1a64(const uint8_t *bytes, size_t count) {
    uint64_t hash = 0xCBF29CE484222325ULL;
    for (size_t i = 0; i < count; i++) hash = (hash ^ bytes[i]) * 0x00000100000001B3ULL;
    return hash;
}

/// Removes the temporary system folder and what the core put in it. Registered with atexit once the
/// folder exists, so every return and exit — an error's included — leaves nothing behind.
static void removeSystemDirectory(void) {
    DIR *folder = opendir(systemDirectory);
    for (struct dirent *entry; folder && (entry = readdir(folder));) {
        if (entry->d_name[0] == '.') continue;
        char path[PATH_MAX];
        snprintf(path, sizeof path, "%s/%s", systemDirectory, entry->d_name);
        unlink(path);
    }
    if (folder) closedir(folder);
    rmdir(systemDirectory);
}

/// On a signal (Ctrl-C, a kill), with only async-signal-safe calls: the remembered links, then the
/// folder; then the signal's own end. A crash in the core is the one way out that can leave the folder.
static void removeOnSignal(int signal) {
    for (int i = 0; i < linkCount; i++) unlink(links[i]);
    rmdir(systemDirectory);
    struct sigaction standard = { .sa_handler = SIG_DFL };
    sigaction(signal, &standard, NULL);
    raise(signal);
}

static int usage(const char *why) {
    if (why) fprintf(stderr, "oracle: %s\n", why);
    fprintf(stderr, "usage: oracle <core.dylib> --bios <file> [--exe <file>] [--frames <n>] [--frame-trace <out>] [--log <out>]\n");
    return 2;
}

#define CORE_FUNCTION(name) __typeof__(&name) p_##name = (__typeof__(&name))dlsym(core, #name); \
    if (!p_##name) { fprintf(stderr, "the core has no %s\n", #name); return 1; }

int main(int argc, char **argv) {
    const char *corePath = argc > 1 ? argv[1] : NULL, *bios = NULL, *exe = NULL, *frameTrace = NULL, *logPath = NULL;
    long frames = 60;
    // A misspelled flag or a bad number is an error, never a default: a short run would read as agreement.
    for (int i = 2; i < argc; i += 2) {
        if (i + 1 >= argc) return usage("a flag without its value");
        const char *value = argv[i + 1];
        if (!strcmp(argv[i], "--bios")) bios = value;
        else if (!strcmp(argv[i], "--exe")) exe = value;
        else if (!strcmp(argv[i], "--frame-trace")) frameTrace = value;
        else if (!strcmp(argv[i], "--log")) logPath = value;
        else if (!strcmp(argv[i], "--frames")) {
            char *end;
            frames = strtol(value, &end, 10);
            if (!*value || *end || frames < 0) return usage("--frames needs a whole number of at least 0");
        } else return usage("an unknown flag");
    }
    if (!corePath || !bios) return usage(NULL);
    // A PS1 BIOS is 512 KB; SwanStation runs on without one it rejects, which would trace nothing useful.
    struct stat biosInfo;
    if (stat(bios, &biosInfo) != 0) { perror(bios); return 1; }
    if (!S_ISREG(biosInfo.st_mode) || biosInfo.st_size != 0x80000) {
        fprintf(stderr, "%s: %lld bytes, not a 512 KB BIOS image\n", bios, (long long)biosInfo.st_size);
        return 1;
    }
    if (logPath && !(logFile = fopen(logPath, "w"))) { perror(logPath); return 1; }

    // A system folder holding only a link to the user's BIOS.
    char template[] = "/tmp/istation-oracle-XXXXXX";
    if (!mkdtemp(template)) { perror("mkdtemp"); return 1; }
    snprintf(systemDirectory, sizeof systemDirectory, "%s", template);
    atexit(removeSystemDirectory);
    struct sigaction cleanup = { .sa_handler = removeOnSignal };
    sigaction(SIGINT, &cleanup, NULL);
    sigaction(SIGTERM, &cleanup, NULL);
    sigaction(SIGHUP, &cleanup, NULL);
    char biosName[PATH_MAX], link[PATH_MAX];
    if (!realpath(bios, biosPath)) { perror(bios); return 1; }
    snprintf(biosName, sizeof biosName, "%s", biosPath);
    snprintf(link, sizeof link, "%s/%s", systemDirectory, basename(biosName));
    if (symlink(biosPath, link) != 0) { perror("symlink"); return 1; }
    remember(link);

    void *core = dlopen(corePath, RTLD_NOW | RTLD_LOCAL);
    if (!core) { fprintf(stderr, "%s\n", dlerror()); return 1; }
    CORE_FUNCTION(retro_set_environment)
    CORE_FUNCTION(retro_set_video_refresh)
    CORE_FUNCTION(retro_set_audio_sample)
    CORE_FUNCTION(retro_set_audio_sample_batch)
    CORE_FUNCTION(retro_set_input_poll)
    CORE_FUNCTION(retro_set_input_state)
    CORE_FUNCTION(retro_init)
    CORE_FUNCTION(retro_deinit)
    CORE_FUNCTION(retro_load_game)
    CORE_FUNCTION(retro_unload_game)
    CORE_FUNCTION(retro_run)
    CORE_FUNCTION(retro_get_memory_data)
    CORE_FUNCTION(retro_get_memory_size)

    p_retro_set_environment(environment);
    p_retro_set_video_refresh(videoRefresh);
    p_retro_set_audio_sample(audioSample);
    p_retro_set_audio_sample_batch(audioSampleBatch);
    p_retro_set_input_poll(inputPoll);
    p_retro_set_input_state(inputState);
    p_retro_init();

    struct retro_game_info game = { .path = exe };
    if (!p_retro_load_game(exe ? &game : NULL)) {
        fprintf(stderr, "the core refused to start (%s)\n", exe ? exe : supportsNoGame ? "no content" : "no content, which it doesn't support");
        return 1;
    }
    // Nothing in either port, as on the Swift console: libretro assumes a joypad in every port.
    void (*setPortDevice)(unsigned, unsigned) = (void (*)(unsigned, unsigned))dlsym(core, "retro_set_controller_port_device");
    if (!setPortDevice) { fprintf(stderr, "the core has no retro_set_controller_port_device\n"); return 1; }
    for (unsigned port = 0; port < 2; port++) setPortDevice(port, RETRO_DEVICE_NONE);
    note("[ports] 1 and 2: nothing plugged in\n");

    FILE *trace = frameTrace ? fopen(frameTrace, "wb") : NULL;
    if (frameTrace && !trace) { perror(frameTrace); return 1; }
    if (trace) {
        fwrite("ISTR", 1, 4, trace);
        put(trace, 1, 2); // version
        put(trace, 2, 1); // per frame
        put(trace, 0, 1);
        put(trace, 0, 4);
        put(trace, 0, 4);
    }
    for (long frame = 0; frame < frames; frame++) {
        p_retro_run();
        if (!trace) continue;
        const uint8_t *ram = p_retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM);
        size_t size = p_retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM);
        if (!ram || size != 0x200000) { // the format's checksum is over exactly 2 MB of guest RAM
            fprintf(stderr, "the core's system RAM is %zu bytes at %p, not 2 MB\n", size, (const void *)ram);
            return 1;
        }
        fputc(0x03, trace);
        put(trace, (uint64_t)frame, 8);
        put(trace, fnv1a64(ram, size), 8);
        put(trace, 0, 8); // no picture checksum until v0.1.0 fixes its format
        put(trace, 0, 8); // nor sound until v0.2.0
    }
    if (trace && (ferror(trace) || fclose(trace) != 0)) { perror(frameTrace); return 1; }
    note("[oracle] %ld frames, RAM %zu bytes\n", frames, p_retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM));

    p_retro_unload_game();
    p_retro_deinit();
    if (logFile && fclose(logFile) != 0) { perror(logPath); return 1; }
    return 0;
}
