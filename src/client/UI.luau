--[[
	UI – vstupní bod uživatelského rozhraní. Spojuje HUD, okna a hlavní menu.
	Návrh je pro 1280x720 a automaticky se škáluje (PC, tablet, mobil).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)
local MainMenu = require(script.Parent.MainMenu)
local UIKit = require(script.Parent.UIKit)
local Windows = require(script.Parent.Windows)

local UI = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local state = nil
local callbacks = nil

local function onMenu(name: string)
	if name == "Daily" then
		local ok, message = Remotes.ClaimDaily:InvokeServer()
		if not ok then
			Hud.toast(message or "", "info")
			callbacks.sfx("Error", 0.5)
		end
	elseif name == "Camp" then
		Windows.close()
		Remotes.TeleportCamp:FireServer()
	elseif name == "Music" then
		local on = callbacks.toggleMusic()
		Hud.setMusicOn(on)
	else
		Windows.open(name)
	end
end

function UI.init(cb)
	callbacks = cb
	local playerGui = player:WaitForChild("PlayerGui")
	gui = UIKit.new("ScreenGui", {
		Name = "DuneDiggersUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	-- škálování podle velikosti obrazovky
	local uiScale = UIKit.new("UIScale", { Parent = gui })
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.5, 1.5)
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	UIKit.clickSound = function()
		cb.sfx("Click", 0.5)
	end

	local context = {
		open = Windows.open,
		menu = onMenu,
		toast = Hud.toast,
		bigPopup = Hud.bigPopup,
		flash = Hud.flash,
		flyCoins = Hud.flyCoins,
		sfx = cb.sfx,
		settingsChanged = cb.settingsChanged,
	}
	Hud.build(gui, context)
	Windows.build(gui, context)

	for _, attribute in { "DesertCleared", "StormPhase", "StormIn", "ServerLuckUntil" } do
		workspace:GetAttributeChangedSignal(attribute):Connect(Hud.updateWorld)
	end
	Hud.updateWorld()
	task.spawn(function()
		while true do
			task.wait(1)
			Hud.updateWorld()
		end
	end)
end

function UI.showMenu(onPlay)
	return MainMenu.show(gui, { onPlay = onPlay, toggleMusic = callbacks.toggleMusic })
end

function UI.update(newState)
	state = newState
	Hud.update(newState)
	Windows.update(newState)
end

function UI.getState()
	return state
end

UI.toast = function(message: string, kind: string?)
	Hud.toast(message, kind)
end
UI.bigPopup = function(message: string, color: Color3)
	Hud.bigPopup(message, color)
end
UI.flash = function(color: Color3?, strength: number?)
	Hud.flash(color, strength)
end
UI.flyCoins = function(count: number)
	Hud.flyCoins(count)
end
UI.open = function(name: string)
	Windows.open(name)
end
UI.close = function()
	Windows.close()
end
UI.setHudVisible = function(visible: boolean)
	Hud.setVisible(visible)
end
UI.applySettings = function(settings)
	Windows.applySettings(settings)
	Hud.setMusicOn((settings.Music or 0) > 0)
end

return UI
