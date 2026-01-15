--///////////////////////////////////////////////////////////
--// ULTRA FAST TREE FARM + TERRAIN DROP COLLECT WITH BURST DAMAGE
--///////////////////////////////////////////////////////////

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- SETTINGS
local TREE_OFFSET = Vector3.new(0, 5, 0)  -- height above tree
local STACKS_PER_BURST = 5                -- BreathFire shots per burst
local TELEPORT_STEPS = 10                 -- smooth teleport steps
local TELEPORT_STEP_DELAY = 0.01          -- delay between teleport steps
local DROP_WAIT = 0.02                     -- delay between drop collections
local LOOP_DELAY = 0.01                    -- small delay between trees

local enabled = false

-- GUI (Black + White)
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.fromOffset(160, 50)
startBtn.Position = UDim2.fromOffset(20, 20)
startBtn.BackgroundColor3 = Color3.new(0,0,0)
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.SourceSansBold
startBtn.TextSize = 20
startBtn.Text = "START FARM"
startBtn.Parent = gui

startBtn.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        startBtn.Text = "STOP FARM"
        startBtn.BackgroundColor3 = Color3.new(1,1,1)
        startBtn.TextColor3 = Color3.new(0,0,0)
    else
        startBtn.Text = "START FARM"
        startBtn.BackgroundColor3 = Color3.new(0,0,0)
        startBtn.TextColor3 = Color3.new(1,1,1)
    end
end)

-- GLOBALS
local hrp, dragon, BreathFireRemote, PlaySoundRemote
local LargeNodeDropsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LargeNodeDropsRemote")

-- SETUP CHARACTER & DRAGON
local function setupCharacter()
    repeat
        local char = player.Character or player.CharacterAdded:Wait()
        hrp = char:FindFirstChild("HumanoidRootPart")
        dragon = char:FindFirstChild("Dragons") and char.Dragons:FindFirstChild("1")
        task.wait(0.1)
    until hrp and dragon

    local dragonRemotes = dragon:FindFirstChild("Remotes")
    BreathFireRemote = dragonRemotes and dragonRemotes:FindFirstChild("BreathFireRemote")
    PlaySoundRemote = dragonRemotes and dragonRemotes:FindFirstChild("PlaySoundRemote")
end

-- TREE FUNCTIONS
local function getTrees()
    local folder = Workspace:FindFirstChild("Interactions")
    folder = folder and folder:FindFirstChild("Nodes")
    folder = folder and folder:FindFirstChild("Food")
    if not folder then return {} end

    local trees = {}
    for _, t in ipairs(folder:GetChildren()) do
        if t and t.Parent then
            table.insert(trees, t)
        end
    end
    return trees
end

local function isTreeAlive(tree)
    return tree and tree.Parent
end

-- DAMAGE TREE FUNCTION WITH BURST DAMAGE
local function attackTree(tree)
    if not isTreeAlive(tree) then return end
    local billboard = tree:FindFirstChild("BillboardPart")
    if not billboard then return end

    -- get all hitboxes
    local hitboxes = {}
    for _, c in ipairs(tree:GetChildren()) do
        if c:IsA("BasePart") and c.Name:lower():find("hitbox") then
            table.insert(hitboxes, c)
        end
    end

    -- smooth teleport above tree
    if hrp then
        local targetPos = billboard.Position + TREE_OFFSET
        local startPos = hrp.Position
        for i = 1, TELEPORT_STEPS do
            local alpha = i / TELEPORT_STEPS
            hrp.CFrame = CFrame.new(startPos:Lerp(targetPos, alpha))
            task.wait(TELEPORT_STEP_DELAY)
        end
    end

    -- BURST DAMAGE: hit all parts STACKS_PER_BURST times instantly
    for i = 1, STACKS_PER_BURST do
        BreathFireRemote:FireServer(true)
        task.wait(0.003) -- tiny delay for server registration
        -- hit main billboard
        PlaySoundRemote:FireServer("Breath","Destructibles", billboard)
        -- hit all hitboxes
        for _, hb in ipairs(hitboxes) do
            PlaySoundRemote:FireServer("Breath","Destructibles", hb)
        end
        BreathFireRemote:FireServer(false)
    end
end

-- TERRAIN DROP COLLECTION FUNCTIONS
local function getTerrainDrops()
    local drops = {}
    local terrain = Workspace:FindFirstChild("Terrain")
    if not terrain then return drops end

    for _, attachment in ipairs(terrain:GetDescendants()) do
        if attachment:IsA("PartAdorneeAttachment") then
            local itemDrop = attachment:FindFirstChild("ItemDrops")
            if itemDrop then
                table.insert(drops, itemDrop)
            end
        end
    end

    return drops
end

local function collectTerrainDrop(itemDrop)
    if itemDrop then
        local args = {itemDrop, 1, 6} -- adjust numbers if needed
        LargeNodeDropsRemote:FireServer(unpack(args))
    end
end

-- TERRAIN DROP COLLECTION LOOP
task.spawn(function()
    while true do
        if enabled then
            local drops = getTerrainDrops()
            for _, drop in ipairs(drops) do
                collectTerrainDrop(drop)
                task.wait(DROP_WAIT)
            end
        end
        task.wait(0.05)
    end
end)

-- TREE FARM LOOP
task.spawn(function()
    setupCharacter()
    while true do
        if enabled and hrp and dragon and BreathFireRemote and PlaySoundRemote then
            local trees = getTrees()
            for _, tree in ipairs(trees) do
                if not enabled then break end
                if isTreeAlive(tree) then
                    attackTree(tree)
                    task.wait(LOOP_DELAY)
                end
            end
        end
        task.wait(0.005)
    end
end)
