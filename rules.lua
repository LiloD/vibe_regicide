-- Game Rules Module
-- 合并攻击计算和花色效果系统，统一处理游戏规则逻辑
--
-- 数据结构说明：
-- Card 结构: {suit = "Spades|Hearts|Clubs|Diamonds", rank = "A|2-10|J|Q|K", type = "Normal|Royal"}
-- Effect 结构: {suit = "Spades|Hearts|Clubs|Diamonds", rank = "A|2-10|J|Q|K", value = 数值}
-- State 结构: 游戏状态对象，包含 player, boss, turn 等子模块
--
-- 回合阶段常量（rules.TURN_PHASE）：
-- INIT            - 初始状态
-- PLAYER          - 玩家选择出牌
-- EFFECTS         - 应用花色效果
-- PLAYER_DAMAGE   - 计算玩家对BOSS的伤害
-- BOSS_DAMAGE     - 计算BOSS对玩家的伤害
--
-- 模块功能说明：
--
-- 回合管理相关：
-- resetTurn(state)                               - 重置回合数据：玩家伤害设为0，BOSS伤害设为当前攻击力
--
-- 伤害计算相关：
-- calculatePlayerDamage(state)                   - 计算玩家对BOSS的基础伤害，存储到turn.playerDamage
-- handlePlayerDamage(state)                      - 处理玩家伤害逻辑：扣除BOSS血量，处理BOSS击败
-- handleBossDamage(state)                        - 处理BOSS对玩家的伤害（预留接口）
-- isBossDefeated(boss)                           - 检查BOSS是否被击败（health <= 0）
--
-- 花色效果相关：
-- applySuitEffects(state)                        - 应用花色效果（按顺序：黑桃→红心→梅花→方块）
-- applySpadesEffect(state, effect)               - 黑桃效果：降低BOSS对玩家的伤害（effect.value点）
-- applyHeartsEffect(state, effect)               - 红心效果：从弃牌堆补充effect.value张牌到牌库底部
-- applyClubsEffect(state, effect)                - 梅花效果：额外造成effect.value点伤害（双倍伤害的一部分）
-- applyDiamondsEffect(state, effect)             - 方块效果：抽取effect.value张牌（最多到8张手牌上限）
--
-- 重要规则：
-- 1. 与BOSS同花色的牌不会产生效果
-- 2. 花色效果按固定顺序应用：黑桃→红心→梅花→方块
-- 3. 基础伤害计算：A=1, 2-10=牌面值, J=10, Q=15, K=20
-- 4. 梅花效果实现双倍伤害：基础伤害 + 额外effect.value伤害
-- 5. 黑桃效果现在作用于BOSS伤害（turn.bossDamage）而非BOSS攻击力

local rules = {}

rules.TURN_PHASE = {
    INIT = "init",                   -- 初始状态
    PLAYER = "player",               -- 玩家选择出牌
    EFFECTS = "effects",             -- 应用花色效果
    PLAYER_DAMAGE = "player_damage", -- 计算玩家对BOSS的伤害
    BOSS_DAMAGE = "boss_damage"      -- 计算 BOSS 对玩家的伤害
}

function rules.resetTurn(state)
    state.turn.playerDamage = 0                       -- 玩家伤害重置为 0
    state.turn.bossDamage = state.boss.current.attack -- boss伤害重置为当前BOSS的攻击力
end

function rules.validatePlayCards(cards)
    if #cards < 2 then
        return true
    end

    if rules.canPlayCardsTogether(cards) then
        return true
    end

    return rules.canPlayAWithCard(cards)
end

function rules.canPlayCardsTogether(cards)
    local firstRank = cards[1].rank

    -- Check if all cards have same rank
    for i = 2, #cards do
        if cards[i].rank ~= firstRank then
            return false
        end
    end

    -- Check if sum is <= 10
    local totalAttack = 0
    for _, card in ipairs(cards) do
        totalAttack = totalAttack + card.attack
    end

    return totalAttack <= 10
end

-- Check if A can be played with another card
function rules.canPlayAWithCard(cards)
    if #cards ~= 2 then
        return false
    end

    for _, card in ipairs(cards) do
        if card.rank == "A" then
            return true
        end
    end

    return false
end

-- Calculate final player damage
function rules.calculatePlayerDamage(state)
    local totalDamage = 0

    -- calculate base damage for each select card
    for _, card in ipairs(state.turn.playCards) do
        local baseDamage = 0

        -- Calculate base damage for this card
        if card.type == "Normal" then
            if card.rank == "A" then
                baseDamage = 1
            else
                baseDamage = card.rank
            end
        else
            if card.rank == "J" then
                baseDamage = 10
            elseif card.rank == "Q" then
                baseDamage = 15
            elseif card.rank == "K" then
                baseDamage = 20
            end
        end

        totalDamage = totalDamage + baseDamage
    end

    state.turn.playerDamage = state.turn.playerDamage + totalDamage
end

-- TODO: need further do to defeated boss scenario
function rules.handlePlayerDamage(state)
    rules.calculatePlayerDamage(state)
    print("Player Damage: " .. state.turn.playerDamage)
    print("BOSS Health: " .. state.boss.health)
    state.boss.health = state.boss.health - state.turn.playerDamage
    print("BOSS Health after Player Damage: " .. state.boss.health)
    if state.boss.health <= 0 then
        -- Remove defeated boss from deck
        table.remove(state.boss.deck, 1)

        -- Check if there are more bosses
        if #state.boss.deck > 0 then
            -- Set next boss
            state.boss.current = state.boss.deck[1]
            state.boss.health = state.boss.current.health
        else
            -- All bosses defeated - game win!
            state.boss.current = nil
            state.boss.health = 0
        end
    end
end

-- Handle player taking damage
function rules.handleBossDamage(state)
    if not state.boss.current then
        return true -- No BOSS, no damage
    end

    -- local bossAttack = state.boss.current.attack

    -- -- Enter damage selection phase
    -- state.turn.phase = "damage_selection"
    -- state.turn.message = "Select cards to discard (sum >= " .. bossAttack .. "). Press ENTER to confirm"
    -- state.turn.damageCards = {}

    return true
end

-- Apply suit effects
function rules.applySuitEffects(state)
    -- Collect effects from played cards. We need to take care of the boss's suit
    state.turn.effects = {}
    for _, card in ipairs(state.turn.playCards) do
        if card.suit ~= state.boss.current.suit then
            local value = 0
            if card.type == "Normal" then
                if card.rank == "A" then
                    value = 1
                else
                    value = card.rank
                end
            else
                if card.rank == "J" then
                    value = 10
                elseif card.rank == "Q" then
                    value = 15
                elseif card.rank == "K" then
                    value = 20
                end
            end

            table.insert(state.turn.effects, {
                suit = card.suit,
                rank = card.rank,
                value = value,
            })
        end
    end

    -- Apply suit effects in order: Spades → Hearts → Clubs → Diamonds
    -- Apply Spades effects first
    for _, effect in ipairs(state.turn.effects) do
        if effect.suit == "Spades" then
            rules.applySpadesEffect(state, effect)
        end
    end

    -- Apply Hearts effects
    for _, effect in ipairs(state.turn.effects) do
        if effect.suit == "Hearts" then
            rules.applyHeartsEffect(state, effect)
        end
    end

    -- Apply Clubs effects (damage multiplier handled separately)
    for i, effect in ipairs(state.turn.effects) do
        if effect.suit == "Clubs" then
            rules.applyClubsEffect(state, effect)
        end
    end

    -- Apply Diamonds effects last
    for i, effect in ipairs(state.turn.effects) do
        if effect.suit == "Diamonds" then
            rules.applyDiamondsEffect(state, effect)
        end
    end
end

-- Spades effect: Lower enemy attack by N
function rules.applySpadesEffect(state, effect)
    if not state.boss.current then return end

    local reduction = effect.value
    state.turn.bossDamage = math.max(0, state.turn.bossDamage - reduction)
end

-- Hearts effect: Take N cards from discard to deck bottom
function rules.applyHeartsEffect(state, effect)
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
    state.turn.playerDamage = state.turn.playerDamage + effect.value
end

-- Diamonds effect: Draw N cards (up to hand limit)
function rules.applyDiamondsEffect(state, effect)
    local cardsDrawn = 0

    -- Draw cards up to hand limit
    while #state.player.hand < 8 and #state.player.deck > 0 and cardsDrawn < effect.value do
        local card = table.remove(state.player.deck, 1)
        table.insert(state.player.hand, card)
        cardsDrawn = cardsDrawn + 1
    end
end

return rules
