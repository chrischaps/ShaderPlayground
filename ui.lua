--[[
    UI - Shader Playground Interface
    Displays shader info, parameters, and controls
]]

local ShaderManager = require("shader_manager")

local UI = {}

-- Colors
local colors = {
    background = {0.1, 0.1, 0.15, 0.9},
    panel = {0.15, 0.15, 0.2, 0.95},
    text = {0.9, 0.9, 0.95, 1},
    textDim = {0.6, 0.6, 0.65, 1},
    accent = {0.4, 0.7, 1.0, 1},
    selected = {0.3, 0.8, 0.5, 1},
    warning = {1.0, 0.6, 0.3, 1},
    bypass = {1.0, 0.4, 0.4, 1}
}

-- Layout
local panelWidth = 320
local panelPadding = 16
local lineHeight = 24
local font
local smallFont

function UI.init()
    font = love.graphics.newFont(16)
    smallFont = love.graphics.newFont(12)
end

function UI.update(dt)
    -- Nothing to update for now
end

function UI.draw(bypass)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    love.graphics.setFont(font)

    -- Draw main panel (right side)
    local panelX = screenWidth - panelWidth - 10
    local panelY = 10
    local panelHeight = screenHeight - 20

    -- Panel background
    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)

    -- Panel border
    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)

    local x = panelX + panelPadding
    local y = panelY + panelPadding

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.print("SHADER PLAYGROUND", x, y)
    y = y + lineHeight + 8

    -- Current shader
    local shaders = ShaderManager.getShaders()
    local currentIndex = ShaderManager.getCurrentIndex()
    local currentShader = ShaderManager.getCurrent()

    love.graphics.setColor(colors.textDim)
    love.graphics.print("Shader " .. currentIndex .. "/" .. #shaders, x, y)
    y = y + lineHeight

    if currentShader then
        love.graphics.setColor(colors.text)
        love.graphics.print(currentShader.name, x, y)
        y = y + lineHeight

        -- Shader status
        if bypass then
            love.graphics.setColor(colors.bypass)
            love.graphics.print("[BYPASS]", x, y)
            y = y + lineHeight
        elseif currentShader.error then
            love.graphics.setColor(colors.warning)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Error: " .. currentShader.error, x, y, panelWidth - panelPadding * 2)
            love.graphics.setFont(font)
            y = y + lineHeight * 2
        end

        y = y + 16

        -- Parameters
        love.graphics.setColor(colors.accent)
        love.graphics.print("Parameters:", x, y)
        y = y + lineHeight + 4

        local selectedParam = ShaderManager.getSelectedParam()
        local visibleIndex = 0

        for i, param in ipairs(currentShader.params) do
            if not param.auto and not param.hidden then
                visibleIndex = visibleIndex + 1
                local isSelected = visibleIndex == selectedParam

                -- Selection indicator
                if isSelected then
                    love.graphics.setColor(colors.selected[1], colors.selected[2], colors.selected[3], 0.2)
                    love.graphics.rectangle("fill", x - 8, y - 2, panelWidth - panelPadding * 2 + 8, lineHeight + 4, 4)
                    love.graphics.setColor(colors.selected)
                    love.graphics.print("▸", x - 8, y)
                end

                -- Parameter name
                love.graphics.setColor(isSelected and colors.selected or colors.text)
                love.graphics.print(param.name, x + 8, y)

                -- Parameter value
                local valueStr = formatValue(param)
                local valueWidth = font:getWidth(valueStr)
                love.graphics.setColor(isSelected and colors.selected or colors.textDim)
                love.graphics.print(valueStr, panelX + panelWidth - panelPadding - valueWidth, y)

                -- Value bar for numeric params
                if type(param.value) == "number" and param.min and param.max then
                    y = y + lineHeight
                    local barWidth = panelWidth - panelPadding * 2 - 16
                    local barHeight = 6
                    local progress = (param.value - param.min) / (param.max - param.min)

                    -- Bar background
                    love.graphics.setColor(0.2, 0.2, 0.25, 1)
                    love.graphics.rectangle("fill", x + 8, y, barWidth, barHeight, 3)

                    -- Bar fill
                    love.graphics.setColor(isSelected and colors.selected or colors.accent)
                    love.graphics.rectangle("fill", x + 8, y, barWidth * progress, barHeight, 3)

                    y = y + 4
                end

                y = y + lineHeight
            end
        end

        if visibleIndex == 0 then
            love.graphics.setColor(colors.textDim)
            love.graphics.print("(no adjustable parameters)", x, y)
            y = y + lineHeight
        end
    end

    -- Controls help at bottom
    y = panelY + panelHeight - panelPadding - lineHeight * 8
    love.graphics.setColor(colors.accent)
    love.graphics.print("Controls:", x, y)
    y = y + lineHeight + 4

    love.graphics.setFont(smallFont)
    love.graphics.setColor(colors.textDim)
    local controls = {
        "← → or A/D  Switch shader",
        "↑ ↓ or W/S  Select parameter",
        "+/- or Q/E  Adjust value",
        "Shift       Fine adjustment",
        "R           Reset parameters",
        "Space       Toggle bypass",
        "Tab         Toggle UI",
        "1/2/3       Demo modes"
    }
    for _, control in ipairs(controls) do
        love.graphics.print(control, x, y)
        y = y + lineHeight * 0.9
    end
    love.graphics.setFont(font)

    -- FPS counter (top left)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(colors.textDim)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.setFont(font)
end

function formatValue(param)
    if type(param.value) == "number" then
        if param.value == math.floor(param.value) then
            return tostring(math.floor(param.value))
        else
            return string.format("%.3f", param.value)
        end
    elseif type(param.value) == "table" then
        if param.type == "color" then
            return string.format("RGB(%.2f,%.2f,%.2f)", param.value[1], param.value[2], param.value[3])
        elseif param.type == "vec2" then
            return string.format("(%.2f, %.2f)", param.value[1], param.value[2])
        else
            return "{"..table.concat(param.value, ", ").."}"
        end
    else
        return tostring(param.value)
    end
end

return UI
