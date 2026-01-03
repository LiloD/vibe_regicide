local game = require("game")

local test_game = {}

function test_game.clear_screen()
    -- 根据操作系统选择清屏命令
    if package.config:sub(1, 1) == "\\" then
        -- Windows系统
        os.execute("cls")
    else
        -- Linux/Unix系统
        os.execute("clear")
    end
end

function test_game.run()
    test_game.clear_screen()
    print("=== Vibe Regicide Game CLI 测试程序 ===")
    print("初始化游戏中...")

    game.init()

    print("游戏初始化完成！")
    print("当前状态: " .. (game.current_state and game.current_state.name or "未知"))

    -- 游戏开始时的操作说明
    print("\n操作说明:")
    print("  数字 1-8: 选择/取消选择卡牌")
    print("  enter: 确认当前选择")
    print("  status: 查看游戏状态")
    print("  help: 显示操作说明")

    local running = true

    while running do
        -- 清屏并显示当前回合信息
        test_game.clear_screen()

        -- 使用游戏内部的当前状态名称
        local current_state_name = game.current_state and game.current_state.name or "未知"

        print("=== 当前游戏状态: " .. current_state_name .. " ===")

        -- 显示BOSS信息
        if game.game_data.boss.current then
            local bossCard = game.game_data.boss.current
            print("当前BOSS: " .. bossCard.suit .. " " .. bossCard.rank)
            print("BOSS生命值: " .. game.game_data.boss.health)
            print("BOSS攻击力: " .. game.game_data.turn.bossDamage)
        else
            print("当前BOSS: 无")
            print("BOSS生命值: 0")
            print("BOSS攻击力: 0")
        end

        -- 根据当前状态显示不同的操作界面
        if current_state_name == "player" then
            test_game.interactive_player_turn()
        elseif current_state_name == "effects" then
            -- 效果结算由游戏内部自动执行，这里只需要显示结果
            print("\n--- 效果结算阶段 ---")
            print("效果结算已完成")

            -- 检查BOSS是否被击败
            if game.game_data.boss.health <= 0 then
                print("\n=== 游戏胜利！BOSS被击败！ ===")
                running = false
            else
                print("\n进入BOSS回合，当前BOSS状态:")
                print("  BOSS生命值: " .. game.game_data.boss.health)
                print("  BOSS攻击力: " .. game.game_data.turn.bossDamage)
            end
        elseif current_state_name == "boss" then
            local game_ended = test_game.interactive_boss_turn()

            if game_ended then
                print("\n=== 游戏结束！玩家被击败！ ===")
                running = false
            end
        else
            print("游戏结束或未知状态")
            running = false
        end

        -- 检查游戏是否结束（玩家无牌可用）
        if #game.game_data.player.hand == 0 and #game.game_data.player.discard == 0 then
            print("\n=== 游戏结束！玩家无牌可用！ ===")
            running = false
        end
    end

    print("\n=== 最终游戏状态 ===")
    test_game.show_game_status()
end

function test_game.interactive_player_turn()
    -- 清屏并显示玩家回合信息
    test_game.clear_screen()

    print("=== 玩家回合 ===")

    -- 显示BOSS信息
    if game.game_data.boss.current then
        local bossCard = game.game_data.boss.current
        print("当前BOSS: " .. bossCard.suit .. " " .. bossCard.rank)
        print("BOSS生命值: " .. game.game_data.boss.health)
        print("BOSS攻击力: " .. game.game_data.turn.bossDamage)
    else
        print("当前BOSS: 无")
    end

    print("\n当前玩家手牌:")
    for i, card in ipairs(game.game_data.player.hand) do
        local effectInfo = test_game.getCardEffectInfo(card)
        print(string.format("  %d. %s%s (攻击力: %d) - %s", i, card.suit, card.rank, card.attack, effectInfo))
    end

    print("\n请选择卡牌对BOSS造成伤害")
    print("输入数字 1-8 选择/取消选择卡牌，输入 'enter' 确认选择")
    print("输入 'hand' 查看当前手牌，输入 'boss' 查看BOSS状态")


    while true do
        io.write("\n选择操作: ")
        local input = io.read():gsub("^%s*(.-)%s*$", "%1")

        if input == "help" then
            print("\n玩家回合操作说明:")
            print("  数字 1-8: 选择/取消选择对应卡牌")
            print("  enter: 确认卡牌选择")
            print("  hand: 查看当前手牌")
            print("  boss: 查看BOSS状态")
            print("  status: 查看游戏状态")
            print("  help: 显示此帮助")
        elseif input == "status" then
            test_game.show_game_status()
        elseif input == "hand" then
            print("\n当前玩家手牌:")
            for i, card in ipairs(game.game_data.player.hand) do
                local effectInfo = test_game.getCardEffectInfo(card)
                print(string.format("  %d. %s%s (攻击力: %d) - %s", i, card.suit, card.rank, card.attack, effectInfo))
            end
        elseif input == "boss" then
            print("\n当前BOSS状态:")
            if game.game_data.boss.current then
                local bossCard = game.game_data.boss.current
                print("  BOSS: " .. bossCard.suit .. " " .. bossCard.rank)
                print("  生命值: " .. game.game_data.boss.health)
                print("  攻击力: " .. game.game_data.turn.bossDamage)
            else
                print("  当前BOSS: 无")
            end
        elseif input == "enter" or input == "" then
            -- 使用游戏内置的按键处理
            game.keypressed("return")
            break
        elseif tonumber(input) then
            local cardIndex = tonumber(input)
            if cardIndex >= 1 and cardIndex <= #game.game_data.player.hand then
                -- 使用游戏内置的按键处理
                game.keypressed(input)

                print("当前已选择的卡牌:")
                if #game.game_data.turn.selectedCards > 0 then
                    for i, card in ipairs(game.game_data.turn.selectedCards) do
                        local effectInfo = test_game.getCardEffectInfo(card)
                        print(string.format("  %d. %s%s - %s", i, card.suit, card.rank, effectInfo))
                    end
                else
                    print("  无")
                end
            else
                print("无效的卡牌索引")
            end
        else
            print("无效输入，输入 'help' 查看操作说明")
        end
    end
end

function test_game.interactive_boss_turn()
    -- 清屏并显示BOSS回合信息
    test_game.clear_screen()

    print("=== BOSS回合 ===")

    -- 显示BOSS信息
    if game.game_data.boss.current then
        local bossCard = game.game_data.boss.current
        print("当前BOSS: " .. bossCard.suit .. " " .. bossCard.rank)
        print("BOSS生命值: " .. game.game_data.boss.health)
        print("BOSS攻击力: " .. game.game_data.turn.bossDamage)
    else
        print("当前BOSS: 无")
    end

    print("\n当前玩家手牌:")
    for i, card in ipairs(game.game_data.player.hand) do
        local effectInfo = test_game.getCardEffectInfo(card)
        print(string.format("  %d. %s%s (防御值: %d) - %s", i, card.suit, card.rank, card.attack, effectInfo))
    end

    print("\nBOSS即将发动攻击，攻击力: " .. game.game_data.turn.bossDamage)
    print("请选择弃牌来抵挡BOSS攻击")
    print("输入数字 1-8 选择/取消选择弃牌，输入 'enter' 确认选择")
    print("输入 'hand' 查看当前手牌，输入 'boss' 查看BOSS状态")

    local game_ended = false

    while true do
        io.write("\n选择操作: ")
        local input = io.read():gsub("^%s*(.-)%s*$", "%1")

        if input == "help" then
            print("\nBOSS回合操作说明:")
            print("  数字 1-8: 选择/取消选择弃牌")
            print("  enter: 确认弃牌选择")
            print("  hand: 查看当前手牌")
            print("  boss: 查看BOSS状态")
            print("  status: 查看游戏状态")
            print("  help: 显示此帮助")
        elseif input == "status" then
            test_game.show_game_status()
        elseif input == "hand" then
            print("\n当前玩家手牌:")
            for i, card in ipairs(game.game_data.player.hand) do
                local effectInfo = test_game.getCardEffectInfo(card)
                print(string.format("  %d. %s%s (防御值: %d) - %s", i, card.suit, card.rank, card.attack, effectInfo))
            end
        elseif input == "boss" then
            print("\n当前BOSS状态:")
            if game.game_data.boss.current then
                local bossCard = game.game_data.boss.current
                print("  BOSS: " .. bossCard.suit .. " " .. bossCard.rank)
                print("  生命值: " .. game.game_data.boss.health)
                print("  攻击力: " .. game.game_data.turn.bossDamage)
            else
                print("  当前BOSS: 无")
            end
        elseif input == "enter" or input == "" then
            -- 使用游戏内置的按键处理
            game.keypressed("return")

            -- 检查玩家是否被击败
            if #game.game_data.player.hand == 0 and #game.game_data.player.discard == 0 then
                print("玩家被击败！游戏结束")
                game_ended = true
                break
            else
                print("成功抵挡BOSS攻击！")
                break
            end
        elseif tonumber(input) then
            local cardIndex = tonumber(input)
            if cardIndex >= 1 and cardIndex <= #game.game_data.player.hand then
                -- 使用游戏内置的按键处理
                game.keypressed(input)

                print("当前已选择的弃牌:")
                if #game.game_data.turn.discardCards > 0 then
                    local totalDefense = 0
                    for i, card in ipairs(game.game_data.turn.discardCards) do
                        totalDefense = totalDefense + card.attack
                        print(string.format("  %d. %s%s (防御值: %d)", i, card.suit, card.rank, card.attack))
                    end
                    print("总防御值: " .. totalDefense .. " / 需要: " .. game.game_data.turn.bossDamage)
                else
                    print("  无")
                end
            else
                print("无效的卡牌索引")
            end
        else
            print("无效输入，输入 'help' 查看操作说明")
        end
    end

    return game_ended
end

function test_game.getCardEffectInfo(card)
    local effectDescriptions = {
        Spades = "降低敌方攻击力",
        Hearts = "从弃牌堆回收卡牌",
        Clubs = "造成双倍伤害",
        Diamonds = "抽卡"
    }

    local effectInfo = effectDescriptions[card.suit] or "无特效"

    -- 检查是否被BOSS花色屏蔽
    if game.game_data.boss.current and card.suit == game.game_data.boss.current.suit then
        effectInfo = effectInfo .. " (被BOSS屏蔽)"
    end

    return effectInfo
end

function test_game.show_game_status()
    print("\n--- 游戏状态信息 ---")

    print("BOSS信息:")
    if game.game_data.boss.current then
        local bossCard = game.game_data.boss.current
        print("  当前BOSS: " .. bossCard.suit .. " " .. bossCard.rank)
        print("  生命值: " .. game.game_data.boss.health)
        print("  攻击力: " .. game.game_data.turn.bossDamage)
    else
        print("  当前BOSS: 无")
        print("  生命值: 0")
        print("  攻击力: 0")
    end

    print("\n玩家信息:")
    print("  手牌数量: " .. #game.game_data.player.hand)
    print("  弃牌堆数量: " .. #game.game_data.player.discard)

    print("\n回合信息:")
    print("  玩家伤害: " .. game.game_data.turn.playerDamage)
    print("  BOSS伤害: " .. game.game_data.turn.bossDamage)

    print("\n最近日志:")
    for i = 1, math.min(5, #game.game_data.log) do
        print("  " .. game.game_data.log[i])
    end
end

-- return test_game
test_game.run()
