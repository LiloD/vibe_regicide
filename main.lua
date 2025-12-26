local game_state = require("game_state")
local rules = require("rules")

local gameState
local fonts = {}
local showLog = true

local COLORS = {
    bg = {0.12, 0.13, 0.16},
    panel = {0.18, 0.19, 0.22},
    panelLight = {0.22, 0.23, 0.26},
    border = {0.35, 0.36, 0.4},
    text = {0.9, 0.91, 0.93},
    textDim = {0.5, 0.52, 0.55},
    accent = {0.4, 0.55, 0.9},
    accentHover = {0.5, 0.65, 1},
    danger = {0.85, 0.3, 0.35},
    dangerHover = {0.95, 0.4, 0.45},
    success = {0.25, 0.75, 0.5},
    spades = {0.4, 0.55, 0.95},
    hearts = {1, 0.35, 0.45},
    clubs = {0.25, 0.85, 0.55},
    diamonds = {0.2, 0.7, 1},
    selected = {0.95, 0.8, 0.3},
    discard = {0.95, 0.55, 0.25}
}

function love.load()
    love.window.setMode(900, 700)
    
    fonts = {
        title = love.graphics.newFont(24),
        subtitle = love.graphics.newFont(18),
        cardRank = love.graphics.newFont(14),
        cardSuit = love.graphics.newFont(20),
        cardRankBoss = love.graphics.newFont(22),
        cardSuitBoss = love.graphics.newFont(36),
        body = love.graphics.newFont(13),
        small = love.graphics.newFont(11)
    }
    
    math.randomseed(os.time())
    gameState = game_state.init()
    game_state.change_phase(gameState, rules.TURN_PHASE.PLAYER)
end

function love.keypressed(key)
    if key == "l" then
        showLog = not showLog
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local windowWidth = 900
    local windowHeight = 700
    local battleWidth = showLog and windowWidth * 0.55 or windowWidth * 0.85
    local margin = 20
    
    local battleAreaX = showLog and margin or (windowWidth - battleWidth) / 2
    local battleAreaY = margin
    local battleAreaWidth = battleWidth - margin * 2
    local battleAreaHeight = windowHeight - margin * 2 - 70
    
    local bossAreaHeight = battleAreaHeight * 0.38
    local playerAreaY = battleAreaY + bossAreaHeight
    
    local cardsPerRow = showLog and 4 or 8
    local cardHeight = 95
    local cardWidth = math.floor(cardHeight * 0.714)
    local cardSpacing = 12
    local cardRowSpacing = 15
    
    local playerRowWidth = cardsPerRow * cardWidth + (cardsPerRow - 1) * cardSpacing
    local playerStartX = battleAreaX + (battleAreaWidth - playerRowWidth) / 2
    local playerStartY = playerAreaY + 45
    
    if y >= playerStartY + 25 then
        for i, card in ipairs(gameState.player.hand) do
            local row = math.floor((i - 1) / cardsPerRow)
            local col = (i - 1) % cardsPerRow
            local cardX = playerStartX + col * (cardWidth + cardSpacing)
            local cardY = playerStartY + 25 + row * (cardHeight + cardRowSpacing)
            
            if x >= cardX and x <= cardX + cardWidth and y >= cardY and y <= cardY + cardHeight then
                if gameState.turn.phase == rules.TURN_PHASE.PLAYER then
                    game_state.handlePlayCardSelection(gameState, i)
                elseif gameState.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
                    game_state.handleDiscardCardSelection(gameState, i)
                end
                return
            end
        end
    end
    
    local buttonY = windowHeight - 60
    if y >= buttonY - 5 and y <= buttonY + 45 then
        local restartX = battleAreaX + 25
        if x >= restartX and x <= restartX + 110 then
            gameState = game_state.init()
            game_state.change_phase(gameState, rules.TURN_PHASE.PLAYER)
            return
        end
        
        local confirmX = battleAreaX + battleAreaWidth - 145
        if x >= confirmX and x <= confirmX + 130 then
            local canConfirm = false
            if gameState.turn.phase == rules.TURN_PHASE.PLAYER then
                canConfirm = #gameState.turn.selectedCards > 0
            elseif gameState.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
                canConfirm = #gameState.turn.discardCards > 0
            end
            
            if canConfirm then
                if gameState.turn.phase == rules.TURN_PHASE.PLAYER then
                    game_state.confirmPlayCardSelection(gameState)
                elseif gameState.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
                    local isDefeated = game_state.confirmDiscardSelection(gameState)
                    if isDefeated then
                        game_state.addLog(gameState, "GAME OVER! Player is defeated")
                        gameState.turn.message = "GAME OVER - Press R to restart"
                    else
                        game_state.change_phase(gameState, rules.TURN_PHASE.PLAYER)
                    end
                end
            end
            return
        end
    end
end

function drawRoundedRect(x, y, w, h, radius, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)
end

function drawOutline(x, y, w, h, radius, r, g, b, a, lineWidth)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(lineWidth or 1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
end

function drawCard(x, y, card, isSelected, isBoss, phase, selectedCards, discardCards, health, damage)
    local cardHeight = isBoss and 160 or 95
    local cardWidth = math.floor(cardHeight * 0.714)
    local radius = 10
    
    local suitColor
    if card.suit == "Spades" then
        suitColor = COLORS.spades
    elseif card.suit == "Hearts" then
        suitColor = COLORS.hearts
    elseif card.suit == "Clubs" then
        suitColor = COLORS.clubs
    else
        suitColor = COLORS.diamonds
    end
    
    local isCardSelected = false
    local highlightColor = COLORS.selected
    
    for _, c in ipairs(selectedCards) do
        if c == card then isCardSelected = true break end
    end
    
    for _, c in ipairs(discardCards) do
        if c == card then isCardSelected = true highlightColor = COLORS.discard break end
    end
    
    if isCardSelected then
        drawRoundedRect(x - 3, y - 3, cardWidth + 6, cardHeight + 6, radius + 3, highlightColor[1], highlightColor[2], highlightColor[3], 0.4)
    end
    
    if isSelected and isCardSelected then
        drawRoundedRect(x, y, cardWidth, cardHeight, radius, suitColor[1], suitColor[2], suitColor[3], 0.35)
    else
        drawRoundedRect(x, y, cardWidth, cardHeight, radius, 0.28, 0.29, 0.32, 1)
    end
    
    drawOutline(x, y, cardWidth, cardHeight, radius, 0.4, 0.42, 0.45, 1, 1.5)
    
    if isBoss then
        love.graphics.setFont(fonts.cardRankBoss)
    else
        love.graphics.setFont(fonts.cardRank)
    end
    love.graphics.setColor(0.85, 0.86, 0.9)
    love.graphics.print(card.rank, x + 12, y + 10)
    
    if isBoss then
        love.graphics.setFont(fonts.cardSuitBoss)
    else
        love.graphics.setFont(fonts.cardSuit)
    end
    love.graphics.setColor(suitColor[1], suitColor[2], suitColor[3])
    local symbolX = x + cardWidth / 2 - (isBoss and 16 or 10)
    local symbolY = y + cardHeight / 2 - (isBoss and 22 or 14)
    love.graphics.print(card.suit:sub(1,1), symbolX, symbolY)
    
    if isBoss then
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(COLORS.danger)
        love.graphics.print("HP " .. health, x + 12, y + cardHeight - 22)
        love.graphics.setColor(COLORS.accent)
        love.graphics.print("ATK " .. damage, x + cardWidth - 55, y + cardHeight - 22)
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.body)
end

function drawButton(x, y, w, h, text, isEnabled, isHovered, bgColor, hoverColor)
    local bg = isEnabled and (isHovered and hoverColor or bgColor) or {0.25, 0.26, 0.29}
    drawRoundedRect(x, y, w, h, 8, bg[1], bg[2], bg[3], 1)
    
    local borderColor = isEnabled and (isHovered and {0.6, 0.62, 0.7} or {0.45, 0.47, 0.52}) or {0.35, 0.36, 0.4}
    drawOutline(x, y, w, h, 8, borderColor[1], borderColor[2], borderColor[3], 1, 1.5)
    
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(isEnabled and COLORS.text or COLORS.textDim)
    local textW = love.graphics.getFont():getWidth(text)
    love.graphics.print(text, x + (w - textW) / 2, y + (h - love.graphics.getFont():getHeight()) / 2 + 1)
end

function love.draw()
    local windowWidth = 900
    local windowHeight = 700
    
    drawRoundedRect(0, 0, windowWidth, windowHeight, 0, COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    
    local battleWidth = showLog and windowWidth * 0.55 or windowWidth * 0.85
    local margin = 20
    
    local battleX = showLog and margin or (windowWidth - battleWidth) / 2
    local battleY = margin
    local battleW = battleWidth - margin * 2
    local battleH = windowHeight - margin * 2 - 70
    
    drawRoundedRect(battleX, battleY, battleW, battleH, 12, COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 1)
    drawOutline(battleX, battleY, battleW, battleH, 12, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1, 1)
    
    local bossAreaHeight = battleH * 0.38
    local playerAreaY = battleY + bossAreaHeight
    
    local topInfoY = battleY + 18
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(COLORS.textDim)
    local turnText = gameState.turn.message
    local textW = love.graphics.getFont():getWidth(turnText)
    love.graphics.print(turnText, battleX + (battleW - textW) / 2, topInfoY)
    
    local bossX = battleX + 30
    local bossY = battleY + 45
    
    drawRoundedRect(bossX, bossY, battleW - 60, bossAreaHeight - 20, 10, COLORS.panelLight[1], COLORS.panelLight[2], COLORS.panelLight[3], 1)
    
    if gameState.boss.current then
        local bossCardWidth = 114
        local bossCardX = bossX + (battleW - 60 - bossCardWidth) / 2
        local bossCardY = bossY + (bossAreaHeight - 20 - 160) / 2
        drawCard(bossCardX, bossCardY, gameState.boss.current, false, true, gameState.turn.phase, gameState.turn.selectedCards, gameState.turn.discardCards, gameState.boss.health, gameState.turn.bossDamage)
    else
        love.graphics.setFont(fonts.subtitle)
        love.graphics.setColor(COLORS.success)
        local textW = love.graphics.getFont():getWidth("VICTORY!")
        love.graphics.print("VICTORY!", battleX + (battleW - textW) / 2, bossY + bossAreaHeight / 2 - 20)
    end
    
    local cardsPerRow = showLog and 4 or 8
    local cardHeight = 95
    local cardWidth = math.floor(cardHeight * 0.714)
    local cardSpacing = 12
    local cardRowSpacing = 15
    
    local playerRowWidth = cardsPerRow * cardWidth + (cardsPerRow - 1) * cardSpacing
    local playerX = battleX + (battleW - playerRowWidth) / 2
    local playerY = playerAreaY + 40
    
    for i, card in ipairs(gameState.player.hand) do
        local row = math.floor((i - 1) / cardsPerRow)
        local col = (i - 1) % cardsPerRow
        local cardX = playerX + col * (cardWidth + cardSpacing)
        local cardY = playerY + 25 + row * (cardHeight + cardRowSpacing)
        
        local isSelected = false
        for _, c in ipairs(gameState.turn.selectedCards) do
            if c == card then isSelected = true break end
        end
        for _, c in ipairs(gameState.turn.discardCards) do
            if c == card then isSelected = true break end
        end
        
        drawCard(cardX, cardY, card, isSelected, false, gameState.turn.phase, gameState.turn.selectedCards, gameState.turn.discardCards)
    end
    
    if showLog then
        local logX = battleWidth + 25
        local logY = margin
        local logW = windowWidth - logX - margin - 15
        local logH = battleH
        
        drawRoundedRect(logX, logY, logW, logH, 12, COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 1)
        drawOutline(logX, logY, logW, logH, 12, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1, 1)
        
        love.graphics.setFont(fonts.subtitle)
        love.graphics.setColor(COLORS.text)
        love.graphics.print("Activity Log", logX + 15, logY + 15)
        
        love.graphics.setLineWidth(1)
        love.graphics.setColor(COLORS.border[1], COLORS.border[2], COLORS.border[3])
        love.graphics.line(logX + 15, logY + 45, logX + logW - 15, logY + 45)
        
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(COLORS.textDim)
        for i, entry in ipairs(gameState.log) do
            if i <= 28 then
                local truncated = entry
                if #entry > 45 then
                    truncated = entry:sub(1, 42) .. "..."
                end
                love.graphics.print(truncated, logX + 15, logY + 55 + (i - 1) * 18)
            end
        end
    end
    
    local buttonY = windowHeight - 60
    
    local canConfirm = false
    if gameState.turn.phase == rules.TURN_PHASE.PLAYER then
        canConfirm = #gameState.turn.selectedCards > 0
    elseif gameState.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE then
        canConfirm = #gameState.turn.discardCards > 0
    end
    
    drawButton(battleX + 25, buttonY, 110, 42, "Restart", true, false, COLORS.danger, COLORS.dangerHover)
    drawButton(battleX + battleW - 145, buttonY, 130, 42, "Confirm", canConfirm, false, COLORS.success, {0.35, 0.85, 0.6})
    
    if gameState.turn.phase == rules.TURN_PHASE.PLAYER and #gameState.turn.selectedCards > 0 then
        local total = 0
        for _, c in ipairs(gameState.turn.selectedCards) do total = total + c.attack end
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(COLORS.selected)
        love.graphics.print(#gameState.turn.selectedCards .. " cards, " .. total .. " damage", battleX + 145, buttonY + 14)
    elseif gameState.turn.phase == rules.TURN_PHASE.BOSS_DAMAGE and #gameState.turn.discardCards > 0 then
        local total = 0
        for _, c in ipairs(gameState.turn.discardCards) do total = total + c.attack end
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(COLORS.discard)
        love.graphics.print(total .. " / " .. gameState.turn.bossDamage .. " (need " .. gameState.turn.bossDamage .. ")", battleX + 145, buttonY + 14)
    end
end
