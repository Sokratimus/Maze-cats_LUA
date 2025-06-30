-- Установка путей к модулям
package.path = package.path .. ";./?.lua;../?.lua;D:/unic6/demo/Maze&cats_LUA/?.lua"

-- Зависимости
local socket = require("socket")
local json = require("dkjson")
local common = require("game_common")
local logger = require("logger")

-- Логгер
logger.init("D:/unic6/demo/Maze&cats_LUA/server_log.txt")
logger.log("🚀 Сервер запускается...")

-- Серверный объект
local server = {
    listener = nil,
    connections = {},
    clientToPlayerId = {},
    players = {},
    grid = {},
    tunnelStats = {},
    tunnelIdCounter = 1,
    currentPlayerIndex = 1,
    drawnCard = nil,
    GRID_SIZE = 25
}
--Ініціалізація сервера
function server.start()
    server.listener = socket.bind("*", 22122)
    server.listener:settimeout(0)
     logger.log("🚀 Сервер запущено")
    for y = 1, server.GRID_SIZE do
        server.grid[y] = {}
        for x = 1, server.GRID_SIZE do
            server.grid[y][x] = {
                type = "void",
                rotation = 0,
                occupied = false
            }
        end
    end

    server.drawnCard = server.drawRandomCard()
end

--Синхронізація стану гри
function server.serializeState()
    local gridCopy = deepCopyGrid(server.grid)
    local playersCopy = {}
    for i, p in ipairs(server.players) do
        local handCopy = {}
        for _, c in ipairs(p.hand or {}) do
            table.insert(handCopy, {
                type = c.type,
                rotation = c.rotation,
                x = c.x or 0,
                y = c.y or 0,
                hover = c.hover or false
            })
        end

        playersCopy[i] = {
            x = p.x, y = p.y,
            hand = handCopy,
            color = p.color,
            turnStage = p.turnStage,
            placedCard = p.placedCard
        }
    end

    return json.encode({
        grid = gridCopy,
        players = playersCopy,
        currentPlayerIndex = server.currentPlayerIndex,
    })
end

function server.broadcastGameState()
    local json = require("dkjson")

    for i, c in ipairs(server.connections) do
        local baseState = server.serializeState()
        local parsed = json.decode(baseState)

        -- Добавляем drawnCard только активному игроку
        if i == server.currentPlayerIndex and server.drawnCard then
            parsed.drawnCard = server.drawnCard
        end

        local personalized = json.encode(parsed)
        c:send("SYNC:" .. personalized .. "\n")
    end
end

function broadcastExcept(excludeClient, message)
    for _, c in ipairs(server.connections) do
        if c ~= excludeClient then c:send(message) end
    end
end

--Оновлення стану сервера (підключення та повідомлення)
function server.update()
    logger.log("[SERVER] update()")
    local conn = server.listener:accept()
    if conn then
        logger.log("[SERVER] Нове з'єднання")
        conn:settimeout(0)
        table.insert(server.connections, conn)
        local id = #server.players + 1
        server.addNewPlayer()
        logger.log("Нове з'єднання. Всього гравців: " .. #server.players)
        server.clientToPlayerId[conn] = id
        conn:send("YOURID:" .. id .. "\n")
        logger.log("YOURID: " .. id)
        local state = server.serializeState()
        conn:send("SYNC:" .. state .. "\n")
        server.broadcastGameState()
        logger.log("SYNC отправлено клієнту " .. id)
    end

    for _, c in ipairs(server.connections) do
        local line = c:receive()
        if line then
            logger.log("[SERVER] Від клієнта: " .. tostring(line))
            server.handleMessage(line, c)
        end
    end
end

--Додавання нового гравця
function server.addNewPlayer()

    if #server.players >= 4 then return end
    local n = #server.players
    local spawnX, spawnY, rotation
        if n == 0 then
            spawnX, spawnY, rotation = 13, 25, 270
        elseif n == 1 then
            spawnX, spawnY, rotation = 13, 1, 90
        elseif n == 2 then
            spawnX, spawnY, rotation = 25, 13, 180
        elseif n == 3 then
            spawnX, spawnY, rotation = 1, 13, 0
        end

    if not server.grid or not server.grid[spawnY] then
        logger.log("❌ Сітка не ініціалізована або spawnY недійсний: " .. tostring(spawnY))
        return
    end
        
    local id = server.tunnelIdCounter
    server.tunnelIdCounter = server.tunnelIdCounter + 1

    server.grid[spawnY][spawnX] = {
        type = "deadend", rotation = rotation,
        tunnelId = id, occupied = false
    }

    local openSides = common.getOpenSides({type = "deadend", rotation = rotation})
    local exitScore = 0
    for _, _ in pairs(openSides) do
        exitScore = exitScore + 1
    end
        logger.log("Стартовий тунель " .. id .. " має вихід(и): " .. exitScore)
    server.tunnelStats[id] = {
        tileCount = 1,
        exitScore = exitScore
        
    }

    local hand = {}
    for i = 1, 6 do
        table.insert(hand, {
            type = common.randomCardType(),
            rotation = 0, x = 0, y = 0, hover = false
        })
    end

    local colors = {{1, 0, 0}, {0, 0, 1}, {0, 1, 0}, {1, 0, 1}}
    table.insert(server.players, {
        x = spawnX, y = spawnY,
        hand = hand,
        color = colors[n + 1],
        turnStage = "place",
        placedCard = false
    })
end

--Обробка повідомлень
function server.handleMessage(msg, client)
    local cmd, data = msg:match("^(%w+):(.*)$")
    local pid = server.clientToPlayerId[client]
    if not pid then return end
    local player = server.players[pid]

 if cmd == "PLACE" then
    -- 🌐 Разбор аргументов
    local parts = {}
    for part in data:gmatch("[^,]+") do
        table.insert(parts, part)
    end

    local x = tonumber(parts[1])
    local y = tonumber(parts[2])
    local tileType = parts[3]
    local rot = tonumber(parts[4])
    local source = parts[5]

    logger.log("📩 PLACE запит: type=" .. tostring(tileType) .. ", source=" .. tostring(source))
    if server.drawnCard then
        logger.log("📦 drawnCard = " .. server.drawnCard.type)
    else
        logger.log("📦 drawnCard = nil")
    end

    -- 🔒 Проверка фазы и флага
    if player.turnStage ~= "place" then
        logger.log("❌ Гравець не в фазі place")
        client:send("RESULT:ERR\n")
        return
    end

    if player.placedCard then
        logger.log("❌ Гравець вже розмістив карту в цьому ході")
        client:send("RESULT:ERR\n")
        return
    end

    if not common.isPlacementValid(server.grid, server.tunnelStats, x, y, tileType, rot) then
        logger.log("❌ Розміщення недійсне: " .. x .. "," .. y .. " тип=" .. tileType .. " rot=" .. rot)
        client:send("RESULT:ERR\n")
        return
    end

    -- ✅ Розміщення карти
    logger.log("✅ Гравець " .. pid .. " ставить " .. tileType .. " на (" .. x .. "," .. y .. ")")
    server.applyPlacement(pid, x, y, tileType, rot)

    local removedFromHand = false
    if source == "D" and server.drawnCard and server.drawnCard.type == tileType then
        logger.log("🧺 Використано drawnCard: " .. tileType)
        server.drawnCard = nil
        removedFromHand = true
    else
        local idx = tonumber(source)
        if idx and player.hand[idx] and player.hand[idx].type == tileType then
            table.remove(player.hand, idx)
            logger.log("🧺 Видалено карту з руки: " .. tileType .. " (позиція " .. idx .. ")")
            removedFromHand = true
        end
    end

    player.placedCard = true

    client:send("RESULT:OK\n")
    server.broadcastGameState()

    elseif cmd == "MOVE" then
        if player.turnStage ~= "move" then
            logger.log("❌ Гравець " .. pid .. " намагається рухатися не у фазі move")
            client:send("RESULT:ERR\n")
            return
        end

        local x, y = data:match("^(%d+),(%d+)$")
        x, y = tonumber(x), tonumber(y)

        if not x or not y then
            logger.log("❌ Невірні координати у MOVE")
            client:send("RESULT:ERR\n")
            return
        end

        if not common.canMove(server.grid, player.x, player.y, x, y) then
            logger.log("❌ Переміщення недійсне: " .. player.x .. "," .. player.y .. " → " .. x .. "," .. y)
            client:send("RESULT:ERR\n")
            return
        end

        logger.log("🚶 Гравець " .. pid .. " перемістився на " .. x .. "," .. y)
        player.x = x
        player.y = y
        player.turnStage = "done"

        client:send("RESULT:OK\n")
        server.broadcastGameState()

    elseif cmd == "ENDTURN" then
        logger.log("Гравець " .. pid .. " натиснув 'Кінець ходу' (стадія: " .. tostring(player.turnStage) .. ")")
        if player.turnStage == "place" then
            player.turnStage = "move"
            logger.log("🔄 Переходимо до фази переміщення")
            server.broadcastGameState()

        elseif player.turnStage == "move" or player.turnStage == "done" then
            logger.log("✅ Гравець " .. pid .. " завершив хід")

            -- Переходим до наступного гравця (в том числе самого себя)
            server.currentPlayerIndex = server.currentPlayerIndex % #server.players + 1

            local next = server.players[server.currentPlayerIndex]
            if not next then
                logger.log("❌ Наступного гравця не існує! Поточний індекс: " .. tostring(server.currentPlayerIndex))
                return
            end

            next.turnStage = "place"
            next.placedCard = false
            server.drawnCard = server.drawRandomCard()

            logger.log("🎯 Хід переходить до гравця " .. tostring(server.currentPlayerIndex))
            server.broadcastGameState()
        end  

    elseif cmd == "TAKECARD" then
        if player.turnStage ~= "place" then
            logger.log("❌ Не можна взяти карту не у фазі 'place'")
            client:send("RESULT:ERR\n")
            return
         end

         if not server.drawnCard then
            logger.log("❌ Немає витягнутої карти")
            client:send("RESULT:ERR\n")
            return
        end

        local target = data:match("^(%w+)$")
        if target == "X" then
            logger.log("🗑️ Гравець відмовився від карти")
            server.drawnCard = nil
        elseif tonumber(target) and tonumber(target) >= 1 and tonumber(target) <= 6 then
            local i = tonumber(target)
            if #player.hand < 6 then
                table.insert(player.hand, i, server.drawnCard)
                logger.log("📥 Гравець поклав карту у руку в слот " .. i)
                server.drawnCard = nil
            else
                logger.log("❌ Рука повна")
                client:send("RESULT:ERR\n")
                return
            end
        end
        server.broadcastGameState()
    elseif cmd == "EXIT" then
            logger.log("🛑 Отримано EXIT — зупинка сервера")
            os.exit()
            elseif cmd == "START" then
        logger.log("🎮 Хост розпочинає гру")

        server.currentPlayerIndex = 1

        for i, p in ipairs(server.players) do
            p.turnStage = "wait"
            p.placedCard = false
        end

        server.players[1].turnStage = "place"
        server.drawnCard = server.drawRandomCard()

        for _, c in ipairs(server.connections) do
            c:send("START:\n")
        end

        server.broadcastGameState()
    end
end

-- Розміщення плитки
function server.applyPlacement(pid, x, y, tileType, rotation)
    local player = server.players[pid]
    local grid = server.grid

    grid[y][x].type = tileType
    grid[y][x].rotation = rotation
    player.placedCard = true

    local neighbors = {}
    for _, dir in ipairs({{0, -1}, {0, 1}, {-1, 0}, {1, 0}}) do
        local nx, ny = x + dir[1], y + dir[2]
        if nx >= 1 and nx <= server.GRID_SIZE and ny >= 1 and ny <= server.GRID_SIZE then
            local cell = grid[ny][nx]
            if cell.tunnelId then table.insert(neighbors, cell.tunnelId) end
        end
    end

    local id = server.tunnelIdCounter
    if #neighbors == 0 then
        server.tunnelStats[id] = {tileCount = 0, exitScore = 0}
        server.tunnelIdCounter = server.tunnelIdCounter + 1
    else
        id = neighbors[1]
        local toMerge = {}
        for _, tid in ipairs(neighbors) do if tid ~= id then toMerge[tid] = true end end
        if next(toMerge) then
            common.mergeTunnels(server.grid, server.tunnelStats, id, toMerge)
        end
    end

    grid[y][x].tunnelId = id
    server.tunnelStats[id].tileCount = server.tunnelStats[id].tileCount + 1
    server.tunnelStats[id].exitScore = server.tunnelStats[id].exitScore + common.getExitDelta(tileType)
end

--Випадкова карта
function server.drawRandomCard()
    local types = { "straight", "cross", "t", "corner", "deadend", "empty" }
    return {
        type = types[math.random(#types)],
        rotation = 0,
        x = 0, y = 0, hover = false
    }
end

--Копіювання сітки
function deepCopyGrid(grid)
    local copy = {}
    for y = 1, #grid do
        copy[y] = {}
        for x = 1, #grid[y] do
            local c = grid[y][x]
            copy[y][x] = {
                type = c.type,
                rotation = c.rotation,
                tunnelId = c.tunnelId,
                occupied = c.occupied
            }
        end
    end
    return copy
end

server.start()

logger.log("Сервер повністю запущено і працює.")
while true do
    local success, err = pcall(server.update)
    if not success then
        logger.log("Помилка у server.update: " .. tostring(err))
    end
    socket.sleep(0.05) -- позволяет CPU отдохнуть
end