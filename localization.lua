--[[

	xMerchant
	Copyright (c) 2010-2014, Nils Ruesch
	All rights reserved.

]]

local xm = select(2, ...);
local getlocale	= GetLocale();
local locale = {
	deDE = {
		["To browse item tooltips, too"] = "Gegenstandstooltip auch durchsuchen",
	},

	frFR = {
		["To browse item tooltips, too"] = "Chercher aussi dans les bulles d'aide", -- << Thanks to Tchao at WoWInterface
	},

	zhCN = {
		["To browse item tooltips, too"] = "对物品详细提示信息也进行搜索",	-- by doneykoo@gmail.com
	},

	zhTW = {
		["To browse item tooltips, too"] = "對物品詳細提示訊息也進行檢索",	-- by doneykoo@gmail.com
	},
};

local L = setmetatable(locale[getlocale] or {}, {
	__index = function(t, i)
		return i;
	end
});
xm.L = L;
