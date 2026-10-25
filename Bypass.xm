#import <Foundation/Foundation.h>
#import <substrate.h>
#import <unistd.h>
#import <mach-o/dyld.h>
#import <string.h>

static void (*orig_exit)(int);
static void new_exit(int status) {
    NSLog(@"[Bypass] Blocked exit");
}

static const char* (*orig_dyld_get_image_name)(uint32_t);
static const char* new_dyld_get_image_name(uint32_t idx) {
    const char* name = orig_dyld_get_image_name(idx);
    if (name && (strstr(name, "Bypass") || strstr(name, "oxide"))) {
        return "/usr/lib/libSystem.B.dylib";
    }
    return name;
}

%ctor {
    MSHookFunction((void *)exit, (void *)new_exit, (void **)&orig_exit);
    MSHookFunction((void *)_dyld_get_image_name, (void *)new_dyld_get_image_name, (void **)&orig_dyld_get_image_name);
}
