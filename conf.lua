-- Love2D 游戏配置文件
-- 弑君者游戏引擎配置文件 - 定义游戏窗口、模块等基础设置
--
-- 配置说明：
-- 该文件在Love2D引擎启动时自动加载，用于配置游戏运行环境
--
-- 主要配置项：
-- t.identity              - 游戏标识符（保存目录名）
-- t.version               - Love2D引擎版本要求
-- t.console               - 是否启用控制台窗口（调试用）
--
-- 窗口设置：
-- t.window.title          - 游戏窗口标题"弑君者 (Regicide)"
-- t.window.width          - 窗口宽度1024像素
-- t.window.height         - 窗口高度768像素
-- t.window.resizable      - 是否允许调整窗口大小（false）
-- t.window.minwidth       - 最小宽度800像素
-- t.window.minheight      - 最小高度600像素
--
-- 模块启用设置：
-- 启用模块：audio, event, graphics, image, keyboard, math, mouse, sound, system, timer, window
-- 禁用模块：joystick, physics, touch, video, thread
--
-- 注意：窗口大小与main.lua中绘制逻辑保持一致性

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