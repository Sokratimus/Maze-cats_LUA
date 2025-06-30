local client = require("client")
local drawUI = require("draw")
local logger = require("logger")
local baseDir = love.filesystem.getSourceBaseDirectory()
local luaExe = baseDir .. "\\Maze&cats_LUA\\Lua\\lua.exe"
local script = baseDir .. "\\Maze&cats_LUA\\server_main.lua"

menuState = "menu"
local isServer = false
local font
client.isHost = false

function love.load()
    love.window.setMode(1920, 1080, {resizable = false})
    love.graphics.setBackgroundColor(0.7, 0.7, 0.7)

    font = love.graphics.newFont("assets/fonts/Roboto.ttf", 20)
    love.graphics.setFont(font)

    drawUI.load()
end

function love.update(dt)
    if isServer and menuState == "connected" then
        server.update()
    elseif not isServer and client.connected then
    client.update()
    -- Перевірка, що ID вже отримано
    if not client.playerId then
        logger.log("Очікуємо ID від сервера...")
        return 
    end
end

    if client.playerId then
        drawUI.update(dt)
    end
end

function love.draw()
    if menuState == "menu" then
        drawMenu()
    elseif menuState == "lobby" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("⏳ Очікуємо гравців...", 100, 100)

        local state = client.getState()
        if state.players then
            for i, p in ipairs(state.players) do
                love.graphics.print("Гравець " .. i, 120, 130 + i * 20)
            end
        end

        if client.isHost then
            local mouseX, mouseY = love.mouse.getPosition()
            local btnX, btnY, btnW, btnH = 100, 300, 200, 50
            local hover = mouseX >= btnX and mouseX <= btnX + btnW and mouseY >= btnY and mouseY <= btnY + btnH

            -- Хитбокс кнопки
            love.graphics.setColor(hover and {0.1, 0.8, 0.1} or {0.2, 0.6, 0.2})
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)

            -- 🔳 Рамка хитбокса
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH)

            -- Текст
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("Почати гру", btnX, btnY + 15, btnW, "center")
        end
    else
        if client.playerId then
            drawUI.draw()
        end
    end
end
function drawMenu()
    love.graphics.setColor(0.3, 0.6, 0.3)
    love.graphics.rectangle("fill", 100, 200, 300, 60)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Створити гру (Сервер)", 100, 215, 300, "center")

    love.graphics.setColor(0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", 100, 300, 300, 60)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Приєднатися до гри (Клієнт)", 100, 315, 300, "center")
end

function love.mousepressed(mx, my, button)
    if menuState == "menu" then
        if mx >= 100 and mx <= 400 and my >= 200 and my <= 260 then
            logger.log("🖥️ Запускаємо сервер в окремому процесі...")
            os.execute('start "" /min "' .. luaExe .. '" "' .. script .. '"')
            love.timer.sleep(1)
            client.connect("127.0.0.1", 22122)
            client.isHost = true
            menuState = "lobby"

        elseif mx >= 100 and mx <= 400 and my >= 300 and my <= 360 then
            isServer = false
            client.connect("127.0.0.1", 22122)
            menuState = "lobby"
        end

    elseif menuState == "lobby" and button == 1 then
        local btnX, btnY, btnW, btnH = 100, 300, 200, 50
        if mx >= btnX and mx <= btnX + btnW and my >= my and my <= btnY + btnH then
            logger.log(" Кнопка 'Почати гру' натиснута")
            client.send("START:")
        end
        return

    else
        drawUI.mousepressed(mx, my, button)
    end
end

function love.quit()
    if client.isHost then
        client.send("EXIT:")
    end
end