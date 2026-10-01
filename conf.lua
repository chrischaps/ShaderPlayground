function love.conf(t)
    t.identity = "ShaderPlayground"
    t.version = "11.5"

    t.window.title = "Shader Playground"
    t.window.width = 1600
    t.window.height = 900
    t.window.minwidth = 960
    t.window.minheight = 600
    t.window.resizable = true
    t.window.vsync = 1
    t.window.msaa = 0

    t.console = true  -- Enable console on Windows for debugging

    t.modules.audio = true
    t.modules.joystick = false
    t.modules.physics = false
end
