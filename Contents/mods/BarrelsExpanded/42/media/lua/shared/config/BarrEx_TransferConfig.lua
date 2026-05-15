-- BarrEx_TransferConfig: tuning constants for the liquid transfer mechanic.
--
-- Keeping timing and step parameters here makes it straightforward to
-- adjust the transfer experience (speed, visual smoothness, network
-- frequency) without touching timed action logic or the server tick handler.

local TransferConfig = {}

-- Multiplier applied on top of the vanilla fluid transfer duration.
-- Higher values make pours and extractions take longer.
TransferConfig.ACTION_TIME_MULTIPLIER = 2

-- Number of server ticks between each transfer step advance.
-- Lower values move liquid faster per second at the cost of more
-- frequent server-side computation.
TransferConfig.SERVER_TICK_INTERVAL = 5

-- Number of ticks between progress sync messages sent to the client.
-- Increasing this reduces network traffic at the cost of less smooth
-- client-side progress feedback.
TransferConfig.SERVER_SYNC_INTERVAL = 10

return TransferConfig
