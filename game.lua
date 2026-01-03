local rules = require("rules")
local game = {
    game_data = {},
    states = {},
    current_state = nil,

    -- game states enum
    STATE_PLAYER = "player",
    STATE_EFFECTS = "effects",
    STATE_BOSS = "boss",
}

-- 玩家打牌回合，选择牌进行攻击
local function player_state(game_data)
    local phase = {
        name = "player"
    }

    -- a new turn starts here
    function phase.on_enter()
        game_data.turn.playerDamage = 0                           -- 玩家伤害重置为 0
        game_data.turn.bossDamage = game_data.boss.current.attack -- boss伤害重置为当前BOSS的攻击力
        game_data.turn.selectedCards = {}
        game_data.turn.playCards = {}
    end

    -- handle player input
    function phase.keypressed(key)
        if key >= "1" and key <= "8" then
            local cardIndex = tonumber(key)
            game.handlePlayCardSelection(game_data, cardIndex)
        elseif key == "return" then
            game.confirmPlayCardSelection(game_data)
            -- change to effects state
            game.change_state("effects")
        end
    end

    return phase
end

-- 花色结算 + 造成伤害回合
local function effects_state(game_data)
    local phase = {
        name = "effects"
    }

    function phase.on_enter()
        rules.applySuitEffects(game_data)
        local isBossDefeated = rules.handlePlayerDamage(game_data)
        if isBossDefeated then
            local canBossRotate = rules.rotateBoss(game_data)
            if not canBossRotate then
                -- change to win
                game.change_state("win")
            else
                -- change back to player state
                -- to start a new turn
                game.change_state("player")
            end
        else
            -- change to boss state
            game.change_state("boss")
        end
    end

    return phase
end

-- Boss 攻击，玩家承受伤害
local function boss_state(game_data)
    local phase = {
        name = "boss"
    }

    function phase.on_enter()
        game_data.turn.selectedCards = {}
        game_data.turn.discardCards = {}
    end

    function phase.on_exit()
        game_data.turn.selectedCards = {}
        game_data.turn.discardCards = {}
    end

    -- handle boss input
    function phase.keypressed(key)
        if key >= "1" and key <= "8" then
            local cardIndex = tonumber(key)
            game.handleDiscardCardSelection(game_data, cardIndex)
        elseif key == "return" then
            local isPlayerDefeated = game.confirmDiscardSelection(game_data)
            if not isPlayerDefeated then
                -- change to player state to start a new turn
                game.change_state("player")
            end
        end
    end

    return phase
end

-- Initialize game state
function game.init()
    rules.init(game.game_data)

    game.states[game.STATE_PLAYER] = player_state(game.game_data)
    game.states[game.STATE_EFFECTS] = effects_state(game.game_data)
    game.states[game.STATE_BOSS] = boss_state(game.game_data)

    game.change_state(game.STATE_PLAYER)
end

function game.keypressed(key)
    if game.current_state and game.current_state.keypressed then
        game.current_state.keypressed(key)
    end
end

-- change inner game state
function game.change_state(name)
    if game.current_state and game.current_state.on_exit then
        game.current_state.on_exit(game.game_data)
    end

    game.current_state = game.states[name]

    if game.current_state and game.current_state.on_enter then
        game.current_state.on_enter(game.game_data)
    end
end

-- Add log entry
function game.addLog(game_data, message)
    -- table.insert(game_data.log, 1, message)
    print(message)
end

-- Handle card selection for player
-- Card Selection won't trigger turn phase change
function game.handlePlayCardSelection(game_data, cardIndex)
    if cardIndex < 1 or cardIndex > #game_data.player.hand then
        game.addLog(game_data, "Invalid card index: " .. cardIndex)
        return
    end

    local card = game_data.player.hand[cardIndex]

    -- Check if card is already selected
    for i, selectedCard in ipairs(game_data.turn.selectedCards) do
        if selectedCard == card then
            -- Deselect card
            table.remove(game_data.turn.selectedCards, i)
            game.addLog(game_data, "Deselected card: " .. card.suit .. card.rank)
            return
        end
    end

    -- Check if we can add this card to selection
    local testSelection = {}
    for i, selectedCard in ipairs(game_data.turn.selectedCards) do
        table.insert(testSelection, selectedCard)
    end
    table.insert(testSelection, card)

    if rules.validatePlayCards(game_data, testSelection) then
        -- A can be played with another card
        table.insert(game_data.turn.selectedCards, card)
        game.addLog(game_data, "Selected card: " .. card.suit .. card.rank)
        return
    end

    game.addLog(game_data, "Invalid card combination")
end

-- Confirm card selection
function game.confirmPlayCardSelection(game_data)
    if #game_data.turn.selectedCards == 0 then
        game.addLog(game_data, "No cards selected")
        return
    end

    -- Move selected cards to played cards
    for _, card in ipairs(game_data.turn.selectedCards) do
        table.insert(game_data.turn.playCards, card)
        -- Remove from hand
        for j = #game_data.player.hand, 1, -1 do
            if game_data.player.hand[j] == card then
                table.remove(game_data.player.hand, j)
                break
            end
        end
    end

    game.addLog(game_data, "Playing " .. #game_data.turn.selectedCards .. " cards")
    game_data.turn.selectedCards = {}
end

-- Handle card selection for player_damage phase
-- Card Selection won't trigger turn phase change
function game.handleDiscardCardSelection(game_data, cardIndex)
    if cardIndex < 1 or cardIndex > #game_data.player.hand then
        game.addLog(game_data, "Invalid card index: " .. cardIndex)
        return
    end

    local card = game_data.player.hand[cardIndex]

    -- Check if card is already selected for damage
    for i, selectedCard in ipairs(game_data.turn.discardCards) do
        if selectedCard == card then
            -- Deselect card
            table.remove(game_data.turn.discardCards, i)
            game.addLog(game_data, "Deselected card for discard: " .. card.suit .. card.rank)
            return
        end
    end

    -- Select card for damage
    table.insert(game_data.turn.discardCards, card)
    game.addLog(game_data, "Selected card for discard: " .. card.suit .. card.rank)
end

-- Confirm damage selection
function game.confirmDiscardSelection(game_data)
    local totalDiscardValue = 0
    local bossDamage = game_data.turn.bossDamage

    for _, card in ipairs(game_data.turn.discardCards) do
        totalDiscardValue = totalDiscardValue + card.attack
    end

    local isPlayerDefeated = totalDiscardValue < bossDamage
    if not isPlayerDefeated then
        -- Discard selected cards
        for _, card in ipairs(game_data.turn.discardCards) do
            for j = #game_data.player.hand, 1, -1 do
                if game_data.player.hand[j] == card then
                    table.insert(game_data.player.discard, game_data.player.hand[j])
                    table.remove(game_data.player.hand, j)
                    break
                end
            end
        end

        game.addLog(game_data,
            "Player discarded " .. totalDiscardValue .. " damage to block " .. bossDamage .. " damage")
        game_data.turn.discardCards = {}
    end

    return isPlayerDefeated
end

return game
