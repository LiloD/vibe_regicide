-- Game State Management Module
-- 弑君者游戏状态管理模块 - 负责游戏流程控制、回合管理和用户交互处理
--
-- 数据结构说明：
-- State 结构: {
--   player: {hand = {}, deck = {}, discard = {}},     -- 玩家相关数据：手牌、牌库、弃牌堆
--   boss: {current = nil, health = 0, deck = {}},    -- BOSS相关数据：当前BOSS、生命值、BOSS牌库
--   turn: {
--     phase = 回合阶段常量,                           -- 当前回合阶段（init/player/effects/player_damage/boss_damage）
--     message = 显示消息,                             -- 界面提示信息，指导玩家操作
--     playerDamage = 数值,                            -- 玩家本回合对BOSS造成的伤害值
--     bossDamage = 数值,                              -- BOSS本回合对玩家造成的伤害值
--     selectedCards = {},                             -- 玩家当前选中的卡牌数组
--     playCards = {},                                 -- 玩家本回合确认打出的牌
--     discardCards = {},                              -- 玩家选中的弃牌（用于抵挡伤害）
--     effects = {},                                   -- 本回合生效的花色效果数组
--     skipDamagePhase = boolean                       -- 是否跳过BOSS伤害阶段（BOSS被击败时）
--   },
--   log: []                                           -- 游戏日志数组，倒序存储（新日志在前）
--   addLog: function(message)                       -- 添加日志的函数
-- }
--
-- 模块功能分类：
--
-- 游戏初始化：
-- init()                                           - 创建并初始化游戏状态（调用rules.initGame）
--
-- 回合流程控制：
-- change_phase(state, phase)                       - 切换回合阶段，自动处理阶段间逻辑和BOSS击败
--
-- 玩家出牌阶段管理：
-- handlePlayCardSelection(state, cardIndex)        - 处理玩家出牌选择/取消选择（1-8数字键）
-- confirmPlayCardSelection(state)                  - 确认出牌选择，验证合法性并进入效果阶段
--
-- BOSS伤害阶段管理：
-- handleDiscardCardSelection(state, cardIndex)       - 处理玩家弃牌选择/取消选择（抵挡伤害）
-- confirmDiscardSelection(state)                    - 确认弃牌选择，检查是否足够抵挡BOSS伤害
--
-- 用户输入处理：
-- handleInput(state, key)                          - 统一处理键盘输入（数字1-8、Enter确认、R重启）
--
-- 辅助功能：
-- addLog(state, message)                           - 添加游戏日志条目，用于界面显示
local game_state = {}
local rules = require("rules")
local deck_manager = require("deck_manager")

-- Initialize game state
function game_state.init()
    local state = {}

    state.log = {}
    state.addLog = function (message)
        table.insert(state.log, 1, message)
    end
    
    rules.initGame(state)

    game_state.addLog(state, "Game started! Defeat all bosses to win!")
    game_state.addLog(state, "Current boss: " .. deck_manager.getCardAbbreviation(state.boss.current))

    return state
end

function game_state.change_phase(state, phase)
    game_state.addLog(state, "Phase changed from " .. state.turn.phase .. " to " .. phase)
    state.turn.phase = phase

    if phase == rules.TURN_PHASE.PLAYER then
        rules.newTurn(state)
        state.turn.message = "New Turn Start, select cards to play (1-8), Press Enter to confirm"
    elseif phase == rules.TURN_PHASE.EFFECTS then
        rules.applySuitEffects(state) -- player hands, deck, discards all updated
        game_state.change_phase(state, rules.TURN_PHASE.PLAYER_DAMAGE)
    elseif phase == rules.TURN_PHASE.PLAYER_DAMAGE then
        local isBossDefeated = rules.handlePlayerDamage(state)

        if isBossDefeated then
            if state.boss.current then
                -- have next boss start a new turn directly
                game_state.change_phase(state, rules.TURN_PHASE.PLAYER)
            else
                -- no boss next, we won
                game_state.addLog(state, "All bosses defeated! You win!")
            end
        else
            game_state.change_phase(state, rules.TURN_PHASE.BOSS_DAMAGE)
        end
    elseif phase == rules.TURN_PHASE.BOSS_DAMAGE then
        state.turn.message = "Boss will deal " .. state.turn.bossDamage .. " damage, select cards to discard (1-8), Press Enter to confirm"
        state.turn.selectedCards = {}
        state.turn.discardCards = {}
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

    if rules.validatePlayCards(state, testSelection) then
        -- A can be played with another card
        table.insert(state.turn.selectedCards, card)
        game_state.addLog(state, "Selected card: " .. card.suit .. card.rank)
        return
    end

    game_state.addLog(state, "Invalid card combination")
end

-- Confirm card selection
function game_state.confirmPlayCardSelection(state)
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
    local totalDiscardValue = 0
    local bossDamage = state.turn.bossDamage

    for _, card in ipairs(state.turn.discardCards) do
        totalDiscardValue = totalDiscardValue + card.attack
    end

    local isPlayerDefeated = totalDiscardValue < bossDamage
    if not isPlayerDefeated then
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

        game_state.addLog(state, "Player discarded " .. totalDiscardValue .. " damage to block " .. bossDamage .. " damage")
        state.turn.discardCards = {}
    end

    return isPlayerDefeated
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
            game_state.confirmPlayCardSelection(state)
        elseif state.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
            -- Confirm discard cards selection
            local isPlayerDefeated = game_state.confirmDiscardSelection(state)
            if isPlayerDefeated then
                -- Player is defeated, end game
                game_state.addLog(state, "GAME OVER! Player is defeated")
                state.turn.message = "GAME OVER - Press R to restart"
            else
                -- Player is not defeated, continue game
                game_state.change_phase(state, rules.TURN_PHASE.PLAYER)
            end
        end
        return "handled"
    end

    return "unhandled"
end

return game_state
