local Constant = require("BarrEx_Constant")

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

log("Mod Initialized!")

Events.OnGameStart.Add(function()
    log("Game Started")
end)
