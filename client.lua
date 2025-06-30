local socket = require("socket")
local json = require("dkjson")
local logger = require("logger")
_G.menuState = "connected"

local client = {
    socket = nil,
    connected = false,
    playerId = nil,
    gameState = {
        grid = {},
        players = {},
        currentPlayerIndex = 1,
        drawnCard = nil
    },
    debugMessages = {}
}


function client.connect(ip, port)
    client.socket = socket.tcp()
    client.socket:settimeout(5)
    local success, err = client.socket:connect(ip, port)

    if success or err == "already connected" then
        client.socket:settimeout(0)
        client.connected = true
        logger.log("✅ Клієнт підключився до " .. ip .. ":" .. port)

        -- 🧠 Одразу пробуємо прочитати перше повідомлення
        local line = client.socket:receive("*l")
        if line and line:match("^YOURID:%d+") then
            client.playerId = tonumber(line:match("^YOURID:(%d+)"))
            logger.log("🔥 Отримано ID (миттєво): " .. tostring(client.playerId))
            logger.init("client_log_" .. client.playerId .. ".txt")
        end
    end
end

function client.initializeGrid(playerId)
    logger.log("Ініціалізація сітки для гравця ID " .. tostring(playerId))
    local GRID_SIZE = 25
    local grid = {}
    for y = 1, GRID_SIZE do
        grid[y] = {}
        for x = 1, GRID_SIZE do
            grid[y][x] = { type = "void", rotation = 0, occupied = false }
        end
    end

    local spawns = {
        [1] = {x = 13, y = 25, rotation = 270},
        [2] = {x = 13, y = 1,  rotation = 90},
        [3] = {x = 25, y = 13, rotation = 180},
        [4] = {x = 1,  y = 13, rotation = 0}
    }

    local s = spawns[playerId]
    grid[s.y][s.x] = { type = "deadend", rotation = s.rotation, tunnelId = 1, occupied = false }

    client.gameState.grid = grid
end

function client.update()
    if not client.connected or not client.socket then return end

    local line, err, partial = client.socket:receive("*l")
    local message = line or partial
    if not message then return end

    logger.log("[RECV] " .. message)

    if message:match("^YOURID:%d+") then
        client.playerId = tonumber(message:match("^YOURID:(%d+)"))
        logger.log("Отримано ID: " .. client.playerId)
        client.initializeGrid(client.playerId)
        if not logger.initialized then
            logger.init("client_log_" .. client.playerId .. ".txt")
        end
    elseif message:match("^RESULT:") then
        logger.log("Результат: " .. message:sub(8))

    elseif message:match("^DELTA:") then
        local delta = message:match("^DELTA:(.+)")
        if delta then
            client.applyDelta(delta)
        end
    elseif message:match("^SYNC:") then
        local jsonData = message:sub(6)
        client.applyGameState(jsonData)
    elseif message:match("^START:") then
        logger.log("Отримано команду START")
        menuState = "connected"
    end
end

function client.applyGameState(jsonData)
    logger.log("applyGameState викликано")
    local state, pos, err = json.decode(jsonData, 1, nil)
    if not state then
        logger.log("JSON decode error: " .. tostring(err))
        return
    end

    if not state.grid or type(state.grid) ~= "table" then
        logger.log("Отримано SYNC без grid!")
        return
    end

    logger.log("Успішно розібрано SYNC")

    logger.log("🧍 Кількість гравців: " .. tostring(#state.players))
    for i, p in ipairs(state.players) do
        logger.log("Гравець " .. i .. ": x=" .. tostring(p.x) .. ", y=" .. tostring(p.y))
    end
    logger.log("Ваш ID: " .. tostring(client.playerId))

    local fixedGrid = {}
    for y = 1, 25 do
        fixedGrid[y] = {}
        local row = state.grid[y]
        for x = 1, 25 do
            local cell = row and row[x]
            if type(cell) == "table" then
                fixedGrid[y][x] = cell
            else
                fixedGrid[y][x] = { type = "void", rotation = 0, occupied = false }
            end
        end
    end

    state.grid = fixedGrid
    client.gameState = state
    for _, player in ipairs(state.players or {}) do
        for _, card in ipairs(player.hand or {}) do
            card.x = card.x or 0
            card.y = card.y or 0
            card.hover = card.hover or false
        end
    end

    if state.drawnCard then
        state.drawnCard.x = state.drawnCard.x or 0
        state.drawnCard.y = state.drawnCard.y or 0
        state.drawnCard.hover = state.drawnCard.hover or false
    end
    client.myTurn = (tonumber(client.playerId) == tonumber(state.currentPlayerIndex))
    client.gameState = state
end

function client.send(message)
    if client.socket and client.connected then
        client.socket:send(message .. "\n")
        logger.log("[CLIENT] Надіслано: " .. message)
    end
end

function client.isMyTurn()
    return client.playerId == client.gameState.currentPlayerIndex
end

function client.getPlayer()
    -- НАДЁЖНЫЙ способ получить игрока по позиции
    local pid = tonumber(client.playerId)
    if not pid then return nil end
    local players = client.gameState.players or {}
    return players[pid]
end

function client.getState()
    return client.gameState
end

function client.getGrid()
    return client.gameState.grid
end

function client.getDrawnCard()
    return client.gameState.drawnCard
end

function client.getCurrentPlayer()
    return client.gameState.players[client.gameState.currentPlayerIndex]
end

function client.applyDelta(delta)
    local parts = {}
    for part in delta:gmatch("[^,]+") do table.insert(parts, part) end
    local action = parts[1]

    if action == "PLACE" then
        local x = tonumber(parts[2])
        local y = tonumber(parts[3])
        local tileType = parts[4]
        local rot = tonumber(parts[5])
        client.gameState.grid[y][x] = {
            type = tileType,
            rotation = rot,
            tunnelId = nil,
            occupied = false
        }

    elseif action == "MOVE" then
        local pid = tonumber(parts[2])
        local x = tonumber(parts[3])
        local y = tonumber(parts[4])
        if client.gameState.players[pid] then
            client.gameState.players[pid].x = x
            client.gameState.players[pid].y = y
        end
    end
end

return client