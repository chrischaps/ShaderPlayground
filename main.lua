--[[
    Shader Playground
    A tool for testing and tweaking GLSL shader effects in Love 2D

    Controls:
        Left/Right or A/D  - Switch between shaders
        Up/Down or W/S     - Select parameter
        +/- or Q/E         - Adjust selected parameter
        Shift + adjust     - Fine adjustment (0.01 instead of 0.1)
        R                  - Reset current shader parameters to defaults
        Space              - Toggle shader on/off (bypass)
        Tab                - Toggle UI visibility
        F11                - Toggle fullscreen
        Escape             - Quit
]]

local ShaderManager = require("shader_manager")
local UI = require("ui")

-- Constants
local CANVAS_WIDTH = 1280
local CANVAS_HEIGHT = 720

-- State
local canvas
local time = 0
local showUI = true
local bypass = false
local demoMode = "gradient"  -- What to draw behind the shader

-- Demo content
local demoImage
local particles = {}

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")

    -- Create main canvas
    canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)

    -- Initialize shader manager with example shaders
    ShaderManager.init()

    -- Initialize UI
    UI.init()

    -- Create some particles for demo
    for i = 1, 50 do
        table.insert(particles, {
            x = love.math.random() * CANVAS_WIDTH,
            y = love.math.random() * CANVAS_HEIGHT,
            vx = (love.math.random() - 0.5) * 100,
            vy = (love.math.random() - 0.5) * 100,
            radius = love.math.random(5, 20),
            hue = love.math.random()
        })
    end

    -- Try to load a demo image if one exists
    local success, result = pcall(love.graphics.newImage, "demo.png")
    if success then
        demoImage = result
    end
end

function love.update(dt)
    time = time + dt

    -- Update shader time uniform
    ShaderManager.update(dt)

    -- Update UI
    UI.update(dt)

    -- Update demo particles
    for _, p in ipairs(particles) do
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.hue = (p.hue + dt * 0.1) % 1

        -- Bounce off edges
        if p.x < 0 or p.x > CANVAS_WIDTH then p.vx = -p.vx end
        if p.y < 0 or p.y > CANVAS_HEIGHT then p.vy = -p.vy end
    end
end

function love.draw()
    -- Draw demo content to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.05, 0.05, 0.1, 1)

    drawDemoContent()

    love.graphics.setCanvas()

    -- Apply shader to canvas and draw to screen
    local scale = math.min(
        love.graphics.getWidth() / CANVAS_WIDTH,
        love.graphics.getHeight() / CANVAS_HEIGHT
    )
    local offsetX = (love.graphics.getWidth() - CANVAS_WIDTH * scale) / 2
    local offsetY = (love.graphics.getHeight() - CANVAS_HEIGHT * scale) / 2

    love.graphics.setColor(1, 1, 1, 1)

    if not bypass then
        local shader = ShaderManager.getCurrentShader()
        if shader then
            love.graphics.setShader(shader)
        end
    end

    love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
    love.graphics.setShader()

    -- Draw UI overlay
    if showUI then
        UI.draw(bypass)
    end
end

function drawDemoContent()
    love.graphics.setColor(1, 1, 1, 1)

    if demoMode == "gradient" then
        -- Colorful gradient background
        for y = 0, CANVAS_HEIGHT, 4 do
            local t = y / CANVAS_HEIGHT
            local r = 0.1 + 0.3 * math.sin(time + t * 3)
            local g = 0.1 + 0.3 * math.sin(time * 0.7 + t * 5)
            local b = 0.2 + 0.4 * math.sin(time * 0.5 + t * 2)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, y, CANVAS_WIDTH, 4)
        end

        -- Draw particles
        for _, p in ipairs(particles) do
            local r, g, b = hsvToRgb(p.hue, 0.8, 0.9)
            love.graphics.setColor(r, g, b, 0.8)
            love.graphics.circle("fill", p.x, p.y, p.radius)
        end

        -- Center glow
        local cx, cy = CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2
        for i = 1, 5 do
            local radius = 50 + i * 30 + math.sin(time * 2) * 20
            local alpha = 0.3 - i * 0.05
            love.graphics.setColor(0.8, 0.6, 1.0, alpha)
            love.graphics.circle("fill", cx, cy, radius)
        end

    elseif demoMode == "image" and demoImage then
        -- Draw demo image centered
        local iw, ih = demoImage:getDimensions()
        local scale = math.min(CANVAS_WIDTH / iw, CANVAS_HEIGHT / ih)
        local x = (CANVAS_WIDTH - iw * scale) / 2
        local y = (CANVAS_HEIGHT - ih * scale) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(demoImage, x, y, 0, scale, scale)

    elseif demoMode == "shapes" then
        -- Geometric shapes
        love.graphics.setColor(0.2, 0.3, 0.5, 1)
        love.graphics.rectangle("fill", 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)

        -- Rotating squares
        love.graphics.push()
        love.graphics.translate(CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2)
        for i = 1, 8 do
            love.graphics.push()
            love.graphics.rotate(time * 0.5 + i * math.pi / 4)
            local size = 100 + i * 30
            local r, g, b = hsvToRgb(i / 8, 0.7, 0.8)
            love.graphics.setColor(r, g, b, 0.6)
            love.graphics.rectangle("fill", -size/2, -size/2, size, size)
            love.graphics.pop()
        end
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function hsvToRgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end

    return r, g, b
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
    elseif key == "tab" then
        showUI = not showUI
    elseif key == "space" then
        bypass = not bypass
    elseif key == "r" then
        ShaderManager.resetCurrentParameters()
    elseif key == "1" then
        demoMode = "gradient"
    elseif key == "2" then
        demoMode = "shapes"
    elseif key == "3" and demoImage then
        demoMode = "image"
    else
        -- Pass to shader manager for shader/parameter navigation
        local shift = love.keyboard.isDown("lshift", "rshift")
        ShaderManager.handleKey(key, shift)
    end
end

function love.wheelmoved(x, y)
    local shift = love.keyboard.isDown("lshift", "rshift")
    ShaderManager.adjustParameter(y > 0 and 1 or -1, shift)
end

function love.resize(w, h)
    -- Canvas stays the same, just scaling changes
end
