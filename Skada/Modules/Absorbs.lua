local _, Skada = ...
local Private = Skada.Private

-- cache frequently used globals
local pairs, format, uformat = pairs, string.format, Private.uformat
local new, del = Private.newTable, Private.delTable

-- ============== --
-- Absorbs module --
-- ============== --

Skada:RegisterModule("Absorbs", function(L, P)
	local mod = Skada:NewModule("Absorbs")
	local playermod = mod:NewModule("Absorb spell list")
	local targetmod = mod:NewModule("Absorbed target list")
	local spellmod = targetmod:NewModule("Absorb spell list")
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100
	local COMBATLOG_OBJECT_AFFILIATION_OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER or 0x00000008
	local COMBATLOG_OBJECT_REACTION_MASK = COMBATLOG_OBJECT_REACTION_MASK or 0x000000F0

	local band, wipe = bit.band, wipe
	local del, clear = Private.delTable, Private.clearTable
	local mod_cols = nil

	local function format_valuetext(d, columns, total, aps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Absorbs and Skada:FormatNumber(d.value),
			columns[subview and "sAPS" or "APS"] and aps and Skada:FormatNumber(aps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_spellcast(set, actorid, actorname, actorflags, spellid, spellschool)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local actor = Skada:FindPlayer(set, actorid, actorname, actorflags)
		if actor and actor.absorbspells and actor.absorbspells[spellid] then
			actor.absorbspells[spellid].casts = (actor.absorbspells[spellid].casts or 1) + 1

			-- fix possible missing spell school.
			if not actor.absorbspells[spellid].school and spellschool then
				actor.absorbspells[spellid].school = spellschool
			end
		end
	end

	local absorb = {}
	local function log_absorb(set, nocount)
		if not absorb.spellid then return end

		local amount = max(0, absorb.amount - absorb.overheal)
		if amount == 0 then return end

		local actor = Skada:GetPlayer(set, absorb.actorid, absorb.actorname)
		if not actor then
			return
		elseif actor.role ~= "DAMAGER" and not passiveSpells[absorb.spellid] and not nocount then
			Skada:AddActiveTime(set, actor, absorb.dstName)
		end

		-- add absorbs amount
		actor.absorb = (actor.absorb or 0) + amount
		set.absorb = (set.absorb or 0) + amount

		if absorb.overheal then
			actor.overheal = (actor.overheal or 0) + absorb.overheal
			set.overheal = (set.overheal or 0) + absorb.overheal
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell
		local spell = actor.absorbspells and actor.absorbspells[absorb.spellid]
		if not spell then
			actor.absorbspells = actor.absorbspells or {}
			spell = {school = absorb.school, amount = amount, o_amt = absorb.overheal, count = 1}
			actor.absorbspells[absorb.spellid] = spell
		else
			if not spell.school and absorb.school then
				spell.school = absorb.school
			end
			spell.amount = (spell.amount or 0) + amount
			if not nocount then
				spell.count = (spell.count or 0) + 1
			end

			if absorb.overheal then
				spell.o_amt = (spell.o_amt or 0) + absorb.overheal
			end
		end

		-- start cast counter.
		spell.casts = spell.casts or 1

		if not spell.min or amount < spell.min then
			spell.min = amount
		end
		if not spell.max or amount > spell.max then
			spell.max = amount
		end

		-- record the target
		if not absorb.dstName then return end
		local target = spell.targets and spell.targets[absorb.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[absorb.dstName] = {amount = amount, o_amt = absorb.overheal}
		else
			target.amount = target.amount + amount
			if absorb.overheal then
				target.o_amt = (target.o_amt or 0) + amount
			end
		end
	end

	local BITMASK_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100
	local BITMASK_REACTION_MASK = COMBATLOG_OBJECT_REACTION_MASK or 0x000000F0
	local BITMASK_AFFILIATION_OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER or 0x00000008

	local function validate_shield(srcFlags, dstFlags)
		local valid = band(srcFlags, dstFlags, BITMASK_CONTROL_PLAYER) ~= 0
		valid = valid and (band(srcFlags, BITMASK_AFFILIATION_OUTSIDER) == 0)
		valid = valid and (band(dstFlags, BITMASK_AFFILIATION_OUTSIDER) == 0)
		valid = valid and (band(srcFlags, dstFlags, BITMASK_REACTION_MASK) ~= 0)
		return valid
	end

	local shields = {}
	local function handle_shield(_, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, spellschool, _, amount = ...
		if not amount or not spellid or ignoredSpells[spellid] then return end

		dstName = Skada:FixPetsName(dstGUID, dstName, dstFlags)

		if eventtype == "SPELL_AURA_APPLIED" then
			if not validate_shield(srcFlags, dstFlags) then return end

			local shield = shields[dstName] and shields[dstName][spellid]
			if not shield then
				shields[dstName] = shields[dstName] or new()
				shields[dstName][spellid] = new()
				shield = shields[dstName][spellid]
			end
			shield[srcName] = amount
		elseif eventtype == "SPELL_AURA_REFRESH" then
			local prev_amount = shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName]
			if not prev_amount then return end

			absorb.actorid, absorb.actorname, absorb.actorflags = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			absorb.dstName = dstName

			absorb.spellid = spellid
			absorb.school = spellschool
			absorb.amount = 0
			absorb.overheal = prev_amount

			Skada:DispatchSets(log_absorb)
			shields[dstName][spellid][srcName] = amount -- refresh amount
		else
			local prev_amount = shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName]
			if prev_amount then
				absorb.actorid, absorb.actorname, absorb.actorflags = Skada:FixMyPets(srcGUID, srcName, srcFlags)
				absorb.dstName = dstName

				absorb.spellid = spellid
				absorb.school = spellschool
				absorb.amount = 0
				absorb.overheal = amount

				Skada:DispatchSets(log_absorb)
			end

			shields[dstName][spellid][srcName] = nil -- remove shield
		end
	end

	local function spell_absorbed(_, _, _, _, srcFlags, _, dstName, dstFlags, ...)
		if band(srcFlags, BITMASK_CONTROL_PLAYER) == 0 or band(srcFlags, dstFlags, BITMASK_REACTION_MASK) == 0 then
			return
		end

		local absGUID, absName, absFlags, _, spellid, _, spellschool, amount = ...
		if type(absGUID) == "number" then
			_, _, _, absGUID, absName, absFlags, _, spellid, _, spellschool, amount = ...
		end

		if not ignoredSpells[spellid] then
			absorb.actorid, absorb.actorname, absorb.actorflags = Skada:FixMyPets(absGUID, absName, absFlags)
			absorb.dstName = dstName

			absorb.spellid = spellid
			absorb.school = spellschool
			absorb.amount = amount
			absorb.overheal = 0

			Skada:DispatchSets(log_absorb)
		end
	end

	local function absorb_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local aps, damage = actor:GetAPS(set)

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(aps), 1, 1, 1)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local spell = actor.absorbspells and actor.absorbspells[id]
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.casts and spell.casts > 0 then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		local average = nil
		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			average = spell.amount / spell.count
		end

		local separator = nil

		if spell.min then
			tooltip:AddLine(" ")
			separator = true
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
		end

		if spell.max then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
		end

		if average then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(average), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor absorb spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor absorb spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local amount = spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].amount
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor absorb spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor absorb spells"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's absorbed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's absorbed targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local total = actor and actor.absorb or 0
		local targets = (total > 0) and actor:GetAbsorbTargets(set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, nil, targetname)
			d.value = target.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs"], L[win.class]) or L["Absorbs"]

		local total = set and set:GetAbsorb(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set, true) and actor.absorb then
				local aps, amount = actor:GetAPS(set, nil, not mod_cols.APS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy)
					d.value = amount
					format_valuetext(d, mod_cols, total, aps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	do
		local UnitGUID, UnitName = UnitGUID, UnitName
		local UnitIsDeadOrGhost = UnitIsDeadOrGhost
		local GroupIterator = Skada.GroupIterator

		local function check_starting_shields(unit)
			if UnitIsDeadOrGhost(unit) then return end

			local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
			for i = 1, 40 do
				local _, _, _, _, _, _, _, unitCaster, _, _, spellid, _, _, _, amount = UnitBuff(unit, i)
				if not spellid then
					break -- nothing found
				elseif not ignoredSpells[spellid] and unitCaster and amount then
					handle_shield(nil, "SPELL_AURA_APPLIED", UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, nil, amount)
				end
			end
		end

		function mod:CombatEnter(_, set)
			if set and not set.stopped and not self.checked then
				GroupIterator(check_starting_shields)
				self.checked = true
			end
		end

		local function check_remaining_shields(unit)
			if UnitIsDeadOrGhost(unit) then return end

			local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
			for i = 1, 40 do
				local _, _, _, _, _, _, _, unitCaster, _, _, spellid, _, _, _, amount = UnitBuff(unit, i)
				if not spellid then
					break -- nothing found
				elseif not ignoredSpells[spellid] and unitCaster and amount then
					handle_shield(nil, "SPELL_AURA_REMOVED", UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, nil, amount)
				end
			end
		end

		function mod:CombatLeave()
			GroupIterator(check_remaining_shields)
			self.checked = nil
			wipe(absorb)
			clear(shields)
		end
	end

	function mod:GetSetSummary(set, win)
		local aps, amount = set:GetAPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Absorbs and Skada:FormatNumber(amount),
			self.metadata.columns.APS and Skada:FormatNumber(aps)
		)
		return amount, valuetext
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			post_tooltip = absorb_tooltip,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Absorbs = true, APS = true, Percent = true, sAPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_devineaegis]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		local flags_src = {src_is_interesting = true}

		Skada:RegisterForCL(
			handle_shield,
			flags_src,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED"
		)

		Skada:RegisterForCL(
			spell_absorbed,
			{dst_is_interesting = true},
			"SPELL_ABSORBED"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Absorbs and Healing"])

		-- table of ignored spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.absorbs then
				ignoredSpells = setmetatable(ignoredSpells, {__index = Skada.ignoredSpells.absorbs})
				ignoredSpells = Skada.ignoredSpells.absorbs
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		-- clean absorbspells table:
		if not set.absorb or set.absorb == 0 then return end
		for i = 1, #set.actors do
			local actor = set.actors[i]
			if actor and not actor.enemy then
				local amount = actor.absorb
				if (not amount and actor.absorbspells) or amount == 0 then
					actor.absorb = nil
					actor.absorbspells = del(actor.absorbspells, true)
				end
			end
		end
	end
end)

-- ========================== --
-- Absorbs and healing module --
-- ========================== --

Skada:RegisterModule("Absorbs and Healing", function(L, P)
	local mod = Skada:NewModule("Absorbs and Healing")
	local playermod = mod:NewModule("Absorbs and healing spells")
	local targetmod = mod:NewModule("Absorbed and healed targets")
	local spellmod = targetmod:NewModule("Absorbs and healing spells")
	local spellschools = Skada.spellschools
	local mod_cols = nil

	local function format_valuetext(d, columns, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Healing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and hps and Skada:FormatNumber(hps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local hps, amount = actor:GetAHPS(set)

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. suffix, Skada:FormatNumber(hps), 1, 1, 1)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor.absorbspells and actor.absorbspells[id] -- absorb?
		spell = spell or actor.healspells and actor.healspells[id] -- heal?
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if enemy then
			tooltip:AddDoubleLine(L["Amount"], spell.amount, 1, 1, 1)
			return
		end

		if spell.casts then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		local average = nil
		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			average = spell.amount / spell.count

			if spell.c_num and spell.c_num > 0 then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 0.67, 1, 0.67)
			end
		end

		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Total Healing"], Skada:FormatNumber(spell.o_amt + spell.amount), 1, 1, 1)
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.o_amt + spell.amount)), 1, 0.67, 0.67)
		end

		local separator = nil

		if spell.min then
			tooltip:AddLine(" ")
			separator = true

			local spellmin = spell.min
			if spell.c_min and spell.c_min < spellmin then
				spellmin = spell.c_min
			end
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
		end

		if spell.max then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			local spellmax = spell.max
			if spell.c_max and spell.c_max > spellmax then
				spellmax = spell.c_max
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
		end

		if average then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(average), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor absorb and heal spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor absorb and heal spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHealOnTarget(win.targetname)

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sHPS and actor:GetTime(set)

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				local amount = spell.targets and spell.targets[win.targetname]
				amount = enemy and amount or (amount and amount.amount)
				if amount then
					nr = nr + 1

					local d = win:spell(nr, spellid, spell, nil, true)
					d.value = amount
					format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
				end
			end
		end

		spells = actor.absorbspells -- absorb spells
		if not spells then return end

		for spellid, spell in pairs(spells) do
			local amount = spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].amount
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor absorb and heal spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor absorb and heal spells"](win.actorname or L["Unknown"])
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sHPS and actor:GetTime(set)

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid, spell, nil, true)
				d.value = spell.amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end

		spells = actor.absorbspells -- absorb spells
		if not spells then return end

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's absorbed and healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's absorbed and healed targets"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()
		local targets = (total and total > 0) and actor:GetAbsorbHealTargets(set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if target.amount > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, nil, targetname)
				d.value = target.amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs and Healing"], L[win.class]) or L["Absorbs and Healing"]

		local total = set and set:GetAbsorbHeal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set, true) and (actor.absorb or actor.heal) then
				local hps, amount = actor:GetAHPS(set, nil, not mod_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy)
					d.value = amount
					format_valuetext(d, mod_cols, total, hps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		local hps, amount = set:GetAHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local hps, amount = set:GetAHPS()
		if amount > 0 then
			tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(amount), 1, 1, 1)
			tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(hps), 1, 1, 1)
		end
		if set.overheal and set.overheal > 0 then
			amount = amount + set.overheal
			tooltip:AddDoubleLine(L["Overheal"], Skada:FormatPercent(set.overheal, amount), 1, 1, 1)
		end
	end

	local function feed_personal_hps()
		local set = Skada:GetSet("current")
		local actor = set and set:GetPlayer(Skada.userGUID, Skada.userName)
		if actor then
			return Skada:FormatNumber(actor:GetAHPS(set)) .. " " .. L["HPS"]
		end
	end

	local function feed_raid_hps()
		local set = Skada:GetSet("current")
		return Skada:FormatNumber(set and set:GetAHPS() or 0) .. " " .. L["RHPS"]
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			post_tooltip = hps_tooltip,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_healingfocus]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
		Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
		Skada:RemoveMode(self)
	end
end, "Absorbs", "Healing")

-- ============================== --
-- Healing done per second module --
-- ============================== --

Skada:RegisterModule("HPS", function(L, P)
	local mod = Skada:NewModule("HPS")
	local mod_cols = nil

	local function format_valuetext(d, columns, total, metadata)
		d.valuetext = Skada:FormatValueCols(
			columns.HPS and Skada:FormatNumber(d.value),
			columns.Percent and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local hps, amount = actor:GetAHPS(set)

		tooltip:AddLine(actor.name .. " - " .. L["HPS"])
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. suffix, Skada:FormatNumber(hps), 1, 1, 1)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["HPS"], L[win.class]) or L["HPS"]

		local total = set and set:GetAHPS(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set, true) and (actor.absorb or actor.heal) then
				local amount = actor:GetAHPS(set, nil, not mod_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy)
					d.value = amount
					format_valuetext(d, mod_cols, total, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local value =  set:GetAHPS(win and win.class)
		return value, Skada:FormatNumber(value)
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = hps_tooltip,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_rejuvenation]]
		}

		mod_cols = self.metadata.columns

		local parentmod = Skada:GetModule("Absorbs and Healing", true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
		end

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Absorbs", "Healing", "Absorbs and Healing")

-- ===================== --
-- Healing done by spell --
-- ===================== --

Skada:RegisterModule("Healing Done By Spell", function(L, _, _, C)
	local mod = Skada:NewModule("Healing Done By Spell")
	local spellmod = mod:NewModule("Healing spell sources")
	local spellschools = Skada.spellschools
	local GetSpellInfo = Private.spell_info or GetSpellInfo
	local clear = Private.clearTable
	local get_absorb_heal_spells = nil
	local mod_cols = nil

	local function format_valuetext(d, columns, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Healing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and Skada:FormatNumber(hps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		if not player then return end

		local spell = player.healspells and player.healspells[win.spellid]
		spell = spell or player.absorbspells and player.absorbspells[win.spellid]
		if not spell then return end

		tooltip:AddLine(label .. " - " .. win.spellname)

		if spell.casts then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		if spell.count then
			tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)

			if spell.c_num then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 1, 1, 1)
				tooltip:AddLine(" ")
			end

			if spell.min and spell.max then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
			end
		end

		if spell.o_amt then
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.amount + spell.o_amt)), nil, nil, nil, 1, 0.67, 0.67)
		end
	end

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local total = set and set:GetAbsorbHeal()
		if not total or total == 0 then return end

		clear(C)
		for i = 1, #set.actors do
			local actor = set.actors[i]
			if actor and not actor.enemy and (actor.absorbspells or actor.healspells) then
				local spell = actor.absorbspells and actor.absorbspells[id] or actor.healspells and actor.healspells[id]
				if spell and spell.amount then
					local t = C[id]
					if not t then
						t = new()
						t.school = spell.school
						t.amount = spell.amount
						t.o_amt = spell.o_amt
						t.isabsorb = (actor.absorbspells and actor.absorbspells[id])
						C[id] = t
					else
						t.amount = t.amount + spell.amount
						if spell.o_amt then
							t.o_amt = (t.o_amt or 0) + spell.o_amt
						end
					end
				end
			end
		end

		local spell = C[id]
		if not spell then return end

		tooltip:AddLine((GetSpellInfo(id)))
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.casts and spell.casts > 0 then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		end
		tooltip:AddDoubleLine(spell.isabsorb and L["Absorbs"] or L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 1, 1, 1)
		if set.overheal and spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, set.overheal)), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's sources"], label)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if not (win.spellid and set) then return end

		-- let's go...
		local total = 0
		local overheal = 0
		local sources = clear(C)

		local actors = set.actors
		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.enemy and (actor.absorbspells or actor.healspells) then
				local spell = actor.absorbspells and actor.absorbspells[win.spellid]
				spell = spell or actor.healspells and actor.healspells[win.spellid]
				if spell and spell.amount then
					sources[actor.name] = new()
					sources[actor.name].id = actor.id
					sources[actor.name].class = actor.class
					sources[actor.name].role = actor.role
					sources[actor.name].spec = actor.spec
					sources[actor.name].enemy = actor.enemy
					sources[actor.name].amount = spell.amount
					sources[actor.name].time = mod.metadata.columns.sHPS and actor:GetTime(set)
					-- calculate the total.
					total = total + spell.amount
					if spell.o_amt then
						overheal = overheal + spell.o_amt
					end
				end
			end
		end

		if total == 0 and overheal == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, source.enemy, sourcename)
			d.value = source.amount
			format_valuetext(d, mod_cols, total, source.time and (d.value / source.time), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Done By Spell"]
		local total = set and set:GetAbsorbHeal()
		local spells = (total and total > 0) and get_absorb_heal_spells(set)

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local settime = mod_cols.HPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell, nil, true)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {showspots = true, tooltip = player_tooltip}
		self.metadata = {
			click1 = spellmod,
			post_tooltip = spell_tooltip,
			columns = {Healing = true, HPS = false, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_healingwavelesser]]
		}
		mod_cols = self.metadata.columns
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	local function fill_spells_table(t, spellid, info)
		if not info or not (info.amount or info.o_amt) then return end

		local spell = t[spellid]
		if not spell then
			spell = new()
			-- common
			spell.school = info.school
			spell.amount = info.amount

			-- for heals
			spell.o_amt = info.o_amt

			t[spellid] = spell
		else
			spell.amount = spell.amount + info.amount
			if info.o_amt then -- for heals
				spell.o_amt = (spell.o_amt or 0) + info.o_amt
			end
		end
	end

	get_absorb_heal_spells = function(self, tbl)
		if not self.actors or not (self.absorb or self.heal) then return end

		tbl = clear(tbl or C)
		for i = 1, #self.actors do
			local actor = self.actors[i]
			if actor and actor.healspells then
				for spellid, spell in pairs(actor.healspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
			if actor and actor.absorbspells then
				for spellid, spell in pairs(actor.absorbspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
		end
		return tbl
	end
end, "Absorbs", "Healing")
