--!strict
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local useItemEvent = ReplicatedStorage:WaitForChild("UseItem")

-- Q 키 입력 시 아이템 사용 요청
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Q then
		useItemEvent:FireServer()
	end
end)