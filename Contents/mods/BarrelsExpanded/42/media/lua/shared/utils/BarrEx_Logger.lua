local Constant = require("BarrEx_Constant")

local Logger = {}

local LEVELS = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40,
}

local DEFAULT_LEVEL = "WARN"

local function getConfiguredLevel()
    if Constant.DEBUG == true then
        return LEVELS.DEBUG
    end

    local levelName = type(Constant.LOG_LEVEL) == "string" and string.upper(Constant.LOG_LEVEL) or DEFAULT_LEVEL
    return LEVELS[levelName] or LEVELS.WARN
end

local function shouldLog(levelName)
    local level = LEVELS[levelName] or LEVELS.INFO
    return level >= getConfiguredLevel()
end

local function log(levelName, message)
    if not shouldLog(levelName) then return end
    if type(print) ~= "function" then return end

    print(string.format(
        "%s [%s] %s",
        Constant.LOG_PREFIX or "[BarrelsExpanded]",
        levelName,
        tostring(message or "")
    ))
end

function Logger.debug(message)
    log("DEBUG", message)
end

function Logger.info(message)
    log("INFO", message)
end

function Logger.warn(message)
    log("WARN", message)
end

function Logger.error(message)
    log("ERROR", message)
end

return Logger
