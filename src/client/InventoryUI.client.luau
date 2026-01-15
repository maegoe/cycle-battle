--!strict
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI 생성 (ScreenGui)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryUI"
screenGui.ResetOnSpawn = false -- 캐릭터가 죽어도 UI 유지
screenGui.Parent = playerGui

-- 배경 프레임
local frame = Instance.new("Frame")
frame.Name = "Container"
frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0, 20, 1, -120) -- 좌측 하단
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 0
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = frame

-- 제목 텍스트
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Inventory (Q)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame

-- 아이템 목록 텍스트
local list = Instance.new("TextLabel")
list.Name = "List"
list.Size = UDim2.new(1, -20, 1, -40)
list.Position = UDim2.new(0, 10, 0, 35)
list.BackgroundTransparency = 1
list.Text = "Empty"
list.TextColor3 = Color3.fromRGB(200, 200, 200)
list.Font = Enum.Font.Gotham
list.TextSize = 14
list.TextXAlignment = Enum.TextXAlignment.Left
list.TextYAlignment = Enum.TextYAlignment.Top
list.Parent = frame

-- 인벤토리 업데이트 함수
local function updateInventory()
	local inventory = player:FindFirstChild("Inventory")
	local items = inventory and inventory:GetChildren() or {}
	
	local str = #items == 0 and "Empty" or ""
	for _, item in ipairs(items) do
		if item:IsA("StringValue") then
			str = str .. "• " .. item.Value .. "\n"
		end
	end
	list.Text = str
end

-- 인벤토리 변경 감지
local inventory = player:WaitForChild("Inventory")
inventory.ChildAdded:Connect(updateInventory)
inventory.ChildRemoved:Connect(updateInventory)
updateInventory()