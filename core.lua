--[[

	xMerchant
	Copyright (c) 2010-2014, Nils Ruesch
	All rights reserved.

]]

local addonName, xm = ...;
local L = xm.L;

local buttons = {};
local knowns = {};
local factions = {};
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

-- "Requires %s - %s" to "Requires (%s+) - (%s+)"
local REQUIRES_REPUTATION = ITEM_REQ_REPUTATION:gsub("%%s", "(%%a+)");

-- "Requires %s (%d)" to "Requires (%s+) %((%d+)%)"
local REQUIRES_SKILL = ITEM_MIN_SKILL:gsub("%%1?$?s", "(%%a+)"):gsub("%(%%2?$?d%)", "%%((%%d+)%%)");

-- "Classes: %s" to "Classes: (.*)"
local REQUIRES_CLASSES = ITEM_CLASSES_ALLOWED:gsub("%%s", "(.*)");

-- "Requires %s" to "Requires (.*)"
local REQUIRES = ITEM_REQ_SKILL:gsub("%%1?$?s", "(.*)");

local tooltip = CreateFrame("GameTooltip", "NuuhMerchantTooltip", UIParent, "GameTooltipTemplate");

local NUM_BUTTONS = 8;

-- Only illusions we can buy
local ILLUSIONS_LIST = {
	-- [itemID] = sourceID
	[138796] = 3225, -- [Illusion: Executioner]
	[138803] = 4066, -- [Illusion: Mending]
	[138954] = 5364, -- [Illusion: Poisoned]
};

local function ScanItemTooltip(item)
	if ( not item.link or item.tooltipScanned ) then
		return item;
	end

	item.tooltipScanned = true;

	local isRecipe = item.info.itemType and item.info.itemType == RECIPE;
	local itemRarity = item.info.itemRarity;

	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:SetHyperlink(item.link);

	local errormsgs = {};
	local numLines = tooltip:NumLines();

	for i=2, numLines do
		local frame = _G["NuuhMerchantTooltipTextLeft" .. i];
		local r, g, b = frame:GetTextColor();
		local text = frame:GetText();

		if ( text and text ~= RETRIEVING_ITEM_INFO ) then
			if ( r >= 0.9 and g <= 0.2 and b <= 0.2 ) then
				local level = text:match(REQUIRES_LEVEL);

				if ( level ) then
					table.insert(errormsgs, LEVEL_GAINED:format(level));
				end

				if ( not level ) then
					local reputation, factionName = text:match(REQUIRES_REPUTATION);

					if ( reputation and factionName ) then
						local standingLabel = factions[factionName];

						if ( standingLabel ) then
							table.insert(errormsgs, reputation .. " (" .. standingLabel .. ") - " .. factionName);
						else
							table.insert(errormsgs, reputation .. " - " .. factionName);
						end
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

				local classes = text:match(REQUIRES_CLASSES);

				if ( not level and not reputation and not skill and not requires and classes ) then
					table.insert(errormsgs, classes);
				end

				if ( text and not level and not reputation and not skill and not requires and not classes ) then
					table.insert(errormsgs, text);
				end

				if ( text == ITEM_SPELL_KNOWN ) then
					item.isKnown = true;
				end
			end

			if ( itemRarity and itemRarity > LE_ITEM_QUALITY_COMMON
				and ( text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN or text == TRANSMOGRIFY_STYLE_UNCOLLECTED ))
			then
				item.transmogUncollected = true;
			end
		end

		--[[
		frame = _G["NuuhMerchantTooltipTextRight" .. i];
		r, g, b = frame:GetTextColor();
		text = frame:GetText();

		if ( text and r >= 0.9 and g <= 0.2 and b <= 0.2 ) then
			table.insert(errormsgs, text);
		end
		]]--
	end

	item.errormsgs = errormsgs;
	item.hasErrors = #errormsgs > 0;

	return item;
end

local function FactionsUpdate()
	wipe(factions);

	for factionIndex = 1, GetNumFactions() do
		local name, _, standingId, _, _, _, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(factionIndex);
		local friendID, _, _, _, _, _, friendTextLevel = GetFriendshipReputation(factionID);

		if isHeader == nil then
			local standingLabel;

			if friendID ~= nil then
				standingLabel = friendTextLevel or UNKNOWN;
			else
				standingLabel = _G["FACTION_STANDING_LABEL" .. tostring(standingId)] or UNKNOWN;
			end

			factions[name] = standingLabel;
	 	end
	end
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

local function CurrencyUpdate()
	wipe(currencies);

	local limit = GetCurrencyListSize();

	for i=1, limit do
		local name, isHeader, _, _, _, count, _, max = GetCurrencyListInfo(i);

		if ( not isHeader and name and name ~= "" ) then
			local link = GetCurrencyListLink(i);
			local id = link:match("currency:(%d+)");

			table.insert(currencies, {
				type = "currency",
				index = i,
				id = tonumber(id),
				link = link,
				name = name,
				count = count,
				max = max
			});
		end
	end

	for i=INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED, 1 do
		local itemID = GetInventoryItemID("player", i);

		if ( itemID ) then
			table.insert(currencies, {
				type = "equip",
				index = i,
				id = tonumber(itemID),
				count = 1
			});
		end
	end

	for bagID=0, NUM_BAG_SLOTS, 1 do
		local numSlots = GetContainerNumSlots(bagID);

		for slotID=1, numSlots, 1 do
			local itemID = GetContainerItemID(bagID, slotID);

			if ( itemID and itemID ~= 0 ) then
				local count, _, _, _, _, link = select(2, GetContainerItemInfo(bagID, slotID));
				local existed = false;

				for _, currency in ipairs(currencies) do
					if ( currency.id == tonumber(itemID) ) then
						currency.count = currency.count + count;
						existed = true;
					end
				end

				if ( not existed ) then
					table.insert(currencies, {
						type = "bagitem",
						id = tonumber(itemID),
						link = link,
						count = count
					});
				end
			end
		end
	end
end

local function UpdateAltCurrency(button, index)
	local currency_frames = {};
	local lastFrame;
	local itemCount = GetMerchantItemCostInfo(index);

	if ( itemCount > 0 ) then
		for i=1, MAX_ITEM_COST, 1 do
			local texture, cost, link, currencyName = GetMerchantItemCostItem(index, i);
			local item = button.item[i];
			item.index = index;

			local itemID = tonumber((link or "item:0"):match("item:(%d+)"));
			local currency = nil;

			if ( itemID and itemID ~= 0 ) then
				for _, c in ipairs(currencies) do
					if ( c.id == itemID ) then
						currency = c;
						break;
					end
				end
			end

			if ( not currency and currencyName ) then
				for _, c in ipairs(currencies) do
					if ( c.name == currencyName ) then
						currency = c;
						break;
					end
				end
			end

			item.currency = currency;
			item.link = link;

			if ( currency and cost and currency.count < cost or not currency ) then
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
	local _, currentAmount, _, earnedThisWeek, weeklyMax, totalMax, _, rarity = GetCurrencyInfo(item.link);

	item.info.currentAmount = currentAmount;
	item.info.earnedThisWeek = earnedThisWeek;
	item.info.weeklyMax = weeklyMax;
	item.info.totalMax = totalMax;
	item.info.rarity = rarity;

	if ( weeklyMax and weeklyMax > 0 ) then
		table.insert(item.subtext, CURRENCY_WEEKLY_CAP:format("", earnedThisWeek, weeklyMax));
	elseif ( totalMax and totalMax ) then
		table.insert(item.subtext, CURRENCY_TOTAL_CAP:format("", currentAmount, totalMax));
	end

	return item;
end

local function ProcessItem(item)
	local _, _, itemRarity, iLevel, _, itemType, itemSubType, _, equipSlot, _, _, itemClassId, itemSubClassId = GetItemInfo(item.link);

	itemRarity = ( itemRarity or LE_ITEM_QUALITY_COMMON );

	item.info.itemRarity = itemRarity;
	item.info.iLevel = iLevel;
	item.info.itemType = itemType;
	item.info.itemSubType = itemSubType;
	item.info.equipSlot = equipSlot;
	item.info.itemClassId = itemClassId;
	item.info.itemSubClassId = itemSubClassId;

	local isEquippable = IsEquippableItem(item.link);
	local isWeapon = (itemClassId == LE_ITEM_CLASS_WEAPON);
	local isArmor = (itemClassId == LE_ITEM_CLASS_ARMOR);

	-- item level
	if isEquippable
		and iLevel
		and not (itemRarity == 7 and iLevel == 1) -- don't show if heirloom and ilvl == 1
		and equipSlot ~= "INVTYPE_TABARD"
		and equipSlot ~= "INVTYPE_BAG"
		and equipSlot ~= "INVTYPE_BODY"
	then
		table.insert(item.subtext, tostring(iLevel));
	end

	-- item type
	if ( isWeapon or isArmor ) then
		local isGeneric = (itemSubClassId == LE_ITEM_ARMOR_GENERIC); -- neck, finger, trinket, holdable...
		local isCloak = (equipSlot == "INVTYPE_CLOAK");
		local isBag = (equipSlot == "INVTYPE_BAG");

		if not (isArmor and (isGeneric or isCloak or isBag)) then
			local name = GetItemSubClassInfo(itemClassId, itemSubClassId);
			table.insert(item.subtext, name);
		end
	else
		if not item.hasErrors or not isMentionedInErrors(item.errormsgs, itemSubType) then
			table.insert(item.subtext, itemSubType);
		end
	end

	-- equip slot
	if isEquippable
		and equipSlot
		and equipSlot ~=""
		and _G[equipSlot] ~= itemSubType
		and not (isWeapon or itemSubClassId == LE_ITEM_ARMOR_SHIELD)
	then
		table.insert(item.subtext, _G[equipSlot]);
	end

	-- transmog: illusions
	if ( item.itemID and ILLUSIONS_LIST[item.itemID] ) then
		item.transmogIsIllusion = true;
		item.transmogIsIllusionKnown = ( illusions[ILLUSIONS_LIST[item.itemID]] == false );
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
			if (
				TextMatchesSearch(item.info.name)
				or ( item.info.itemRarity and TextMatchesSearch(_G["ITEM_QUALITY" .. tostring(item.info.itemRarity) .. "_DESC"]) )
				or ( TextMatchesSearch(item.info.itemType) )
				or ( TextMatchesSearch(item.info.itemSubType) )
				or ( item.info.equipSlot and TextMatchesSearch(_G[item.info.equipSlot]) )
			) then
				item.isSearchedItem = true;
			elseif ( searchInTooltip ) then
				tooltip:SetOwner(UIParent, "ANCHOR_NONE");
				tooltip:SetHyperlink(item.link);

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
			if (item.isSearchedItem) then
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
			hasErrors = false,
			isKnown = false,
			link = link,
			itemID = 0,
			currencyID = 0,
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

			if ( item.currencyID > 0 ) then
				item = ProcessCurrency(item);
			else
				item = ProcessItem(item);
			end

			item = ScanItemTooltip(item);

			if ( item.transmogIsIllusionKnown ) then
				table.insert(item.errormsgs, ITEM_SPELL_KNOWN);
				item.hasErrors = true;
			end

			if ( item.hasErrors ) then
				table.insert(item.subtext, "|cffd00000" .. table.concat(item.errormsgs, " - ") .. "|r");
			end
		end

		table.insert(items, item);
	end

	-- retry if no data received
	C_Timer.After(0.5, function()
		if ( #items > 0 and items[1].link == nil and MerchantFrame:IsShown() ) then
			UpdateMerchantItems();
			MerchantUpdate();
		end
	end);

	UpdateSearch();
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

			-- recipe and not known
			elseif ( item.info.itemType and item.info.itemType == RECIPE and not item.isKnown ) then
				setButtonBackgroundColor(button, 0.2, 1, 0.2); -- green

			-- errors and known
			elseif item.hasErrors and item.isKnown then
				setButtonBackgroundColor(button, 1, 0.2, 0.2); -- red
			end

			if ( item.currencyID == 0 ) then
				if ( item.hasErrors ) then
					setButtonHoverColor(button, 1, 0.2, 0.2); -- red
				else
					setButtonHoverColor(button, qr, qg, qb); -- item quality color
				end

				if ( item.transmogUncollected or ( item.transmogIsIllusion and item.transmogIsIllusionKnown ) ) then
					setButtonBackgroundColor(button, 0.8, 0.4, 0.8); -- purple
					setButtonHoverColor(button, 0.9, 0.5, 0.9); -- lighter purple
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
			else
				button.extendedCost = nil;
				button.money:SetText(GetMoneyString(item.info.price, true));
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

	if ( self.currency ) then
		if ( self.currency.type == "currency" ) then
			GameTooltip:SetCurrencyToken(self.currency.index);
		elseif (self.currency.type == "equip" ) then
			GameTooltip:SetInventoryItem("player", self.currency.index, nil, true);
		elseif (self.currency.type == "bagitem" ) then
			GameTooltip:SetHyperlink(self.currency.link);
		end

		GameTooltip:Show();
	elseif ( self.link ) then
		GameTooltip:SetHyperlink(self.link);
		GameTooltip:Show();
	end

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
		FactionsUpdate();
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
	PlaySound("igMainMenuOptionCheckBox" .. (searchInTooltip and "On" or "Off"));

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
	itemname:SetTextHeight(13);
	itemname:SetHeight(15);

	local iteminfo = button:CreateFontString("ARTWORK", "$parentItemInfo", "GameFontDisableSmall");
	button.iteminfo = iteminfo;
	iteminfo:SetPoint("TOPLEFT", itemname, "BOTTOMLEFT", 0, 2);
	iteminfo:SetJustifyH("LEFT");
	iteminfo:SetTextHeight(12);
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

hooksecurefunc("MerchantFrame_Update", function()
	if ( MerchantNameText:GetText() ~= npcName ) then
		if npcName ~= "" then
			-- frame was open, but npc changed
			PlaySound("igCharacterInfoOpen");
		end

		FauxScrollFrame_OnVerticalScroll(NuuhMerchantFrame.scrollframe, 0, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, function() end);
		CurrencyUpdate();
		FactionsUpdate();
		IllusionsUpdate();
		C_Timer.After(0.01, function()
			UpdateMerchantItems();
			MerchantUpdate();
			frame:Show();
		end);
	end

	npcName = UnitName("NPC");

	if ( MerchantFrame.selectedTab == 1 ) then
		for i=1, 12, 1 do
			_G["MerchantItem" .. i]:Hide();
		end
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
	wipe(factions);
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
