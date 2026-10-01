--[[
    Hover preview check: hover an effect and a source in the library.

        lovec . --fresh --preset 06_watercolor_dream --script tests/preview.lua
]]

local function hover(pattern)
    return function(App)
        local S = require("src.ui.core").state
        for id, r in pairs(S.rects or {}) do
            if id:match(pattern) then
                S.virtualMouse[1], S.virtualMouse[2] = r[1] + r[3] / 2, r[2] + r[4] / 2
                return true, "hover " .. id
            end
        end
        return false, "hover " .. pattern
    end
end

return {
    -- Settings persist across runs and --fresh only skips the session, so
    -- start from the Library tab whatever the last run left selected.
    { at = 0.05, check = function(App) App.leftTab = "library"; return true, "library tab" end },
    { at = 0.8, check = hover("^lib:effects/chromatic_aberration$") },
    { at = 1.6, shot = "preview_effect" },
    { at = 1.7, check = hover("^lib:sources/glass_garden$") },
    { at = 2.6, shot = "preview_source" },
    { at = 2.7, move = { 800, 450 } },
    { at = 3.2, quit = true },
}
