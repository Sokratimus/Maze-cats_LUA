local GRID_SIZE = 25
local cellSize = 32 -- буде перераховуватись

function love.load()
    love.window.setMode(1080, 720, {resizable = true, minwidth = 300, minheight = 300})

    -- ініціалізація сітки
    grid = {}
    for y = 1, GRID_SIZE do
        grid[y] = {}
        for x = 1, GRID_SIZE do
            grid[y][x] = {
                type = "empty",  -- тип клітинки
                occupied = false
            }
        end
    end

    -- тестові тунелі
    --grid[13][13].type = "tunnel"
    --grid[13][14].type = "tunnel"
    --grid[13][15].type = "tunnel"
end

function love.resize(w, h)
    recalculateCellSize(w, h)
end

function recalculateCellSize(w, h)
    local minDim = math.min(w, h)
    cellSize = math.floor(minDim / GRID_SIZE)
end

function love.draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    recalculateCellSize(windowWidth, windowHeight)

    -- центроване поле
    local offsetX = (windowWidth - cellSize * GRID_SIZE) / 2
    local offsetY = (windowHeight - cellSize * GRID_SIZE) / 2

    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cell = grid[y][x]
            local drawX = offsetX + (x - 1) * cellSize
            local drawY = offsetY + (y - 1) * cellSize

            if cell.type == "empty" then
                love.graphics.setColor(0.9, 0.9, 0.9)
            elseif cell.type == "tunnel" then
                love.graphics.setColor(0.4, 0.7, 1.0)
            else
                love.graphics.setColor(1, 1, 1)
            end

            love.graphics.rectangle("fill", drawX, drawY, cellSize, cellSize)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", drawX, drawY, cellSize, cellSize)
        end
    end
end