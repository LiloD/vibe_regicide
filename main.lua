-- Regicide Game Main File
-- Based on Love2D Game Engine

-- Card suit definitions
local SUITS = {
    CLUBS = "Clubs",    -- Clubs: Double attack power
    DIAMONDS = "Diamonds", -- Diamonds: Draw one card
    HEARTS = "Hearts",   -- Hearts: Heal 1 HP
    SPADES = "Spades"    -- Spades: No special effect
}

-- Card type definitions
local CARD_TYPES = {
    NORMAL = "Normal",
    ROYAL = "Royal"
}

-- Suit abbreviation mapping
local SUIT_ABBREVIATIONS = {
    ["Clubs"] = "C",
    ["Diamonds"] = "D", 
    ["Hearts"] = "H",
    ["Spades"] = "S"
}

-- Function to get card abbreviation
function getCardAbbreviation(card)
    local suitAbbr = SUIT_ABBREVIATIONS[card.suit] or card.suit:sub(1,1)
    return suitAbbr .. card.rank
end

-- Create card data structure
function createCard(suit, rank, cardType)
    local card = {
        suit = suit,
        rank = rank,
        type = cardType,
        attack = 0,
        health = 0
    }
    
    -- Set properties based on card type
    if cardType == CARD_TYPES.NORMAL then
        -- Normal cards: A=1, 2=2, ..., 10=10
        card.attack = rank
        card.health = 0
    else
        -- Royal cards: J=10, Q=15, K=20
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

-- Game state management
local gameState = {
    -- Player state
    player = {
        hand = {},           -- Hand cards list
        handLimit = 8,       -- Hand limit
        deck = {},           -- Player deck
        discard = {}         -- Discard pile
    },
    
    -- BOSS state
    boss = {
        current = nil,       -- Current BOSS card
        health = 0,          -- Remaining health
        royalDeck = {}       -- Royal member deck
    },
    
    -- Turn state
    turn = {
        phase = "player",    -- Current turn phase
        message = "Game started! Press S to shuffle, D to draw"
    },
    
    -- Operation log
    log = {}
}

-- Add log entry
function addLog(message)
    table.insert(gameState.log, 1, message)
    if #gameState.log > 10 then
        table.remove(gameState.log, 11)
    end
end

-- Initialize complete deck
function initializeDeck()
    local deck = {}
    
    -- Create normal cards (A-10)
    local normalRanks = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
    for _, suit in pairs(SUITS) do
        for _, rank in ipairs(normalRanks) do
            local numericRank = 0
            -- Convert A to 1, other ranks to their numeric value
            if rank == "A" then
                numericRank = 1
            else
                numericRank = tonumber(rank)
            end
            table.insert(deck, createCard(suit, numericRank, CARD_TYPES.NORMAL))
        end
    end
    
    -- Create royal cards (J, Q, K)
    local royalRanks = {"J", "Q", "K"}
    for _, suit in pairs(SUITS) do
        for _, rank in ipairs(royalRanks) do
            table.insert(gameState.boss.royalDeck, createCard(suit, rank, CARD_TYPES.ROYAL))
        end
    end
    
    return deck
end

-- Shuffle deck using Fisher-Yates algorithm
function shuffleDeck(deck)
    local shuffled = {}
    -- Copy the original deck
    for i = 1, #deck do
        shuffled[i] = deck[i]
    end
    
    -- Fisher-Yates shuffle algorithm
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    
    return shuffled
end

-- Draw card logic
function drawCard()
    if #gameState.player.deck == 0 then
        -- Deck is empty, reshuffle discard pile
        if #gameState.player.discard > 0 then
            gameState.player.deck = shuffleDeck(gameState.player.discard)
            gameState.player.discard = {}
            addLog("Deck empty, reshuffling discard pile")
        else
            addLog("Both deck and discard pile are empty, cannot draw")
            return nil
        end
    end
    
    if #gameState.player.hand < gameState.player.handLimit then
        local card = table.remove(gameState.player.deck, 1)
        table.insert(gameState.player.hand, card)
        addLog("Drew a card: " .. card.suit .. card.rank)
        return card
    else
        addLog("Hand full, cannot draw")
        return nil
    end
end

-- Discard card logic
function discardCard(cardIndex)
    if cardIndex and cardIndex >= 1 and cardIndex <= #gameState.player.hand then
        local card = table.remove(gameState.player.hand, cardIndex)
        table.insert(gameState.player.discard, card)
        addLog("Discarded a card: " .. card.suit .. card.rank)
        return card
    end
    return nil
end

-- Initialize BOSS
function initializeBoss()
    if #gameState.boss.royalDeck > 0 then
        gameState.boss.current = table.remove(gameState.boss.royalDeck, 1)
        gameState.boss.health = gameState.boss.current.health
        addLog("BOSS appears: " .. gameState.boss.current.suit .. gameState.boss.current.rank)
    else
        addLog("All BOSS defeated! Game victory!")
    end
end

-- Game initialization
function love.load()
    -- Set random seed for proper shuffling
    math.randomseed(os.time())
    
    -- Set background color to dark blue
    love.graphics.setBackgroundColor(0.1, 0.1, 0.3)
    
    -- Initialize and shuffle player deck
    gameState.player.deck = initializeDeck()
    gameState.player.deck = shuffleDeck(gameState.player.deck)
    
    -- Initialize first BOSS
    initializeBoss()
    
    -- Draw initial 5 cards for player
    for i = 1, 5 do
        drawCard()
    end
    
    addLog("Game initialization complete")
    print("Game initialization complete")
end

-- Game logic update
function love.update(dt)
    -- Game logic update (currently empty)
end

-- Game drawing
function love.draw()
    love.graphics.setColor(1, 1, 1)
    
    -- Draw game title
    love.graphics.print("Regicide Game", 50, 20)
    
    -- Draw player hand information
    love.graphics.print("Player Hand (" .. #gameState.player.hand .. "/" .. gameState.player.handLimit .. "):", 50, 50)
    for i, card in ipairs(gameState.player.hand) do
        local cardText = i .. ". " .. card.suit .. card.rank 
        if card.type == CARD_TYPES.ROYAL then
            cardText = cardText .. " [BOSS]"
        else
            cardText = cardText .. " (Attack:" .. card.attack .. ")"
        end
        love.graphics.print(cardText, 70, 70 + i * 20)
    end
    
    -- Draw BOSS information
    if gameState.boss.current then
        love.graphics.print("Current BOSS: " .. gameState.boss.current.suit .. gameState.boss.current.rank, 300, 50)
        love.graphics.print("Attack: " .. gameState.boss.current.attack, 300, 70)
        love.graphics.print("Health: " .. gameState.boss.health .. "/" .. gameState.boss.current.health, 300, 90)
    else
        love.graphics.print("All BOSS defeated!", 300, 50)
    end
    
    -- Draw deck information
    love.graphics.print("Deck: " .. #gameState.player.deck, 300, 120)
    if #gameState.player.deck > 0 then
        local deckDisplay = "Top: "
        -- Show top 3 cards from deck
        for i = 1, math.min(3, #gameState.player.deck) do
            deckDisplay = deckDisplay .. getCardAbbreviation(gameState.player.deck[i]) .. " "
        end
        love.graphics.print(deckDisplay, 300, 140)
    end
    
    love.graphics.print("Discard: " .. #gameState.player.discard, 300, 160)
    if #gameState.player.discard > 0 then
        local discardDisplay = "Top: "
        -- Show top 3 cards from discard pile
        for i = 1, math.min(3, #gameState.player.discard) do
            discardDisplay = discardDisplay .. getCardAbbreviation(gameState.player.discard[i]) .. " "
        end
        love.graphics.print(discardDisplay, 300, 180)
    end
    
    love.graphics.print("Remaining BOSS: " .. #gameState.boss.royalDeck, 300, 200)
    
    -- Draw operation hints
    love.graphics.print("Controls:", 50, 280)
    love.graphics.print("S - Shuffle deck", 70, 300)
    love.graphics.print("D - Draw card", 70, 320)
    love.graphics.print("1-8 - Discard corresponding card", 70, 340)
    love.graphics.print("ESC - Quit game", 70, 360)
    
    -- Draw operation log
    love.graphics.print("Log:", 50, 400)
    for i, logEntry in ipairs(gameState.log) do
        love.graphics.print(logEntry, 70, 420 + i * 20)
    end
    
    -- Draw turn state
    love.graphics.print("Current Turn: " .. gameState.turn.phase, 300, 220)
    love.graphics.print(gameState.turn.message, 300, 240)
end

-- Keyboard input handling
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "s" then
        -- Shuffle deck
        gameState.player.deck = shuffleDeck(gameState.player.deck)
        addLog("Deck shuffled")
        gameState.turn.message = "Deck shuffled"
    elseif key == "d" then
        -- Draw card
        drawCard()
        gameState.turn.message = "Draw card completed"
    elseif key >= "1" and key <= "8" then
        -- Discard card
        local cardIndex = tonumber(key)
        discardCard(cardIndex)
        gameState.turn.message = "Discard card completed"
    end
end