local rules = {}
local deck_manager = require("deck_manager")

rules.STATE_PHASE = {
    INIT = "init",
    PLAYER = "player",
    EFFECTS = "effects",
    BOSS_DAMAGE = "boss_damage"
}

-- 游戏开始，需要作这些事情
-- 初始化BOSS牌堆
-- 初始化玩家牌堆
-- 玩家抽牌，单人游戏的情况下 8 张
-- 翻出 BOSS 牌堆第一张
function rules.init(state)
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
        message = "start of the game", -- 当前回合提示信息，显示给玩家
        playerDamage = 0,              -- 玩家本回合对BOSS造成的伤害值
        bossDamage = 0,                -- BOSS本回合对玩家造成的伤害值
        selectedCards = {},            -- 玩家当前选择的卡牌索引数组
        playCards = {},                -- 玩家本回合打出的卡牌数组
        discardCards = {},             -- 玩家本回合弃掉的卡牌数组（用于抵挡伤害）
        effects = {},                  -- 本回合生效的花色效果数组
    }

    -- debug log
    state.log = {}
    function state.addLog(message)
        -- table.insert(state.log, 1, message)
        print(message)
    end

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
    rules.rotateBoss(state)
end

-- 开始新的一个回合
-- 1. 重置玩家伤害为 0
-- 2. 重置 BOSS 伤害为当前 BOSS 的攻击力
function rules.newTurn(state)
    state.turn.playerDamage = 0                       -- 玩家伤害重置为 0
    state.turn.bossDamage = state.boss.current.attack -- boss伤害重置为当前BOSS的攻击力
end

-- check if player can play these cards together
-- 1. 一张牌可以直接出
-- 2. 多张牌考虑如下规则：
--  2.1 必须同点数且总攻击值必须 <= 10
--  2.2 A 可以和另一张牌一起打出
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

-- 处理玩家伤害逻辑
function rules.handlePlayerDamage(state)
    rules.calculatePlayerDamage(state)
    state.boss.health = state.boss.health - state.turn.playerDamage
    return state.boss.health <= 0
end

-- 处理BOSS被击败逻辑
-- 1. 如果 boss 生命小于 0，将 ta 放入弃牌堆
-- 2. 如果 boss 生命正好等于 0，将 ta 放到"玩家牌堆顶"
function rules.handleBossDefeated(state)
    local defeatedBoss = state.boss.current

    if state.boss.health < 0 then
        table.insert(state.player.discard, defeatedBoss)
    else
        table.insert(state.player.deck, 1, defeatedBoss)
    end
end

-- 轮转 BOSS
-- 1. 如果当前 BOSS 被击败，从 BOSS 牌堆中抽一张牌作为新的当前 BOSS，返回 true
-- 2. 如果没有 Boss 了，返回 false
function rules.rotateBoss(state)
    if #state.boss.deck == 0 then
        return false
    end
    state.boss.current = deck_manager.drawCard(state.boss.deck)
    state.boss.health = state.boss.current.health
    return true
end

-- Apply suit effects
function rules.applySuitEffects(state)
    print("apply suit effects, playCards: " .. #state.turn.playCards)
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
    state.addLog("Spades effect: Lower enemy attack by " .. effect.value)
    state.turn.bossDamage = math.max(0, state.turn.bossDamage - effect.value)
end

-- Hearts effect: Take N cards from discard to deck bottom
function rules.applyHeartsEffect(state, effect)
    state.addLog("Hearts effect: Take " .. effect.value .. " cards from discard to deck bottom")
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
    state.addLog("Clubs effect: Deal additional " .. effect.value .. " damage")
    state.turn.playerDamage = state.turn.playerDamage + effect.value
end

-- Diamonds effect: Draw N cards (up to hand limit)
function rules.applyDiamondsEffect(state, effect)
    state.addLog("Diamonds effect: Draw " .. effect.value .. " cards (up to hand limit)")
    local cardsDrawn = 0

    -- Draw cards up to hand limit
    while #state.player.hand < 8 and #state.player.deck > 0 and cardsDrawn < effect.value do
        local card = table.remove(state.player.deck, 1)
        table.insert(state.player.hand, card)
        cardsDrawn = cardsDrawn + 1
    end
end

return rules
