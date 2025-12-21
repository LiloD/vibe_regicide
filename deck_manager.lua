-- Deck and Card Management Module
-- 牌堆和卡牌管理模块，负责卡牌数据结构、牌堆创建、洗牌、抽牌等核心功能
--
-- 数据结构说明：
-- Card 结构: {
--   suit = "Spades|Hearts|Clubs|Diamonds",      -- 花色
--   rank = "A|2-10|J|Q|K",                     -- 牌面
--   type = "Normal|Royal",                     -- 类型（普通/皇家）
--   attack = 数值,                              -- 攻击力
--   health = 数值                               -- 生命值（皇家牌）
-- }
--
-- 模块常量：
-- SUITS                    - 花色定义：Spades(黑桃), Hearts(红心), Clubs(梅花), Diamonds(方块)
-- CARD_TYPES              - 卡牌类型：Normal(普通牌), Royal(皇家牌)
-- SUIT_ABBREVIATIONS      - 花色缩写映射表：C/D/H/S
--
-- 核心功能分类：
--
-- 卡牌工具函数：
-- getCardAbbreviation(card)           - 获取卡牌缩写（如C5表示梅花5）
-- createCard(suit, rank, type)        - 创建卡牌数据结构，自动设置攻击力和生命值
--
-- 牌堆创建函数：
-- createPlayerDeck()                  - 创建玩家牌堆（A, 2-10，共40张普通牌）
-- createBossDeck()                    - 创建BOSS牌堆（J, Q, K，共12张皇家牌）
--
-- 牌堆操作函数：
-- shuffleDeck(deck)                   - 使用Fisher-Yates算法洗牌
-- drawCard(deck)                      - 从牌堆顶部抽一张牌
-- addCardToHand(hand, card, maxHandSize) - 添加牌到手牌（默认上限8张）
-- discardCardFromHand(hand, cardIndex, discardPile) - 从手牌弃牌到弃牌堆
--
-- 初始化函数：
-- initializePlayerDeck(state)           - 初始化玩家牌堆：洗牌+发5张起始手牌
-- initializeBossDeck(state)             - 初始化BOSS牌堆：洗牌+设置当前BOSS
--
-- 数值规则：
-- 普通牌：A=1攻击，2-10=牌面数值攻击
-- 皇家牌：J=10攻击/20生命，Q=15攻击/30生命，K=20攻击/40生命

local deck_manager = {}

-- Card suit definitions
deck_manager.SUITS = {
    SPADES = "Spades",    -- Spades: Lower enemy attack by N
    HEARTS = "Hearts",   -- Hearts: Take N cards from discard to deck bottom
    CLUBS = "Clubs",     -- Clubs: Deal 2*N damage
    DIAMONDS = "Diamonds" -- Diamonds: Draw N cards (up to hand limit)
}

-- Card type definitions
deck_manager.CARD_TYPES = {
    NORMAL = "Normal",
    ROYAL = "Royal"
}

-- Suit abbreviation mapping
deck_manager.SUIT_ABBREVIATIONS = {
    ["Clubs"] = "C",
    ["Diamonds"] = "D",
    ["Hearts"] = "H",
    ["Spades"] = "S"
}

-- Function to get card abbreviation
function deck_manager.getCardAbbreviation(card)
    local suitAbbr = deck_manager.SUIT_ABBREVIATIONS[card.suit] or card.suit:sub(1,1)
    return suitAbbr .. card.rank
end

-- Create card data structure
function deck_manager.createCard(suit, rank, cardType)
    local card = {
        suit = suit,
        rank = rank,
        type = cardType,
        attack = 0,
        health = 0
    }
    
    -- Set properties based on card type
    if cardType == deck_manager.CARD_TYPES.NORMAL then
        -- Normal cards: A=1, 2=2, ..., 10=10
        card.attack = rank
        card.health = 0
    else
        -- Royal cards: J=10/20, Q=15/30, K=20/40 (attack/health)
        if rank == "J" then
            card.attack = 10
            card.health = 20
        elseif rank == "Q" then
            card.attack = 15
            card.health = 30
        elseif rank == "K" then
            card.attack = 20
            card.health = 40
        end
    end
    
    return card
end

-- Create player deck (all cards except J, Q, K)
function deck_manager.createPlayerDeck()
    local deck = {}
    local suits = {"Clubs", "Diamonds", "Hearts", "Spades"}
    
    -- Add normal cards (A, 2-10) only
    for _, suit in ipairs(suits) do
        -- Add Aces
        table.insert(deck, {suit = suit, rank = "A", type = "Normal", attack = 1})
        
        -- Add number cards (2-10)
        for rank = 2, 10 do
            table.insert(deck, {suit = suit, rank = rank, type = "Normal", attack = rank})
        end
    end
    
    return deck
end

-- Create BOSS deck (J, Q, K only)
function deck_manager.createBossDeck()
    local deck = {}
    local suits = {"Clubs", "Diamonds", "Hearts", "Spades"}
    
    -- Add royal cards (J, Q, K) for BOSS deck
    for _, suit in ipairs(suits) do
        local royalCards = {"J", "Q", "K"}
        local royalAttacks = {J = 10, Q = 15, K = 20}
        
        for _, rank in ipairs(royalCards) do
            table.insert(deck, {suit = suit, rank = rank, type = "Royal", attack = royalAttacks[rank], health = 20})
        end
    end
    
    return deck
end

-- Shuffle deck using Fisher-Yates algorithm
function deck_manager.shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- Draw card from deck
function deck_manager.drawCard(deck)
    if #deck == 0 then
        return nil
    end
    return table.remove(deck, 1)
end

-- Add card to hand (respecting hand limit)
function deck_manager.addCardToHand(hand, card, maxHandSize)
    maxHandSize = maxHandSize or 8
    if #hand < maxHandSize then
        table.insert(hand, card)
        return true
    end
    return false
end

-- Discard card from hand
function deck_manager.discardCardFromHand(hand, cardIndex, discardPile)
    if cardIndex < 1 or cardIndex > #hand then
        return false
    end
    
    local card = table.remove(hand, cardIndex)
    if discardPile then
        table.insert(discardPile, card)
    end
    
    return true
end

-- Initialize player deck and hand
function deck_manager.initializePlayerDeck(state)
    -- Create and shuffle player deck (A, 2-10 only)
    state.player.deck = deck_manager.createPlayerDeck()
    deck_manager.shuffleDeck(state.player.deck)
    
    -- Draw initial hand (5 cards)
    state.player.hand = {}
    for i = 1, 5 do
        local card = deck_manager.drawCard(state.player.deck)
        if card then
            deck_manager.addCardToHand(state.player.hand, card)
        end
    end
    
    -- Initialize discard pile
    state.player.discard = {}
end

-- Initialize boss deck
function deck_manager.initializeBossDeck(state)
    -- Create boss deck (J, Q, K only)
    state.boss.deck = deck_manager.createBossDeck()
    
    -- Shuffle boss deck
    deck_manager.shuffleDeck(state.boss.deck)
    
    -- Set current boss (first card in boss deck)
    state.boss.current = state.boss.deck[1]
    state.boss.health = state.boss.current.health
    state.turn.bossDamage = state.boss.current.attack
end

return deck_manager