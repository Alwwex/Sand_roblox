--[[
	Remotes – komunikace mezi serverem a klientem.
	Server je vytvoří, klient na ně počká.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	-- klient -> server
	Dig = "RemoteEvent",
	TeleportCamp = "RemoteEvent",
	BuyItem = "RemoteFunction",
	EquipItem = "RemoteFunction",
	Rebirth = "RemoteFunction",
	RedeemCode = "RemoteFunction",
	GetData = "RemoteFunction",
	ClaimDaily = "RemoteFunction",
	SaveSettings = "RemoteEvent",
	-- server -> klient
	DataSync = "RemoteEvent",
	DigResult = "RemoteEvent",
	Notify = "RemoteEvent",
	Sold = "RemoteEvent",
	ChestOpened = "RemoteEvent",
	OpenWindow = "RemoteEvent",
	Reward = "RemoteEvent",
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for name in DEFINITIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
