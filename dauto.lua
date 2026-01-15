--///////////////////////////////////////////////////////////
--// CONTINUOUS TREE AUTOFARM (All nodes + drop collection)
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

-- Get all trees
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

-- Sort by distance
local function sortByDistance(list, hrp)
    table.sort(list,function(a,b)
        return (hrp.Position - a.PrimaryPart.Position).Magnitude <
               (hrp.Position - b.PrimaryPart.Position).Magnitude
    end)
end

-- Attack tree + collect drops
local STACKS = 20 -- faster than 50
local HIT_DELAY = 0.003
local TREE_OFFSET = Vector3.new(0,0,6)

local function hitTree(tree, hrp, BreathFireRemote, PlaySoundRemote)
    if not tree or not tree.Parent or not tree:FindFirstChild("BillboardPart") then return end
    local billboard = tree.BillboardPart

    -- Teleport close to tree
    local targetCFrame = tree.PrimaryPart.CFrame + TREE_OFFSET
    hrp.CFrame = targetCFrame

    -- Hit all hitboxes
    local hitboxes = {}
    for _, v in ipairs(tree:GetDescendants()) do
        if v:IsA("BasePart") then
            table.insert(hitboxes, v)
        end
    end

    for i=1,STACKS do
        BreathFireRemote:FireServer(true)
        PlaySoundRemote:FireServer("Breath","Destructibles",billboard)
        for _,hb in ipairs(hitboxes) do
            PlaySoundRemote:FireServer("Breath","Destructibles",hb)
        end
        BreathFireRemote:FireServer(false)
        task.wait(HIT_DELAY)
    end

    task.wait(0.05)
    -- Fire drop remote multiple times to ensure collection
    for i=1,3 do
        LargeNodeDropsRemote:FireServer(billboard,1,6)
        task.wait(0.05)
    end
end

-- Random position generator (optional fallback)
local function getRandomPosition()
    local x = math.random(-500,500)
    local y = 10
    local z = math.random(-500,500)
    return Vector3.new(x,y,z)
end

-- Continuous loop
task.spawn(function()
    local hrp, BreathFireRemote, PlaySoundRemote = getChar()

    while true do
        if enabled then
            local trees = getTrees()
            sortByDistance(trees, hrp)

            if #trees == 0 then
                -- No trees nearby: move randomly
                local newPos = getRandomPosition()
                hrp.CFrame = CFrame.new(newPos)
                task.wait(0.5)
            else
                -- Loop through all trees continuously
                for _, tree in ipairs(trees) do
                    hitTree(tree, hrp, BreathFireRemote, PlaySoundRemote)
                end
            end
        end
        task.wait(0.1) -- small wait to prevent freezing
    end
end)
