-- BarrEx_NetworkConfig: tuning for the reusable barrel networking protocol.

local ConfigKeys = require("config/BarrEx_ConfigKeys")
local ConfigRepository = require("config/BarrEx_ConfigRepository")

local NetworkConfig = {}

-- Client ticks before a one-shot action asks the server for the latest state
-- when no ack/reject has arrived yet.
NetworkConfig.ACTION_ACK_TIMEOUT_TICKS = ConfigRepository.getInteger(ConfigKeys.ACTION_ACK_TIMEOUT_TICKS)

-- Minimum ticks between client state refresh requests for the same barrel.
NetworkConfig.STATE_REQUEST_COOLDOWN_TICKS = ConfigRepository.getInteger(ConfigKeys.STATE_REQUEST_COOLDOWN_TICKS)

return NetworkConfig
