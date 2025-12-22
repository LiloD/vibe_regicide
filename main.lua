-- Regicide Game Main File
-- 弑君者游戏主文件 - 基于Love2D游戏引擎
--
-- 游戏概述：
-- 弑君者是一款卡牌策略游戏，玩家需要使用扑克牌击败一系列BOSS（J、Q、K）。
-- 每种花色都有不同的特殊效果，与BOSS同花色的牌不会产生效果。
--
-- 模块职责：
-- 1. Love2D引擎入口点，处理游戏生命周期
-- 2. 游戏初始化：设置窗口、创建游戏状态、初始化牌堆
-- 3. 用户输入处理：转发键盘事件到游戏状态模块
-- 4. 游戏渲染：绘制游戏界面、卡牌、BOSS信息、日志等
--
-- Love2D核心回调函数：
-- love.load()      - 游戏初始化，设置窗口和初始状态
-- love.keypressed(key) - 键盘输入处理
-- love.draw()      - 游戏画面渲染
--
-- 界面绘制内容：
-- - 玩家手牌（带选择高亮）
-- - BOSS信息（当前BOSS、血量、伤害）
-- - 回合阶段和提示信息
-- - 已打出的卡牌
-- - 操作说明
-- - 游戏日志
--
-- 视觉特色：
-- - 黄色高亮：出牌选择
-- - 橙色高亮：伤害抵挡选择
-- - 数字快捷键：1-8选择卡牌
-- - Enter键确认选择
-- - R键重新开始

-- Import modules
local game_state = require("game_state")
local rules = require("rules")

-- Global game state
local gameState

-- Initialize game
function love.load()
    -- Set window size
    love.window.setMode(800, 700)
    
    -- 定义字体
    fonts = {
        bossRank = love.graphics.newFont(20),
        bossSuit = love.graphics.newFont(32),
        playerRank = love.graphics.newFont(16),
        playerSuit = love.graphics.newFont(24),
        default = love.graphics.newFont(12)
    }
    
    -- 设置默认字体
    love.graphics.setFont(fonts.default)
    
    local randomSeed = os.time()
    --  local randomSeed = 1766397099
    print("Random Seed: " .. randomSeed)
    math.randomseed(randomSeed)

    -- Initialize game state
    gameState = game_state.init()

    -- Start game directly change to player phase
    game_state.change_phase(gameState, rules.TURN_PHASE.PLAYER)
end

-- Handle keyboard input
function love.keypressed(key)
     game_state.handleInput(gameState, key)
end

-- Draw game
-- 绘制卡牌函数
function drawCard(x, y, card, isSelected, highlightColor, isBoss)
    -- 现实扑克牌比例约为 2.5:3.5 (约0.714)
    local cardHeight = isBoss and 180 or 120
    local cardWidth = math.floor(cardHeight * 0.714)  -- 按比例计算宽度
    local cornerRadius = 8
    
    -- 卡牌背景
    if isSelected and highlightColor then
        love.graphics.setColor(unpack(highlightColor))
    else
        love.graphics.setColor(0.95, 0.95, 0.95) -- 浅灰色背景
    end
    love.graphics.rectangle("fill", x, y, cardWidth, cardHeight, cornerRadius, cornerRadius)
    
    -- 卡牌边框
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("line", x, y, cardWidth, cardHeight, cornerRadius, cornerRadius)
    
    -- 花色符号和颜色
    local suitColor = {0.2, 0.2, 0.2} -- 默认黑色
    local suitSymbol = "?"
    
    if card.suit == "Hearts" then
        suitColor = {0.9, 0.1, 0.1} -- 亮红色
        suitSymbol = "H"
    elseif card.suit == "Diamonds" then
        suitColor = {0.1, 0.7, 0.9} -- 天蓝色
        suitSymbol = "D"
    elseif card.suit == "Clubs" then
        suitColor = {0.1, 0.6, 0.1} -- 深绿色
        suitSymbol = "C"
    elseif card.suit == "Spades" then
        suitColor = {0.3, 0.1, 0.6} -- 深紫色
        suitSymbol = "S"
    end
    
    -- 卡牌内容
    love.graphics.setColor(unpack(suitColor))
    
    -- 左上角显示数字
    if isBoss then
        love.graphics.setFont(fonts.bossRank)
    else
        love.graphics.setFont(fonts.playerRank)
    end
    love.graphics.print(card.rank, x + 10, y + 10)
    
    -- 正中央显示花色符号
    if isBoss then
        love.graphics.setFont(fonts.bossSuit)
    else
        love.graphics.setFont(fonts.playerSuit)
    end
    love.graphics.print(suitSymbol, x + cardWidth/2 - 10, y + cardHeight/2 - 15)
    
    -- 重置颜色和字体
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.default)
end

function love.draw()
    -- Clear screen
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    love.graphics.setColor(1, 1, 1)
    
    -- 布局常量定义
    local windowWidth = 800
    local windowHeight = 700
    local battleAreaWidth = windowWidth * 2 / 3  -- 战斗区域宽度 (约533px)
    local battleAreaHeight = windowHeight
    local logAreaX = battleAreaWidth  -- 日志区域起始X坐标
    
    -- 战斗区域边框参数
    local battleAreaMargin = 20  -- 边距
    local battleAreaBorderX = battleAreaMargin
    local battleAreaBorderY = battleAreaMargin
    local battleAreaBorderWidth = battleAreaWidth - battleAreaMargin * 2
    local battleAreaBorderHeight = battleAreaHeight - battleAreaMargin * 2
    
    -- 战斗区域内部分区
    local bossAreaHeight = battleAreaHeight / 3  -- BOSS区域高度 (约300px)
    local playerAreaY = bossAreaHeight  -- 玩家区域起始Y坐标
    
    -- ==================== 战斗区域边框 ====================
    love.graphics.rectangle("line", battleAreaBorderX, battleAreaBorderY, battleAreaBorderWidth, battleAreaBorderHeight)
    
    -- ==================== 战斗区域顶部 - 回合信息 ====================
    local topInfoY = battleAreaBorderY + 15
    
    -- Draw turn info at top of battle area (centered)
    local turnInfoText = gameState.turn.message
    local textWidth = love.graphics.getFont():getWidth(turnInfoText)
    local topInfoX = battleAreaBorderX + (battleAreaBorderWidth - textWidth) / 2
    love.graphics.print(turnInfoText, topInfoX, topInfoY)
    
    -- ==================== BOSS区域 (战斗区域上半部分) ====================
    local bossStartX = battleAreaBorderX + 30
    local bossStartY = battleAreaBorderY + 60  -- 下移，为顶部回合信息留出空间
    
    -- Draw BOSS info
    if gameState.boss.current then
        -- 绘制BOSS卡牌
        drawCard(bossStartX, bossStartY, gameState.boss.current, false, nil, true)
        
        -- BOSS状态信息
        love.graphics.print("BOSS", bossStartX + 130, bossStartY + 10)
        love.graphics.print("Health: " .. gameState.boss.health, bossStartX + 130, bossStartY + 35)
        love.graphics.print("Damage: " .. gameState.turn.bossDamage, bossStartX + 130, bossStartY + 60)
    else
        love.graphics.print("No BOSS", bossStartX, bossStartY)
    end
    
    -- ==================== 玩家区域 (战斗区域下半部分) ====================
    local playerStartX = battleAreaBorderX + 30
    local playerStartY = playerAreaY + battleAreaBorderY + 80  -- 上移一些，为卡牌留出更多空间
    
    -- Draw player info
    love.graphics.print("Hand: " .. #gameState.player.hand .. "/8", playerStartX, playerStartY)
    love.graphics.print("Deck: " .. #gameState.player.deck, playerStartX + 120, playerStartY)
    
    -- Draw player hand
    love.graphics.print("Cards:", playerStartX, playerStartY + 30)
    
    -- 计算手牌布局
    local cardsPerRow = 4
    local cardHeight = 120
    local cardWidth = math.floor(cardHeight * 0.714)  -- 按比例计算宽度
    local cardSpacing = 20
    
    for i, card in ipairs(gameState.player.hand) do
        -- Highlight selected cards
        local isSelected = false
        local highlightColor = {1, 1, 0} -- Yellow for playing selecion
        
        if gameState.turn.phase == rules.TURN_PHASE.PLAYER then
            for j, selectedCard in ipairs(gameState.turn.selectedCards) do
                if selectedCard == card then
                    isSelected = true
                    break
                end
            end
        elseif gameState.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
            for j, selectedCard in ipairs(gameState.turn.discardCards) do
                if selectedCard == card then
                    isSelected = true
                    highlightColor = {1, 0.5, 0} -- Orange for damage selection
                    break
                end
            end
        end
        
        -- 计算卡牌位置
        local row = math.floor((i - 1) / cardsPerRow)
        local col = (i - 1) % cardsPerRow
        local cardX = playerStartX + col * (cardWidth + cardSpacing)
        local cardY = playerStartY + 60 + row * (cardHeight + 30)
        
        -- 绘制卡牌
        drawCard(cardX, cardY, card, isSelected, highlightColor, false)
        
        -- 在卡牌上方显示编号
        love.graphics.print(i, cardX + cardWidth/2 - 5, cardY - 15)
    end
    
    -- ==================== 日志区域 (右侧1/3) ====================
    local logStartX = logAreaX + 20
    local logStartY = 30
    
    -- Draw operation log
    love.graphics.print("Game Log:", logStartX, logStartY)
    for i, logEntry in ipairs(gameState.log) do
        -- 限制日志显示行数，避免超出屏幕
        if i <= 25 then  -- 大约显示25行日志
            love.graphics.print(logEntry, logStartX, logStartY + 30 + i * 20)
        end
    end
end