-- BarrEx_SafeCall: centralized safe method invocation.
--
-- Protects callers from nil targets and non-function members without
-- each module having to replicate the same guard pattern.  The helper
-- is intentionally small and dependency-free so it can be required
-- from shared, client and server without risk.

local SafeCall = {}

--- Invokes target[methodName](target, ...) when target is non-nil and
--- the member is a function.  Returns nil in all other cases.
--- Compatible with Lua 5.1.
---@param target any
---@param methodName string
---@return any
function SafeCall.call(target, methodName, ...)
    if not target then return nil end

    local method = target[methodName]
    if type(method) ~= "function" then return nil end

    return method(target, ...)
end

return SafeCall
