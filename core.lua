--[[

	xMerchant
	Copyright (c) 2010-2014, Nils Ruesch
	All rights reserved.

]]

local addonName, xm = ...;
local L = xm.L;

local buttons = {};
local knowns = {};
local errors = {};
local factions = {};
local currencies = {};
local searching = "";
local npcName = "";

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

local function GetError(link, isRecipe)
	if ( not link ) then
		return false;
	end

	local id = link:match("item:(%d+)");

	if ( errors[id] ) then
		return errors[id];
	end

	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:SetHyperlink(link);

	local errormsgs = {};

	for i=2, tooltip:NumLines() do
		local frame = _G["NuuhMerchantTooltipTextLeft" .. i];
		local r, g, b = frame:GetTextColor();
		local text = frame:GetText();

		if ( text and r >= 0.9 and g <= 0.2 and b <= 0.2 and text ~= RETRIEVING_ITEM_INFO ) then
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
		end

		frame = _G["NuuhMerchantTooltipTextRight" .. i];
		r, g, b = frame:GetTextColor();
		text = frame:GetText();

		if ( text and r >= 0.9 and g <= 0.2 and b <= 0.2 ) then
			table.insert(errormsgs, text);
		end

		if ( isRecipe and i == 5 ) then
			break;
		end
	end

	if #errormsgs == 0 then
		return false;
	end

	errors[id] = errormsgs;

	return errormsgs;
end

local function GetKnown(link)
	if ( not link ) then
		return false;
	end

	local id = link:match("item:(%d+)");

	if ( knowns[id] ) then
		return true;
	end

	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:SetHyperlink(link);

	for i=1, tooltip:NumLines() do
		if ( _G["NuuhMerchantTooltipTextLeft" .. i]:GetText() == ITEM_SPELL_KNOWN ) then
			knowns[id] = true;
			return true;
		end
	end

	return false;
end

local function IsAppearanceUnknown(link)
	if ( not link ) then
		return false;
	end

	local id = link:match("item:(%d+)");

	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:SetHyperlink(link);

	for i=1, tooltip:NumLines() do
		if ( _G["NuuhMerchantTooltipTextLeft" .. i]:GetText() == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN ) then
			return true;
		end
	end

	return false;
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

				for _, i in ipairs(currencies) do
					if ( currencies[i] and currencies[i].id == tonumber(itemID) ) then
						currencies[i].count = currencies[i].count + count;
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

local function UpdateAltCurrency(button, index, i)
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

local function GetFilteredMerchantItemIndexes()
	local numMerchantItems = GetMerchantNumItems();
	local items = {};
	local isSearching = searching ~= "" and searching ~= SEARCH:lower();

	for i=1, numMerchantItems, 1 do
		local item = { index = i, isSearchedItem = false };
		local name = GetMerchantItemInfo(i);
		local link = GetMerchantItemLink(i);

		if ( isSearching and link ) then
			local currencyID = link:match("currency:(%d+)");

			if ( currencyID and name:lower():match(searching) ) then
				item.isSearchedItem = true;
			elseif ( not currencyID ) then
				local _, _, itemRarity, _, _, itemType, itemSubType, _, equipSlot = GetItemInfo(link);

				itemRarity = itemRarity or LE_ITEM_QUALITY_COMMON;

				if ( name:lower():match(searching)
					or ( itemRarity and (
						tostring(itemRarity):lower():match(searching) or
						_G["ITEM_QUALITY" .. tostring(itemRarity) .. "_DESC"]:lower():match(searching)
					) )
					or ( itemType and itemType:lower():match(searching) )
					or ( itemSubType and itemSubType:lower():match(searching) )
					or ( equipSlot and _G[equipSlot] and _G[equipSlot]:lower():match(searching) )
				) then
					item.isSearchedItem = true;
				elseif ( NuuhMerchantFrame.tooltipsearching ) then
					tooltip:SetOwner(UIParent, "ANCHOR_NONE");
					tooltip:SetHyperlink(link);

					for i=1, tooltip:NumLines() do
						if ( _G["NuuhMerchantTooltipTextLeft" .. i]:GetText():lower():match(searching) ) then
							item.isSearchedItem = true;
							break;
						end
					end
				end
			end
		end

		table.insert(items, item);
	end

	table.sort(items, function(a, b)
		return a.isSearchedItem and not b.isSearchedItem;
	end);

	return numMerchantItems, items, isSearching;
end

local function MerchantUpdate()
	local self = NuuhMerchantFrame;
	local numMerchantItems, items, isSearching = GetFilteredMerchantItemIndexes();

	FauxScrollFrame_Update(self.scrollframe, numMerchantItems, NUM_BUTTONS, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, nil, nil, nil, nil, nil, nil, 1);

	for i=1, NUM_BUTTONS, 1 do
		local offset = i + FauxScrollFrame_GetOffset(self.scrollframe);
		local item = items[offset];
		local button = buttons[i];
		button.hover = nil;

		if ( offset <= numMerchantItems ) then
			local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(item.index);
			local link = GetMerchantItemLink(item.index);
			local r, g, b = 0.5, 0.5, 0.5;
			local itemType, errormsgs;
			local subtext = {};

			if ( numAvailable == 0 ) then
				button.highlight:SetVertexColor(0.5, 0.5, 0.5, 0.5);
				button.highlight:Show();
				button.isShown = 1;
			elseif ( not isUsable ) then
				button.highlight:SetVertexColor(1, 0.2, 0.2, 0.5);
				button.highlight:Show();
				button.isShown = 1;

				errormsgs = GetError(link, itemType and itemType == RECIPE);
			elseif ( itemType and itemType == RECIPE and not GetKnown(link) ) then
				button.highlight:SetVertexColor(0.2, 1, 0.2, 0.5);
				button.highlight:Show();
				button.isShown = 1;
			else
				button.highlight:SetVertexColor(r, g, b, 0.5);
				button.highlight:Hide();
				button.isShown = nil;

				errormsgs = GetError(link, itemType and itemType == RECIPE);

				if errormsgs and GetKnown(link) then
					button.highlight:SetVertexColor(1, 0.2, 0.2, 0.5);
					button.highlight:Show();
					button.isShown = 1;
				end
			end

			if ( link ) then
				local currencyID = link:match("currency:(%d+)");

				if ( currencyID ) then
					local _, currentAmount, _, earnedThisWeek, weeklyMax, totalMax, _, rarity = GetCurrencyInfo(link);

					button.itemname:SetTextColor(GetItemQualityColor(rarity));

					if ( weeklyMax and weeklyMax > 0 ) then
						table.insert(subtext, CURRENCY_WEEKLY_CAP:format("", earnedThisWeek, weeklyMax));
					elseif ( totalMax and totalMax ) then
						table.insert(subtext, CURRENCY_TOTAL_CAP:format("", currentAmount, totalMax));
					end
				else
					local _, itemRarity, iLevel, itemSubType, equipSlot, itemClassId, itemSubClassId;
					_, _, itemRarity, iLevel, _, itemType, itemSubType, _, equipSlot, _, _, itemClassId, itemSubClassId = GetItemInfo(link);

					local isWeapon = (itemClassId == LE_ITEM_CLASS_WEAPON);
					local isArmor = (itemClassId == LE_ITEM_CLASS_ARMOR);

					itemRarity = itemRarity or LE_ITEM_QUALITY_COMMON;

					local qr, qg, qb = GetItemQualityColor(itemRarity);
					button.itemname:SetTextColor(qr, qg, qb);

					if not errormsgs then
						r, g, b = qr, qg, qb;
					else
						r, g, b = 1, 0.3, 0.3;
					end

					-- item level
					if IsEquippableItem(link)
						and iLevel
						and not (itemRarity == 7 and iLevel == 1) -- don't show if heirloom and ilvl == 1
						and equipSlot ~= "INVTYPE_TABARD"
						and equipSlot ~= "INVTYPE_BAG"
						and equipSlot ~= "INVTYPE_BODY"
					then
						table.insert(subtext, tostring(iLevel));
					end

					-- item type
					if isWeapon or isArmor then
						local isGeneric = (itemSubClassId == LE_ITEM_ARMOR_GENERIC); -- neck, finger, trinket, holdable...
						local isCloak = (equipSlot == "INVTYPE_CLOAK");
						local isBag = (equipSlot == "INVTYPE_BAG");

						if not (isArmor and (isGeneric or isCloak or isBag)) then
							local name = GetItemSubClassInfo(itemClassId, itemSubClassId);
							table.insert(subtext, name);
						end
					else
						if not errormsgs or not isMentionedInErrors(errormsgs, itemSubType) then
							table.insert(subtext, itemSubType);
						end
					end

					-- equip slot
					if IsEquippableItem(link)
						and equipSlot
						and equipSlot ~=""
						and _G[equipSlot] ~= itemSubType
						and not (isWeapon or itemSubClassId == LE_ITEM_ARMOR_SHIELD)
					then
						table.insert(subtext, _G[equipSlot]);
					end

					if itemRarity > LE_ITEM_QUALITY_COMMON and IsAppearanceUnknown(link) then
						button.highlight:SetVertexColor(0.8, 0.4, 0.8, 0.5);
						button.highlight:Show();
						button.isShown = 1;

						r, g, b = 0.9, 0.5, 0.9
					end
				end
			end

			button.itemname:SetText(
				(numAvailable >= 0 and "|cffffffff[" .. numAvailable .. "]|r " or "") ..
				(quantity > 1 and "|cffffffff" .. quantity .. "x|r " or "") ..
				(name or "|cffff0000" .. RETRIEVING_ITEM_INFO)
			);

			button.icon:SetTexture(texture);

			UpdateAltCurrency(button, offset, i);

			if ( extendedCost and price <= 0 ) then
				button.price = nil;
				button.extendedCost = true;
				button.money:SetText("");
			elseif ( extendedCost and price > 0 ) then
				button.price = price;
				button.extendedCost = true;
				button.money:SetText(GetMoneyString(price, true));
			else
				button.price = price;
				button.extendedCost = nil;
				button.money:SetText(GetMoneyString(price, true));
			end

			if ( GetMoney() < price ) then
				button.money:SetTextColor(1, 0, 0);
			else
				button.money:SetTextColor(1, 1, 1);
			end

			local moneyWidth = 0;

			for i,frame in ipairs(button.currency_frames) do
				moneyWidth = moneyWidth + frame:GetWidth();
			end

			local textWidth = NuuhMerchantFrame:GetWidth() - 40 - moneyWidth;

			button.itemname:SetWidth(textWidth);
			button.iteminfo:SetWidth(textWidth);

			if errormsgs then
				table.insert(subtext, "|cffd00000" .. table.concat(errormsgs, " - ") .. "|r");
			end

			button.iteminfo:SetText(table.concat(subtext, " - ") or "");

			button.r = r;
			button.g = g;
			button.b = b;
			button.link = link;
			button.hasItem = true;
			button.texture = texture;
			button:SetID(offset);
			button:Show();
			button:SetAlpha(isSearching and (item.isSearchedItem and 1 or 0.3) or 1);
		else
			button.price = nil;
			button.hasItem = nil;
			button:Hide();
		end
		if ( button.hasStackSplit == 1 ) then
			StackSplitFrame:Hide();
		end
	end
end

local function OnVerticalScroll(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, MerchantUpdate);
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
		self.oldr, self.oldg, self.oldb, self.olda = self.highlight:GetVertexColor();
		self.highlight:SetVertexColor(self.r, self.g, self.b, self.olda);
		self.hover = 1;
	else
		self.highlight:Show();
	end

	MerchantItemButton_OnEnter(self);
end

local function OnLeave(self)
	if ( self.isShown ) then
		self.highlight:SetVertexColor(self.oldr, self.oldg, self.oldb, self.olda);
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
		parent.oldr, parent.oldg, parent.oldb, parent.olda = parent.highlight:GetVertexColor();
		parent.highlight:SetVertexColor(parent.r, parent.g, parent.b, parent.olda);
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
		parent.highlight:SetVertexColor(parent.oldr, parent.oldg, parent.oldb, parent.olda);
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

	if ( event == "BAG_UPDATE_DELAYED" ) then
		CurrencyUpdate();
		FactionsUpdate();
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
	searching = self:GetText():trim():lower();
	MerchantUpdate();
	if ( searching ~= "" and searching ~= SEARCH:lower() ) then
		FauxScrollFrame_OnVerticalScroll(NuuhMerchantFrame.scrollframe, 0, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, MerchantUpdate);
	end
end

local function OnShow(self)
	self:SetText(SEARCH);
	searching = "";
end

local function OnEnterPressed(self)
	self:ClearFocus();
end

local function OnEscapePressed(self)
	self:ClearFocus();
	self:SetText(SEARCH);
	searching = "";
end

local function OnEditFocusLost(self)
	self:HighlightText(0, 0);

	if ( strtrim(self:GetText()) == "" ) then
		self:SetText(SEARCH);
		searching = "";
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
	if ( self:GetChecked() ) then
		PlaySound("igMainMenuOptionCheckBoxOn");
		frame.tooltipsearching = 1;
	else
		PlaySound("igMainMenuOptionCheckBoxOff");
		frame.tooltipsearching = nil;
	end

	if ( searching ~= "" and searching ~= SEARCH:lower() ) then
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

local function Update()
	if MerchantNameText:GetText() ~= npcName then
		FauxScrollFrame_OnVerticalScroll(NuuhMerchantFrame.scrollframe, 0, NuuhMerchantScrollFrame:GetHeight() / NUM_BUTTONS, MerchantUpdate);
	end

	npcName = UnitName("NPC");

	if ( MerchantFrame.selectedTab == 1 ) then
		for i=1, 12, 1 do
			_G["MerchantItem" .. i]:Hide();
		end

		frame:Show();
		CurrencyUpdate();
		FactionsUpdate();
		MerchantUpdate();
	else
		frame:Hide();

		for i=1, 12, 1 do
			_G["MerchantItem" .. i]:Show();
		end

		if ( StackSplitFrame:IsShown() ) then
			StackSplitFrame:Hide();
		end
	end
end

hooksecurefunc("MerchantFrame_Update", Update);

local function OnHide()
	wipe(errors);
	wipe(currencies);
	npcName = "";
end

hooksecurefunc("MerchantFrame_OnHide", OnHide);

MerchantBuyBackItem:ClearAllPoints();
MerchantBuyBackItem:SetPoint("BOTTOMLEFT", 175, 32);

for _, frame in next, { MerchantNextPageButton, MerchantPrevPageButton, MerchantPageText } do
	frame:Hide();
	frame.Show = function() end;
end
