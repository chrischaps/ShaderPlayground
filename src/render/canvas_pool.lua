--[[
    Frame-scoped canvas pool.

    Transient pass targets are acquired during a frame and all returned at the
    start of the next frame (beginFrame), so anything rendered stays valid
    until the following render - long enough to draw, compare and capture.
    Canvases are only allocated when a new (w, h, format) is first needed.
]]

local Pool = {}
Pool.__index = Pool

function Pool.new()
    return setmetatable({
        free = {},      -- key -> list of canvases
        used = {},      -- list of {key, canvas} acquired this frame
        allocated = 0,
    }, Pool)
end

local function key(w, h, fmt)
    return w .. "x" .. h .. ":" .. fmt
end

function Pool:acquire(w, h, fmt)
    local k = key(w, h, fmt)
    local list = self.free[k]
    local c
    if list and #list > 0 then
        c = table.remove(list)
    else
        c = love.graphics.newCanvas(w, h, { format = fmt })
        self.allocated = self.allocated + 1
    end
    table.insert(self.used, { k, c })
    return c
end

function Pool:beginFrame()
    for _, u in ipairs(self.used) do
        local list = self.free[u[1]]
        if not list then
            list = {}
            self.free[u[1]] = list
        end
        table.insert(list, u[2])
    end
    self.used = {}
end

-- Drop free canvases (after a resize, so stale sizes don't pile up).
function Pool:trim()
    for _, list in pairs(self.free) do
        for _, c in ipairs(list) do
            c:release()
            self.allocated = self.allocated - 1
        end
    end
    self.free = {}
end

return Pool
