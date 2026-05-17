-- BarrEx_NetworkConfig: tuning for the reusable barrel networking protocol.

local NetworkConfig = {}

-- Client ticks before a one-shot action asks the server for the latest state
-- when no ack/reject has arrived yet.
NetworkConfig.ACTION_ACK_TIMEOUT_TICKS = 240

-- Minimum ticks between client state refresh requests for the same barrel.
NetworkConfig.STATE_REQUEST_COOLDOWN_TICKS = 60

return NetworkConfig
