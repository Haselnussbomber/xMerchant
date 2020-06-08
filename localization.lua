local _, addon = ...

local locale = {
	deDE = {
		["Search in item tooltips"] = "Gegenstandstooltip durchsuchen",
		["RECIPE"] = "Rezept",
	},

	enUS = {
		["Search in item tooltips"] = "Search in item tooltips",
		["RECIPE"] = "Recipe",
	}
}

addon.L = setmetatable(locale[GetLocale()] or locale["enUS"], {
	__index = function(_, i)
		return i
	end
})
