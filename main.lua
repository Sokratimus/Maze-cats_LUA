local GRID_SIZE = 25
local cellSize = 32
local tunnelIdCounter = 1
local tunnelStats = {}

local selectedCard = {
    type = nil,
    rotation = 0
}

local cardList = { "straight", "cross", "t", "corner", "deadend", "empty" }

function love.load()
    love.graphics.setBackgroundColor(0.7, 0.7, 0.7)
    love.window.setMode(1080, 720, {resizable = true, minwidth = 300, minheight = 300})

    tiles = {
        straight = love.graphics.newImage("assets/tiles/Straight.jpg"),
        cross = love.graphics.newImage("assets/tiles/Cross.jpg"),
        t = love.graphics.newImage("assets/tiles/T.jpg"),
        corner = love.graphics.newImage("assets/tiles/Corner.jpg"),
        deadend = love.graphics.newImage("assets/tiles/DeadEnd.jpg"),
        empty = love.graphics.newImage("assets/tiles/Empty.jpg"),
        void = nil
    }

    grid = {}
    for y = 1, GRID_SIZE do
        grid[y] = {}
        for x = 1, GRID_SIZE do
            grid[y][x] = {
                type = "void",
                rotation = 0,
                occupied = false
            }
        end
    end

    player = nil
    playerTurnActive = false
end

function getOpenSides(cell)
    local open = {
        straight = {
            [0] = {left=true, right=true},
            [90] = {up=true, down=true},
            [180] = {left=true, right=true},
            [270] = {up=true, down=true}
        },
        cross = {
            [0] = {up=true, down=true, left=true, right=true},
            [90] = {up=true, down=true, left=true, right=true},
            [180] = {up=true, down=true, left=true, right=true},
            [270] = {up=true, down=true, left=true, right=true}
        },
        t = {
            [0] = {left=true, right=true, down=true},
            [90] = {up=true, down=true, right=true},
            [180] = {left=true, right=true, up=true},
            [270] = {up=true, down=true, left=true}
        },
        corner = {
            [0] = {down=true, right=true},
            [90] = {down=true, left=true},
            [180] = {up=true, left=true},
            [270] = {up=true, right=true}
        },
        deadend = {
            [0] = {right=true},
            [90] = {down=true},
            [180] = {left=true},
            [270] = {up=true}
        },
        empty = {
            [0] = {}
        }
    }
    return open[cell.type] and open[cell.type][cell.rotation or 0] or {}
end

function getExitDelta(tileType)
    if tileType == "deadend" then return -1 end
    if tileType == "t" then return 1 end
    if tileType == "cross" then return 2 end
    return 0
end

function mergeTunnels(targetId, otherId)
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cell = grid[y][x]
            if cell.tunnelId == otherId then
                cell.tunnelId = targetId
            end
        end
    end
    if tunnelStats[otherId] then
        tunnelStats[targetId].tileCount = tunnelStats[targetId].tileCount + tunnelStats[otherId].tileCount
        tunnelStats[targetId].exitScore = tunnelStats[targetId].exitScore + tunnelStats[otherId].exitScore
        tunnelStats[otherId] = nil
    end
end

function canMove(fromX, fromY, toX, toY)
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) + math.abs(dy) ~= 1 then return false end

    local from = grid[fromY] and grid[fromY][fromX]
    local to = grid[toY] and grid[toY][toX]
    if not from or not to then return false end
    if from.type == "void" or to.type == "void" then return false end

    local fromSides = getOpenSides(from)
    local toSides = getOpenSides(to)

    if dx == 1 then return fromSides.right and toSides.left end
    if dx == -1 then return fromSides.left and toSides.right end
    if dy == 1 then return fromSides.down and toSides.up end
    if dy == -1 then return fromSides.up and toSides.down end

    return false
end

function getConnectedNeighbors(x, y, cardType, rotation)
    local directions = {
        {dx=0, dy=-1, from="up", to="down"},
        {dx=0, dy=1,  from="down", to="up"},
        {dx=-1, dy=0, from="left", to="right"},
        {dx=1, dy=0,  from="right", to="left"}
    }

    local openSides = getOpenSides({type = cardType, rotation = rotation})
    local hasConnection = false

    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.dx, y + dir.dy
        if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
            local neighbor = grid[ny][nx]
            if neighbor and neighbor.type ~= "void" then
                local neighborSides = getOpenSides(neighbor)

                local thisSide = openSides[dir.from]
                local neighborSide = neighborSides[dir.to]

                if (thisSide and not neighborSide) or (not thisSide and neighborSide) then
                    return false
                end

                if thisSide and neighborSide then
                    hasConnection = true
                end
            end
        end
    end

    return hasConnection
end

function isPlacementValid(x, y, cardType, rotation)
    if cardType == "empty" then
        local directions = {
            {dx=0, dy=-1, side="down"},
            {dx=0, dy=1,  side="up"},
            {dx=-1, dy=0, side="right"},
            {dx=1, dy=0,  side="left"}
        }

        for _, dir in ipairs(directions) do
            local nx, ny = x + dir.dx, y + dir.dy
            if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
                local neighbor = grid[ny][nx]
                if neighbor and neighbor.type ~= "void" then
                    local sides = getOpenSides(neighbor)
                    if sides[dir.side] then
                        return false
                    end
                end
            end
        end

        return true
    else
        if cardType == "deadend" then
            local neighborTunnels = {}
            local dirs = {
                {dx=0, dy=-1}, {dx=0, dy=1}, {dx=-1, dy=0}, {dx=1, dy=0}
            }

            for _, dir in ipairs(dirs) do
                local nx, ny = x + dir.dx, y + dir.dy
                if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
                    local neighbor = grid[ny][nx]
                    if neighbor and neighbor.tunnelId then
                        neighborTunnels[neighbor.tunnelId] = true
                    end
                end
            end

            local affectedId = next(neighborTunnels)
            if affectedId and tunnelStats[affectedId] then
                local newScore = tunnelStats[affectedId].exitScore + getExitDelta(cardType)
                if newScore < 0 then
                    return false
                end
            end
        end

        return getConnectedNeighbors(x, y, cardType, rotation)
    end
end

function love.mousepressed(mx, my, button)
    local winW, winH = love.graphics.getDimensions()
    local cardSize = 64
    local cardX = winW - cardSize - 20

    -- Выбор карты
    for i, card in ipairs(cardList) do
        local cardY = 20 + (i - 1) * (cardSize + 10)
        if mx >= cardX and mx <= cardX + cardSize and my >= cardY and my <= cardY + cardSize then
            if button == 1 then
                selectedCard.type = card
                selectedCard.rotation = 0
                return
            end
        end
    end

    -- Поворот карты
    if button == 2 and selectedCard.type then
        selectedCard.rotation = (selectedCard.rotation + 90) % 360
        return
    end

    -- Размещение карты
    if button == 1 and selectedCard.type then
        local offsetX = (winW - cellSize * GRID_SIZE) / 2
        local offsetY = (winH - cellSize * GRID_SIZE) / 2
        local gridX = math.floor((mx - offsetX) / cellSize) + 1
        local gridY = math.floor((my - offsetY) / cellSize) + 1

        if gridX >= 1 and gridX <= GRID_SIZE and gridY >= 1 and gridY <= GRID_SIZE then
            local newType = selectedCard.type
            local newRot = selectedCard.rotation

            if isPlacementValid(gridX, gridY, newType, newRot) then
                grid[gridY][gridX].type = newType
                grid[gridY][gridX].rotation = newRot
                local neighbors = {}
                for _, dir in ipairs({{0,-1}, {0,1}, {-1,0}, {1,0}}) do
                    local nx, ny = gridX + dir[1], gridY + dir[2]
                    if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
                        local neighbor = grid[ny][nx]
                        if neighbor.tunnelId then
                            table.insert(neighbors, neighbor.tunnelId)
                        end
                    end
                end

                local idToUse
                if #neighbors == 0 then
                    idToUse = tunnelIdCounter
                    tunnelIdCounter = tunnelIdCounter + 1
                    tunnelStats[idToUse] = {tileCount = 0, exitScore = 0}
                else
                    idToUse = neighbors[1]
                    for i = 2, #neighbors do
                        if neighbors[i] ~= idToUse then
                            mergeTunnels(idToUse, neighbors[i])
                        end
                    end
                end

                grid[gridY][gridX].tunnelId = idToUse
                tunnelStats[idToUse].tileCount = tunnelStats[idToUse].tileCount + 1
                tunnelStats[idToUse].exitScore = tunnelStats[idToUse].exitScore + getExitDelta(newType)
                selectedCard.type = nil
                selectedCard.rotation = 0

            end
        end
    end

    -- Создание игрока
    local buttonW, buttonH = 160, 40
    local buttonX = 20
    local buttonY = love.graphics.getHeight() - buttonH - 20
    if mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH then
        if not player then
            local spawnX = math.ceil(GRID_SIZE / 2)
            local spawnY = GRID_SIZE
            player = { x = spawnX, y = spawnY }
            grid[spawnY][spawnX] = { type = "deadend", rotation = 270, occupied = false }
        end
        return
    end

    -- Активация хода игрока
    local turnBtnW, turnBtnH = 160, 40
    local turnBtnX = 200
    local turnBtnY = love.graphics.getHeight() - turnBtnH - 20
    if mx >= turnBtnX and mx <= turnBtnX + turnBtnW and my >= turnBtnY and my <= turnBtnY + turnBtnH then
        if player then
            playerTurnActive = not playerTurnActive
        end
        return
    end

    -- Перемещение игрока
    if playerTurnActive and player and button == 1 then
        local offsetX = (winW - cellSize * GRID_SIZE) / 2
        local offsetY = (winH - cellSize * GRID_SIZE) / 2
        local gridX = math.floor((mx - offsetX) / cellSize) + 1
        local gridY = math.floor((my - offsetY) / cellSize) + 1

        if gridX >= 1 and gridX <= GRID_SIZE and gridY >= 1 and gridY <= GRID_SIZE then
            if canMove(player.x, player.y, gridX, gridY) then
                player.x = gridX
                player.y = gridY
                playerTurnActive = false
            end
        end
    end
end

function drawCardPreview(cardType, x, y, size, rotation)
    local texture = tiles[cardType] or tiles.empty
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(texture, x + size / 2, y + size / 2, math.rad(rotation),
        size / texture:getWidth(),
        size / texture:getHeight(),
        texture:getWidth() / 2,
        texture:getHeight() / 2)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", x, y, size, size)
end

function love.draw()
    local winW, winH = love.graphics.getDimensions()
    local offsetX = (winW - cellSize * GRID_SIZE) / 2
    local offsetY = (winH - cellSize * GRID_SIZE) / 2

    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cell = grid[y][x]
            local drawX = offsetX + (x - 1) * cellSize
            local drawY = offsetY + (y - 1) * cellSize
            local texture = tiles[cell.type]
            local rotation = math.rad(cell.rotation or 0)

            if texture then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(texture, drawX + cellSize / 2, drawY + cellSize / 2,
                    rotation,
                    cellSize / texture:getWidth(),
                    cellSize / texture:getHeight(),
                    texture:getWidth() / 2,
                    texture:getHeight() / 2)
            end

            -- Рамки
            local neighbors = {
                up = (y > 1) and grid[y - 1][x] or nil,
                down = (y < GRID_SIZE) and grid[y + 1][x] or nil,
                left = (x > 1) and grid[y][x - 1] or nil,
                right = (x < GRID_SIZE) and grid[y][x + 1] or nil
            }

            love.graphics.setColor(0, 0, 0)
            if not neighbors.up or neighbors.up.type == "void" then
                love.graphics.line(drawX, drawY, drawX + cellSize, drawY)
            end
            if not neighbors.down or neighbors.down.type == "void" then
                love.graphics.line(drawX, drawY + cellSize, drawX + cellSize, drawY + cellSize)
            end
            if not neighbors.left or neighbors.left.type == "void" then
                love.graphics.line(drawX, drawY, drawX, drawY + cellSize)
            end
            if not neighbors.right or neighbors.right.type == "void" then
                love.graphics.line(drawX + cellSize, drawY, drawX + cellSize, drawY + cellSize)
            end
        end
    end

    -- Панель карт
    local cardSize = 64
    local cardX = winW - cardSize - 20
    for i, card in ipairs(cardList) do
        local cardY = 20 + (i - 1) * (cardSize + 10)
        drawCardPreview(card, cardX, cardY, cardSize, 0)
    end

    -- Превью выбранной карты
    if selectedCard.type then
        local mx, my = love.mouse.getPosition()
        drawCardPreview(selectedCard.type, mx - cardSize / 2, my - cardSize / 2, cardSize, selectedCard.rotation)
    end

    -- Игрок
    if player then
        local px = offsetX + (player.x - 1) * cellSize + cellSize / 2
        local py = offsetY + (player.y - 1) * cellSize + cellSize / 2
        if playerTurnActive then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 0, 0)
        end
        love.graphics.circle("fill", px, py, cellSize / 4)
    end

    -- Кнопки
    love.graphics.setFont(love.graphics.newFont(16))

    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", 20, winH - 60, 160, 40, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Создать игрока", 20, winH - 50, 160, "center")

    love.graphics.setColor(0.2, 0.4, 0.8)
    love.graphics.rectangle("fill", 200, winH - 60, 160, 40, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Ход игрока", 200, winH - 50, 160, "center")
end