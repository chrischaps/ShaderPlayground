--[[
    Shader Manager
    Handles loading, switching, and parameter management for shaders
]]

local ShaderManager = {}

-- State
local shaders = {}
local currentIndex = 1
local selectedParam = 1
local time = 0

-- Register a shader with its parameters
function ShaderManager.register(name, source, params)
    local shader = {
        name = name,
        source = source,
        params = params or {},
        compiled = nil
    }

    -- Store default values for reset
    for _, param in ipairs(shader.params) do
        param.default = param.value
    end

    -- Try to compile
    local success, result = pcall(love.graphics.newShader, source)
    if success then
        shader.compiled = result
    else
        print("[ShaderManager] Failed to compile '" .. name .. "': " .. tostring(result))
        shader.error = tostring(result)
    end

    table.insert(shaders, shader)
end

-- Initialize with example shaders
function ShaderManager.init()
    -- Wave Distortion
    ShaderManager.register("Wave Distortion", [[
        extern float time;
        extern float amplitude;
        extern float frequency;
        extern float speed;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 offset;
            offset.x = sin(uv.y * frequency + time * speed) * amplitude;
            offset.y = cos(uv.x * frequency * 0.8 + time * speed * 0.7) * amplitude * 0.5;
            return Texel(tex, clamp(uv + offset, 0.0, 1.0)) * color;
        }
    ]], {
        { name = "time", value = 0, min = 0, max = 1000, auto = true },
        { name = "amplitude", value = 0.02, min = 0, max = 0.1, step = 0.005 },
        { name = "frequency", value = 10.0, min = 1, max = 50, step = 1 },
        { name = "speed", value = 2.0, min = 0, max = 10, step = 0.5 }
    })

    -- Chromatic Aberration
    ShaderManager.register("Chromatic Aberration", [[
        extern float offset;
        extern float angle;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 dir = vec2(cos(angle), sin(angle)) * offset;
            float r = Texel(tex, uv + dir).r;
            float g = Texel(tex, uv).g;
            float b = Texel(tex, uv - dir).b;
            float a = Texel(tex, uv).a;
            return vec4(r, g, b, a) * color;
        }
    ]], {
        { name = "offset", value = 0.005, min = 0, max = 0.05, step = 0.001 },
        { name = "angle", value = 0.0, min = 0, max = 6.28, step = 0.1 }
    })

    -- Pixelate
    ShaderManager.register("Pixelate", [[
        extern float pixelSize;
        extern vec2 resolution;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 size = resolution / pixelSize;
            vec2 coord = floor(uv * size) / size;
            return Texel(tex, coord) * color;
        }
    ]], {
        { name = "pixelSize", value = 8.0, min = 1, max = 64, step = 1 },
        { name = "resolution", value = {1280, 720}, hidden = true }
    })

    -- Vignette
    ShaderManager.register("Vignette", [[
        extern float radius;
        extern float softness;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 texcolor = Texel(tex, uv);
            vec2 center = uv - vec2(0.5);
            float dist = length(center);
            float vig = 1.0 - smoothstep(radius - softness, radius + softness, dist) * intensity;
            return vec4(texcolor.rgb * vig, texcolor.a) * color;
        }
    ]], {
        { name = "radius", value = 0.5, min = 0.1, max = 1.0, step = 0.05 },
        { name = "softness", value = 0.3, min = 0, max = 0.5, step = 0.05 },
        { name = "intensity", value = 0.7, min = 0, max = 1.0, step = 0.1 }
    })

    -- Bloom/Glow (simplified)
    ShaderManager.register("Glow", [[
        extern float threshold;
        extern float intensity;
        extern float blur_size;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 texcolor = Texel(tex, uv);
            vec4 bloom = vec4(0.0);

            // Simple box blur for glow
            for(float x = -2.0; x <= 2.0; x += 1.0) {
                for(float y = -2.0; y <= 2.0; y += 1.0) {
                    vec2 offset = vec2(x, y) * blur_size;
                    vec4 sample = Texel(tex, uv + offset);
                    float brightness = dot(sample.rgb, vec3(0.299, 0.587, 0.114));
                    if(brightness > threshold) {
                        bloom += sample;
                    }
                }
            }
            bloom /= 25.0;

            return (texcolor + bloom * intensity) * color;
        }
    ]], {
        { name = "threshold", value = 0.5, min = 0, max = 1.0, step = 0.05 },
        { name = "intensity", value = 0.5, min = 0, max = 2.0, step = 0.1 },
        { name = "blur_size", value = 0.003, min = 0, max = 0.01, step = 0.001 }
    })

    -- Grayscale with Tint
    ShaderManager.register("Grayscale Tint", [[
        extern float amount;
        extern vec3 tint;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 texcolor = Texel(tex, uv);
            float gray = dot(texcolor.rgb, vec3(0.299, 0.587, 0.114));
            vec3 tinted = gray * tint;
            vec3 result = mix(texcolor.rgb, tinted, amount);
            return vec4(result, texcolor.a) * color;
        }
    ]], {
        { name = "amount", value = 0.5, min = 0, max = 1.0, step = 0.1 },
        { name = "tint", value = {1.0, 0.9, 0.7}, type = "color" }
    })

    -- CRT Scanlines
    ShaderManager.register("CRT Scanlines", [[
        extern float time;
        extern float scanlineIntensity;
        extern float scanlineCount;
        extern float curvature;
        extern float flickerSpeed;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            // Apply curvature
            vec2 curved = uv - 0.5;
            float dist = dot(curved, curved) * curvature;
            curved = curved * (1.0 + dist) + 0.5;

            // Out of bounds check
            if(curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0) {
                return vec4(0.0, 0.0, 0.0, 1.0);
            }

            vec4 texcolor = Texel(tex, curved);

            // Scanlines
            float scanline = sin(curved.y * scanlineCount * 3.14159) * 0.5 + 0.5;
            scanline = pow(scanline, 2.0) * scanlineIntensity + (1.0 - scanlineIntensity);

            // Flicker
            float flicker = 1.0 - sin(time * flickerSpeed) * 0.02;

            return vec4(texcolor.rgb * scanline * flicker, texcolor.a) * color;
        }
    ]], {
        { name = "time", value = 0, min = 0, max = 1000, auto = true },
        { name = "scanlineIntensity", value = 0.3, min = 0, max = 1.0, step = 0.1 },
        { name = "scanlineCount", value = 200, min = 50, max = 500, step = 10 },
        { name = "curvature", value = 0.1, min = 0, max = 0.5, step = 0.05 },
        { name = "flickerSpeed", value = 10.0, min = 0, max = 50, step = 5 }
    })

    -- Film Grain
    ShaderManager.register("Film Grain", [[
        extern float time;
        extern float intensity;
        extern float speed;

        float random(vec2 co) {
            return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
        }

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 texcolor = Texel(tex, uv);
            float noise = random(uv + vec2(time * speed, 0.0));
            noise = (noise - 0.5) * intensity;
            return vec4(texcolor.rgb + noise, texcolor.a) * color;
        }
    ]], {
        { name = "time", value = 0, min = 0, max = 1000, auto = true },
        { name = "intensity", value = 0.15, min = 0, max = 0.5, step = 0.05 },
        { name = "speed", value = 20.0, min = 1, max = 100, step = 5 }
    })

    -- Color Invert
    ShaderManager.register("Invert Colors", [[
        extern float amount;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 texcolor = Texel(tex, uv);
            vec3 inverted = vec3(1.0) - texcolor.rgb;
            vec3 result = mix(texcolor.rgb, inverted, amount);
            return vec4(result, texcolor.a) * color;
        }
    ]], {
        { name = "amount", value = 1.0, min = 0, max = 1.0, step = 0.1 }
    })

    -- Posterize
    ShaderManager.register("Posterize", [[
        extern float levels;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec4 texcolor = Texel(tex, uv);
            vec3 posterized = floor(texcolor.rgb * levels) / levels;
            return vec4(posterized, texcolor.a) * color;
        }
    ]], {
        { name = "levels", value = 8.0, min = 2, max = 32, step = 1 }
    })

    -- Edge Detection (Sobel)
    ShaderManager.register("Edge Detection", [[
        extern float threshold;
        extern vec2 resolution;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 texel = 1.0 / resolution;

            float tl = dot(Texel(tex, uv + vec2(-texel.x,  texel.y)).rgb, vec3(0.299, 0.587, 0.114));
            float t  = dot(Texel(tex, uv + vec2( 0.0,      texel.y)).rgb, vec3(0.299, 0.587, 0.114));
            float tr = dot(Texel(tex, uv + vec2( texel.x,  texel.y)).rgb, vec3(0.299, 0.587, 0.114));
            float l  = dot(Texel(tex, uv + vec2(-texel.x,  0.0)).rgb,     vec3(0.299, 0.587, 0.114));
            float r  = dot(Texel(tex, uv + vec2( texel.x,  0.0)).rgb,     vec3(0.299, 0.587, 0.114));
            float bl = dot(Texel(tex, uv + vec2(-texel.x, -texel.y)).rgb, vec3(0.299, 0.587, 0.114));
            float b  = dot(Texel(tex, uv + vec2( 0.0,     -texel.y)).rgb, vec3(0.299, 0.587, 0.114));
            float br = dot(Texel(tex, uv + vec2( texel.x, -texel.y)).rgb, vec3(0.299, 0.587, 0.114));

            float gx = tl + 2.0*l + bl - tr - 2.0*r - br;
            float gy = tl + 2.0*t + tr - bl - 2.0*b - br;
            float edge = sqrt(gx*gx + gy*gy);

            edge = step(threshold, edge);

            return vec4(vec3(edge), 1.0) * color;
        }
    ]], {
        { name = "threshold", value = 0.1, min = 0, max = 1.0, step = 0.05 },
        { name = "resolution", value = {1280, 720}, hidden = true }
    })

    -- Kaleidoscope
    ShaderManager.register("Kaleidoscope", [[
        extern float segments;
        extern float rotation;

        #define PI 3.14159265359

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 center = uv - 0.5;
            float angle = atan(center.y, center.x) + rotation;
            float radius = length(center);

            // Create segments
            angle = mod(angle, 2.0 * PI / segments);
            if(mod(floor(atan(center.y, center.x) * segments / PI), 2.0) == 1.0) {
                angle = 2.0 * PI / segments - angle;
            }

            vec2 newUV = vec2(cos(angle), sin(angle)) * radius + 0.5;
            return Texel(tex, clamp(newUV, 0.0, 1.0)) * color;
        }
    ]], {
        { name = "segments", value = 6.0, min = 2, max = 16, step = 1 },
        { name = "rotation", value = 0.0, min = 0, max = 6.28, step = 0.1 }
    })

    -- Radial Blur
    ShaderManager.register("Radial Blur", [[
        extern float strength;
        extern float samples;
        extern vec2 center;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            vec2 dir = uv - center;
            vec4 result = vec4(0.0);

            for(float i = 0.0; i < 16.0; i++) {
                if(i >= samples) break;
                float scale = 1.0 - strength * (i / samples);
                result += Texel(tex, center + dir * scale);
            }

            return (result / samples) * color;
        }
    ]], {
        { name = "strength", value = 0.1, min = 0, max = 0.5, step = 0.05 },
        { name = "samples", value = 8.0, min = 2, max = 16, step = 1 },
        { name = "center", value = {0.5, 0.5}, type = "vec2" }
    })

    print("[ShaderManager] Loaded " .. #shaders .. " shaders")
end

function ShaderManager.update(dt)
    time = time + dt

    -- Update auto parameters (like time)
    local shader = shaders[currentIndex]
    if shader and shader.compiled then
        for _, param in ipairs(shader.params) do
            if param.auto then
                param.value = time
                if shader.compiled:hasUniform(param.name) then
                    shader.compiled:send(param.name, param.value)
                end
            elseif not param.hidden then
                ShaderManager.sendParam(shader.compiled, param)
            end
        end
    end
end

function ShaderManager.sendParam(shader, param)
    if not shader:hasUniform(param.name) then return end

    if type(param.value) == "table" then
        shader:send(param.name, param.value)
    else
        shader:send(param.name, param.value)
    end
end

function ShaderManager.getCurrentShader()
    local shader = shaders[currentIndex]
    return shader and shader.compiled
end

function ShaderManager.getCurrent()
    return shaders[currentIndex]
end

function ShaderManager.getShaders()
    return shaders
end

function ShaderManager.getCurrentIndex()
    return currentIndex
end

function ShaderManager.getSelectedParam()
    return selectedParam
end

function ShaderManager.nextShader()
    currentIndex = currentIndex + 1
    if currentIndex > #shaders then
        currentIndex = 1
    end
    selectedParam = 1
end

function ShaderManager.prevShader()
    currentIndex = currentIndex - 1
    if currentIndex < 1 then
        currentIndex = #shaders
    end
    selectedParam = 1
end

function ShaderManager.nextParam()
    local shader = shaders[currentIndex]
    if not shader then return end

    local visibleParams = {}
    for i, param in ipairs(shader.params) do
        if not param.auto and not param.hidden then
            table.insert(visibleParams, i)
        end
    end

    if #visibleParams == 0 then return end

    selectedParam = selectedParam + 1
    if selectedParam > #visibleParams then
        selectedParam = 1
    end
end

function ShaderManager.prevParam()
    local shader = shaders[currentIndex]
    if not shader then return end

    local visibleParams = {}
    for i, param in ipairs(shader.params) do
        if not param.auto and not param.hidden then
            table.insert(visibleParams, i)
        end
    end

    if #visibleParams == 0 then return end

    selectedParam = selectedParam - 1
    if selectedParam < 1 then
        selectedParam = #visibleParams
    end
end

function ShaderManager.adjustParameter(direction, fine)
    local shader = shaders[currentIndex]
    if not shader then return end

    local visibleParams = {}
    for i, param in ipairs(shader.params) do
        if not param.auto and not param.hidden then
            table.insert(visibleParams, param)
        end
    end

    if #visibleParams == 0 then return end

    local param = visibleParams[selectedParam]
    if not param then return end

    if type(param.value) == "number" then
        local step = param.step or 0.1
        if fine then step = step * 0.1 end
        param.value = param.value + direction * step
        if param.min then param.value = math.max(param.min, param.value) end
        if param.max then param.value = math.min(param.max, param.value) end
    elseif param.type == "color" then
        -- For colors, adjust the first component
        local step = fine and 0.01 or 0.05
        param.value[1] = math.max(0, math.min(1, param.value[1] + direction * step))
    end
end

function ShaderManager.resetCurrentParameters()
    local shader = shaders[currentIndex]
    if not shader then return end

    for _, param in ipairs(shader.params) do
        if param.default then
            if type(param.default) == "table" then
                param.value = {unpack(param.default)}
            else
                param.value = param.default
            end
        end
    end
end

function ShaderManager.handleKey(key, shift)
    if key == "left" or key == "a" then
        ShaderManager.prevShader()
    elseif key == "right" or key == "d" then
        ShaderManager.nextShader()
    elseif key == "up" or key == "w" then
        ShaderManager.prevParam()
    elseif key == "down" or key == "s" then
        ShaderManager.nextParam()
    elseif key == "=" or key == "e" then
        ShaderManager.adjustParameter(1, shift)
    elseif key == "-" or key == "q" then
        ShaderManager.adjustParameter(-1, shift)
    end
end

return ShaderManager
