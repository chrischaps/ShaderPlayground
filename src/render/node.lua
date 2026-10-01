--[[
    A node is one slot in the chain (or the source): a registry entry plus
    this instance's param values, enabled flag and persistent buffers.
]]

local Params = require("src.params")

local Node = {}
Node.__index = Node

local nextUid = 0

function Node.new(entry)
    nextUid = nextUid + 1
    local self = setmetatable({
        uid = nextUid,
        entry = entry,
        values = {},
        enabled = true,
        version = -1,
        buffers = {},  -- pass name -> { cur, nxt, w, h, fmt }
        frame = 0,
    }, Node)
    self:sync()
    return self
end

function Node:id()
    return self.entry.id
end

-- Bring values (and Lua state) in line with the entry after a (re)load.
function Node:sync()
    local e = self.entry
    if self.version == e.version then return false end
    local old = self.values
    local values = {}
    for _, def in ipairs(e.params or {}) do
        local v = old[def.name]
        if v ~= nil and Params.compatible(def, v) then
            values[def.name] = Params.clamp(def, v)
        else
            values[def.name] = Params.defaultValue(def)
        end
    end
    self.values = values

    -- Drop buffers for passes that no longer exist.
    if e.passes then
        local names = {}
        for _, p in ipairs(e.passes) do names[p.opts.name] = true end
        for name, buf in pairs(self.buffers) do
            if not names[name] then
                buf.cur:release()
                buf.nxt:release()
                self.buffers[name] = nil
            end
        end
    end

    if e.lang == "lua" then
        self.luaState = nil -- recreated lazily by the pipeline
    end
    self.version = e.version
    return true
end

function Node:setValue(name, v)
    for _, def in ipairs(self.entry.params or {}) do
        if def.name == name then
            self.values[name] = Params.clamp(def, v)
            return true
        end
    end
    return false
end

function Node:resetParams()
    for _, def in ipairs(self.entry.params or {}) do
        self.values[def.name] = Params.defaultValue(def)
    end
end

-- Restart simulations / feedback.
function Node:restart()
    self.frame = 0
    for _, buf in pairs(self.buffers) do
        for _, c in ipairs({ buf.cur, buf.nxt }) do
            love.graphics.setCanvas(c)
            love.graphics.clear(0, 0, 0, 1)
        end
    end
    love.graphics.setCanvas()
    self.luaState = nil
end

-- Persistent double buffer for a pass. Content survives resizes (rescaled).
function Node:buffer(name, w, h, fmt)
    local buf = self.buffers[name]
    if buf and buf.w == w and buf.h == h and buf.fmt == fmt then
        return buf
    end
    local new = {
        cur = love.graphics.newCanvas(w, h, { format = fmt }),
        nxt = love.graphics.newCanvas(w, h, { format = fmt }),
        w = w, h = h, fmt = fmt,
    }
    local lg = love.graphics
    lg.push("all")
    lg.setShader()
    lg.setBlendMode("replace", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    for _, c in ipairs({ new.cur, new.nxt }) do
        lg.setCanvas(c)
        lg.clear(0, 0, 0, 1)
        if buf and buf.fmt == fmt then
            lg.draw(buf.cur, 0, 0, 0, w / buf.w, h / buf.h)
        end
    end
    lg.pop()
    if buf then
        buf.cur:release()
        buf.nxt:release()
    end
    self.buffers[name] = new
    return new
end

function Node:destroy()
    for _, buf in pairs(self.buffers) do
        buf.cur:release()
        buf.nxt:release()
    end
    self.buffers = {}
end

function Node:serialize()
    local params = {}
    for k, v in pairs(self.values) do params[k] = Params.copy(v) end
    return { id = self.entry.id, enabled = self.enabled, params = params }
end

function Node:applyParams(params)
    if type(params) ~= "table" then return end
    for _, def in ipairs(self.entry.params or {}) do
        local v = params[def.name]
        if v ~= nil and Params.compatible(def, v) then
            self.values[def.name] = Params.clamp(def, v)
        end
    end
end

return Node
