--[[

	xMerchant
	Copyright (c) 2010-2014, Nils Ruesch
	All rights reserved.

]]

local addonName, xm = ...;
local L = xm.L;

local buttons = {};
local illusions = {};
local currencies = {};
local npcName = "";
local numMerchantItems = 0;
local items = {};
local searchText = "";
local isSearching = false;
local searchInTooltip = false;

-- "Requires Level %d" to "Requires Level (%d+)"
local REQUIRES_LEVEL = ITEM_MIN_LEVEL:gsub("%%d", "(%%d+)");

-- "Requires %s - %s" to "Requires ([^-]+) %%- ([^-]+)"
local REQUIRES_REPUTATION = ITEM_REQ_REPUTATION:gsub("%-", "%%-"):gsub("%%s", "([^-]+)");

-- "Requires %s (%d)" to "Requires (%a+) %((%d+)%)"
local REQUIRES_SKILL = ITEM_MIN_SKILL:gsub("%%1?$?s", "(%%a+)"):gsub("%(%%2?$?d%)", "%%((%%d+)%%)");

-- "Classes: %s" to "Classes: (.*)"
local REQUIRES_CLASSES = ITEM_CLASSES_ALLOWED:gsub("%%s", "(.*)");

-- "Requires %s" to "Requires (.*)"
local REQUIRES = ITEM_REQ_SKILL:gsub("%%1?$?s", "(.*)");

-- "Collected (%d/%d)" to "Collected %((%d+)/(%d+)%)"
local PET_COLLECTED_COUNT = ITEM_PET_KNOWN:gsub("%(%%d/%%d%)", "%%((%%d+)/(%%d+)%%)");

local tooltip = CreateFrame("GameTooltip", "NuuhMerchantTooltip", UIParent, "GameTooltipTemplate");

local NUM_BUTTONS = 8;

-- Only illusions we can buy
local ILLUSIONS_LIST = {
	-- [itemID] = sourceID
	[138796] = 3225, -- [Illusion: Executioner]
	[138803] = 4066, -- [Illusion: Mending]
	[138954] = 5364, -- [Illusion: Poisoned]
};

local PRESERVED_CONTAMINANT_LIST = {
	[177955] = {318268,1,15}, -- Deadly Momentum I
	[177965] = {318493,2,20}, -- Deadly Momentum II
	[177966] = {318497,3,35}, -- Deadly Momentum III
	[177967] = {318486,3,60}, -- Echoing Void III
	[177968] = {318485,2,35}, -- Echoing Void II
	[177969] = {318280,1,25}, -- Echoing Void I
	[177970] = {315607,1,10}, -- Avoidant I
	[177971] = {315608,2,15}, -- Avoidant II
	[177972] = {315609,3,20}, -- Avoidant III
	[177973] = {315544,1,10}, -- Expedient I
	[177974] = {315545,2,15}, -- Expedient II
	[177975] = {315546,3,20}, -- Expedient III
	[177976] = {318239,0,15}, -- Glimpse of Clarity
	[177977] = {318272,0,15}, -- Gushing Wound
	[177978] = {318269,1,15}, -- Honed Mind I
	[177979] = {318494,2,20}, -- Honed Mind II
	[177980] = {318498,3,35}, -- Honed Mind III
	[177981] = {318303,1,12}, -- Ineffable Truth I
	[177982] = {318484,2,30}, -- Ineffable Truth II
	[177983] = {318274,1,20}, -- Infinite Stars I
	[177984] = {318487,2,35}, -- Infinite Stars II
	[177985] = {318488,3,60}, -- Infinite Stars III
	[177986] = {315529,1,10}, -- Masterful I
	[177987] = {315530,2,15}, -- Masterful II
	[177988] = {315531,3,20}, -- Masterful III
	[177989] = {318266,1,15}, -- Racing Pulse I
	[177990] = {318492,2,20}, -- Racing Pulse II
	[177991] = {318496,3,35}, -- Racing Pulse III
	[177992] = {315554,1,10}, -- Severe I
	[177993] = {315557,2,15}, -- Severe II
	[177994] = {315558,3,20}, -- Severe III
	[177995] = {315590,1,17}, -- Siphoner I
	[177996] = {315591,2,28}, -- Siphoner II
	[177997] = {315592,3,45}, -- Siphoner III
	[177998] = {315277,1,10}, -- Strikethrough I
	[177999] = {315281,2,15}, -- Strikethrough II
	[178000] = {315282,3,20}, -- Strikethrough III
	[178001] = {318270,1,15}, -- Surging Vitality I
	[178002] = {318495,2,20}, -- Surging Vitality II
	[178003] = {318499,3,35}, -- Surging Vitality III
	[178004] = {318276,1,25}, -- Twilight Devastation I
	[178005] = {318477,2,50}, -- Twilight Devastation II
	[178006] = {318478,3,75}, -- Twilight Devastation III
	[178007] = {318481,1,10}, -- Twisted Appendage I
	[178008] = {318482,2,35}, -- Twisted Appendage II
	[178009] = {318483,3,66}, -- Twisted Appendage III
	[178010] = {315549,1,10}, -- Versatile I
	[178011] = {315552,2,15}, -- Versatile II
	[178012] = {315553,3,20}, -- Versatile III
	[178013] = {318286,1,15}, -- Void Ritual I
	[178014] = {318479,2,35}, -- Void Ritual II
    [178015] = {318480,3,66}, -- Void Ritual III
};

local ACHIEVEMENT_LIST = {
	[47541] = 3736, -- Argent Pony Bridle / Pony Up!
};

local function ScanItemTooltip(item)
	if ( not item.link or item.tooltipScanned ) then
		return item;
	end

	item.tooltipScanned = true;

	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:SetMerchantItem(item.index);

	local errormsgs = {};
	local numLines = tooltip:NumLines();

	for i=2, numLines do
		local frame = _G["NuuhMerchantTooltipTextLeft" .. i];
		local r, g, b = frame:GetTextColor();
		local text = frame:GetText();

		if ( text and text ~= RETRIEVING_ITEM_INFO ) then
			if ( item.info.itemClassId == LE_ITEM_CLASS_MISCELLANEOUS
				and item.info.itemSubClassId == LE_ITEM_MISCELLANEOUS_COMPANION_PET
			) then
				local pet_collected_count, pet_collected_max = text:match(PET_COLLECTED_COUNT);

				if ( pet_collected_count ~= nil and pet_collected_max ~= nil ) then
					item.petCollected = true;
					item.petCollectedCount = tonumber(pet_collected_count);
					item.petCollectedMax = tonumber(pet_collected_max);
				end
			end

			-- red text
			if ( r >= 0.9 and g <= 0.2 and b <= 0.2 ) then
				local level = text:match(REQUIRES_LEVEL);
				local reputation, factionName, classes, is2HWeapon;

				if ( level ) then
					table.insert(errormsgs, LEVEL_GAINED:format(level));
				end

				if ( not level ) then
					factionName, reputation = text:match(REQUIRES_REPUTATION);

					if ( reputation and factionName ) then
						table.insert(errormsgs, reputation);
					end
				end

				local skill, slevel = text:match(REQUIRES_SKILL);

				if ( skill and slevel ) then
					table.insert(errormsgs, AUCTION_MAIL_ITEM_STACK:format(skill, slevel));
				end

				local requires = text:match(REQUIRES);

				if ( not level and not reputation and not skill and requires ) then
					table.insert(errormsgs, requires);
				end

				if ( not item.isRecipe ) then
					classes = text:match(REQUIRES_CLASSES);

					if ( not level and not reputation and not skill and not requires and classes ) then
						table.insert(errormsgs, classes);
					end

					is2HWeapon = text:match(INVTYPE_2HWEAPON);

					if ( not level and not reputation and not skill and not requires and not classes and is2HWeapon ) then
						item.cantEquip = true;
					end
				end

				if ( text and text ~= TOOLTIP_SUPERCEDING_SPELL_NOT_KNOWN and not level and not reputation and not skill and not requires and not classes and not is2HWeapon and not item.petCollected ) then
					table.insert(errormsgs, text);
				end

				if ( text == ITEM_SPELL_KNOWN ) then
					errormsgs = { text }; -- only show that it's known
					item.isKnown = true;
				end

				if ( text == TOOLTIP_SUPERCEDING_SPELL_NOT_KNOWN ) then
					item.previousRecipeMissing = true;
				end
			end

			if ( not item.isRecipe and text == TOY ) then
				item.isToy = true;
			end

			--if ( not item.isRecipe and ( text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN or text == TRANSMOGRIFY_STYLE_UNCOLLECTED ) ) then
			--	item.transmogUncollected = true;
			--end
		end

		frame = _G["NuuhMerchantTooltipTextRight" .. i];
		r, g, b = frame:GetTextColor();
		text = frame:GetText();

		if ( text and r >= 0.9 and g <= 0.2 and b <= 0.2 ) then
			-- is there anything else that can be on the right in red color?
			--table.insert(errormsgs, text);
			item.cantEquip = true;
		end
	end

	if ( item.previousRecipeMissing ) then
		table.insert(errormsgs, TOOLTIP_SUPERCEDING_SPELL_NOT_KNOWN);
	end

	item.errormsgs = errormsgs;
	item.hasErrors = #errormsgs > 0;

	return item;
end

local function IllusionsUpdate()
	wipe(illusions);

	local list = C_TransmogCollection.GetIllusions();

	for i = 1, #list do
		if ( list[i] and list[i].sourceID ) then
			illusions[list[i].sourceID] = list[i].isCollected;
		end
	end
end

local function CurrencyUpdate_Currencies()
	local merchantCurrencies = { GetMerchantCurrencies() };
	local numMerchantCurrencies = #merchantCurrencies;
	
	for i = 1, numMerchantCurrencies do
		local id = merchantCurrencies[i];
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(id);

		if ( currencyInfo ) then
			table.insert(currencies, {
				type = "currency",
				index = i,
				id = id,
				link = C_CurrencyInfo.GetCurrencyListLink(i),
				name = currencyInfo.name,
				count = currencyInfo.quantity,
				max = currencyInfo.maxQuantity
			});
		end
	end

	local numCurrencies = C_CurrencyInfo.GetCurrencyListSize();

	for i = 1, numCurrencies do
		local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(i);

		if ( currencyInfo and not currencyInfo.isHeader and currencyInfo.name ~= "" ) then
			local link = C_CurrencyInfo.GetCurrencyListLink(i);
			local id = tonumber(link:match("currency:(%d+)") or 0);

			table.insert(currencies, {
				type = "currency",
				index = numMerchantCurrencies + i,
				id = id,
				link = link,
				name = currencyInfo.name, -- add name because sometimes we get no itemID for currencies
				count = currencyInfo.quantity,
				max = currencyInfo.maxQuantity
			});
		end
	end
end

local function CurrencyUpdate_Equip()
	for i = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local itemID = tonumber(GetInventoryItemID("player", i) or 0);

		if ( itemID and itemID ~= 0 ) then
			local link = GetInventoryItemLink("player", i);

			table.insert(currencies, {
				type = "equip",
				index = i,
				id = itemID,
				link = link,
				count = 0
			});
		end
	end
end

local function CurrencyUpdate_BagItems()
	for bagID = 0, NUM_BAG_SLOTS do
		local numSlots = GetContainerNumSlots(bagID);

		for slotID=1, numSlots, 1 do
			local count, _, _, _, _, link = select(2, GetContainerItemInfo(bagID, slotID));

			-- if there is no link, then there is no item in this slot
			if ( link ) then
				local itemID = tonumber((link or ""):match("item:(%d+)") or 0);

				if ( itemID and itemID ~= 0 ) then
					local existed = false;

					for _, currency in ipairs(currencies) do
						if ( currency.type == "bagitem" and currency.id == itemID ) then
							currency.count = currency.count + count;
							existed = true;
						end
					end

					if ( not existed ) then
						table.insert(currencies, {
							type = "bagitem",
							id = itemID,
							link = link,
							count = count
						});
					end
				end
			end
		end
	end
end

local function CurrencyUpdate_ReagentBankItems()
	local numReagentBankSlots = GetContainerNumSlots(REAGENTBANK_CONTAINER);

	for slotID=1, numReagentBankSlots, 1 do
		local count, _, _, _, _, link = select(2, GetContainerItemInfo(REAGENTBANK_CONTAINER, slotID));

		-- if there is no link, then there is no item in this slot
		if ( link ) then
			local itemID = tonumber((link or ""):match("item:(%d+)") or 0);

			if ( itemID and itemID ~= 0 ) then
				local existed = false;

				for _, currency in ipairs(currencies) do
					if ( currency.type == "reagentbankitem" and currency.id == itemID ) then
						currency.count = currency.count + count;
						existed = true;
					end
				end

				if ( not existed ) then
					table.insert(currencies, {
						type = "reagentbankitem",
						id = itemID,
						link = link,
						count = count
					});
				end
			end
		end
	end
end

local function CurrencyUpdate()
	wipe(currencies);

	CurrencyUpdate_Currencies();
	CurrencyUpdate_Equip();
	CurrencyUpdate_BagItems();
	CurrencyUpdate_ReagentBankItems();
end

local function UpdateAltCurrency(button, index)
	local currency_frames = {};
	local lastFrame;
	local itemCount = GetMerchantItemCostInfo(index);

	if ( itemCount > 0 ) then
		for i=1, MAX_ITEM_COST, 1 do
			local texture, cost, link, name = GetMerchantItemCostItem(index, i);

			local itemID = tonumber((link or ""):match("item:(%d+)") or 0);
			local currencyID = tonumber((link or ""):match("currency:(%d+)") or 0);
			local item = button.item[i];

			item.itemIndex = index;
			item.costItemIndex = i;

			if ( itemID or currencyID ) then
				local currency = nil;

				for _, c in ipairs(currencies) do
					if (
						(c.type == "equip" or c.type == "bagitem" or c.type == "reagentbankitem")
						and c.id == itemID
					) then
						currency = c;
						break;
					end

					if (c.type == "currency" and c.id == currencyID) then
						currency = c;
						break;
					end
				end

				if ( not currency or (currency and cost and currency.count < cost) ) then
					item.count:SetTextColor(1, 0, 0);
				else
					item.count:SetTextColor(1, 1, 1);
				end

				item.count:SetText(cost);
				item.icon:SetTexture(texture);

				item.count:SetPoint("RIGHT", item.icon, "LEFT", -2, 0);
				item.icon:SetTexCoord(0, 1, 0, 1);

				local iconWidth = 17;
				item.icon:SetWidth(iconWidth);
				item.icon:SetHeight(iconWidth);
				item:SetWidth(item.count:GetWidth() + iconWidth + 4);
				item:SetHeight(item.count:GetHeight() + 4);

				if ( not texture ) then
					item:Hide();
				else
					lastFrame = item;
					table.insert(currency_frames, item);
					item:Show();
				end
			else
				item:Hide();
			end
		end
	else
		for i=1, MAX_ITEM_COST, 1 do
			button.item[i]:Hide();
		end
	end

	table.insert(currency_frames, button.money);
	button.currency_frames = currency_frames;

	lastFrame = nil;

	for i,frame in ipairs(currency_frames) do
		if i == 1 then
			frame:SetPoint("RIGHT", -2, 6);
		else
			if lastFrame then
				frame:SetPoint("RIGHT", lastFrame, "LEFT", -2, 0);
			else
				frame:SetPoint("RIGHT", -2, 0);
			end
		end

		lastFrame = frame;
	end
end

local function isMentionedInErrors(errors, text)
	for i,err in ipairs(errors) do
		if err and err ~= "" and err:match(text) then
			return true;
		end
	end

	return false;
end

local function ProcessCurrency(item)
	local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(item.link);

	if (not currencyInfo) then
		return item;
	end

	item.info.currentAmount = currencyInfo.quantity;
	item.info.earnedThisWeek = currencyInfo.quantityEarnedThisWeek;
	item.info.weeklyMax = currencyInfo.maxWeeklyQuantity;
	item.info.totalMax = currencyInfo.maxQuantity;
	item.info.rarity = currencyInfo.quality;

	if ( item.info.weeklyMax and item.info.weeklyMax > 0 ) then
		table.insert(item.subtext, CURRENCY_WEEKLY_CAP:format("", item.info.earnedThisWeek, item.info.weeklyMax));
	elseif ( item.info.totalMax and item.info.totalMax ) then
		table.insert(item.subtext, CURRENCY_TOTAL_CAP:format("", item.info.currentAmount, item.info.totalMax));
	end

	return item;
end

local function ProcessGetItemInfo(item)
	local _, _, itemRarity, iLevel, _, itemType, itemSubType, _, equipSlot, _, _, itemClassId, itemSubClassId = GetItemInfo(item.link);

	itemRarity = ( itemRarity or Enum.ItemQuality.Common );

	item.info.itemRarity = itemRarity;
	item.info.iLevel = iLevel;
	item.info.itemType = itemType;
	item.info.itemSubType = itemSubType;
	item.info.equipSlot = equipSlot;
	item.info.itemClassId = itemClassId;
	item.info.itemSubClassId = itemSubClassId;

	if ( itemType and itemType == L["RECIPE"] ) then
		item.isRecipe = true;
	end

	item.isEquippable = IsEquippableItem(item.link);
	item.isWeapon = (itemClassId == LE_ITEM_CLASS_WEAPON);
	item.isArmor = (itemClassId == LE_ITEM_CLASS_ARMOR);

	return item;
end

local function ProcessItem(item)
	if ( not item.info ) then
		return item;
	end

	local iLevel = item.info.iLevel;
	local itemRarity = item.info.itemRarity;
	local itemType = item.info.itemType;
	local itemSubType = item.info.itemSubType;
	local equipSlot = item.info.equipSlot;
	local itemClassId = item.info.itemClassId;
	local itemSubClassId = item.info.itemSubClassId;

	-- item level
	if ( item.isEquippable
		and iLevel
		and not ( itemRarity == Enum.ItemQuality.Heirloom and iLevel == 1 )
		and equipSlot ~= "INVTYPE_TABARD"
		and equipSlot ~= "INVTYPE_BAG"
		and equipSlot ~= "INVTYPE_BODY"
	) then
		table.insert(item.subtext, tostring(iLevel));
	end

	-- item type
	if ( item.isWeapon or item.isArmor ) then
		local isGeneric = (itemSubClassId == LE_ITEM_ARMOR_GENERIC); -- neck, finger, trinket, holdable...
		local isCloak = (equipSlot == "INVTYPE_CLOAK");
		local isBag = (equipSlot == "INVTYPE_BAG");

		if ( not ( item.isArmor and ( isGeneric or isCloak or isBag ) ) ) then
			local name = GetItemSubClassInfo(itemClassId, itemSubClassId);

			if ( item.cantEquip ) then
				table.insert(item.subtext, "|cffd00000" .. name .. "|r");
			else
				table.insert(item.subtext, name);
			end
		end
	else
		if ( not item.hasErrors or not isMentionedInErrors(item.errormsgs, itemSubType) ) and not (itemSubClassId == 8) then
			local text = itemSubType;

			if ( item.petCollected and item.petCollectedCount > 0 ) then
				local color = "";

				if ( item.petCollectedCount == item.petCollectedMax ) then
					color = RED_FONT_COLOR_CODE;
					item.hasErrors = true;
				end

				local count = ((" (%d/%d)"):format(item.petCollectedCount, item.petCollectedMax));

				text = color .. text .. count .. "|r";
			end

			table.insert(item.subtext, text);
		end
	end

	-- equip slot
	if ( item.isEquippable
		and equipSlot
		and equipSlot ~= ""
		and _G[equipSlot] ~= itemSubType
		and not ( item.isWeapon or itemSubClassId == LE_ITEM_ARMOR_SHIELD )
	) then
		table.insert(item.subtext, _G[equipSlot]);
	end

	-- transmog: illusions
	if ( item.itemID and ILLUSIONS_LIST[item.itemID] ) then
		item.transmogIsIllusion = true;
		item.transmogIsIllusionKnown = ( illusions[ILLUSIONS_LIST[item.itemID]] == true );
	end

	-- heirlooms
	if ( not item.isRecipe
		and item.itemID
		and itemRarity == Enum.ItemQuality.Heirloom
		and not C_Heirloom.PlayerHasHeirloom(item.itemID)
	) then
		item.heirloomUncollected = true;
	end

	if ( item.isToy
		and item.itemID
		and PlayerHasToy(item.itemID) == false
	) then
		item.toyUncollected = true;
	end

	return item;
end

local function TextMatchesSearch(text)
	return text and text:lower():match(searchText) and true or false;
end

local function ProcessSearch(item)
	item.isSearchedItem = false;

	if ( isSearching ) then
		if ( item.currencyID > 0 ) then
			if ( TextMatchesSearch(item.info.name) ) then
				item.isSearchedItem = true;
			end
		else
			if ( TextMatchesSearch(item.info.name)
				or ( item.info.itemRarity and TextMatchesSearch(_G["ITEM_QUALITY" .. tostring(item.info.itemRarity) .. "_DESC"]) )
				or ( TextMatchesSearch(item.info.itemType) )
				or ( TextMatchesSearch(item.info.itemSubType) )
				or ( item.info.equipSlot and TextMatchesSearch(_G[item.info.equipSlot]) )
			) then
				item.isSearchedItem = true;
			elseif ( searchInTooltip ) then
				tooltip:SetOwner(UIParent, "ANCHOR_NONE");
				tooltip:SetMerchantItem(item.index);

				for i=1, tooltip:NumLines() do
					if ( _G["NuuhMerchantTooltipTextLeft" .. i]:GetText():lower():match(searchText) ) then
						item.isSearchedItem = true;
					end
				end
			end
		end
	end

	return item;
end

local function SortItems()
	table.sort(items, function(a, b)
		return a.index < b.index;
	end);

	if ( isSearching ) then
		local found = {};
		local others = {};

		for _, item in ipairs(items) do
			if ( item.isSearchedItem ) then
				table.insert(found, item);
			else
				table.insert(others, item);
			end
		end

		for _, item in ipairs(others) do
			table.insert(found, item);
		end

		items = found;
	end
end

local function UpdateSearch()
	for i=1, numMerchantItems, 1 do
		if ( items[i] ) then
			items[i] = ProcessSearch(items[i]);
		end
	end

	SortItems();
end

local function resetButtonBackgroundColor(button)
	button.highlight:SetVertexColor(0.5, 0.5, 0.5);
	button.highlight:Hide();
	button.isShown = nil;
end

local function setButtonBackgroundColor(button, r, g, b)
	button.highlight:SetVertexColor(r, g, b);
	button.highlight:Show();
	button.isShown = 1;
end

local function setButtonHoverColor(button, r, g, b)
	button.r = r;
	button.g = g;
	button.b = b;
end

local function MerchantUpdate()
	FauxScrollFrame_Update(NuuhMerchantFrame.scrollframe, numMerchantItems, NUM_BUTTONS, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, nil, nil, nil, nil, nil, nil, 1);

	for i=1, NUM_BUTTONS, 1 do
		local offset = i + FauxScrollFrame_GetOffset(NuuhMerchantFrame.scrollframe);
		local item = items[offset];
		local button = buttons[i];
		button.hover = nil;

		if ( item and item.link and offset <= numMerchantItems ) then
			local qr, qg, qb = GetItemQualityColor(item.info.itemRarity or item.info.rarity);
			local moneyWidth = 0;

			resetButtonBackgroundColor(button);
			setButtonHoverColor(button, 0.5, 0.5, 0.5);

			-- not in stock
			if ( item.info.numAvailable == 0 ) then
				setButtonBackgroundColor(button, 0.5, 0.5, 0.5); -- grey

			-- not useable
			elseif ( not item.info.isUsable ) then
				setButtonBackgroundColor(button, 1, 0.2, 0.2); -- red

			-- errors and not known
			elseif ( item.hasErrors and not item.isKnown ) then
				setButtonBackgroundColor(button, 1, 0.2, 0.2); -- red
			end

			-- not a currency
			if ( item.currencyID == 0 and not item.hasErrors ) then
				setButtonHoverColor(button, qr, qg, qb); -- item quality color

				if ( item.transmogUncollected
					or ( item.transmogIsIllusion and item.transmogIsIllusionKnown )
					or item.toyUncollected
				) then
					setButtonBackgroundColor(button, 0.8, 0.4, 0.8); -- purple
					setButtonHoverColor(button, 0.9, 0.5, 0.9); -- lighter purple
				end

				if ( item.heirloomUncollected ) then
					setButtonBackgroundColor(button, 0, 0.4, 0.5); -- darker heirloom quality color
					setButtonHoverColor(button, qr, qg, qb); -- item quality color (heirloom)
				end
			end

			button.itemname:SetTextColor(qr, qg, qb);

			button.itemname:SetText(
				(item.info.numAvailable >= 0 and "|cffffffff[" .. item.info.numAvailable .. "]|r " or "") ..
				(item.info.quantity > 1 and "|cffffffff" .. item.info.quantity .. "x|r " or "") ..
				(item.info.name or "|cffff0000" .. RETRIEVING_ITEM_INFO)
			);

			button.icon:SetTexture(item.info.texture);

			UpdateAltCurrency(button, item.index);

			if ( item.info.extendedCost and item.info.price <= 0 ) then
				button.extendedCost = true;
				button.money:SetText("");
			elseif ( item.info.extendedCost and item.info.price > 0 ) then
				button.extendedCost = true;
				button.money:SetText(GetMoneyString(item.info.price, true));
			elseif ( item.info.price > 0 ) then
				button.extendedCost = nil;
				button.money:SetText(GetMoneyString(item.info.price, true));
			else
				button.extendedCost = nil;
				button.money:SetText("");
			end

			if ( GetMoney() < item.info.price ) then
				button.money:SetTextColor(1, 0, 0);
			else
				button.money:SetTextColor(1, 1, 1);
			end

			for i,frame in ipairs(button.currency_frames) do
				moneyWidth = moneyWidth + frame:GetWidth();
			end

			local textWidth = NuuhMerchantFrame:GetWidth() - 40 - moneyWidth;

			button.itemname:SetWidth(textWidth);
			button.iteminfo:SetWidth(textWidth);
			button.iteminfo:SetText(table.concat(item.subtext, " - ") or "");

			-- used by refund confirmation popups
			button.name = item.info.name;
			button.link = item.link;
			button.texture = item.info.texture;
			button.price = item.info.price;

			-- used to buy item
			button.count = item.info.quantity;
			button.hasItem = true;
			button:SetID(item.index);

			button:SetAlpha(isSearching and (item.isSearchedItem and 1 or 0.3) or 1);
			button:Show();
		else
			button.hasItem = nil;
			button:Hide();
		end

		if ( button.hasStackSplit == 1 ) then
			StackSplitFrame:Hide();
		end
	end
end

local function UpdateMerchantItems()
	numMerchantItems = GetMerchantNumItems();
	wipe(items);

	for i=1, numMerchantItems, 1 do
		local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i);
		local link = GetMerchantItemLink(i);

		local item = {
			index = i,
			isSearchedItem = false,
			transmogUncollected = false,
			transmogIsIllusion = false,
			transmogIsIllusionKnown = false,
			heirloomUncollected = false,
			toyUncollected = false,
			cantEquip = false,
			hasErrors = false,
			isKnown = false,
			previousRecipeMissing = false,
			isRecipe = false,
			isToy = false,
			isEquippable = false,
			isWeapon = false,
			isArmor = false,
			link = link,
			itemID = 0,
			currencyID = 0,
			petCollected = false,
			petCollectedCount = 0,
			petCollectedMax = 0,
			subtext = {},
			info = {
				name = name,
				texture = texture,
				price = price,
				quantity = quantity,
				numAvailable = numAvailable,
				isUsable = isUsable,
				extendedCost = extendedCost
			}
		};

		if ( link ) then
			item.itemID = tonumber(link:match("item:(%d+)") or 0);
			item.currencyID = tonumber(link:match("currency:(%d+)") or 0);

			if PRESERVED_CONTAMINANT_LIST[item.itemID] then
				local spellID, rank, corruption = unpack(PRESERVED_CONTAMINANT_LIST[item.itemID])
				local spellName, _, spellIcon = GetSpellInfo(spellID)
				if spellName then
					item.info.name = spellName
					if rank and rank > 0 then
						item.info.name = item.info.name .. " " .. string.rep("I", rank)
					end

					item.info.texture = spellIcon
					
					table.insert(item.subtext, CORRUPTION_COLOR:WrapTextInColorCode(ITEM_CORRUPTION_BONUS_STAT:format(corruption)))
				end
			end

			if ( CanIMogIt and CanIMogIt:IsTransmogable(link) ) then
				item.transmogUncollected = (
					CanIMogIt:PlayerKnowsTransmogFromItem(link) == false
					and CanIMogIt:PlayerKnowsTransmog(link) == false
					and CanIMogIt:CharacterCanLearnTransmog(link) == true
				);
			end

			item = ProcessGetItemInfo(item);

			item = ScanItemTooltip(item);

			if ( item.currencyID > 0 ) then
				item = ProcessCurrency(item);
			else
				item = ProcessItem(item);
			end

			if ( ACHIEVEMENT_LIST[item.itemID] ) then
				local _, _, _, completed = GetAchievementInfo(ACHIEVEMENT_LIST[item.itemID]);
				if ( not item.isKnown ) then
					item.isKnown = completed;
				end
			end

			if ( item.transmogIsIllusionKnown or item.isKnown ) and ( not isMentionedInErrors(item.errormsgs, ITEM_SPELL_KNOWN) ) then
				table.insert(item.errormsgs, ITEM_SPELL_KNOWN);
			end

			item.hasErrors = #item.errormsgs > 0;

			if ( item.hasErrors ) then
				table.insert(item.subtext, "|cffd00000" .. table.concat(item.errormsgs, " - ") .. "|r");
			end
		end

		table.insert(items, item);
	end

	-- retry if no data received
	C_Timer.After(0.5, function()
		if ( not MerchantFrame:IsShown() ) then
			return;
		end

		local shouldRetry = false;

		for i=1, #items, 1 do
			if ( not items[i] or not items[i].link ) then
				shouldRetry = true;
				break;
			end
		end

		if ( shouldRetry ) then
			UpdateMerchantItems();
			MerchantUpdate();
		end
	end);

	UpdateSearch();
end

local function OnVerticalScroll(self, offset)
	FauxScrollFrame_OnVerticalScroll(NuuhMerchantFrame.scrollframe, offset, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, MerchantUpdate);
end

local function OnClick(self, button)
	if ( IsModifiedClick() ) then
		MerchantItemButton_OnModifiedClick(self, button);
	else
		MerchantItemButton_OnClick(self, button);
	end
end

local function OnEnter(self)
	if ( self.isShown and not self.hover ) then
		self.oldr, self.oldg, self.oldb = self.highlight:GetVertexColor();
		self.highlight:SetVertexColor(self.r, self.g, self.b);
		self.hover = 1;
	else
		self.highlight:Show();
	end

	MerchantItemButton_OnEnter(self);
end

local function OnLeave(self)
	if ( self.isShown ) then
		self.highlight:SetVertexColor(self.oldr, self.oldg, self.oldb);
		self.hover = nil;
	else
		self.highlight:Hide();
	end

	GameTooltip:Hide();
	ResetCursor();
	MerchantFrame.itemHover = nil;
end

local function SplitStack(button, split)
	if ( button.extendedCost ) then
		MerchantFrame_ConfirmExtendedItemCost(button, split);
	elseif ( split > 0 ) then
		BuyMerchantItem(button:GetID(), split);
	end
end

local function Item_OnClick(self)
	HandleModifiedItemClick(self.itemLink);
	CurrencyUpdate();
end

local function Item_OnEnter(self)
	local parent = self:GetParent();

	if ( parent.isShown and not parent.hover ) then
		parent.oldr, parent.oldg, parent.oldb = parent.highlight:GetVertexColor();
		parent.highlight:SetVertexColor(parent.r, parent.g, parent.b);
		parent.hover = 1;
	else
		parent.highlight:Show();
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetMerchantCostItem(self.itemIndex, self.costItemIndex);
	GameTooltip:Show();

	if ( IsModifiedClick("DRESSUP") ) then
		ShowInspectCursor();
	else
		ResetCursor();
	end
end

local function Item_OnLeave(self)
	local parent = self:GetParent();

	if ( parent.isShown ) then
		parent.highlight:SetVertexColor(parent.oldr, parent.oldg, parent.oldb);
		parent.hover = nil;
	else
		parent.highlight:Hide();
	end

	GameTooltip:Hide();
	ResetCursor();
end

local function OnEvent(self, event, ...)
	if ( event == "ADDON_LOADED" and addonName == select(1, ...) ) then
		self:UnregisterEvent("ADDON_LOADED");

		local x = 0;

		if ( IsAddOnLoaded("SellOMatic") ) then
			x = 20;
		elseif ( IsAddOnLoaded("DropTheCheapestThing") ) then
			x = 14;
		end

		if ( x ~= 0 ) then
			self.search:SetWidth(92-x);
			self.search:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 50-x, 9);
		end

		return;
	end

	if ( event == "BAG_UPDATE_DELAYED" and MerchantFrame:IsShown() ) then
		CurrencyUpdate();
		IllusionsUpdate();
		UpdateMerchantItems();
		MerchantUpdate();
	end
end

local frame = CreateFrame("Frame", "NuuhMerchantFrame", MerchantFrame);
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("BAG_UPDATE_DELAYED");
frame:SetScript("OnEvent", OnEvent);
frame:SetWidth(294);
frame:SetHeight(294);
frame:SetPoint("TOPLEFT", 10, -65);

local function OnTextChanged(self)
	searchText = self:GetText():trim():lower();
	isSearching = searchText ~= "" and searchText ~= SEARCH:lower();

	UpdateSearch();
	MerchantUpdate();

	if ( isSearching ) then
		FauxScrollFrame_OnVerticalScroll(NuuhMerchantFrame.scrollframe, 0, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, function() end);
	end
end

local function OnShow(self)
	self:SetText(SEARCH);
	searchText = "";
end

local function OnEnterPressed(self)
	self:ClearFocus();
end

local function OnEscapePressed(self)
	self:ClearFocus();
	self:SetText(SEARCH);
	searchText = "";
end

local function OnEditFocusLost(self)
	self:HighlightText(0, 0);

	if ( self:GetText():trim() == "" ) then
		self:SetText(SEARCH);
		searchText = "";
	end
end

local function OnEditFocusGained(self)
	self:HighlightText();

	if ( self:GetText():trim():lower() == SEARCH:lower() ) then
		self:SetText("");
	end
end

local search = CreateFrame("EditBox", "$parentSearch", frame, "InputBoxTemplate");
frame.search = search;
search:SetWidth(92);
search:SetHeight(24);
search:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 50, 9);
search:SetAutoFocus(false);
search:SetFontObject(ChatFontSmall);
search:SetScript("OnTextChanged", OnTextChanged);
search:SetScript("OnShow", OnShow);
search:SetScript("OnEnterPressed", OnEnterPressed);
search:SetScript("OnEscapePressed", OnEscapePressed);
search:SetScript("OnEditFocusLost", OnEditFocusLost);
search:SetScript("OnEditFocusGained", OnEditFocusGained);
search:SetText(SEARCH);

local function Search_OnClick(self)
	searchInTooltip = self:GetChecked();

	if ( searchInTooltip ) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
	end

	if ( isSearching ) then
		UpdateSearch();
		MerchantUpdate();
	end
end

local function Search_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(L["Search in item tooltips"]);
end

local tooltipsearching = CreateFrame("CheckButton", "$parentTooltipSearching", frame, "InterfaceOptionsSmallCheckButtonTemplate");
search.tooltipsearching = tooltipsearching;
tooltipsearching:SetWidth(21);
tooltipsearching:SetHeight(21);
tooltipsearching:SetPoint("LEFT", search, "RIGHT", -1, 0);
tooltipsearching:SetHitRectInsets(0, 0, 0, 0);
tooltipsearching:SetScript("OnClick", Search_OnClick);
tooltipsearching:SetScript("OnEnter", Search_OnEnter);
tooltipsearching:SetScript("OnLeave", GameTooltip_Hide);
tooltipsearching:SetChecked(false);

local scrollframe = CreateFrame("ScrollFrame", "NuuhMerchantScrollFrame", frame, "FauxScrollFrameTemplate");
frame.scrollframe = scrollframe;
scrollframe:SetWidth(283);
scrollframe:SetHeight(298);
scrollframe:SetPoint("TOPLEFT", MerchantFrame, 22, -65);
scrollframe:SetScript("OnVerticalScroll", OnVerticalScroll);

local top = frame:CreateTexture("$parentTop", "ARTWORK");
frame.top = top;
top:SetWidth(30);
top:SetHeight(256);
top:SetPoint("TOPRIGHT", 30, 7);
top:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");
top:SetTexCoord(0, 0.484375, 0, 1);

local bottom = frame:CreateTexture("$parentBottom", "ARTWORK");
frame.bottom = bottom;
bottom:SetWidth(30);
bottom:SetHeight(108);
bottom:SetPoint("BOTTOMRIGHT", 30, -8);
bottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");
bottom:SetTexCoord(0.515625, 1, 0, 0.421875);

local function SetFontSize(frame, size)
	local font, _, flags = frame:GetFont();
	frame:SetFont(font, size, flags);
end

for i=1, NUM_BUTTONS, 1 do
	local button = CreateFrame("Button", "NuuhMerchantFrame" .. i, frame);
	button:SetWidth(frame:GetWidth());
	button:SetHeight(scrollframe:GetHeight() / NUM_BUTTONS);

	if ( i == 1 ) then
		button:SetPoint("TOPLEFT", 0, -1);
	else
		button:SetPoint("TOP", buttons[i-1], "BOTTOM");
	end

	button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	button:RegisterForDrag("LeftButton");
	button.UpdateTooltip = OnEnter;
	button.SplitStack = SplitStack;
	button:SetScript("OnClick", OnClick);
	button:SetScript("OnDragStart", MerchantItemButton_OnClick);
	button:SetScript("OnEnter", OnEnter);
	button:SetScript("OnLeave", OnLeave);
	button:SetScript("OnHide", OnHide);

	local icon = button:CreateTexture("$parentIcon", "BORDER");
	button.icon = icon;
	icon:SetWidth(25.4);
	icon:SetHeight(25.4);
	icon:SetPoint("LEFT", 2, 0);
	icon:SetTexture("Interface\\Icons\\temp");

	local highlight = button:CreateTexture("$parentHighlight", "BACKGROUND");
	button.highlight = highlight;
	highlight:SetAllPoints();
	highlight:SetAlpha(0.5);
	highlight:SetBlendMode("ADD");
	highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2");
	highlight:Hide();

	local itemname = button:CreateFontString("ARTWORK", "$parentItemName", "GameFontHighlightSmall");
	button.itemname = itemname;
	itemname:SetPoint("TOPLEFT", icon, "TOPRIGHT", 5, 2);
	itemname:SetJustifyH("LEFT");
	SetFontSize(itemname, 13);
	itemname:SetHeight(15);

	local iteminfo = button:CreateFontString("ARTWORK", "$parentItemInfo", "GameFontDisableSmall");
	button.iteminfo = iteminfo;
	iteminfo:SetPoint("TOPLEFT", itemname, "BOTTOMLEFT", 0, 2);
	iteminfo:SetJustifyH("LEFT");
	SetFontSize(iteminfo, 12);
	iteminfo:SetHeight(16);

	local money = button:CreateFontString("ARTWORK", "$parentMoney", "GameFontHighlight");
	button.money = money;
	money:SetPoint("RIGHT", -2, 0);
	money:SetJustifyH("RIGHT");

	button.item = {};
	button.currency_frames = {};

	for j=1, MAX_ITEM_COST, 1 do
		local item = CreateFrame("Button", "$parentItem" .. j, button);
		button.item[j] = item;
		item:SetWidth(17);
		item:SetHeight(17);

		if ( j == 1 ) then
			item:SetPoint("RIGHT", -2, 0);
		else
			item:SetPoint("RIGHT", button.item[j-1], "LEFT", -2, 0);
		end

		item:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		item:SetScript("OnClick", Item_OnClick);
		item:SetScript("OnEnter", Item_OnEnter);
		item:SetScript("OnLeave", Item_OnLeave);
		item.hasItem = true;
		item.UpdateTooltip = Item_OnEnter;

		local icon = item:CreateTexture("$parentIcon", "BORDER");
		item.icon = icon;
		icon:SetWidth(17);
		icon:SetHeight(17);
		icon:SetPoint("RIGHT");

		local count = item:CreateFontString("ARTWORK", "$parentCount", "GameFontHighlight");
		item.count = count;
		count:SetPoint("RIGHT", icon, "LEFT", -2, 0);
	end

	buttons[i] = button;
end

hooksecurefunc("MerchantFrame_SetFilter", function()
	UpdateMerchantItems();
	MerchantUpdate();
end);

hooksecurefunc("MerchantFrame_Update", function()
	if ( MerchantFrame.selectedTab == 1 ) then
		for i=1, 12, 1 do
			_G["MerchantItem" .. i]:Hide();
		end

		if ( MerchantNameText:GetText() ~= npcName ) then
			if npcName ~= "" then
				-- frame was open, but npc changed
				PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);
			end

			FauxScrollFrame_OnVerticalScroll(NuuhMerchantFrame.scrollframe, 0, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, function() end);
			CurrencyUpdate();
			IllusionsUpdate();
			C_Timer.After(0.01, function()
				UpdateMerchantItems();
				MerchantUpdate();
			end);
		end

		frame:Show();

		npcName = UnitName("NPC");
	else
		frame:Hide();

		for i=1, 12, 1 do
			_G["MerchantItem" .. i]:Show();
		end

		if ( StackSplitFrame:IsShown() ) then
			StackSplitFrame:Hide();
		end
	end
end);

MerchantFrame:HookScript("OnHide", function()
	wipe(currencies);
	wipe(illusions);
	wipe(items);
	npcName = "";
end);

MerchantBuyBackItem:ClearAllPoints();
MerchantBuyBackItem:SetPoint("BOTTOMLEFT", 175, 32);

for _, frame in next, { MerchantNextPageButton, MerchantPrevPageButton, MerchantPageText } do
	frame:Hide();
	frame.Show = function() end;
end
