--!strict
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local useItemEvent = ReplicatedStorage:WaitForChild("UseItem")
local camera = workspace.CurrentCamera

-- Q 키 입력 시 아이템 사용 요청
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Q then
		useItemEvent:FireServer()
	end
end)

-- 옵저버 모드 및 투표 버튼 처리
local function setupObserverControls()
	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("IsObserver") then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChild("Humanoid")
			
			if root and humanoid then
				humanoid.PlatformStand = true -- 물리/애니메이션 비활성화
				
				local moveDir = Vector3.zero
				local speed = 50
				
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
				
				root.AssemblyLinearVelocity = moveDir * speed
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end)
end

setupObserverControls()

-- UI가 로드되면 투표 버튼 연결
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("GameHUD", 30)
	if hud then
		local voteBtn = hud:WaitForChild("VoteButton", 10)
		if voteBtn then
			voteBtn.MouseButton1Click:Connect(function()
				local voteEvent = ReplicatedStorage:FindFirstChild("VoteRestart")
				if voteEvent then voteEvent:FireServer() end
			end)
		end
	end
end)