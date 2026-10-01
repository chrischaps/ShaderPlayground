--[[
    Presets: a source + effect chain + all param values, stored as Lua table
    literals in presets/*.lua.

    Schema (version 1):
        return {
            version = 1,
            name = "Neon Noir",
            desc = "One line shown in the browser and gallery",
            gallery = true,          -- include in gallery mode
            order = 10,              -- sort key for curated presets
            render = { scale = 1 },
            source = { id = "sources/glass_garden", params = { ... } },
            chain = {
                { id = "effects/bloom", enabled = true, params = { ... } },
            },
            mod = {},                -- reserved for modulation (LFOs, audio)
        }
    Unknown params are ignored and missing ones take defaults, so presets
    survive shader edits.
]]

local Serialize = require("src.util.serialize")
local FS = require("src.util.fs")

local Presets = {}

Presets.DIR = "presets"
Presets.SESSION = "session.lua"

function Presets.slug(name)
    local s = name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if s == "" then s = "preset" end
    return s
end

function Presets.list()
    local out = {}
    for _, file in ipairs(FS.list(Presets.DIR, ".lua")) do
        local path = Presets.DIR .. "/" .. file
        local text = FS.read(path)
        local t = text and Serialize.decode(text, "=" .. path)
        if t then
            local realDir = love.filesystem.getRealDirectory(path)
            table.insert(out, {
                file = file,
                path = path,
                name = t.name or file:gsub("%.lua$", ""),
                desc = t.desc,
                gallery = t.gallery,
                order = t.order or 1000,
                user = realDir == love.filesystem.getSaveDirectory(),
                data = t,
            })
        end
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function Presets.read(info)
    if info.data then return info.data end
    local text = FS.read(info.path)
    if not text then return nil, "cannot read " .. info.path end
    return Serialize.decode(text, "=" .. info.path)
end

function Presets.capture(pipeline, meta)
    meta = meta or {}
    local t = {
        version = 1,
        name = meta.name or "Untitled",
        desc = meta.desc,
        gallery = meta.gallery,
        order = meta.order,
        render = { scale = pipeline.renderScale },
        chain = {},
        mod = {},
    }
    if pipeline.source then
        local s = pipeline.source:serialize()
        t.source = { id = s.id, params = s.params }
    end
    for _, node in ipairs(pipeline.chain) do
        table.insert(t.chain, node:serialize())
    end
    return t
end

-- Load a preset into a pipeline. Returns true, warnings | nil, err
function Presets.apply(pipeline, preset, registry)
    if type(preset) ~= "table" then return nil, "not a preset" end
    local warnings = {}
    if preset.source and preset.source.id then
        local e = registry.get(preset.source.id)
        if e then
            local node = pipeline:setSource(e)
            node:applyParams(preset.source.params)
        else
            table.insert(warnings, "missing source " .. preset.source.id)
        end
    end
    pipeline:clearChain()
    for _, item in ipairs(preset.chain or {}) do
        local e = item.id and registry.get(item.id)
        if e then
            local node = pipeline:addEffect(e)
            node.enabled = item.enabled ~= false
            node:applyParams(item.params)
        else
            table.insert(warnings, "missing effect " .. tostring(item.id))
        end
    end
    if preset.render and preset.render.scale then
        pipeline:setRenderScale(preset.render.scale)
    end
    return true, warnings
end

function Presets.save(pipeline, name, meta)
    meta = meta or {}
    meta.name = name
    local t = Presets.capture(pipeline, meta)
    local text = Serialize.encode(t, "-- Shader Playground preset")
    local path = Presets.DIR .. "/" .. Presets.slug(name) .. ".lua"
    return FS.writeProject(path, text)
end

function Presets.delete(info)
    if info.user then
        return love.filesystem.remove(info.path)
    end
    local src = FS.writableSourceDir()
    if src then
        return os.remove(src .. "/" .. info.path)
    end
    return false
end

-- Session autosave (save directory only; not part of the project).
function Presets.saveSession(pipeline, extra)
    local t = Presets.capture(pipeline, { name = "Session" })
    t.extra = extra
    love.filesystem.write(Presets.SESSION, Serialize.encode(t, "-- autosaved session"))
end

function Presets.loadSession()
    if not love.filesystem.getInfo(Presets.SESSION) then return nil end
    local text = love.filesystem.read(Presets.SESSION)
    return Serialize.decode(text, "=session")
end

return Presets
