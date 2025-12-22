-- Game Rules Module
-- 弑君者游戏规则模块 - 统一处理游戏逻辑、伤害计算和花色效果
--
-- 数据结构说明：
-- Card 结构: {suit = "Spades|Hearts|Clubs|Diamonds", rank = "A|2-10|J|Q|K", type = "Normal|Royal", attack = 数值}
-- Effect 结构: {suit = "Spades|Hearts|Clubs|Diamonds", rank = "A|2-10|J|Q|K", value = 数值}
-- State 结构: 游戏状态对象，包含以下子模块：
--   player: {hand, deck, discard} - 玩家相关数据结构
--   boss: {current, health, deck} - BOSS相关数据结构  
--   turn: {phase, message, playerDamage, bossDamage, selectedCards, playCards, discardCards, effects, skipDamagePhase} - 回合相关数据
--
-- 回合阶段常量（rules.TURN_PHASE）：
-- INIT            - 初始状态
-- PLAYER          - 玩家选择出牌
-- EFFECTS         - 应用花色效果
-- PLAYER_DAMAGE   - 计算玩家对BOSS的伤害
-- BOSS_DAMAGE     - 计算BOSS对玩家的伤害
--
-- 游戏初始化相关：
-- initGame(state)                                  - 游戏初始化：创建牌堆、发牌、设置初始BOSS
-- newTurn(state)                                   - 开始新回合：重置伤害值和回合数据
--
-- 出牌验证相关：
-- validatePlayCards(state, cards)                  - 验证出牌合法性：同点数组合或A配牌规则
-- canPlayCardsTogether(state, cards)               - 检查同点数组合：所有牌同点数且总攻击≤10
-- canPlayAWithCard(state, cards)                   - 检查A配牌规则：只能有一张A配一张其他牌
--
-- 伤害计算相关：
-- calculatePlayerDamage(state)                     - 计算玩家对BOSS的基础伤害，存储到turn.playerDamage
-- handlePlayerDamage(state)                        - 处理玩家伤害逻辑：扣除BOSS血量，处理BOSS击败
-- handleBossDamage(state)                          - 处理BOSS对玩家的伤害（预留接口）
-- isBossDefeated(boss)                             - 检查BOSS是否被击败（health <= 0）
--
-- 花色效果相关：
-- applySuitEffects(state)                          - 应用花色效果（按顺序：黑桃→红心→梅花→方块）
-- applySpadesEffect(state, effect)                 - 黑桃效果：降低BOSS对玩家的伤害（effect.value点）
-- applyHeartsEffect(state, effect)                   - 红心效果：从弃牌堆补充effect.value张牌到牌库底部
-- applyClubsEffect(state, effect)                    - 梅花效果：额外造成effect.value点伤害（双倍伤害的一部分）
-- applyDiamondsEffect(state, effect)               - 方块效果：抽取effect.value张牌（最多到8张手牌上限）
--
-- 重要规则：
-- 1. 与BOSS同花色的牌不会产生效果
-- 2. 花色效果按固定顺序应用：黑桃→红心→梅花→方块
-- 3. 基础伤害计算：A=1, 2-10=牌面值, J=10, Q=15, K=20
-- 4. 梅花效果实现双倍伤害：基础伤害 + 额外effect.value伤害
-- 5. 黑桃效果现在作用于BOSS伤害（turn.bossDamage）而非BOSS攻击力
-- 6. 出牌规则：多张牌必须同点数且总攻击≤10，或A可以与任意单张牌组合
-- 7. BOSS被击败后自动切换到下一张BOSS牌，全部击败则游戏胜利
-- 8. BOSS生命值=0时放入玩家牌库顶，生命值<0时放入弃牌堆
-- 9. BOSS被击败时跳过承受伤害阶段

local rules = {}
local deck_manager = require("deck_manager")

rules.TURN_PHASE = {
    INIT = "init",                   -- 初始状态
    PLAYER = "player",               -- 玩家选择出牌
    EFFECTS = "effects",             -- 应用花色效果
    PLAYER_DAMAGE = "player_damage", -- 计算玩家对BOSS的伤害
    BOSS_DAMAGE = "boss_damage"      -- 计算 BOSS 对玩家的伤害
}

-- 游戏开始，需要作这些事情
-- 初始化BOSS牌堆
-- 初始化玩家牌堆
-- 玩家抽牌，单人游戏的情况下 8 张
-- 翻出 BOSS 牌堆第一张
function rules.initGame(state)
    -- 确保状态对象有必要的结构
    state.player = {
        hand = {},    -- 玩家手牌数组，存储当前持有的卡牌
        deck = {},    -- 玩家牌库数组，存储未抽到的卡牌
        discard = {}, -- 玩家弃牌堆数组，存储已使用的卡牌
    }
    state.boss = {
        current = nil, -- 当前BOSS卡牌对象（J/Q/K），nil表示无BOSS
        health = 0,    -- 当前BOSS剩余生命值
        deck = {}      -- BOSS牌库数组，存储剩余的BOSS卡牌
    }
    state.turn = {
        phase = rules.TURN_PHASE.INIT, -- 当前回合阶段（init/player/effects/player_damage/boss_damage）
        message = "start of the game", -- 当前回合提示信息，显示给玩家
        playerDamage = 0,              -- 玩家本回合对BOSS造成的伤害值
        bossDamage = 0,                -- BOSS本回合对玩家造成的伤害值
        selectedCards = {},            -- 玩家当前选择的卡牌索引数组
        playCards = {},                -- 玩家本回合打出的卡牌数组
        discardCards = {},             -- 玩家本回合弃掉的卡牌数组（用于抵挡伤害）
        effects = {},                  -- 本回合生效的花色效果数组
    }

    -- 初始化玩家牌堆（创建、洗牌、发初始手牌）
    deck_manager.initializePlayerDeck(state)

    -- 调整初始手牌数量为8张（单人游戏）
    state.player.hand = {}
    for i = 1, 8 do
        local card = deck_manager.drawCard(state.player.deck)
        if card then
            deck_manager.addCardToHand(state.player.hand, card, 8)
        end
    end

    -- 初始化BOSS牌堆（创建、洗牌、设置当前BOSS）
    deck_manager.initializeBossDeck(state)

    -- 抽 BOSS 牌堆第一张牌作为当前 BOSS
    state.boss.current = deck_manager.drawCard(state.boss.deck)
    state.boss.health = state.boss.current.health
    state.turn.bossDamage = state.boss.current.attack
end

-- 开始新的一个回合
-- 1. 重置玩家伤害为 0
-- 2. 重置 BOSS 伤害为当前 BOSS 的攻击力
function rules.newTurn(state)
    state.turn.playerDamage = 0                       -- 玩家伤害重置为 0
    state.turn.bossDamage = state.boss.current.attack -- boss伤害重置为当前BOSS的攻击力
end

function rules.validatePlayCards(state, cards)
    if #cards < 2 then
        return true
    end

    if rules.canPlayCardsTogether(state, cards) then
        return true
    end

    return rules.canPlayAWithCard(state, cards)
end

function rules.canPlayCardsTogether(state, cards) 
    local firstRank = cards[1].rank

    -- Check if all cards have same rank
    for i = 2, #cards do
        if cards[i].rank ~= firstRank then
            state.addLog("Cards must have same rank to play together")
            return false
        end
    end

    -- Check if sum is <= 10
    local totalAttack = 0
    for _, card in ipairs(cards) do
        totalAttack = totalAttack + card.attack
    end

    if totalAttack > 10 then
        state.addLog("Total attack must be <= 10 to play together")
        return false
    end

    return true
end

-- Check if A can be played with another card
function rules.canPlayAWithCard(state, cards)
    if #cards ~= 2 then
        return false
    end

    for _, card in ipairs(cards) do
        if card.rank == "A" then
            return true
        end
    end

    state.addLog("Must be A or other card with same rank")
    return false
end

-- Calculate final player damage
function rules.calculatePlayerDamage(state)
    local totalDamage = 0

    -- calculate base damage for each select card
    for _, card in ipairs(state.turn.playCards) do
        totalDamage = totalDamage + card.attack
    end

    state.turn.playerDamage = state.turn.playerDamage + totalDamage
end

function rules.handlePlayerDamage(state)
    rules.calculatePlayerDamage(state)
    print("Player Damage: " .. state.turn.playerDamage)
    print("BOSS Health: " .. state.boss.health)
    state.boss.health = state.boss.health - state.turn.playerDamage
    print("BOSS Health after Player Damage: " .. state.boss.health)

    local isBossDefeated = state.boss.health <= 0

    -- Check if boss is defeated
    if isBossDefeated then
        -- Handle boss defeat based on health value
        local defeatedBoss = table.remove(state.boss.deck, 1) -- Remove defeated boss

        if state.boss.health < 0 then
            -- Health < 0: Put boss in discard pile
            if state.player.discard then
                table.insert(state.player.discard, defeatedBoss)
            end
        else -- state.boss.health == 0
            -- Health = 0: Put boss on top of player deck
            if state.player.deck then
                table.insert(state.player.deck, 1, defeatedBoss)
            end
        end

        -- Check if there are more bosses
        if #state.boss.deck > 0 then
            -- Set next boss
            state.boss.current = deck_manager.drawCard(state.boss.deck)
            state.boss.health = state.boss.current.health
        else
            -- All bosses defeated
            state.boss.current = nil
            state.boss.health = 0
        end
    end

    return isBossDefeated
end

-- Apply suit effects
function rules.applySuitEffects(state)
    -- Collect effects from played cards. We need to take care of the boss's suit
    state.turn.effects = {}
    for _, card in ipairs(state.turn.playCards) do
        if card.suit ~= state.boss.current.suit then
            table.insert(state.turn.effects, {
                suit = card.suit,
                rank = card.rank,
                value = card.attack,
            })
        end
    end

    -- Apply suit effects in order: Spades → Hearts → Clubs → Diamonds
    -- Apply Spades effects first
    for _, effect in ipairs(state.turn.effects) do
        if effect.suit == deck_manager.SUITS.SPADES then
            rules.applySpadesEffect(state, effect)
        end
    end

    -- Apply Hearts effects
    for _, effect in ipairs(state.turn.effects) do
        if effect.suit == deck_manager.SUITS.HEARTS then
            rules.applyHeartsEffect(state, effect)
        end
    end

    -- Apply Clubs effects (damage multiplier handled separately)
    for _, effect in ipairs(state.turn.effects) do
        if effect.suit == deck_manager.SUITS.CLUBS then
            rules.applyClubsEffect(state, effect)
        end
    end

    -- Apply Diamonds effects last
    for _, effect in ipairs(state.turn.effects) do
        if effect.suit == deck_manager.SUITS.DIAMONDS then
            rules.applyDiamondsEffect(state, effect)
        end
    end
end

-- Spades effect: Lower enemy attack by N
function rules.applySpadesEffect(state, effect)
    print("Spades effect: Lower enemy attack by " .. effect.value)
    state.turn.bossDamage = math.max(0, state.turn.bossDamage - effect.value)
end

-- Hearts effect: Take N cards from discard to deck bottom
function rules.applyHeartsEffect(state, effect)
    print("Hearts effect: Take " .. effect.value .. " cards from discard to deck bottom")
    local cardsTaken = 0

    -- Take cards from discard pile
    while #state.player.discard > 0 and cardsTaken < effect.value do
        local card = table.remove(state.player.discard)
        table.insert(state.player.deck, card) -- Add to bottom of deck
        cardsTaken = cardsTaken + 1
    end
end

-- Clubs effect: Deal 2*N damage - which means we added additional N to player damage
function rules.applyClubsEffect(state, effect)
    print("Clubs effect: Deal additional " .. effect.value .. " damage")
    state.turn.playerDamage = state.turn.playerDamage + effect.value
end

-- Diamonds effect: Draw N cards (up to hand limit)
function rules.applyDiamondsEffect(state, effect)
    print("Diamonds effect: Draw " .. effect.value .. " cards (up to hand limit)")
    local cardsDrawn = 0

    -- Draw cards up to hand limit
    while #state.player.hand < 8 and #state.player.deck > 0 and cardsDrawn < effect.value do
        local card = table.remove(state.player.deck, 1)
        table.insert(state.player.hand, card)
        cardsDrawn = cardsDrawn + 1
    end
end

return rules
