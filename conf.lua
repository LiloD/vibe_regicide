-- Love2D 游戏配置文件

function love.conf(t)
    t.identity = "regicide_game"
    t.version = "11.4"
    t.console = true
    
    -- 窗口设置
    t.window.title = "弑君者 (Regicide)"
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = false
    t.window.minwidth = 800
    t.window.minheight = 600
    
    -- 模块设置
    t.modules.audio = true
    t.modules.event = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
    t.modules.thread = false
    
    print("游戏配置加载完成")
end