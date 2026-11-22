--[[
	Audio – hudba, ambience a zvukové efekty.

	- Hudba se mění podle místa: menu/lobby = "Lobby", poušť = "Desert",
	  písečná bouře = "Storm" (plynulé prolínání).
	- Vítr hraje jen venku v poušti.
	- Efekty jsou v jednom souboru (Config.SfxPack), přehrávají se jeho části
	  (PlaybackRegion). Dokud není nahraný, použijí se vestavěné zvuky Robloxu.
	- Hlasitost hudby a efektů jde z nastavení hráče.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Audio = {}

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local tracks = {} -- [name] = Sound
local ambience: Sound? = nil
local current: string? = nil
local inMenu = true
local musicVolume = 0.5
local sfxVolume = 0.8

-- Záložní vestavěné zvuky pro efekty, které v Config.Sounds nejsou
local FALLBACK = {
	Dig = "Dig",
	Dig2 = "Dig",
	Coin = "Sell",
	Sell = "Sell",
	Buy = "Sell",
	Click = "Click",
	Open = "Click",
	Error = "Click",
	Chest = "Chest",
	Rare = "Chest",
	Rebirth = "Chest",
	Storm = nil,
}

local function makeGroup(name: string, volume: number): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = volume
	group.Parent = SoundService
	return group
end

local function makeTrack(name: string, id: string, volume: number): Sound?
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound:SetAttribute("TargetVolume", volume)
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	return sound
end

function Audio.init()
	musicGroup = makeGroup("Music", musicVolume)
	sfxGroup = makeGroup("SFX", sfxVolume)
	local base = Config.Music.Volume or 0.5
	tracks.Lobby = makeTrack("Lobby", Config.Music.Lobby, base)
	tracks.Desert = makeTrack("Desert", Config.Music.Desert, base)
	tracks.Storm = makeTrack("Storm", Config.Music.Storm, base * 1.1)
	ambience = makeTrack("Ambience", Config.Music.Ambience, base * 0.8)
	if Config.Music.Lobby == "" then
		print("[Audio] Hudba zatím není nahraná – viz docs/NAVOD.md, sekce Hudba a zvuky.")
	end
end

function Audio.setVolumes(music: number, sfx: number)
	musicVolume = math.clamp(music, 0, 1)
	sfxVolume = math.clamp(sfx, 0, 1)
	if musicGroup then
		musicGroup.Volume = musicVolume
	end
	if sfxGroup then
		sfxGroup.Volume = sfxVolume
	end
end

local fadeInfo = TweenInfo.new(1.6, Enum.EasingStyle.Sine)

local function fadeTo(sound: Sound?, on: boolean)
	if not sound then
		return
	end
	if on and not sound.IsPlaying then
		sound:Play()
	end
	local target = if on then (sound:GetAttribute("TargetVolume") or 0.5) else 0
	local tween = TweenService:Create(sound, fadeInfo, { Volume = target })
	tween:Play()
	if not on then
		tween.Completed:Connect(function()
			if sound.Volume <= 0.01 then
				sound:Pause()
			end
		end)
	end
end

function Audio.setMusic(name: string?)
	if name == current then
		return
	end
	current = name
	for trackName, sound in tracks do
		fadeTo(sound, trackName == name)
	end
end

function Audio.setMenu(value: boolean)
	inMenu = value
	Audio.refresh()
end

-- Vybere hudbu podle pozice hráče a stavu bouře (volá se pravidelně)
function Audio.refresh()
	local phase = workspace:GetAttribute("StormPhase") or "Calm"
	local inLobby = true
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local p = root.Position
		inLobby = math.max(math.abs(p.X), math.abs(p.Z)) < Config.World.CampHalf + 6 and p.Y > Config.World.CampTop - 6
	end
	local storm = phase == "Warning" or phase == "Active"
	local track = if inMenu or (inLobby and not storm) then "Lobby" elseif storm then "Storm" else "Desert"
	Audio.setMusic(track)
	fadeTo(ambience, not inMenu and not inLobby)
end

-- Zvukový efekt (name = klíč z Config.SfxRegions)
function Audio.sfx(name: string, volume: number?, pitch: number?)
	if sfxVolume <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	local region = Config.SfxRegions[name]
	if Config.SfxPack ~= "" and region then
		sound.SoundId = Config.SfxPack
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region[1], region[2])
		sound.Volume = volume or 0.7
	else
		local key = FALLBACK[name]
		local id = key and Config.Sounds[key]
		if not id or id == "" then
			sound:Destroy()
			return
		end
		sound.SoundId = id
		sound.Volume = (volume or 0.7) * 0.6
	end
	sound.PlaybackSpeed = pitch or 1
	sound.SoundGroup = sfxGroup
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Audio
