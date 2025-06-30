-- game_common.lua
local common = {}

function common.getOpenSides(cell)
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
    local rot = tonumber(cell.rotation or 0) % 360
    if rot ~= 0 and rot ~= 90 and rot ~= 180 and rot ~= 270 then
        rot = math.floor((rot + 45) / 90) * 90
    end
    return open[cell.type] and open[cell.type][rot] or {}
end

function common.getExitDelta(tileType)
    if tileType == "deadend" then return -1 end
    if tileType == "t" then return 1 end
    if tileType == "cross" then return 2 end
    return 0
end

function common.mergeTunnels(grid, tunnelStats, mainId, otherIds)
    for y = 1, #grid do
        for x = 1, #grid[y] do
            local cell = grid[y][x]
            if cell.tunnelId and otherIds[cell.tunnelId] then
                cell.tunnelId = mainId
            end
        end
    end

    for id in pairs(otherIds) do
        if id ~= mainId and tunnelStats[id] then
            tunnelStats[mainId].tileCount = tunnelStats[mainId].tileCount + tunnelStats[id].tileCount
            tunnelStats[mainId].exitScore = tunnelStats[mainId].exitScore + tunnelStats[id].exitScore
            tunnelStats[id] = nil
        end
    end
end

function common.canMove(grid, fromX, fromY, toX, toY)
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) + math.abs(dy) ~= 1 then return false end

    local from = grid[fromY] and grid[fromY][fromX]
    local to = grid[toY] and grid[toY][toX]
    if not from or not to then return false end
    if from.type == "void" or to.type == "void" then return false end

    local fromSides = common.getOpenSides(from)
    local toSides = common.getOpenSides(to)

    if dx == 1 then return fromSides.right and toSides.left end
    if dx == -1 then return fromSides.left and toSides.right end
    if dy == 1 then return fromSides.down and toSides.up end
    if dy == -1 then return fromSides.up and toSides.down end

    return false
end

function common.isPlacementValid(grid, tunnelStats, x, y, cardType, rotation)
    logger = logger or require("logger")
    logger.log("🔍 VALIDATING: x=" .. x .. ", y=" .. y .. ", type=" .. cardType .. ", rot=" .. rotation)

    if grid[y][x].type ~= "void" then
        logger.log("❌ Відмова: клітинка не пуста (x=" .. x .. ", y=" .. y .. ") тип=" .. grid[y][x].type)
        return false
    end

    local openSides = common.getOpenSides({type = cardType, rotation = rotation})
    local directions = {
        {dx=0, dy=-1, side="up", opp="down"},
        {dx=0, dy=1,  side="down", opp="up"},
        {dx=-1, dy=0, side="left", opp="right"},
        {dx=1, dy=0,  side="right", opp="left"}
    }

    if cardType == "empty" then
        for _, dir in ipairs(directions) do
            local nx, ny = x + dir.dx, y + dir.dy
            if grid[ny] and grid[ny][nx] then
                local neighbor = grid[ny][nx]
                if neighbor and neighbor.type ~= "void" then
                    local neighborSides = common.getOpenSides(neighbor)
                    if neighborSides[dir.side] then
                        logger.log("❌ empty touching tile with open side at (" .. nx .. "," .. ny .. ")")
                        return false
                    end
                end
            end
        end
        return true
    end

    local hasConnection = false
    local seenTunnels = {}
    local totalExitScore = 0
    local overlapCount = 0

    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.dx, y + dir.dy
        if grid[ny] and grid[ny][nx] then
            local neighbor = grid[ny][nx]
            if neighbor and neighbor.type ~= "void" and neighbor.tunnelId then
                local neighborSides = common.getOpenSides(neighbor)
                local thisSide = openSides[dir.side]
                local neighborSide = neighborSides[dir.opp]

                if thisSide and neighborSide then
                    hasConnection = true
                    overlapCount = overlapCount + 2
                elseif thisSide ~= neighborSide then
                    logger.log("❌ Несумісність сторін: " .. dir.side .. " vs " .. dir.opp .. " на (" .. nx .. "," .. ny .. ")")
                    return false
                end

                if not seenTunnels[neighbor.tunnelId] then
                    seenTunnels[neighbor.tunnelId] = true
                    local stats = tunnelStats[neighbor.tunnelId]
                    if stats then
                        totalExitScore = totalExitScore + stats.exitScore
                    end
                end
            end
        end
    end

    local newExits = 0
    for _, open in pairs(openSides) do
        if open then newExits = newExits + 1 end
    end

    local netScore = totalExitScore + newExits - overlapCount

    if not hasConnection then
        logger.log("❌ Відмова: немає з'єднання з сусідніми тунелями")
        return false
    end

    if netScore <= 0 then
        logger.log("❌ Відмова: netScore <= 0 (" .. netScore .. ")")
        return false
    end

    logger.log("✅ Розміщення допустиме (netScore = " .. netScore .. ")")
    return true
end

function common.randomCardType()
    local types = { "straight", "cross", "t", "corner", "deadend", "empty" }
    return types[math.random(#types)]
end

return common