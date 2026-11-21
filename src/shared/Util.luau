--[[
	Util – drobné pomocné funkce sdílené serverem i klientem.
]]

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1,234" ; 1520000 -> "1.52M"
function Util.formatNumber(value: number): string
	value = math.floor(value or 0)
	if math.abs(value) < 100000 then
		local text = tostring(value)
		local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then
			formatted = formatted:sub(2)
		end
		return (formatted:gsub("^%-,", "-"))
	end
	local index = 1
	local scaled = value
	while math.abs(scaled) >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	local decimals = if math.abs(scaled) >= 100 then 0 elseif math.abs(scaled) >= 10 then 1 else 2
	local text = string.format("%." .. decimals .. "f", scaled)
	if decimals > 0 then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text .. SUFFIXES[index]
end

-- 125 -> "2:05"
function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.formatPercent(fraction: number): string
	return string.format("%d%%", math.floor((fraction or 0) * 100 + 0.5))
end

return Util
