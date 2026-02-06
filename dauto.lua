--///////////////////////////////////////////////////////////
--// ULTIMATE TREE ORBIT AUTOFARM (SAFE TELEPORT)
--///////////////////////////////////////////////////////////

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LargeNodeDropsRemote = Remotes:WaitForChild("LargeNodeDropsRemote")

local enabled = false

-- GUI
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "TreeFarm"

local btn = Instance.new("TextButton", gui)
btn.Size = UDim2.fromOffset(160, 50)
btn.Position = UDim2.fromOffset(20, 20)
btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
btn.TextColor3 = Color3.fromRGB(255,255,255)
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 20
btn.Text = "START"

btn.MouseButton1Click:Connect(function()
    enabled = not enabled
    btn.Text = enabled and "STOP" or "START"
end)

-- Character + Dragon
local function getChar()
    local c = player.Character or player.CharacterAdded:Wait()
    local hrp = c:WaitForChild("HumanoidRootPart")

    local dragon
    repeat
        dragon = c:FindFirstChild("Dragons") and c.Dragons:FindFirstChild("1")
        task.wait()
    until dragon

    local remotes = dragon:WaitForChild("Remotes")
    return hrp, remotes:WaitForChild("BreathFireRemote"), remotes:WaitForChild("PlaySoundRemote")
end

-- Tree scanner
local function getTrees()
    local folder = Workspace:FindFirstChild("Interactions")
    folder = folder and folder:FindFirstChild("Nodes")
    folder = folder and folder:FindFirstChild("Food")
    if not folder then return {} end

    local t = {}
    for _, v in ipairs(folder:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("BillboardPart") and v.PrimaryPart then
            table.insert(t, v)
        end
    end
    return t
end

-- Alive check
local function isTreeAlive(tree)
    if not tree or not tree.Parent then return false end
    if not tree:FindFirstChild("BillboardPart") then return false end
    for _, v in ipairs(tree:GetDescendants()) do
        if v:IsA("BasePart") then return true end
    end
    return false
end

-- Sort by distance
local function sortByDistance(list, hrp)
    table.sort(list,function(a,b)
        return (hrp.Position - a.PrimaryPart.Position).Magnitude <
               (hrp.Position - b.PrimaryPart.Position).Magnitude
    end)
end

-- SAFE Y calculation using raycast
local function getSafeY(position)
    local rayOrigin = position + Vector3.new(0, 500, 0)
    local rayDirection = Vector3.new(0, -1000, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {player.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local ray = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if ray then
        return ray.Position.Y + 5
    else
        return position.Y
    end
end

-- Attack system: teleport to tree + orbit
local function hitTree(tree, hrp, BreathFireRemote, PlaySoundRemote)
    if not isTreeAlive(tree) then return end
    local billboard = tree.BillboardPart

    local hitboxes = {}
    for _, v in ipairs(tree:GetDescendants()) do
        if v:IsA("BasePart") then
            table.insert(hitboxes, v)
        end
    end

    local STACKS = 50
    local HIT_DELAY = 0.012
    local MIN_RADIUS = 15
    local MAX_RADIUS = 25

    local lastOffset

    for i = 1, STACKS do
        if not isTreeAlive(tree) then break end

        -- Orbit offset every 8 hits
        if i % 8 == 1 or not lastOffset then
            local angle = math.rad(math.random(0, 360))
            local radius = math.random(MIN_RADIUS, MAX_RADIUS)
            lastOffset = Vector3.new(
                math.cos(angle) * radius,
                0,
                math.sin(angle) * radius
            )
        end

        -- teleport to tree + orbit
        local targetPos = tree.PrimaryPart.Position + lastOffset
        targetPos = Vector3.new(targetPos.X, getSafeY(targetPos), targetPos.Z)
        hrp.CFrame = CFrame.new(targetPos)

        BreathFireRemote:FireServer(true)
        PlaySoundRemote:FireServer("Breath","Destructibles",billboard)
        for _, hb in ipairs(hitboxes) do
            PlaySoundRemote:FireServer("Breath","Destructibles",hb)
        end
        BreathFireRemote:FireServer(false)

        task.wait(HIT_DELAY)
    end

    -- Collect drops
    task.wait(0.05)
    for i = 1, 3 do
        LargeNodeDropsRemote:FireServer(billboard, 1, 6)
        task.wait(0.05)
    end
end

-- Main engine: teleport from tree to tree
task.spawn(function()
    local hrp, BreathFireRemote, PlaySoundRemote = getChar()

    while true do
        if enabled then
            local trees = getTrees()
            sortByDistance(trees, hrp)

            for _, tree in ipairs(trees) do
                if isTreeAlive(tree) then
                    hitTree(tree, hrp, BreathFireRemote, PlaySoundRemote)
                    task.wait(0.2) -- slight delay between trees
                end
            end
        else
            task.wait(0.2)
        end
    end
end)

-- New tree spawns
Workspace.DescendantAdded:Connect(function(obj)
    if enabled and obj:IsA("Model") and obj.Name:match("LargeFoodNode") and obj:FindFirstChild("BillboardPart") and obj.PrimaryPart then
        task.spawn(function()
            local hrp, bf, ps = getChar()
            hitTree(obj, hrp, bf, ps)
        end)
    end
end)
