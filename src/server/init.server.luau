--!strict
local ServerScriptService = game:GetService("ServerScriptService")

-- 서비스 모듈들이 위치한 폴더
local ServicesFolder = script:WaitForChild("Services")

-- 로드할 서비스 목록을 관리하거나, 폴더 내의 모든 모듈을 자동으로 로드할 수 있습니다.
local services = {}

-- 1단계: 모든 서비스 모듈 require (로드)
for _, moduleScript in ipairs(ServicesFolder:GetChildren()) do
	if moduleScript:IsA("ModuleScript") then
		local success, result = pcall(require, moduleScript)
		if success then
			table.insert(services, result)
			print(string.format("[Server] Loaded service: %s", moduleScript.Name))
		else
			warn(string.format("[Server] Failed to load service %s: %s", moduleScript.Name, result))
		end
	end
end

-- 2단계: Init (초기화 - 다른 서비스에 의존하지 않는 설정)
for _, service in ipairs(services) do
	if type(service.Init) == "function" then
		task.spawn(service.Init)
	end
end

-- 3단계: Start (실행 - 이벤트 연결 및 다른 서비스 사용)
for _, service in ipairs(services) do
	if type(service.Start) == "function" then
		task.spawn(service.Start)
	end
end

print("[Server] All services started successfully.")
