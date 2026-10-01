--[[
    Render pipeline: source -> effect chain -> present.

        source node  ──▶ sourceTex (GLSL passes or a Lua draw)
        effect nodes ──▶ each node runs its passes; output feeds the next
        present      ──▶ outputCanvas (rgba8, out size, dithered)

    Sizes: the output size is what gets displayed / captured. Work size is
    output × renderScale. A shader's @scale and each pass's scale multiply
    on top. Transient targets come from a frame-scoped pool; persistent
    passes (persist / in=self / iFeedback) use node-owned double buffers.
]]

local Params = require("src.params")
local Pool = require("src.render.canvas_pool")
local Node = require("src.render.node")

local lg = love.graphics

local Pipeline = {}
Pipeline.__index = Pipeline

local whiteImage, blackImage, presentShader

local PRESENT_GLSL = [[
#pragma language glsl3
uniform float dither;
float h12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    // Triangular dither removes banding when HDR buffers drop to 8 bits.
    float n = h12(sc) + h12(sc + 17.13) - 1.0;
    c += n * dither / 255.0;
    return vec4(clamp(c, 0.0, 1.0), 1.0);
}
]]

local function initShared()
    if whiteImage then return end
    local d = love.image.newImageData(1, 1)
    d:setPixel(0, 0, 1, 1, 1, 1)
    whiteImage = lg.newImage(d)
    local b = love.image.newImageData(1, 1)
    b:setPixel(0, 0, 0, 0, 0, 1)
    blackImage = lg.newImage(b)
    presentShader = lg.newShader(PRESENT_GLSL)
end

function Pipeline.new(opts)
    initShared()
    opts = opts or {}
    local formats = lg.getCanvasFormats()
    local self = setmetatable({
        pool = Pool.new(),
        source = nil,
        chain = {},
        outW = opts.width or 1280,
        outH = opts.height or 720,
        renderScale = opts.renderScale or 1,
        format = formats.rgba16f and "rgba16f" or "rgba8",
        dither = 1,
        bypass = false,
        solo = nil,          -- node: render the chain only up to this node
        sourceTex = nil,
        finalTex = nil,
        outputCanvas = nil,
        lastError = nil,
    }, Pipeline)
    self:setOutputSize(self.outW, self.outH)
    return self
end

function Pipeline:setOutputSize(w, h)
    w, h = math.max(16, math.floor(w)), math.max(16, math.floor(h))
    if self.outputCanvas and self.outW == w and self.outH == h then return end
    self.outW, self.outH = w, h
    if self.outputCanvas then self.outputCanvas:release() end
    self.outputCanvas = lg.newCanvas(w, h, { format = "rgba8" })
    self.pool:trim()
end

function Pipeline:setRenderScale(s)
    s = math.max(0.25, math.min(1, s))
    if s ~= self.renderScale then
        self.renderScale = s
        self.pool:trim()
    end
end

function Pipeline:workSize()
    return math.max(8, math.floor(self.outW * self.renderScale + 0.5)),
           math.max(8, math.floor(self.outH * self.renderScale + 0.5))
end

----------------------------------------------------------------------
-- Chain editing
----------------------------------------------------------------------

function Pipeline:setSource(entry)
    if self.source then self.source:destroy() end
    self.source = entry and Node.new(entry) or nil
    return self.source
end

function Pipeline:addEffect(entry, index)
    local node = Node.new(entry)
    index = index or (#self.chain + 1)
    table.insert(self.chain, math.max(1, math.min(index, #self.chain + 1)), node)
    return node
end

function Pipeline:removeEffect(node)
    for i, n in ipairs(self.chain) do
        if n == node then
            table.remove(self.chain, i)
            node:destroy()
            if self.solo == node then self.solo = nil end
            return i
        end
    end
end

function Pipeline:moveEffect(node, delta)
    for i, n in ipairs(self.chain) do
        if n == node then
            local j = math.max(1, math.min(#self.chain, i + delta))
            table.remove(self.chain, i)
            table.insert(self.chain, j, node)
            return j
        end
    end
end

function Pipeline:moveEffectTo(node, index)
    for i, n in ipairs(self.chain) do
        if n == node then
            table.remove(self.chain, i)
            index = math.max(1, math.min(#self.chain + 1, index))
            table.insert(self.chain, index, node)
            return index
        end
    end
end

function Pipeline:replaceEffect(node, entry)
    for i, n in ipairs(self.chain) do
        if n == node then
            local new = Node.new(entry)
            new.enabled = node.enabled
            self.chain[i] = new
            node:destroy()
            if self.solo == node then self.solo = new end
            return new
        end
    end
end

function Pipeline:clearChain()
    for _, n in ipairs(self.chain) do n:destroy() end
    self.chain = {}
    self.solo = nil
end

----------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------

local function sendAuto(pass, name, value)
    if pass.has(name) then pass.shader:send(name, value) end
end

function Pipeline:drawPass(node, pass, inTex, target, tw, th, ctx)
    local shader, has = pass.shader, pass.has
    local o = pass.opts
    local entry = node.entry
    local inW, inH = inTex:getDimensions()

    lg.setCanvas(target)
    lg.setShader(shader)

    if has("iTime") then shader:send("iTime", ctx.time) end
    if has("iTimeDelta") then shader:send("iTimeDelta", ctx.dt) end
    if has("iFrame") then shader:send("iFrame", node.frame) end
    if has("iResolution") then shader:send("iResolution", { tw, th, tw / th }) end
    if has("iTexel") then shader:send("iTexel", { 1 / inW, 1 / inH }) end
    if has("iMouse") then shader:send("iMouse", ctx.mouse) end
    if has("iSource") then shader:send("iSource", self.sourceTex or blackImage) end
    if has("iInput") then shader:send("iInput", ctx.input or blackImage) end
    if has("iFeedback") then shader:send("iFeedback", ctx.feedback or blackImage) end
    if has("iPrev") then
        local buf = node.buffers[o.name]
        shader:send("iPrev", buf and buf.cur or blackImage)
    end
    for name in pairs(entry.textures or {}) do
        if has(name) then
            local t = ctx.outputs[name]
            if not t and node.buffers[name] then t = node.buffers[name].cur end
            shader:send(name, t or blackImage)
        end
    end
    for _, def in ipairs(entry.params or {}) do
        Params.send(shader, has, def, Params.get(node, def, ctx.time))
    end

    local oldMin, oldMag, oldWrapS, oldWrapT
    if o.filter then
        oldMin, oldMag = inTex:getFilter()
        inTex:setFilter(o.filter, o.filter)
    end
    if o.wrap then
        oldWrapS, oldWrapT = inTex:getWrap()
        inTex:setWrap(o.wrap, o.wrap)
    end

    lg.draw(inTex, 0, 0, 0, tw / inW, th / inH)

    if oldMin then inTex:setFilter(oldMin, oldMag) end
    if oldWrapS then inTex:setWrap(oldWrapS, oldWrapT) end
end

-- Run all passes of a GLSL node. Returns its output texture.
function Pipeline:runNode(node, input, W, H, ctx)
    local entry = node.entry
    local passes = entry.passes
    if not passes or #passes == 0 then return input end

    local outputs = {}
    local lastName = passes[#passes].opts.name
    local fbBuf = entry.usesFeedback and node.buffers[lastName] or nil
    local nodeCtx = {
        time = ctx.time, dt = ctx.dt, mouse = ctx.mouse,
        input = input, outputs = outputs,
        feedback = fbBuf and fbBuf.cur or nil,
    }

    local result
    for i, pass in ipairs(passes) do
        local o = pass.opts
        local tw = math.max(1, math.floor(W * o.scale + 0.5))
        local th = math.max(1, math.floor(H * o.scale + 0.5))
        local fmt = o.format or self.format
        local persist = o.persist or (i == #passes and entry.usesFeedback)
        local buf = persist and node:buffer(o.name, tw, th, fmt) or nil

        local inTex
        if o.input == "input" then
            inTex = input or whiteImage
        elseif o.input == "none" then
            inTex = whiteImage
        elseif o.input == "self" then
            inTex = buf.cur
        else
            inTex = outputs[o.input] or input or whiteImage
        end

        local a, b
        local target
        for it = 1, o.iterations do
            if persist then
                target = buf.nxt
            else
                if it % 2 == 1 then
                    a = a or self.pool:acquire(tw, th, fmt)
                    target = a
                else
                    b = b or self.pool:acquire(tw, th, fmt)
                    target = b
                end
            end
            self:drawPass(node, pass, inTex, target, tw, th, nodeCtx)
            if persist then
                buf.cur, buf.nxt = buf.nxt, buf.cur
                target = buf.cur
            end
            if it < o.iterations then inTex = target end
        end
        outputs[o.name] = target
        result = target
    end
    return result
end

function Pipeline:renderLuaSource(node, W, H, ctx)
    local entry = node.entry
    local mod = entry.module
    local canvas = self.pool:acquire(W, H, self.format)
    lg.setCanvas(canvas)
    lg.clear(0, 0, 0, 1)
    lg.setShader()
    lg.setBlendMode("alpha", "alphamultiply")
    lg.setColor(1, 1, 1, 1)
    if mod and mod.draw then
        if not node.luaState then
            node.luaState = mod.new and mod.new(W, H, node.values) or {}
        end
        local ok, err = pcall(mod.draw, node.luaState, W, H, ctx.time, node.values, ctx)
        if not ok then
            entry.errors = { { file = entry.path, line = tonumber(tostring(err):match(":(%d+):")) or 0, msg = tostring(err) } }
            node.luaState = nil
        end
    end
    lg.origin()
    return canvas
end

-- Advance Lua sources (they own their simulation state).
function Pipeline:update(dt, ctx)
    local node = self.source
    if node and node.entry.lang == "lua" then
        node:sync()
        local mod = node.entry.module
        if mod and mod.update and node.luaState then
            local W, H = self:workSize()
            local ok, err = pcall(mod.update, node.luaState, dt, node.values, W, H, ctx)
            if not ok then
                node.entry.errors = { { file = node.entry.path, line = 0, msg = tostring(err) } }
                node.luaState = nil
            end
        end
    end
end

--[[
    ctx = { time, dt, mouse = {x, y, down, click} }
]]
function Pipeline:render(ctx)
    self.pool:beginFrame()
    local W, H = self:workSize()

    lg.push("all")
    lg.origin()
    lg.setColor(1, 1, 1, 1)

    -- Source (or an external texture, used by the library's hover preview)
    local src = self.source
    local sourceTex = self.inputTex
    if src and not sourceTex then
        src:sync()
        local s = src.entry.scale or 1
        local sw = math.max(8, math.floor(W * s + 0.5))
        local sh = math.max(8, math.floor(H * s + 0.5))
        if src.entry.lang == "lua" then
            sourceTex = self:renderLuaSource(src, sw, sh, ctx)
        else
            lg.setBlendMode("replace", "premultiplied")
            sourceTex = self:runNode(src, nil, sw, sh, ctx)
        end
        src.frame = src.frame + 1
    end
    if not sourceTex then
        sourceTex = self.pool:acquire(W, H, self.format)
        lg.setCanvas(sourceTex)
        lg.clear(0.02, 0.02, 0.03, 1)
    end
    self.sourceTex = sourceTex

    -- Effects
    local tex = sourceTex
    if not self.bypass then
        lg.setBlendMode("replace", "premultiplied")
        for _, node in ipairs(self.chain) do
            node:sync()
            if node.enabled and node.entry.passes then
                tex = self:runNode(node, tex, W, H, ctx)
                node.frame = node.frame + 1
            end
            if node == self.solo then break end
        end
    end
    self.finalTex = tex

    -- Present
    lg.setCanvas(self.outputCanvas)
    lg.setBlendMode("replace", "premultiplied")
    lg.setShader(presentShader)
    presentShader:send("dither", self.dither)
    local tw, th = tex:getDimensions()
    lg.draw(tex, 0, 0, 0, self.outW / tw, self.outH / th)

    lg.pop()
end

-- Draw the output into a rectangle. `split` (0..1) shows the source on
-- the left of the split line for before/after comparison.
function Pipeline:draw(x, y, w, h, split)
    lg.push("all")
    lg.setShader()
    lg.setBlendMode("replace", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    local ow, oh = self.outputCanvas:getDimensions()
    lg.draw(self.outputCanvas, x, y, 0, w / ow, h / oh)
    if split and self.sourceTex then
        local sw, sh = self.sourceTex:getDimensions()
        lg.intersectScissor(x, y, math.max(0, w * split), h)
        lg.draw(self.sourceTex, x, y, 0, w / sw, h / sh)
    end
    lg.pop()
end

function Pipeline:destroy()
    if self.source then self.source:destroy() end
    for _, n in ipairs(self.chain) do n:destroy() end
    self.pool:trim()
end

return Pipeline
