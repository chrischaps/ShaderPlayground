--[[
    Vector icons drawn with primitives, so they stay crisp at any size and
    don't depend on font glyph coverage. Each icon is drawn centered at
    (cx, cy) inside a box of size s using the current color.
]]

local lg = love.graphics

local Icons = {}

function Icons.play(cx, cy, s)
    local r = s * 0.32
    lg.polygon("fill", cx - r * 0.75, cy - r, cx - r * 0.75, cy + r, cx + r, cy)
end

function Icons.pause(cx, cy, s)
    local h, w = s * 0.6, s * 0.16
    lg.rectangle("fill", cx - w * 1.6, cy - h / 2, w, h, 1)
    lg.rectangle("fill", cx + w * 0.6, cy - h / 2, w, h, 1)
end

function Icons.step(cx, cy, s)
    local r = s * 0.28
    lg.polygon("fill", cx - r, cy - r, cx - r, cy + r, cx + r * 0.6, cy)
    lg.rectangle("fill", cx + r * 0.6, cy - r, s * 0.1, r * 2)
end

function Icons.record(cx, cy, s)
    lg.circle("fill", cx, cy, s * 0.26, 24)
end

function Icons.stop(cx, cy, s)
    local r = s * 0.24
    lg.rectangle("fill", cx - r, cy - r, r * 2, r * 2, 2)
end

function Icons.camera(cx, cy, s)
    local w, h = s * 0.62, s * 0.44
    lg.setLineWidth(1.5)
    lg.rectangle("line", cx - w / 2, cy - h / 2 + 1, w, h, 2)
    lg.rectangle("fill", cx - w * 0.18, cy - h / 2 - 2, w * 0.36, 3)
    lg.circle("line", cx, cy + 1, h * 0.28, 16)
end

function Icons.eye(cx, cy, s, closed)
    local w, h = s * 0.36, s * 0.2
    lg.setLineWidth(1.5)
    if closed then
        lg.line(cx - w, cy, cx - w * 0.5, cy + h * 0.7, cx + w * 0.5, cy + h * 0.7, cx + w, cy)
        return
    end
    local pts = {}
    for i = 0, 16 do
        local t = i / 16 * math.pi
        pts[#pts + 1] = cx + math.cos(t) * w
        pts[#pts + 1] = cy - math.sin(t) * h
    end
    for i = 16, 0, -1 do
        local t = i / 16 * math.pi
        pts[#pts + 1] = cx + math.cos(t) * w
        pts[#pts + 1] = cy + math.sin(t) * h
    end
    lg.line(pts)
    lg.circle("fill", cx, cy, h * 0.55, 12)
end

function Icons.close(cx, cy, s)
    local r = s * 0.2
    lg.setLineWidth(1.6)
    lg.line(cx - r, cy - r, cx + r, cy + r)
    lg.line(cx - r, cy + r, cx + r, cy - r)
end

function Icons.plus(cx, cy, s)
    local r = s * 0.24
    lg.setLineWidth(1.6)
    lg.line(cx - r, cy, cx + r, cy)
    lg.line(cx, cy - r, cx, cy + r)
end

function Icons.chevron(cx, cy, s, open)
    local r = s * 0.16
    lg.setLineWidth(1.5)
    if open then
        lg.line(cx - r, cy - r * 0.5, cx, cy + r * 0.5, cx + r, cy - r * 0.5)
    else
        lg.line(cx - r * 0.5, cy - r, cx + r * 0.5, cy, cx - r * 0.5, cy + r)
    end
end

function Icons.grip(cx, cy, s)
    for i = -1, 1 do
        for j = 0, 1 do
            lg.circle("fill", cx - 2.5 + j * 5, cy + i * 5, 1.3, 8)
        end
    end
end

function Icons.compare(cx, cy, s)
    local w, h = s * 0.56, s * 0.44
    lg.setLineWidth(1.5)
    lg.rectangle("line", cx - w / 2, cy - h / 2, w, h, 2)
    lg.rectangle("fill", cx - w / 2, cy - h / 2, w / 2, h, 2)
    lg.line(cx, cy - h / 2 - 3, cx, cy + h / 2 + 3)
end

function Icons.bypass(cx, cy, s)
    local r = s * 0.24
    lg.setLineWidth(1.6)
    lg.circle("line", cx, cy, r, 20)
    lg.line(cx - r * 0.7, cy + r * 0.7, cx + r * 0.7, cy - r * 0.7)
end

function Icons.gallery(cx, cy, s)
    local w, h = s * 0.6, s * 0.44
    lg.setLineWidth(1.5)
    lg.rectangle("line", cx - w / 2, cy - h / 2, w, h, 2)
    lg.polygon("fill", cx - w / 2 + 3, cy + h / 2 - 3, cx - w * 0.1, cy - h * 0.05, cx + w * 0.12, cy + h / 2 - 3)
    lg.polygon("fill", cx, cy + h / 2 - 3, cx + w * 0.22, cy + h * 0.02, cx + w / 2 - 3, cy + h / 2 - 3)
    lg.circle("fill", cx + w * 0.22, cy - h * 0.2, 2, 8)
end

function Icons.reset(cx, cy, s)
    local r = s * 0.24
    lg.setLineWidth(1.5)
    lg.arc("line", "open", cx, cy, r, -math.pi * 0.35, math.pi * 1.25, 20)
    local ax, ay = cx + math.cos(-math.pi * 0.35) * r, cy + math.sin(-math.pi * 0.35) * r
    lg.polygon("fill", ax - 4, ay - 3, ax + 3, ay - 4, ax + 1, ay + 3)
end

function Icons.dice(cx, cy, s)
    local r = s * 0.28
    lg.setLineWidth(1.5)
    lg.rectangle("line", cx - r, cy - r, r * 2, r * 2, 3)
    lg.circle("fill", cx - r * 0.45, cy - r * 0.45, 1.6, 8)
    lg.circle("fill", cx, cy, 1.6, 8)
    lg.circle("fill", cx + r * 0.45, cy + r * 0.45, 1.6, 8)
end

function Icons.file(cx, cy, s)
    local w, h = s * 0.4, s * 0.52
    lg.setLineWidth(1.4)
    lg.polygon("line", cx - w / 2, cy - h / 2, cx + w * 0.15, cy - h / 2, cx + w / 2, cy - h * 0.2,
        cx + w / 2, cy + h / 2, cx - w / 2, cy + h / 2)
    lg.line(cx - w * 0.25, cy, cx + w * 0.25, cy)
    lg.line(cx - w * 0.25, cy + h * 0.2, cx + w * 0.25, cy + h * 0.2)
end

function Icons.restart(cx, cy, s)
    Icons.reset(cx, cy, s)
end

function Icons.solo(cx, cy, s)
    local r = s * 0.24
    lg.setLineWidth(1.5)
    lg.circle("line", cx, cy, r, 20)
    lg.circle("fill", cx, cy, r * 0.45, 12)
end

function Icons.save(cx, cy, s)
    local r = s * 0.27
    lg.setLineWidth(1.5)
    lg.rectangle("line", cx - r, cy - r, r * 2, r * 2, 2)
    lg.rectangle("fill", cx - r * 0.5, cy - r, r, r * 0.7)
    lg.rectangle("line", cx - r * 0.55, cy + r * 0.15, r * 1.1, r * 0.85)
end

function Icons.folder(cx, cy, s)
    local w, h = s * 0.6, s * 0.42
    lg.setLineWidth(1.5)
    lg.polygon("line", cx - w / 2, cy - h / 2, cx - w * 0.1, cy - h / 2, cx, cy - h * 0.3,
        cx + w / 2, cy - h * 0.3, cx + w / 2, cy + h / 2, cx - w / 2, cy + h / 2)
end

function Icons.search(cx, cy, s)
    local r = s * 0.18
    lg.setLineWidth(1.5)
    lg.circle("line", cx - r * 0.3, cy - r * 0.3, r, 16)
    lg.line(cx + r * 0.45, cy + r * 0.45, cx + r * 1.4, cy + r * 1.4)
end

function Icons.dot(cx, cy, s)
    lg.circle("fill", cx, cy, s * 0.14, 12)
end

return Icons
