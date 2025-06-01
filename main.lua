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

    -- Вибір карти з колоди
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

    -- Поворот ПКМ
    if button == 2 and selectedCard.type then
        selectedCard.rotation = (selectedCard.rotation + 90) % 360
        return
    end

    -- Розміщення карти
    if button == 1 and selectedCard.type then
        local offsetX = (winW - cellSize * GRID_SIZE) / 2
        local offsetY = (winH - cellSize * GRID_SIZE) / 2
        local gridX = math.floor((mx - offsetX) / cellSize) + 1
        local gridY = math.floor((my - offsetY) / cellSize) + 1

        if gridX >= 1 and gridX <= GRID_SIZE and gridY >= 1 and gridY <= GRID_SIZE then
            grid[gridY][gridX].type = selectedCard.type
            grid[gridY][gridX].rotation = selectedCard.rotation

            -- Скидання після розміщення
            selectedCard.type = nil
            selectedCard.rotation = 0
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

            -- Малюємо межі лише якщо сусід — "void"
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

    -- Колода справа
    local cardSize = 64
    local cardX = winW - cardSize - 20
    for i, card in ipairs(cardList) do
        local cardY = 20 + (i - 1) * (cardSize + 10)
        drawCardPreview(card, cardX, cardY, cardSize, 0)
    end

    -- Прив’язка карти до миші
    if selectedCard.type then
        local mx, my = love.mouse.getPosition()
        drawCardPreview(selectedCard.type, mx - cardSize / 2, my - cardSize / 2, cardSize, selectedCard.rotation)
    end
end