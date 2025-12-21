-- Game State Management Module
-- 游戏状态管理模块，负责游戏流程控制、回合管理和用户交互处理
--
-- 数据结构说明：
-- State 结构: {
--   player: {hand = {}, deck = {}, discard = {}},     -- 玩家相关数据
--   boss: {current = nil, health = 0, deck = {}},    -- BOSS相关数据  
--   turn: {
--     phase = 回合阶段常量,                           -- 当前回合阶段
--     message = 显示消息,                             -- 界面提示信息
--     playerDamage = 数值,                            -- 玩家对BOSS的伤害
--     bossDamage = 数值,                              -- BOSS对玩家的伤害
--     selectedCards = {},                             -- 玩家选中的出牌
--     playCards = {},                                 -- 确认打出的牌
--     discardCards = {},                              -- 选中的弃牌
--     effects = {}                                    -- 花色效果
--   },
--   log: []                                           -- 游戏日志
-- }
--
-- 模块功能说明：
--
-- 游戏初始化：
-- initializeGameState()                            - 创建并返回初始游戏状态
--
-- 回合流程控制：
-- change_phase(state, phase)                       - 切换回合阶段，自动处理阶段间逻辑
--
-- 卡牌选择管理（玩家出牌阶段）：
-- handlePlayCardSelection(state, cardIndex)        - 处理玩家出牌选择/取消选择
-- confirmCardSelection(state)                      - 确认出牌选择，进入效果阶段
-- canPlayCardsTogether(cards)                      - 检查多张同点数牌是否可一起出（总和≤10）
-- canPlayAWithCard(cards)                          - 检查A是否能与另一张牌一起出
--
-- 伤害选择管理（BOSS伤害阶段）：
-- handleDiscardCardSelection(state, cardIndex)     - 处理玩家弃牌选择/取消选择（抵挡伤害）
-- confirmDiscardSelection(state)                    - 确认弃牌选择，检查是否能抵挡BOSS伤害
--
-- 用户输入处理：
-- handleInput(state, key)                          - 处理键盘输入，支持数字选择、确认、重启等
--
-- 辅助功能：
-- addLog(state, message)                           - 添加游戏日志条目
local game_state = {}
local rules = require("rules")

-- Initialize game state
function game_state.initializeGameState()
    local state = {
        player = {
            hand = {},
            deck = {},
            discard = {},
        },
        boss = {
            current = nil,
            health = 0,
            deck = {}
        },
        turn = {
            phase = rules.TURN_PHASE.INIT,
            message = "start of the game",
            playerDamage = 0,   -- player damage to boss "this turn"
            bossDamage = 0,     -- boss damage to player "this turn"
            selectedCards = {},
            playCards = {},
            discardCards = {},
            effects = {},
        },
        log = {}
    }
    
    return state
end

function game_state.change_phase(state, phase)
    game_state.addLog(state, "Phase changed from " .. state.turn.phase .. " to " .. phase)
    state.turn.phase = phase

    if phase == rules.TURN_PHASE.PLAYER then
        rules.resetTurn(state)
        state.turn.message = "Select cards to play (1-8), Press Enter to confirm"
    elseif phase == rules.TURN_PHASE.EFFECTS then
        rules.applySuitEffects(state)           -- player hands, deck, discards all updated
        game_state.change_phase(state, rules.TURN_PHASE.PLAYER_DAMAGE)
    elseif phase == rules.TURN_PHASE.PLAYER_DAMAGE then
        rules.handlePlayerDamage(state)
        game_state.change_phase(state, rules.TURN_PHASE.BOSS_DAMAGE)
    elseif phase == rules.TURN_PHASE.BOSS_DAMAGE then
        rules.handleBossDamage(state)
        state.turn.message = "Select cards to discard (1-8), Press Enter to confirm"
    end
end

-- Add log entry
function game_state.addLog(state, message)
    table.insert(state.log, 1, message)
end

-- Handle card selection for player
-- Card Selection won't trigger turn phase change
function game_state.handlePlayCardSelection(state, cardIndex)
    if state.turn.phase ~= rules.TURN_PHASE.PLAYER then
        game_state.addLog(state, "Cannot select cards in current phase: " .. state.turn.phase)
        return
    end
    
    if cardIndex < 1 or cardIndex > #state.player.hand then
        game_state.addLog(state, "Invalid card index: " .. cardIndex)
        return
    end
    
    local card = state.player.hand[cardIndex]
    
    -- Check if card is already selected
    for i, selectedCard in ipairs(state.turn.selectedCards) do
        if selectedCard == card then
            -- Deselect card
            table.remove(state.turn.selectedCards, i)
            game_state.addLog(state, "Deselected card: " .. card.suit .. card.rank)
            return
        end
    end
    
    -- Check if we can add this card to selection
    local testSelection = {}
    for i, selectedCard in ipairs(state.turn.selectedCards) do
        table.insert(testSelection, selectedCard)
    end
    table.insert(testSelection, card)

    if rules.validatePlayCards(testSelection) then
        -- A can be played with another card
        table.insert(state.turn.selectedCards, card)
        game_state.addLog(state, "Selected card: " .. card.suit .. card.rank)
        return
    end

    game_state.addLog(state, "Invalid card combination")
end

-- Confirm card selection
function game_state.confirmCardSelection(state)
    if state.turn.phase ~= rules.TURN_PHASE.PLAYER then
        game_state.addLog(state, "Cannot confirm selection in current phase: " .. state.turn.phase)
        return
    end
    
    if #state.turn.selectedCards == 0 then
        game_state.addLog(state, "No cards selected")
        return
    end
    
    -- Move selected cards to played cards
    for i, card in ipairs(state.turn.selectedCards) do
        table.insert(state.turn.playCards, card)
        -- Remove from hand
        for j = #state.player.hand, 1, -1 do
            if state.player.hand[j] == card then
                table.remove(state.player.hand, j)
                break
            end
        end
    end
    
    game_state.addLog(state, "Playing " .. #state.turn.selectedCards .. " cards")
    state.turn.selectedCards = {}

    game_state.change_phase(state, rules.TURN_PHASE.EFFECTS)
end


-- Handle card selection for player_damage phase
-- Card Selection won't trigger turn phase change
function game_state.handleDiscardCardSelection(state, cardIndex)
    if state.turn.phase ~= rules.TURN_PHASE.BOSS_DAMAGE then
        return
    end
    
    if cardIndex < 1 or cardIndex > #state.player.hand then
        game_state.addLog(state, "Invalid card index: " .. cardIndex)
        return
    end
    
    local card = state.player.hand[cardIndex]
    
    -- Check if card is already selected for damage
    for i, selectedCard in ipairs(state.turn.discardCards) do
        if selectedCard == card then
            -- Deselect card
            table.remove(state.turn.discardCards, i)
            game_state.addLog(state, "Deselected card for discard: " .. card.suit .. card.rank)
            return
        end
    end
    
    -- Select card for damage
    table.insert(state.turn.discardCards, card)
    game_state.addLog(state, "Selected card for discard: " .. card.suit .. card.rank)
end

-- Confirm damage selection
function game_state.confirmDiscardSelection(state)
    if state.turn.phase ~= rules.TURN_PHASE.BOSS_DAMAGE then
        return false
    end
    
    local selectedValue = 0
    local bossAttack = state.turn.bossDamage

    for _, card in ipairs(state.turn.discardCards) do
        selectedValue = selectedValue + card.attack
    end
    
    if selectedValue >= state.turn.bossDamage then
        -- Discard selected cards
        for _, card in ipairs(state.turn.discardCards) do
            for j = #state.player.hand, 1, -1 do
                if state.player.hand[j] == card then
                    table.insert(state.player.discard, state.player.hand[j])
                    table.remove(state.player.hand, j)
                    break
                end
            end
        end
        
        game_state.addLog(state, "Player discarded " .. selectedValue .. " damage to block " .. bossAttack .. " attack")
        state.turn.discardCards = {}
        return true
    else
        -- Player cannot block damage, game over
        game_state.addLog(state, "GAME OVER! Player cannot block " .. bossAttack .. " damage (only " .. selectedValue .. ")")
        state.turn.message = "GAME OVER - Press R to restart"
        return false
    end
end


-- Handle keyboard input
function game_state.handleInput(state, key)
    print("handleInput: " .. key)
    if key == "r" then
        -- Restart game
        return "restart"
    end
    
    -- handle user selection  
    if key >= "1" and key <= "8" then
        local cardIndex = tonumber(key)
        if state.turn.phase == rules.TURN_PHASE.PLAYER then
            -- Select/deselect card for dealing damage to boss
            game_state.handlePlayCardSelection(state, cardIndex)
        elseif state.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
            -- Select/deselect card for dealing damage from boss
            game_state.handleDiscardCardSelection(state, cardIndex)
        end
        return "handled"
        
    -- handle confirm selection
    elseif key == "return" then
        if state.turn.phase == rules.TURN_PHASE.PLAYER then
            -- Confirm play cards selection
            game_state.confirmCardSelection(state)
        elseif state.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
            -- Confirm discard cards selection
            game_state.confirmDiscardSelection(state)
            
        end
        return "handled"
    end
    
    return "unhandled"
end
return game_state