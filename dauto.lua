--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

--// SETTINGS
local BREATH_ON = 0.15
local BREATH_OFF = 0.15
local TREE_OFFSET = Vector3.new(0, 0, 6)
local TREE_TIMEOUT = 12
local LOOP_DELAY = 0.15
local DROP_RADIUS = 40

local enabled = false
local destroyedTrees = {}

--// SIMPLE GUI
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.fromOffset(160, 50)
startBtn.Position = UDim2.fromOffset(20, 20)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.SourceSansBold
startBtn.TextSize = 20
startBtn.Text = "START FARM"
startBtn.Parent = gui

startBtn.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        startBtn.Text = "STOP FARM"
        startBtn.BackgroundColor3 = Color3.fromRGB(200,0,0)
    else
        startBtn.Text = "START FARM"
        startBtn.BackgroundColor3 = Color3.fromRGB(0,180,0)
    end
end)

--// CHARACTER & DRAGON
local function getCharacterParts()
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    local dragon = character:WaitForChild("Dragons"):WaitForChild("1")
    local dragonRemotes = dragon:WaitForChild("Remotes")
    return character, hrp, dragon, dragonRemotes
end

--// TREE VALIDATION
local function isTreeValid(tree)
    return tree and tree.Parent and tree:IsDescendantOf(Workspace)
        and tree:IsA("Model") and tree.PrimaryPart and tree:FindFirstChild("BillboardPart")
end

--// GET NEAREST TREES
local function getTrees(hrp)
    local folder = Workspace:WaitForChild("Interactions"):WaitForChild("Nodes"):WaitForChild("Food")
    local list = {}
    for _, tree in ipairs(folder:GetChildren()) do
        if isTreeValid(tree) and not table.find(destroyedTrees, tree) then
            table.insert(list, tree)
        end
    end
    table.sort(list, function(a,b)
        return (hrp.Position - a.PrimaryPart.Position).Magnitude < 
               (hrp.Position - b.PrimaryPart.Position).Magnitude
    end)
    return list
end

--// TELEPORT TO DROPS
local function collectNearbyDrops(hrp, radius)
    radius = radius or DROP_RADIUS
    local drops = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("food") or name:find("sudachi") or name:find("edamame") then
                if (hrp.Position - obj.Position).Magnitude <= radius then
                    table.insert(drops, obj)
                end
            end
        end
    end
    -- Sort by nearest first
    table.sort(drops, function(a,b)
        return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude
    end)
    -- Move to each drop
    for _, drop in ipairs(drops) do
        hrp.CFrame = CFrame.new(drop.Position + Vector3.new(0,2,0))
        task.wait(0.03)
    end
end

--// ATTACK TREE
local function attackTree(hrp, dragon, BreathFireRemote, PlaySoundRemote, tree)
    if not isTreeValid(tree) then return end
    local billboard = tree.BillboardPart
    hrp.CFrame = tree.PrimaryPart.CFrame + TREE_OFFSET

    local startTime = os.clock()

    while enabled do
        if not tree.Parent or not tree:FindFirstChild("BillboardPart") then break end
        if os.clock() - startTime > TREE_TIMEOUT then break end

        -- START BREATH
        BreathFireRemote:FireServer(true)
        task.wait(0.05)
        -- DAMAGE TRIGGER
        PlaySoundRemote:FireServer("Breath","Destructibles",billboard)
        task.wait(BREATH_ON)

        -- STOP BREATH
        BreathFireRemote:FireServer(false)
        task.wait(BREATH_OFF)

        -- TELEPORT TO DROPS WHILE ATTACKING
        collectNearbyDrops(hrp, DROP_RADIUS)
    end

    -- AFTER TREE DESTROYED
    local LargeNodeDropsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LargeNodeDropsRemote")
    if billboard and billboard.Parent then
        LargeNodeDropsRemote:FireServer(billboard, 1, 1)
        task.wait(0.1) -- wait for server to spawn drops
        collectNearbyDrops(hrp, DROP_RADIUS)
    end

    table.insert(destroyedTrees, tree)
end

--// IMMUNITY TO MOB DAMAGE
task.spawn(function()
    while true do
        if enabled then
            pcall(function()
                local character, hrp, dragon, dragonRemotes = getCharacterParts()
                local MobDamageRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MobDamageRemote")
                for _, mob in ipairs(Workspace:GetChildren()) do
                    if mob.Name == "Wanyudo" then
                        MobDamageRemote:FireServer(dragon, 0, mob)
                    end
                end
            end)
        end
        task.wait(0.1)
    end
end)

--// MAIN LOOP
task.spawn(function()
    while true do
        if enabled then
            local character, hrp, dragon, dragonRemotes = getCharacterParts()
            local BreathFireRemote = dragonRemotes:WaitForChild("BreathFireRemote")
            local PlaySoundRemote = dragonRemotes:WaitForChild("PlaySoundRemote")

            local trees = getTrees(hrp)
            for _, tree in ipairs(trees) do
                if not enabled then break end
                attackTree(hrp, dragon, BreathFireRemote, PlaySoundRemote, tree)
                task.wait(LOOP_DELAY)
            end
        end
