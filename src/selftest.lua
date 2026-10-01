--[[
    Self test:  lovec . --selftest
    (the flag must come after the path; LÖVE treats the first argument as the game)

    - parser unit checks on fixture strings
    - compiles every shader and Lua source (fails on errors)
    - renders every source, and every effect over a test source, for a few frames
    - renders every preset
    - round-trips presets through the serializer
    - writes a contact sheet PNG to the save directory
    Exits with code 1 on any failure.
]]

local Parse = require("src.shaderlib.parse")
local Registry = require("src.shaderlib.registry")
local Pipeline = require("src.render.pipeline")
local Serialize = require("src.util.serialize")
local Images = require("src.images")

local SelfTest = {}

local failures = {}
local log = {}

local function fail(msg)
    table.insert(failures, msg)
    print("  FAIL " .. msg)
end

local function check(cond, msg)
    if not cond then fail(msg) end
    return cond
end

local function parserTests()
    print("[selftest] parser")
    local d = Parse.parse([[
// @name Test
// @category Lens
// @about line one
// @about line two
uniform float a; // default=0.5 min=0 max=2 step=0.1 tip="hello world"
uniform vec3 c; // color default=#ff8000
uniform vec2 p; // xy default=0.25,0.75
uniform int m; // enum=One,Two,Three default=Two
uniform bool b; // default=true
uniform float iTime;
uniform float bare;
uniform Image other;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) { return vec4(1.0); }
]], "effect")
    check(d.meta.name == "Test", "meta name")
    check(d.meta.about == "line one line two", "about concatenation")
    check(#d.params == 6, "param count (got " .. #d.params .. ")")
    local byName = {}
    for _, p in ipairs(d.params) do byName[p.name] = p end
    check(byName.a and byName.a.default == 0.5 and byName.a.max == 2 and byName.a.tip == "hello world", "float param")
    check(byName.c and byName.c.kind == "color" and math.abs(byName.c.default[2] - 128 / 255) < 1e-6, "color param")
    check(byName.p and byName.p.kind == "xy" and byName.p.default[2] == 0.75, "xy param")
    check(byName.m and byName.m.kind == "enum" and byName.m.default == 1, "enum default by label")
    check(byName.b and byName.b.kind == "bool" and byName.b.default == true, "bool param")
    check(d.textures.other, "texture uniform")
    check(#d.passes == 1 and d.passes[1].opts.input == "input", "single pass default input")
    local warnedAuto = false
    for _, w in ipairs(d.warnings) do if w.msg:find("iTime") then warnedAuto = true end end
    check(warnedAuto, "warn on redeclared auto uniform")

    local mp = Parse.parse([[
uniform float x; // default=1
//@pass one scale=0.5 format=rgba32f
vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return vec4(x); }
//@pass two
vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return vec4(1.0); }
//@pass sim in=self iterations=4
vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return vec4(1.0); }
//@pass bad in=nowhere bogus=1
vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return vec4(1.0); }
]], "source")
    check(#mp.passes == 4, "multipass count")
    check(mp.passes[1].opts.input == "none", "source first pass reads none")
    check(mp.passes[1].opts.scale == 0.5 and mp.passes[1].opts.format == "rgba32f", "pass options")
    check(mp.passes[2].opts.input == "one", "default input is previous pass")
    check(mp.passes[3].opts.persist and mp.passes[3].opts.iterations == 4, "self implies persist")
    check(mp.passes[4].opts.input == "sim", "bad input falls back")
    check(#mp.common == 1, "common section lines")

    local junk = Parse.parse("uniform float ; // ???\n%%%% garbage\nuniform vec3 q; // color default=#zzz", "effect")
    check(junk ~= nil, "garbage input does not crash")

    local toks = Parse.tokenize([[color default=#fff tip='a b c' min=-1]])
    check(toks[1].word == "color" and toks[3].value == "a b c" and toks[4].value == "-1", "tokenizer")
end

local function serializerTests()
    print("[selftest] serializer")
    local t = { name = "x \"quoted\"", list = { 1, 2.5, -3 }, nested = { a = true, b = { 1, 2, 3, 4, 5 } }, ["weird key"] = 1 }
    local text = Serialize.encode(t)
    local back, err = Serialize.decode(text)
    check(back, "decode: " .. tostring(err))
    if back then
        check(back.name == t.name and back.list[2] == 2.5 and back.nested.b[5] == 5 and back["weird key"] == 1, "round trip")
    end
    check(Serialize.decode("os.exit()") == nil, "sandbox blocks globals")
    check(Serialize.decode(string.char(27) .. "Lua") == nil, "rejects bytecode")
end

local function readPixel(canvas)
    local data = canvas:newImageData()
    local w, h = data:getDimensions()
    local sum = 0
    for i = 0, 7 do
        local r, g, b = data:getPixel(math.floor(w * (i + 0.5) / 8), math.floor(h * 0.5))
        sum = sum + r + g + b
    end
    data:release()
    return sum
end

function SelfTest.run()
    print("[selftest] starting")
    parserTests()
    serializerTests()

    Images.init()
    Registry.init()
    local all = Registry.all()
    print(string.format("[selftest] %d registry entries", #all))
    for _, e in ipairs(all) do
        if e.errors then
            for _, er in ipairs(e.errors) do
                fail(string.format("%s:%d: %s", er.file or "?", er.line or 0, er.msg))
            end
        end
        for _, w in ipairs(e.warnings or {}) do
            print(string.format("  warn %s:%d: %s", w.file or "?", w.line or 0, w.msg))
        end
        check(e.name and e.name ~= "", e.id .. " has a name")
    end

    local TW, TH = 320, 180
    local sheet = {}
    local p = Pipeline.new({ width = TW, height = TH })
    local mouse = { 0.5, 0.5, 0, 0 }

    local function runFrames(n, label)
        local ok, err = pcall(function()
            for f = 1, n do
                local ctx = { time = f / 30, dt = 1 / 30, mouse = mouse }
                p:update(1 / 30, ctx)
                p:render(ctx)
            end
        end)
        if not check(ok, label .. ": " .. tostring(err)) then return end
        local img = p.outputCanvas:newImageData()
        table.insert(sheet, { label = label, image = love.graphics.newImage(img) })
        img:release()
        return true
    end

    local testSource = Registry.get("lua/test_card")
    for _, e in ipairs(Registry.list("source")) do
        p:clearChain()
        p:setSource(e)
        runFrames(20, e.name)
        if readPixel(p.outputCanvas) == 0 and e.id ~= "lua/image" then
            print("  note: " .. e.name .. " rendered black at sample points")
        end
    end
    p:setSource(testSource)
    for _, e in ipairs(Registry.list("effect")) do
        p:clearChain()
        p:addEffect(e)
        runFrames(10, e.name)
    end

    -- Presets
    local okPresets, Presets = pcall(require, "src.presets")
    if okPresets and Presets.list then
        for _, info in ipairs(Presets.list()) do
            local preset, err = Presets.read(info)
            if check(preset, "preset " .. info.file .. ": " .. tostring(err)) then
                -- every param named in the preset must exist on its shader
                local items = { preset.source }
                for _, item in ipairs(preset.chain or {}) do items[#items + 1] = item end
                for _, item in ipairs(items) do
                    local entry = item.id and Registry.get(item.id)
                    if check(entry, info.file .. ": unknown id " .. tostring(item.id)) then
                        local names = {}
                        for _, def in ipairs(entry.params or {}) do names[def.name] = true end
                        for k in pairs(item.params or {}) do
                            check(names[k], info.file .. ": " .. item.id .. " has no param '" .. k .. "'")
                        end
                    end
                end
                local text = Serialize.encode(preset)
                local back = Serialize.decode(text)
                check(back and back.name == preset.name, "preset round trip " .. info.file)
                local applied, aerr = Presets.apply(p, preset, Registry)
                if check(applied, "apply " .. info.file .. ": " .. tostring(aerr)) then
                    runFrames(20, "preset: " .. (preset.name or info.file))
                end
            end
        end
    end

    -- Session round trip: capture a chain, encode, decode, apply to a fresh pipeline
    if okPresets then
        p:clearChain()
        p:setSource(Registry.get("sources/aurora"))
        local a = p:addEffect(Registry.get("effects/bloom"))
        a.values.intensity = 1.7
        local b = p:addEffect(Registry.get("effects/vignette"))
        b.enabled = false
        local text = Serialize.encode(Presets.capture(p, { name = "Session" }))
        local q = Pipeline.new({ width = 64, height = 36 })
        local ok = Presets.apply(q, Serialize.decode(text), Registry)
        check(ok and q.source.entry.id == "sources/aurora" and #q.chain == 2
            and q.chain[1].values.intensity == 1.7 and q.chain[2].enabled == false, "session round trip")
        q:destroy()
    end

    -- Contact sheet
    local cols = 6
    local rows = math.ceil(#sheet / cols)
    local sheetCanvas = love.graphics.newCanvas(cols * TW, rows * (TH + 20))
    love.graphics.push("all")
    love.graphics.setCanvas(sheetCanvas)
    love.graphics.clear(0.1, 0.1, 0.12, 1)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    for i, s in ipairs(sheet) do
        local x = ((i - 1) % cols) * TW
        local y = math.floor((i - 1) / cols) * (TH + 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(s.image, x, y)
        love.graphics.print(s.label, x + 4, y + TH + 3)
    end
    love.graphics.pop()
    local data = sheetCanvas:newImageData()
    data:encode("png", "selftest_contact_sheet.png")
    print("[selftest] contact sheet: " .. love.filesystem.getSaveDirectory() .. "/selftest_contact_sheet.png")

    p:destroy()
    if #failures > 0 then
        print(string.format("[selftest] FAILED (%d)", #failures))
        return false
    end
    print("[selftest] OK")
    return true
end

return SelfTest
