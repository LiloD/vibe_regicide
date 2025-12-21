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
local deck_manager = require("deck_manager")
local rules = require("rules")

-- Global game state
local gameState

-- Initialize game
function love.load()
    -- Set window size
    love.window.setMode(800, 600)
    
    -- Initialize game state
    gameState = game_state.initializeGameState()
    
    -- Initialize decks
    deck_manager.initializePlayerDeck(gameState)
    deck_manager.initializeBossDeck(gameState)

    -- Set initial phase
    game_state.change_phase(gameState, rules.TURN_PHASE.PLAYER)
    
    game_state.addLog(gameState, "Game initialization complete")
end

-- Handle keyboard input
function love.keypressed(key)
     game_state.handleInput(gameState, key)
end

-- Draw game
function love.draw()
    -- Clear screen
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    love.graphics.setColor(1, 1, 1)
    
    -- Draw player info
    love.graphics.print("Hand Size: " .. #gameState.player.hand .. "/8", 50, 20)
    love.graphics.print("Deck Size: " .. #gameState.player.deck, 50, 40)
    
    -- Draw player hand
    love.graphics.print("Player Hand:", 50, 60)
    for i, card in ipairs(gameState.player.hand) do
        local cardText = i .. ". " .. deck_manager.getCardAbbreviation(card)
        
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
        
        if isSelected then
            love.graphics.setColor(unpack(highlightColor))
            love.graphics.print(">> " .. cardText, 70, 70 + i * 20)
            love.graphics.setColor(1, 1, 1) -- Reset to white
        else
            love.graphics.print(cardText, 70, 70 + i * 20)
        end
    end
    
    -- Draw BOSS info
    if gameState.boss.current then
        love.graphics.print("BOSS: " .. gameState.boss.current.rank .. " (" .. gameState.boss.current.suit .. ")", 300, 20)
        love.graphics.print("BOSS Health: " .. gameState.boss.health, 300, 40)
        love.graphics.print("BOSS Damage: " .. gameState.turn.bossDamage, 300, 60)

    else
        love.graphics.print("No BOSS", 300, 20)
    end
    
    -- Draw turn info
    love.graphics.print("Turn Phase: " .. gameState.turn.phase, 50, 300)
    love.graphics.print("Message: " .. gameState.turn.message, 50, 320)
    
    -- Draw played cards
    if #gameState.turn.playCards > 0 then
        love.graphics.print("Played Cards:", 50, 350)
        for i, card in ipairs(gameState.turn.playCards) do
            love.graphics.print(deck_manager.getCardAbbreviation(card), 70, 370 + i * 20)
        end
    end
    
    -- Draw control instructions
    love.graphics.print("Controls:", 500, 20)
    love.graphics.print("R - Restart game", 500, 40)
    love.graphics.print("D - Draw card", 500, 60)
    love.graphics.print("1-8 - Select/deselect card", 500, 80)
    love.graphics.print("ENTER - Confirm selection", 500, 100)
    love.graphics.print("SPACE - Next phase", 500, 120)
    
    -- Draw operation log
    love.graphics.print("Log:", 50, 440)
    for i, logEntry in ipairs(gameState.log) do
        love.graphics.print(logEntry, 70, 460 + i * 20)
    end
end