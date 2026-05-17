-- BarrEx_TransferConfig: tuning constants for the liquid transfer mechanic.
--
-- Keeping timing and step parameters here makes it straightforward to
-- adjust the transfer experience (speed, visual smoothness, network
-- frequency) without touching timed action logic or the server tick handler.

local TransferConfig = {}

-- Multiplier applied on top of the vanilla fluid transfer duration.
-- Higher values make pours and extractions take longer.
TransferConfig.ACTION_TIME_MULTIPLIER = 2

-- Emptying a barrel dumps liquid to the world instead of carefully moving it
-- between containers, so it advances faster while still applying one unit at a
-- time on the server.
TransferConfig.EMPTY_ACTION_TIME_PER_UNIT = 5

-- Number of server ticks between each transfer step advance.
-- Lower values move liquid faster per second at the cost of more
-- frequent server-side computation.
TransferConfig.SERVER_TICK_INTERVAL = 5

-- Number of ticks between progress sync messages sent to the client.
-- Increasing this reduces network traffic at the cost of less smooth
-- client-side progress feedback.
TransferConfig.SERVER_SYNC_INTERVAL = 10

-- Maximum server ticks an in-progress transfer can go without a fresh client
-- animation-progress update before the lock is released. This prevents a
-- disconnected/stalled client from keeping a barrel locked forever.
TransferConfig.SERVER_TRANSFER_STALE_TICKS = 300

-- Number of timed-action update ticks between client animation progress reports.
-- The server uses this only as a throttle for authoritative liquid movement.
TransferConfig.CLIENT_PROGRESS_SYNC_INTERVAL = 5

-- Minimum job-delta change before the client sends another progress report.
TransferConfig.CLIENT_PROGRESS_SYNC_EPSILON = 0.01

return TransferConfig
