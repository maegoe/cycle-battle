--!strict
local Players = game:GetService("Players")

local PlayerService = {}

-- 서비스 초기화 함수 (필요한 경우)
function PlayerService.Init()
	print("[PlayerService] Initializing...")
end

-- 서비스 시작 함수 (이벤트 연결 등)
function PlayerService.Start()
	print("[PlayerService] Starting...")
	
	-- 이미 접속해 있는 플레이어 처리 (Studio 테스트 시 유용)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			PlayerService.OnPlayerAdded(player)
		end)
	end

	-- 새 플레이어 접속 이벤트 연결
	Players.PlayerAdded:Connect(PlayerService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerService.OnPlayerRemoving)
end

function PlayerService.OnPlayerAdded(player: Player)
	print(string.format("%s 님이 접속했습니다. (User ID: %d)", player.Name, player.UserId))
	
	-- 여기에 데이터 로드나 초기 스탯 설정 로직을 추가할 수 있습니다.
	-- 예: DataService.LoadData(player)
end

function PlayerService.OnPlayerRemoving(player: Player)
	print(string.format("%s 님이 퇴장했습니다.", player.Name))
	
	-- 여기에 데이터 저장 로직을 추가할 수 있습니다.
end

return PlayerService
