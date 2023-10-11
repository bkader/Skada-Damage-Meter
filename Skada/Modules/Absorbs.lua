local _, Skada = ...
local Private = Skada.Private

-- cache frequently used globals
local pairs, tostring, format, uformat = pairs, tostring, string.format, Private.uformat
local new, del = Private.newTable, Private.delTable
local PercentToRGB = Private.PercentToRGB
local tooltip_school = Skada.tooltip_school
local hits_perc = "%s (\124cffffffff%s\124r)"
local slash_fmt = "%s/%s"

---------------------------------------------------------------------------
-- Absorbs Module

Skada:RegisterModule("Absorbs", function(L, P, G)
	local mode = Skada:NewModule("Absorbs")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	tooltip_school = tooltip_school or Skada.tooltip_school
	local ignored_spells = Skada.ignored_spells.absorb -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua

	local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100
	local COMBATLOG_OBJECT_AFFILIATION_OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER or 0x00000008
	local COMBATLOG_OBJECT_REACTION_MASK = COMBATLOG_OBJECT_REACTION_MASK or 0x000000F0

	local next, wipe, band = next, wipe, bit.band
	local del, clear = Private.delTable, Private.clearTable
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function format_valuetext(d, total, aps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Absorbs and Skada:FormatNumber(d.value),
			mode_cols[subview and "sAPS" or "APS"] and aps and Skada:FormatNumber(aps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local absorb = {}
	local function log_absorb(set, nocount)
		local amount = absorb.amount
		if amount == 0 then return end

		local actor = Skada:GetActor(set, absorb.actorname, absorb.actorid, absorb.actorflags)
		if not actor then
			return
		elseif actor.role ~= "DAMAGER" and not passive_spells[absorb.spell] and not nocount then
			Skada:AddActiveTime(set, actor, absorb.dstName)
		end

		-- add absorbs amount
		actor.absorb = (actor.absorb or 0) + amount
		set.absorb = (set.absorb or 0) + amount

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell
		local spell = actor.absorbspells and actor.absorbspells[absorb.spellid]
		if not spell then
			actor.absorbspells = actor.absorbspells or {}
			actor.absorbspells[absorb.spellid] = {amount = 0}
			spell = actor.absorbspells[absorb.spellid]
		end
		spell.amount = spell.amount + amount

		if not nocount then
			spell.count = (spell.count or 0) + 1

			if absorb.critical then
				spell.c_num = (spell.c_num or 0) + 1
				spell.c_amt = (spell.c_amt or 0) + absorb.amount
				if not spell.c_max or absorb.amount > spell.c_max then
					spell.c_max = absorb.amount
				end
				if not spell.c_min or absorb.amount < spell.c_min then
					spell.c_min = absorb.amount
				end
			else
				spell.n_num = (spell.n_num or 0) + 1
				spell.n_amt = (spell.n_amt or 0) + absorb.amount
				if not spell.n_max or absorb.amount > spell.n_max then
					spell.n_max = absorb.amount
				end
				if not spell.n_min or absorb.amount < spell.n_min then
					spell.n_min = absorb.amount
				end
			end
		end

		-- record the target
		if not absorb.dstName then return end
		local target = spell.targets and spell.targets[absorb.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[absorb.dstName] = {amount = 0}
			target = spell.targets[absorb.dstName]
		end
		target.amount = target.amount + amount
	end

	local function spell_absorbed(t)
		if t.absorbSpellid and not ignored_spells[t.absorbSpellid] then
			absorb.actorid = t.casterGUID
			absorb.actorname = t.casterName
			absorb.actorflags = t.casterFlags
			absorb.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)

			absorb.spell = t.absorbSpellid
			absorb.spellid = t.absorbSpellstring
			absorb.amount = t.amount
			absorb.overheal = 0
			absorb.critical = t.critical

			Skada:FixPets(absorb)
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

		local activepercent = activetime / totaltime * 100
		tooltip:AddDoubleLine(format(L["%s's activity"], classfmt(actor.class, label)), Skada:FormatPercent(activepercent), nil, nil, nil, PercentToRGB(activepercent))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format(slash_fmt, Skada:FormatNumber(damage), suffix), Skada:FormatNumber(aps), 1, 1, 1)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.absorbspells and actor.absorbspells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(win.actorclass, win.actorname), label))
		tooltip_school(tooltip, id)

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if not spell.count or spell.count == 0 then return end

		-- hits and average
		tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format(hits_perc, Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.amount + spell.o_amt)), 1, 0.67, 0.67)
		end

		-- normal hits
		if spell.n_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Normal Hits"], format(hits_perc, Skada:FormatNumber(spell.n_num), Skada:FormatPercent(spell.n_num, spell.count)))
			if spell.n_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
			end
			if spell.n_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
		end

		-- critical hits
		if spell.c_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Critical Hits"], format(hits_perc, Skada:FormatNumber(spell.c_num), Skada:FormatPercent(spell.c_num, spell.count)))
			if spell.c_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
			end
			if spell.c_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(class, label))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local amount = spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].amount
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = format(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor and actor.absorb or 0
		local targets = (total > 0) and actor:GetAbsorbTargets(set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs"], L[win.class]) or L["Absorbs"]

		local total = set and set:GetAbsorb(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.absorb then
				local aps, amount = actor:GetAPS(set, nil, not mode_cols.APS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, aps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.absorb then return end

		local aps, amount = actor:GetAPS(set, false, not mode_cols.sAPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Absorbs and Skada:FormatNumber(amount),
			mode_cols.sAPS and Skada:FormatNumber(aps)
		)
		return amount, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		local aps, amount = set:GetAPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Absorbs and Skada:FormatNumber(amount),
			mode_cols.APS and Skada:FormatNumber(aps)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_spell.metadata = {tooltip = mode_spell_tooltip}
		mode_target.metadata = {showspots = true, click1 = mode_target_spell}
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = absorb_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Absorbs = true, APS = false, Percent = true, sAPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_devineaegis]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:RegisterForCL(spell_absorbed, {dst_is_interesting = true}, "SPELL_ABSORBED")
		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	function mode:SetComplete(set)
		-- clean absorbspells table:
		if not set.absorb or set.absorb == 0 then return end
		for _, actor in pairs(set.actors) do
			local amount = actor.absorb
			if (not amount and actor.absorbspells) or amount == 0 then
				actor.absorb = nil
				actor.absorbspells = del(actor.absorbspells, true)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Absorbs and Healing Module

Skada:RegisterModule("Absorbs and Healing", function(L, P)
	local mode = Skada:NewModule("Absorbs and Healing")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	tooltip_school = tooltip_school or Skada.tooltip_school
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function format_valuetext(d, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(d.value),
			mode_cols[subview and "sHPS" or "HPS"] and hps and Skada:FormatNumber(hps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
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

		local activepercent = activetime / totaltime * 100
		tooltip:AddDoubleLine(format(L["%s's activity"], classfmt(actor.class, label)), Skada:FormatPercent(activepercent), nil, nil, nil, PercentToRGB(activepercent))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format(slash_fmt, Skada:FormatNumber(amount), suffix), Skada:FormatNumber(hps), 1, 1, 1)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor.healspells and actor.healspells[id] or actor.absorbspells and actor.absorbspells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(win.actorclass, win.actorname), label))
		tooltip_school(tooltip, id)

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if not spell.count or spell.count == 0 then return end

		-- hits and average
		tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format(hits_perc, Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.amount + spell.o_amt)), 1, 0.67, 0.67)
		end

		-- normal hits
		if spell.n_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Normal Hits"], format(hits_perc, Skada:FormatNumber(spell.n_num), Skada:FormatPercent(spell.n_num, spell.count)))
			if spell.n_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
			end
			if spell.n_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
		end

		-- critical hits
		if spell.c_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Critical Hits"], format(hits_perc, Skada:FormatNumber(spell.c_num), Skada:FormatPercent(spell.c_num, spell.count)))
			if spell.c_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
			end
			if spell.c_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(class, label))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHealOnTarget(win.targetname)

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				local amount = spell.targets and spell.targets[win.targetname]
				amount = actor.enemy and amount or (amount and amount.amount)
				if amount then
					nr = nr + 1

					local d = win:spell(nr, spellid, spell, nil, true)
					d.value = amount
					format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = format(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid, spell, nil, true)
				d.value = spell.amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end

		spells = actor.absorbspells -- absorb spells
		if not spells then return end

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()
		local targets = (total and total > 0) and actor:GetAbsorbHealTargets(set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if target.amount > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = target.amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs and Healing"], L[win.class]) or L["Absorbs and Healing"]

		local total = set and set:GetAbsorbHeal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and (actor.absorb or actor.heal) then
				local hps, amount = actor:GetAHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, hps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local hps, amount = actor:GetAHPS(set, false, not mode_cols.sHPS)
		if amount <= 0 then return end

		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.sHPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		if not set then return end
		local hps, amount = set:GetAHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.HPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end

	function mode:AddToTooltip(set, tooltip)
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
		local actor = set and set:GetActor(Skada.userName, Skada.userGUID)
		if actor then
			return format("%s %s", Skada:FormatNumber((actor:GetAHPS(set))), L["HPS"])
		end
	end

	local function feed_raid_hps()
		local set = Skada:GetSet("current")
		return format("%s %s", Skada:FormatNumber(set and set:GetAHPS() or 0), L["RHPS"])
	end

	function mode:OnEnable()
		mode_spell.metadata = {tooltip = mode_spell_tooltip}
		mode_target.metadata = {showspots = true, click1 = mode_target_spell}
		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
		Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
		Skada:RemoveMode(self)
	end

	function mode:OnInitialize()
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = hps_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_healingfocus]]
		}
	end
end, "Absorbs", "Healing")

---------------------------------------------------------------------------
-- HPS Module

Skada:RegisterModule("HPS", function(L, P)
	local mode = Skada:NewModule("HPS")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function format_valuetext(d, total, metadata)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.HPS and Skada:FormatNumber(d.value),
			mode_cols.Percent and Skada:FormatPercent(d.value, total)
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

		tooltip:AddLine(uformat(L["%s's activity"], classfmt(actor.class, label), L["HPS"]))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format(slash_fmt, Skada:FormatNumber(amount), suffix), Skada:FormatNumber(hps), 1, 1, 1)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["HPS"], L[win.class]) or L["HPS"]

		local total = set and set:GetAHPS(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and (actor.absorb or actor.heal) then
				local amount = actor:GetAHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local value =  set:GetAHPS(win and win.class)
		return value, Skada:FormatNumber(value)
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = hps_tooltip,
			columns = {HPS = true, Percent = true},
			icon = [[Interface\ICONS\spell_nature_rejuvenation]]
		}

		mode_cols = self.metadata.columns

		local parent = Skada:GetModule("Absorbs and Healing", true)
		if parent and parent.metadata then
			self.metadata.click1 = parent.metadata.click1
			self.metadata.click2 = parent.metadata.click2
		end

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Absorbs", "Healing", "Absorbs and Healing")

---------------------------------------------------------------------------
-- Healing Done By Spell

Skada:RegisterModule("Healing Done By Spell", function(L, _, _, C)
	local mode = Skada:NewModule("Healing Done By Spell")
	local mode_source = mode:NewModule("Source List")
	local classfmt = Skada.classcolors.format
	local clear = Private.clearTable
	local get_absorb_heal_spells = nil
	local mode_cols = nil

	local function format_valuetext(d, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(d.value),
			mode_cols[subview and "sHPS" or "HPS"] and Skada:FormatNumber(hps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function mode_source_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local spell = actor.healspells and actor.healspells[win.spellid]
		spell = spell or actor.absorbspells and actor.absorbspells[win.spellid]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(actor.class, label), win.spellname))

		local cast = actor.GetSpellCast and actor:GetSpellCast(win.spellid)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if spell.count then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)

			if spell.c_num then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 1, 1, 1)
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

	function mode_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's sources"], label)
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if not (win.spellid and set) then return end

		-- let's go...
		local total = 0
		local overheal = 0
		local sources = clear(C)

		local actors = set.actors
		for actorname, actor in pairs(actors) do
			if actor and not actor.enemy and (actor.absorbspells or actor.healspells) then
				local spell = actor.absorbspells and actor.absorbspells[win.spellid]
				spell = spell or actor.healspells and actor.healspells[win.spellid]
				if spell and spell.amount then
					sources[actorname] = new()
					sources[actorname].id = actor.id
					sources[actorname].class = actor.class
					sources[actorname].role = actor.role
					sources[actorname].spec = actor.spec
					sources[actorname].enemy = actor.enemy
					sources[actorname].amount = spell.amount
					sources[actorname].time = mode.metadata.columns.sHPS and actor:GetTime(set)
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
			format_valuetext(d, total, source.time and (d.value / source.time), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Healing Done By Spell"]
		local total = set and set:GetAbsorbHeal()
		local spells = (total and total > 0) and get_absorb_heal_spells(set)

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local settime = mode_cols.HPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell, nil, true)
			d.value = spell.amount
			format_valuetext(d, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mode:OnEnable()
		mode_source.metadata = {showspots = true, tooltip = mode_source_tooltip}
		self.metadata = {
			click1 = mode_source,
			columns = {Healing = true, HPS = false, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_nature_healingwavelesser]]
		}
		mode_cols = self.metadata.columns
		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	local function fill_spells_table(t, spellid, info)
		if not info or not (info.amount or info.o_amt) then return end

		local spell = t[spellid]
		if not spell then
			spell = new()
			-- common
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
		for _, actor in pairs(self.actors) do
			if actor.healspells then
				for spellid, spell in pairs(actor.healspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
			if actor.absorbspells then
				for spellid, spell in pairs(actor.absorbspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
		end
		return tbl
	end
end, "Absorbs", "Healing")
