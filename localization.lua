--[[

	xMerchant
	Copyright (c) 2010-2014, Nils Ruesch
	All rights reserved.

]]

local xm = select(2, ...);
local getlocale	= GetLocale();
local locale = {
	deDE = {
		["Search in item tooltips"] = "Gegenstandstooltip durchsuchen",
		["RECIPE"] = "Rezept",
	},

	enUS = {
		["Search in item tooltips"] = "Search in item tooltips",
		["RECIPE"] = "Recipe",
	}
};

local L = setmetatable(locale[getlocale] or {}, {
	__index = function(t, i)
		return i;
	end
});
xm.L = L;
