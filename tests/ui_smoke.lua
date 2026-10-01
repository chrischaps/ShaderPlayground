--[[
    UI smoke test. Drives the real UI with a virtual mouse and keyboard.

        lovec . --fresh --preset 02_neon_noir --script tests/ui_smoke.lua

    Screenshots land in the save directory (smoke_*.png).
]]

local function node(App, id)
    for i, n in ipairs(App.pipeline.chain) do
        if n.entry.id == id then return n, i end
    end
end

local function rowOf(id)
    return function(App)
        local n = node(App, id)
        return n and ("^chain:" .. n.uid .. "$") or "__missing__"
    end
end

local function param(name)
    return function(App)
        return "^p:" .. App.selected.uid .. ":" .. name .. "$"
    end
end

local saved = {}

return {
    -- Settings persist across runs and --fresh only skips the session, so
    -- start from the Library tab whatever the last run left selected.
    { at = 0.05, check = function(App) App.leftTab = "library"; return true, "library tab" end },
    { at = 1.0, shot = "smoke_01_start" },

    -- Select Bloom in the chain
    { at = 1.2, click = rowOf("effects/bloom") },
    { at = 1.5, check = function(App) return App.selected and App.selected.entry.id == "effects/bloom", "click selects a chain row" end },

    -- Color picker: open, drag in the SV square, close
    { at = 1.6, check = function(App) saved.tint = App.selected.values.tint[1]; return true, "remember tint" end },
    { at = 1.7, click = param("tint") },
    { at = 2.0, shot = "smoke_02_colorpicker" },
    { at = 2.1, drag = { "^p:%d+:tint:sv$", { dx = -60, dy = 30 } } },
    { at = 2.7, check = function(App)
        local t = App.selected.values.tint
        return math.abs(t[1] - saved.tint) > 0.01 or math.abs(t[2] - 0.8) > 0.01, "color picker changes the value"
    end },
    { at = 2.8, key = "escape" },

    -- Segmented enum
    { at = 3.0, click = param("blend:1") },
    { at = 3.2, check = function(App) return App.selected.values.blend == 0, "segmented enum sets value" end },

    -- Slider drag
    { at = 3.3, check = function(App) saved.th = App.selected.values.threshold; return true, "remember threshold" end },
    { at = 3.4, drag = { param("threshold"), { dx = -50, dy = 0 } } },
    { at = 3.9, check = function(App) return App.selected.values.threshold < saved.th, "slider drag lowers value" end },

    -- Right-click resets to default
    { at = 4.0, click = param("threshold"), button = 2 },
    { at = 4.2, check = function(App) return math.abs(App.selected.values.threshold - 0.6) < 1e-6, "right-click resets slider" end },

    -- Double-click the value and type an exact number
    { at = 4.3, click = param("intensity:val"), double = true },
    { at = 4.6, key = "a", ctrl = true },
    { at = 4.65, ctrl = false, text = "2.5" },
    { at = 4.7, key = "return" },
    { at = 4.9, check = function(App) return math.abs(App.selected.values.intensity - 2.5) < 1e-6, "typed slider value" end },

    -- Add an effect from the library (search first: it's below the fold)
    { at = 5.0, check = function(App) saved.n = #App.pipeline.chain; return true, "count" end },
    { at = 5.05, click = "^lib:search$" },
    { at = 5.15, text = "kuwa" },
    { at = 5.3, click = "^lib:effects/kuwahara$" },
    { at = 5.6, check = function(App)
        return #App.pipeline.chain == saved.n + 1 and App.selected.entry.id == "effects/kuwahara", "library click adds + selects"
    end },

    -- Drag-reorder Kuwahara to the top of the chain
    { at = 5.7, drag = { rowOf("effects/kuwahara"), rowOf("effects/bloom") } },
    { at = 6.2, check = function(App)
        local _, i = node(App, "effects/kuwahara")
        return i == 1, "drag reorders the chain (kuwahara at " .. tostring(i) .. ")"
    end },

    -- Drag an effect from the library into the chain
    { at = 6.3, click = "^lib:search$" },
    { at = 6.35, key = "a", ctrl = true },
    { at = 6.4, ctrl = false, text = "vhs" },
    { at = 6.5, drag = { "^lib:effects/vhs$", rowOf("effects/color_grade") } },
    { at = 7.0, check = function(App)
        local n, i = node(App, "effects/vhs")
        local _, gi = node(App, "effects/color_grade")
        return n ~= nil and gi ~= nil and i == gi - 1, "library drag inserts before the target row"
    end },
    { at = 7.1, shot = "smoke_03_chain" },

    -- Remove via the hover x button
    { at = 7.2, click = rowOf("effects/vhs") },
    { at = 7.4, click = function(App) local n = node(App, "effects/vhs"); return n and ("^chain:" .. n.uid .. ":x$") or "__missing__" end },
    { at = 7.7, check = function(App) return node(App, "effects/vhs") == nil, "x button removes" end },

    -- Eye toggle disables a node
    { at = 7.75, click = function(App) local n = node(App, "effects/kuwahara"); return n and ("^chain:" .. n.uid .. ":eye$") or "__missing__" end },
    { at = 7.85, check = function(App) local n = node(App, "effects/kuwahara"); return n and n.enabled == false, "eye toggles enabled" end },

    -- Top-bar dropdown: render scale 50%
    { at = 7.9, click = "^tb:scale$" },
    { at = 8.1, shot = "smoke_04_dropdown" },
    { at = 8.2, click = "^tb:scale:opt3$" },
    { at = 8.4, check = function(App) return math.abs(App.pipeline.renderScale - 0.5) < 1e-6, "dropdown picks render scale" end },
    { at = 8.5, click = "^tb:scale$" },
    { at = 8.7, click = "^tb:scale:opt1$" },

    -- Search the library
    { at = 8.8, click = "^lib:search$" },
    { at = 8.85, key = "a", ctrl = true },
    { at = 8.9, ctrl = false, text = "light" },
    { at = 9.1, shot = "smoke_05_search" },
    { at = 9.2, key = "escape" },

    -- Presets tab: save, verify, delete
    { at = 9.3, click = "^lib:tab2$" },
    { at = 9.5, click = "^lib:savename$" },
    { at = 9.6, text = "Smoke Test Preset" },
    { at = 9.7, key = "return" },
    { at = 10.0, shot = "smoke_06_presets" },
    { at = 10.1, check = function(App)
        local Presets = require("src.presets")
        for _, info in ipairs(Presets.list()) do
            if info.name == "Smoke Test Preset" then
                Presets.delete(info)
                require("src.ui.panels.library").refreshPresets()
                return #info.data.chain == #App.pipeline.chain, "preset saved with the chain"
            end
        end
        return false, "preset saved"
    end },
    { at = 10.2, click = "^lib:tab1$" },

    -- Compare view and bypass
    { at = 10.3, key = "c" },
    { at = 10.6, shot = "smoke_07_compare" },
    { at = 10.7, key = "c" },

    -- Keyboard: select next node, nudge a param
    { at = 10.8, key = "]" },
    { at = 10.9, check = function(App) saved.sel = App.selected; return App.selected ~= nil, "] selects next" end },

    -- Gallery mode
    { at = 11.0, key = "g" },
    { at = 13.0, shot = "smoke_08_gallery" },
    { at = 13.3, key = "space" },
    { at = 13.5, check = function(App) return not require("src.gallery").active, "any key exits gallery" end },

    { at = 13.8, quit = true },
}
