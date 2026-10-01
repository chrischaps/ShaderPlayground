--[[
    UI theme: palette, metrics, fonts.

    The look is "glass over art": translucent panels float over the live
    image, which shows through them blurred. A single cool accent color
    plus warm signal colors for recording and errors.
]]

local Theme = {}

local function hex(s, a)
    local r = tonumber(s:sub(2, 3), 16) / 255
    local g = tonumber(s:sub(4, 5), 16) / 255
    local b = tonumber(s:sub(6, 7), 16) / 255
    return { r, g, b, a or 1 }
end
Theme.hex = hex

Theme.colors = {
    glass      = hex("#0b0b12", 0.66),   -- panel tint over the blurred scene
    glassEdge  = hex("#ffffff", 0.07),
    glassHi    = hex("#ffffff", 0.10),   -- top highlight line
    surface    = hex("#ffffff", 0.045),  -- rows, fields
    surfaceHi  = hex("#ffffff", 0.085),  -- hovered rows
    surfaceAct = hex("#ffffff", 0.13),
    track      = hex("#ffffff", 0.08),
    text       = hex("#ebe9f4"),
    textDim    = hex("#a3a0b5"),
    textFaint  = hex("#6d6a80"),
    accent     = hex("#a594ff"),
    accentSoft = hex("#a594ff", 0.22),
    accent2    = hex("#6ee7d8"),          -- secondary (sources)
    record     = hex("#ff5c7a"),
    warn       = hex("#ffb547"),
    error      = hex("#ff6b6b"),
    ok         = hex("#5ee6a8"),
    shadow     = hex("#000000", 0.35),
    popup      = hex("#14131d", 0.97),
}

Theme.metrics = {
    radius = 8,
    rowH = 30,
    pad = 14,
    gap = 6,
    topBarH = 46,
    leftW = 264,
    rightW = 330,
    margin = 10,
}

Theme.fonts = {}

function Theme.load()
    local dir = "assets/fonts/"
    local function font(file, size, fallbackSize)
        local ok, f = pcall(love.graphics.newFont, dir .. file, size)
        if ok then return f end
        return love.graphics.newFont(fallbackSize or size)
    end
    Theme.fonts.body = font("Inter-Regular.ttf", 14)
    Theme.fonts.medium = font("Inter-Medium.ttf", 14)
    Theme.fonts.small = font("Inter-Regular.ttf", 12)
    Theme.fonts.tiny = font("Inter-Medium.ttf", 10.5)
    Theme.fonts.title = font("Inter-SemiBold.ttf", 15)
    Theme.fonts.heading = font("Inter-SemiBold.ttf", 11)
    Theme.fonts.big = font("Inter-SemiBold.ttf", 28)
    Theme.fonts.caption = font("Inter-Regular.ttf", 16)
    Theme.fonts.mono = font("JetBrainsMono-Regular.ttf", 12)
    Theme.fonts.monoSmall = font("JetBrainsMono-Regular.ttf", 11)
    for _, f in pairs(Theme.fonts) do
        f:setFilter("linear", "linear")
    end
end

return Theme
