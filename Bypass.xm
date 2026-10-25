#import <Foundation/Foundation.h>
#import <substrate.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/sysctl.h>

// 1. Блокируем exit и _exit
static void (*orig_exit)(int);
static void new_exit(int status) { }
static void (*orig__exit)(int);
static void new__exit(int status) { }

// 2. Скрываем заголовки
static const struct mach_header* (*orig_dyld_get_image_header)(uint32_t);
static const struct mach_header* new_dyld_get_image_header(uint32_t image_index) {
    return orig_dyld_get_image_header(image_index);
}

// 3. Скрываем имя нашего dylib
static const char* (*orig_dyld_get_image_name)(uint32_t);
static const char* new_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (name && (strstr(name, "oxide") || strstr(name, "Bypass") || strstr(name, "substrate"))) {
        return "/usr/lib/libSystem.B.dylib";
    }
    return name;
}

// 4. Обходим проверку отладчика (ptrace) через sysctl
static int (*orig_sysctl)(int *name, u_int namelen, void *info, size_t *infosize, void *newinfo, size_t newinfosize);
static int new_sysctl(int *name, u_int namelen, void *info, size_t *infosize, void *newinfo, size_t newinfosize) {
    if (namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        return 0;
    }
    return orig_sysctl(name, namelen, info, infosize, newinfo, newinfosize);
}

%ctor {
    MSHookFunction((void *)exit, (void *)new_exit, (void **)&orig_exit);
    MSHookFunction((void *)_exit, (void *)new__exit, (void **)&orig__exit);
    MSHookFunction((void *)_dyld_get_image_name, (void *)new_dyld_get_image_name, (void **)&orig_dyld_get_image_name);
    MSHookFunction((void *)_dyld_get_image_header, (void *)new_dyld_get_image_header, (void **)&orig_dyld_get_image_header);
    MSHookFunction((void *)sysctl, (void *)new_sysctl, (void **)&orig_sysctl);
}
