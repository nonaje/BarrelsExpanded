local Constant = require("BarrEx_Constant")
local BarrEx_MoveableSync = require("BarrEx_MoveableSync")

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

log("Mod Initialized!")

Events.OnGameStart.Add(function()
    log("Game Started")
end)

BarrEx_MoveableSync.start()
