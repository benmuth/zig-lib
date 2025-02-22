const profile = @import("profile.zig");

pub const estimateCPUFreq = profile.estimateCPUFreq;
pub const getOSTimerFreq = profile.getOSTimerFreq;
pub const readOSTimer = profile.readOSTimer;
pub const readCPUTimer = profile.readCPUTimer;
pub const profiler = profile.profiler;
pub const beginBlock = profile.beginBlock;
pub const endBlock = profile.endBlock;
pub const beginProfiling = profile.beginProfiling;
pub const endProfiling = profile.endProfiling;
pub const printReport = profile.printReport;
pub const GetCounter = profile.GetCounter;
