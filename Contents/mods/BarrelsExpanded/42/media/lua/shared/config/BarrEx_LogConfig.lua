local LogConfig = {}

LogConfig.DEBUG = false
LogConfig.LOG_LEVEL = "WARN"
LogConfig.LOG_PREFIX = "[BarrelsExpanded]"

local ok, LocalConfig = pcall(require, "config/BarrEx_LogConfigLocal")

if ok and type(LocalConfig) == "table" then
    if type(LocalConfig.DEBUG) == "boolean" then
        LogConfig.DEBUG = LocalConfig.DEBUG
    end

    if type(LocalConfig.LOG_LEVEL) == "string" then
        LogConfig.LOG_LEVEL = LocalConfig.LOG_LEVEL
    end

    if type(LocalConfig.LOG_PREFIX) == "string" then
        LogConfig.LOG_PREFIX = LocalConfig.LOG_PREFIX
    end
end

return LogConfig
