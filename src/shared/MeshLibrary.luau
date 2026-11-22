--[[
	MeshLibrary – hladké 3D modely (MeshParty) z importovaného souboru
	assets/models/DuneDiggersModels.glb.

	Jak je dostat do hry (podrobně v docs/NAVOD.md, sekce 3D modely):
	  1. Roblox Studio → File → Import 3D → vyber DuneDiggersModels.glb → Import
	  2. Vzniklý model přetáhni do ReplicatedStorage a pojmenuj ho "DuneMeshes"
	Hra pak mazlíčky, vajíčka a nástroje staví z těchto modelů. Když DuneMeshes
	chybí, všechno funguje dál se záložními modely z kostiček (PetFactory/ToolFactory).

	Jméno každého meshe nese informace:  <Asset>__<Díl>__<RRGGBB>__<Materiál>__<cx>_<cz>
	Značky RefOrigin/RefUp/RefRight/RefForward opraví měřítko a natočení,
	ať import použije jakékoliv jednotky nebo osy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeshLibrary = {}

local SPACING = 8 -- musí sedět s tools/models/build_models.py
local NAMES = { "DuneMeshes", "DuneDiggersModels" }
local MATERIALS = {
	S = Enum.Material.SmoothPlastic,
	M = Enum.Material.Metal,
	N = Enum.Material.Neon,
	G = Enum.Material.Glass,
	W = Enum.Material.Wood,
}
local REFS = { "RefOrigin", "RefUp", "RefRight", "RefForward" }

local library = nil -- nil = ještě nenačteno, false = modely nejsou k dispozici

local function findRoot(): Instance?
	for _, name in NAMES do
		local found = ReplicatedStorage:FindFirstChild(name)
		if found then
			return found
		end
	end
	for _, name in NAMES do
		if workspace:FindFirstChild(name) then
			warn(
				("[MeshLibrary] Model '%s' je ve Workspace – přesuň ho do ReplicatedStorage a pojmenuj DuneMeshes (viz NAVOD)."):format(
					name
				)
			)
		end
	end
	return nil
end

-- Načte a "přepočítá" všechny MeshParty do souřadnic, ve kterých byly navržené
function MeshLibrary.load(root: Instance?)
	if library ~= nil and root == nil then
		return library
	end
	if root == nil and RunService:IsClient() then
		-- na klientovi počkáme, než se načte celá hra (DuneMeshes se replikuje)
		pcall(function()
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end
		end)
	end
	root = root or findRoot()
	if not root then
		library = false
		return false
	end
	local refs = {}
	local parts = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local isRef = false
			for _, key in REFS do
				if string.find(d.Name, key, 1, true) then
					refs[key] = d.Position
					isRef = true
				end
			end
			if not isRef then
				table.insert(parts, d)
			end
		end
	end
	if not (refs.RefOrigin and refs.RefUp and refs.RefRight and refs.RefForward) then
		warn("[MeshLibrary] V DuneMeshes chybí značky Ref* – použiju záložní modely z kostiček.")
		library = false
		return false
	end
	local origin = refs.RefOrigin
	local up = refs.RefUp - origin
	local right = refs.RefRight - origin
	local back = origin - refs.RefForward -- v návrhu míří "dopředu" po -Z
	local scale = up.Magnitude / 10
	if scale < 1e-4 or right.Unit:Cross(up.Unit):Dot(back.Unit) < 0.9 then
		warn("[MeshLibrary] Značky v DuneMeshes nedávají smysl (zrcadlení?) – použiju záložní modely.")
		library = false
		return false
	end
	local basis = CFrame.fromMatrix(Vector3.zero, right.Unit, up.Unit, back.Unit)
	local inverse = basis:Inverse()
	local result = {}
	local count = 0
	for _, part in parts do
		local asset, label, hex, mat, cx, cz =
			-- bez "^": import může před jméno přidat prefix (např. jméno souboru)
			string.match(part.Name, "(%w+)__(%w+)__(%x%x%x%x%x%x)__(%u)__(%-?%d+)_(%-?%d+)")
		if asset then
			local rel = inverse * (part.CFrame - origin)
			local cell = Vector3.new((tonumber(cx) or 0) * SPACING, 0, (tonumber(cz) or 0) * SPACING)
			local entry = {
				Template = part,
				Label = label,
				CFrame = CFrame.new(rel.Position / scale - cell) * rel.Rotation,
				Size = part.Size / scale,
				Color = Color3.fromHex(hex),
				Material = MATERIALS[mat] or Enum.Material.SmoothPlastic,
				Transparency = if mat == "G" then 0.35 else 0,
			}
			result[asset] = result[asset] or {}
			table.insert(result[asset], entry)
			count += 1
		end
	end
	if count == 0 then
		warn("[MeshLibrary] DuneMeshes neobsahuje žádné MeshParty se správnými jmény.")
		library = false
		return false
	end
	library = result
	return result
end

function MeshLibrary.has(assetId: string): boolean
	local lib = MeshLibrary.load()
	return lib ~= false and lib[assetId] ~= nil
end

local function cloneEntry(entry, scale: number): BasePart
	local part = entry.Template:Clone()
	part.Name = entry.Label
	part.Size = entry.Size * scale
	part.Color = entry.Color
	part.Material = entry.Material
	part.Transparency = entry.Transparency
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = entry.Transparency == 0
	return part
end

-- Ukotvený model (mazlíček, vajíčko, dekorace). Neviditelný "Root" v bodě (0,0,0) = PrimaryPart.
function MeshLibrary.build(assetId: string, options): Model?
	local lib = MeshLibrary.load()
	local entries = lib and lib[assetId]
	if not entries then
		return nil
	end
	local scale = options and options.Scale or 1
	local model = Instance.new("Model")
	model.Name = assetId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	for _, entry in entries do
		local part = cloneEntry(entry, scale)
		part.Anchored = true
		part.CFrame = CFrame.new(entry.CFrame.Position * scale) * entry.CFrame.Rotation
		part.Parent = model
	end
	model.PrimaryPart = root
	model:SetAttribute("Mesh", true)
	return model
end

-- Nástroj: díly přivařené k neviditelnému Handle v místě úchopu (stejně jako ToolFactory)
function MeshLibrary.buildTool(assetId: string, tool: Tool): boolean
	local lib = MeshLibrary.load()
	local entries = lib and lib[assetId]
	if not entries then
		return false
	end
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	for _, entry in entries do
		local part = cloneEntry(entry, 1)
		part.Anchored = false
		part.CFrame = entry.CFrame
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = entry.CFrame
		weld.Parent = part
		part.Parent = tool
	end
	tool:SetAttribute("Mesh", true)
	return true
end

-- Pro testy: zapomene načtená data
function MeshLibrary.reset()
	library = nil
end

return MeshLibrary
