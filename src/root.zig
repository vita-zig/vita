const std = @import("std");
pub const Sce = struct {
    pub const Kernel = struct {
        pub const LwMutex = extern struct {
            data: [4]u64,

            extern fn sceKernelCreateLwMutex(*LwMutex, [*:0]const u8, c_uint, c_int, ?*const OptParam) c_int;
            pub fn init(self: *LwMutex, name: [*:0]const u8, attr: c_uint, init_count: c_int) !void {
                _ = sceKernelCreateLwMutex(self, name, attr, init_count, null);
            }

            extern fn sceKernelDeleteLwMutex(*LwMutex) c_int;
            pub fn deinit(self: *LwMutex) void {
                _ = sceKernelDeleteLwMutex(self);
            }

            extern fn sceKernelLockLwMutex(self: *LwMutex, count: c_int, timeout: ?*c_uint) c_int;
            pub const lock = sceKernelLockLwMutex;

            extern fn sceKernelUnlockLwMutex(self: *LwMutex, count: c_int) c_int;
            pub const unlock = sceKernelUnlockLwMutex;

            extern fn sceKernelTryLockLwMutex(self: *LwMutex, count: c_int) c_int;
            pub const tryLock = sceKernelTryLockLwMutex;

            pub const OptParam = extern struct {
                size: usize,

                comptime {
                    std.debug.assert(@sizeOf(OptParam) == 0x4);
                }
            };

            comptime {
                std.debug.assert(@sizeOf(LwMutex) == 0x20);
            }
        };
    };
};
