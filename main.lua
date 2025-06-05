local GRID_SIZE = 25
local cellSize = 32

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

function canMove(fromX, fromY, toX, toY)
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) + math.abs(dy) ~= 1 then return false end

    local from = grid[fromY] and grid[fromY][fromX]
    local to = grid[toY] and grid[toX] and grid[toY][toX]
    if not from or not to then return false end
    if from.type == "void" or to.type == "void" then return false end

    local function getOpenSides(cell)
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

    local fromSides = getOpenSides(from)
    local toSides = getOpenSides(to)

    if dx == 1 then return fromSides.right and toSides.left end
    if dx == -1 then return fromSides.left and toSides.right end
    if dy == 1 then return fromSides.down and toSides.up end
    if dy == -1 then return fromSides.up and toSides.down end

    return false
end

function recalculateCellSize(w, h)
    local minDim = math.min(w, h)
    cellSize = math.floor(minDim / GRID_SIZE)
end

function love.resize(w, h)
    recalculateCellSize(w, h)
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
            grid[gridY][gridX].type = selectedCard.type
            grid[gridY][gridX].rotation = selectedCard.rotation

            selectedCard.type = nil
            selectedCard.rotation = 0
        end
    end

    -- Кнопка "Создать игрока"
    local buttonW, buttonH = 160, 40
    local buttonX = 20
    local buttonY = love.graphics.getHeight() - buttonH - 20

    if mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH then
        if not player then
            local spawnX = math.ceil(GRID_SIZE / 2)
            local spawnY = GRID_SIZE

            player = {
                x = spawnX,
                y = spawnY
            }

            grid[spawnY][spawnX] = {
                type = "deadend",
                rotation = 270, -- вверх
                occupied = false
            }
        end
        return
    end

      -- Кнопка "Ход игрока"
    local turnBtnW, turnBtnH = 160, 40
    local turnBtnX = 200
    local turnBtnY = love.graphics.getHeight() - turnBtnH - 20

    if mx >= turnBtnX and mx <= turnBtnX + turnBtnW and my >= turnBtnY and my <= turnBtnY + turnBtnH then
        if player then
            playerTurnActive = not playerTurnActive
        end
        return
    end

    -- Перемещение игрока по клику (если режим активен)
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
                love.graphics.draw(texture,
                    drawX + cellSize / 2, drawY + cellSize / 2,
                    rotation,
                    cellSize / texture:getWidth(),
                    cellSize / texture:getHeight(),
                    texture:getWidth() / 2,
                    texture:getHeight() / 2
                )
            end

            -- Границы, если сосед пустой
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

    -- Отрисовка колоды
    local cardSize = 64
    local cardX = winW - cardSize - 20
    for i, card in ipairs(cardList) do
        local cardY = 20 + (i - 1) * (cardSize + 10)
        drawCardPreview(card, cardX, cardY, cardSize, 0)
    end

    -- Превью карты
    if selectedCard.type then
        local mx, my = love.mouse.getPosition()
        drawCardPreview(selectedCard.type, mx - cardSize / 2, my - cardSize / 2, cardSize, selectedCard.rotation)
    end

   -- Игрок
    if player then
        local px = offsetX + (player.x - 1) * cellSize + cellSize / 2
        local py = offsetY + (player.y - 1) * cellSize + cellSize / 2
        if playerTurnActive then
            love.graphics.setColor(1, 1, 0) -- активный ход — жёлтый
        else
            love.graphics.setColor(1, 0, 0) -- обычный — красный
        end
        love.graphics.circle("fill", px, py, cellSize / 4)
    end

    -- Кнопка создания игрока
    local buttonW, buttonH = 160, 40
    local buttonX = 20
    local buttonY = love.graphics.getHeight() - buttonH - 20

    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 10, 10)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("Создать игрока", buttonX, buttonY + 10, buttonW, "center")

    -- Кнопка "Ход игрока"
    local turnBtnW, turnBtnH = 160, 40
    local turnBtnX = 200
    local turnBtnY = love.graphics.getHeight() - turnBtnH - 20

    love.graphics.setColor(0.2, 0.4, 0.8)
    love.graphics.rectangle("fill", turnBtnX, turnBtnY, turnBtnW, turnBtnH, 10, 10)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("Ход игрока", turnBtnX, turnBtnY + 10, turnBtnW, "center")
end