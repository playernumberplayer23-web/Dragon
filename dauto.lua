--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local dragon = character:WaitForChild("Dragons"):WaitForChild("1")
local dragonRemotes = dragon:WaitForChild("Remotes")

local BreathFireRemote = dragonRemotes:WaitForChild("BreathFireRemote")
local PlaySoundRemote = dragonRemotes:WaitForChild("PlaySoundRemote")
local LargeNodeDropsRemote =
    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LargeNodeDropsRemote")

local MobDamageRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MobDamageRemote")

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
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.fromOffset(160, 50)
startBtn.Position = UDim2.fromOffset(20, 20)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0) -- green initially
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.SourceSansBold
startBtn.TextSize = 20
startBtn.Text = "START FARM"
startBtn.Parent = gui

startBtn.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        startBtn.Text = "STOP FARM"
        startBtn.BackgroundColor3 = Color3.fromRGB(200,0,0) -- red while running
    else
        startBtn.Text = "START FARM"
        startBtn.BackgroundColor3 = Color3.fromRGB(0,180,0) -- green when stopped
    end
end)
--// TREE VALIDATION
local function isTreeValid(tree)
    return tree and tree.Parent and tree:IsDescendantOf(Workspace)
        and tree:IsA("Model") and tree.PrimaryPart and tree:FindFirstChild("BillboardPart")
end

--// GET NEAREST TREES
local function getTrees()
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
local function collectNearbyDrops(radius)
    radius = radius or DROP_RADIUS
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("food") or name:find("sudachi") or name:find("edamame") then
                if (hrp.Position - obj.Position).Magnitude <= radius then
                    hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0,2,0))
                    task.wait(0.03)
                end
            end
        end
    end
end

--// ATTACK TREE UNTIL DESTROYED
local function attackTree(tree)
    if not isTreeValid(tree) then return end
    local billboard = tree.BillboardPart
    hrp.CFrame = tree.PrimaryPart.CFrame + TREE_OFFSET

    local startTime = os.clock()

    while enabled do
        if not tree.Parent or not tree:FindFirstChild("BillboardPart") then
            break
        end
        if os.clock() - startTime > TREE_TIMEOUT then
            break
        end

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
        collectNearbyDrops(DROP_RADIUS)
    end

    -- FINAL COLLECTION AFTER TREE DESTROYED
    if billboard and billboard.Parent then
        LargeNodeDropsRemote:FireServer(billboard, 1, 2)
        task.wait(0.1)
        collectNearbyDrops(DROP_RADIUS)
    end

    table.insert(destroyedTrees, tree)
end

--// NULLIFY MOB DAMAGE (IMMUNITY WHILE FARMING)
task.spawn(function()
    while true do
        if enabled then
            pcall(function()
                for _, mob in ipairs(Workspace:GetChildren()) do
                    -- Replace with your mobs folder if different
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
            local trees = getTrees()
            for _, tree in ipairs(trees) do
                if not enabled then break end
                attackTree(tree)
                task.wait(LOOP_DELAY)
            end
        end
        task.wait(0.05)
    end
end)
