--[[
    Shader registry: discovers shaders/ and Lua sources, compiles them, and
    hot-reloads on change.

    Entry fields:
        id        "effects/bloom", "sources/aurora", "lua/particles"
        kind      "effect" | "source"
        lang      "glsl" | "lua"
        path      file path relative to the game root
        name, category, desc, about, scale
        params    list of param defs
        passes    list of { opts, shader, has, lineMap }  (last good build)
        textures  set of texture uniform names
        usesFeedback  true if any pass samples iFeedback
        errors    nil, or list of {file, line, msg} from the latest attempt
        warnings  list of {file, line, msg}
        version   increments every successful (re)load
        module    (lua sources) the loaded module table
]]

local Parse = require("src.shaderlib.parse")
local Compose = require("src.shaderlib.compose")
local Compile = require("src.shaderlib.compile")
local Params = require("src.params")
local FS = require("src.util.fs")

local Registry = {}

local DIRS = {
    { dir = "shaders/sources", kind = "source", lang = "glsl", ext = ".glsl", prefix = "sources/" },
    { dir = "shaders/effects", kind = "effect", lang = "glsl", ext = ".glsl", prefix = "effects/" },
    { dir = "src/sources/lua", kind = "source", lang = "lua", ext = ".lua", prefix = "lua/" },
}

local CATEGORY_ORDER = {
    -- sources
    Generative = 1, Raymarched = 2, Simulation = 3, Scenes = 4, Images = 5,
    -- effects
    Light = 10, Lens = 11, Color = 12, Retro = 13, Paint = 14, Distort = 15,
    Time = 16, Film = 17,
}

local entries = {}
local byId = {}
local listeners = {}
local pollTimer, scanTimer = 0, 0
Registry.pollInterval = 0.25
Registry.scanInterval = 2.0
Registry.enabled = true

local function notify(entry, event)
    for _, fn in ipairs(listeners) do fn(entry, event) end
end

function Registry.onChange(fn)
    table.insert(listeners, fn)
end

local function titleFromFile(file)
    local base = file:gsub("%.%w+$", ""):gsub("[_%-]", " ")
    return (base:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

local function statDeps(deps)
    local out = {}
    for path in pairs(deps) do
        local mt, size = FS.stat(path)
        out[path] = { modtime = mt or -1, size = size or -1 }
    end
    return out
end

local function depsChanged(entry)
    for path, s in pairs(entry.deps or {}) do
        local mt, size = FS.stat(path)
        if (mt or -1) ~= s.modtime or (size or -1) ~= s.size then
            return true
        end
    end
    return false
end

local function signature(entry)
    -- Text of the file plus every dependency, used to skip no-op reloads.
    local parts = {}
    local paths = {}
    for p in pairs(entry.deps or {}) do paths[#paths + 1] = p end
    table.sort(paths)
    for _, p in ipairs(paths) do parts[#parts + 1] = FS.read(p) or "" end
    return table.concat(parts, "\0")
end

----------------------------------------------------------------------
-- GLSL
----------------------------------------------------------------------

local function loadGlsl(entry)
    local text = FS.read(entry.path)
    if not text or text == "" then
        -- Editor mid-save; try again next poll.
        return false, "empty"
    end
    local desc = Parse.parse(text, entry.kind)

    local passes, allErrors, deps = {}, {}, { [entry.path] = true }
    local usesFeedback = false
    for _, pass in ipairs(desc.passes) do
        local code, lineMap, passDeps, composeErrors = Compose.build(desc, pass, entry.path, FS.read)
        for p in pairs(passDeps) do deps[p] = true end
        for _, e in ipairs(composeErrors) do table.insert(allErrors, e) end
        if #composeErrors == 0 then
            local shader, errs = Compile.compile(code, lineMap, entry.path)
            if shader then
                local has = Compile.uniformCache(shader)
                if has("iFeedback") then usesFeedback = true end
                table.insert(passes, { opts = pass.opts, shader = shader, has = has, lineMap = lineMap, code = code })
            else
                for _, e in ipairs(errs) do
                    e.pass = pass.opts.name
                    table.insert(allErrors, e)
                end
            end
        end
    end

    entry.deps = statDeps(deps)
    entry.warnings = {}
    for _, w in ipairs(desc.warnings) do
        table.insert(entry.warnings, { file = entry.path, line = w.line, msg = w.msg })
    end

    -- Metadata and params update even when compile fails, so the UI can show
    -- the file's name. Render keeps the last good passes.
    local m = desc.meta
    entry.name = m.name or titleFromFile(entry.file)
    entry.category = m.category or (entry.kind == "source" and "Generative" or "Other")
    entry.desc = m.desc
    entry.about = m.about
    entry.author = m.author
    entry.scale = m.scale or 1

    if #allErrors > 0 then
        entry.errors = allErrors
        return false, "compile"
    end

    entry.errors = nil
    entry.params = desc.params
    entry.textures = desc.textures
    entry.passes = passes
    entry.usesFeedback = usesFeedback
    entry.version = (entry.version or 0) + 1
    return true
end

----------------------------------------------------------------------
-- Lua sources
----------------------------------------------------------------------

local function loadLua(entry)
    local ok, chunk = pcall(love.filesystem.load, entry.path)
    if not ok or not chunk then
        entry.errors = { { file = entry.path, line = 0, msg = tostring(chunk) } }
        entry.deps = statDeps({ [entry.path] = true })
        return false, "compile"
    end
    local ok2, mod = pcall(chunk)
    if not ok2 or type(mod) ~= "table" then
        local msg = tostring(mod)
        local line = tonumber(msg:match(":(%d+):")) or 0
        entry.errors = { { file = entry.path, line = line, msg = msg } }
        entry.deps = statDeps({ [entry.path] = true })
        return false, "compile"
    end
    entry.deps = statDeps({ [entry.path] = true })
    entry.errors = nil
    entry.warnings = {}
    entry.module = mod
    entry.name = mod.name or titleFromFile(entry.file)
    entry.category = mod.category or "Scenes"
    entry.desc = mod.desc
    entry.about = mod.about
    entry.scale = mod.scale or 1
    entry.params = {}
    for _, raw in ipairs(mod.params or {}) do
        table.insert(entry.params, Params.normalize(raw))
    end
    entry.passes = nil
    entry.version = (entry.version or 0) + 1
    return true
end

----------------------------------------------------------------------

local function load(entry)
    if entry.lang == "lua" then
        return loadLua(entry)
    end
    return loadGlsl(entry)
end

local function sortEntries()
    table.sort(entries, function(a, b)
        if a.kind ~= b.kind then return a.kind == "source" end
        local ca = CATEGORY_ORDER[a.category] or 50
        local cb = CATEGORY_ORDER[b.category] or 50
        if ca ~= cb then return ca < cb end
        if a.category ~= b.category then return (a.category or "") < (b.category or "") end
        return (a.name or a.id) < (b.name or b.id)
    end)
end

local function scan()
    local found = {}
    local added = false
    for _, d in ipairs(DIRS) do
        for _, file in ipairs(FS.list(d.dir, d.ext)) do
            local id = d.prefix .. file:gsub("%.%w+$", "")
            found[id] = true
            if not byId[id] then
                local entry = {
                    id = id, kind = d.kind, lang = d.lang, file = file,
                    path = d.dir .. "/" .. file, version = 0,
                }
                byId[id] = entry
                table.insert(entries, entry)
                local ok = load(entry)
                entry.sig = signature(entry)
                notify(entry, ok and "added" or "error")
                added = true
            end
        end
    end
    for _, e in ipairs(entries) do
        local wasMissing = e.missing
        e.missing = not found[e.id] or nil
        if e.missing and not wasMissing then notify(e, "removed") end
    end
    if added then sortEntries() end
end

function Registry.init()
    scan()
    sortEntries()
end

function Registry.reload(entry)
    local ok, why = load(entry)
    if why == "empty" then return end
    entry.sig = signature(entry)
    notify(entry, ok and "reloaded" or "error")
end

function Registry.reloadAll()
    for _, e in ipairs(entries) do
        Registry.reload(e)
    end
    sortEntries()
end

function Registry.poll(dt)
    if not Registry.enabled then return end
    pollTimer = pollTimer + dt
    scanTimer = scanTimer + dt
    if pollTimer >= Registry.pollInterval then
        pollTimer = 0
        for _, e in ipairs(entries) do
            if not e.missing and depsChanged(e) then
                -- modtime has 1s granularity; compare content before rebuilding.
                local oldSig = e.sig
                local newDeps = e.deps
                e.deps = statDeps(e.deps)
                local sig = signature(e)
                if sig ~= oldSig then
                    local ok, why = load(e)
                    if why == "empty" then
                        e.deps = newDeps -- retry next poll
                    else
                        e.sig = signature(e)
                        notify(e, ok and "reloaded" or "error")
                        sortEntries()
                    end
                end
            end
        end
    end
    if scanTimer >= Registry.scanInterval then
        scanTimer = 0
        scan()
    end
end

function Registry.get(id)
    return byId[id]
end

function Registry.all()
    return entries
end

function Registry.list(kind)
    local out = {}
    for _, e in ipairs(entries) do
        if e.kind == kind and not e.missing then out[#out + 1] = e end
    end
    return out
end

-- Entries with problems (for the error panel).
function Registry.problems()
    local out = {}
    for _, e in ipairs(entries) do
        if e.errors and not e.missing then out[#out + 1] = e end
    end
    return out
end

return Registry
