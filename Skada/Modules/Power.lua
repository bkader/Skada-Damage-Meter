local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Resources", function(L, P)
	local mode = Skada:NewModule("Resources")
	mode.icon = [[Interface\ICONS\spell_holy_rapture]]

	local setmetatable, pairs = setmetatable, pairs
	local format, uformat = string.format, Private.uformat
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local PowerEnum = _G.Enum and _G.Enum.PowerType
	local SPELL_POWER_MANA = _G.SPELL_POWER_MANA or (PowerEnum and PowerEnum.Mana) or 0
	local SPELL_POWER_RAGE = _G.SPELL_POWER_RAGE or (PowerEnum and PowerEnum.Rage) or 1
	local SPELL_POWER_ENERGY = _G.SPELL_POWER_ENERGY or (PowerEnum and PowerEnum.Energy) or 3
	local SPELL_POWER_RUNIC_POWER = _G.SPELL_POWER_RUNIC_POWER or (PowerEnum and PowerEnum.RunicPower) or 6

	-- used to store total amounts for sets and actors
	local gainTable = {
		[SPELL_POWER_MANA] = "mana",
		[SPELL_POWER_RAGE] = "rage",
		[SPELL_POWER_ENERGY] = "energy",
		[SPELL_POWER_RUNIC_POWER] = "runic"
	}

	-- users as keys to store spells and their amounts.
	local spellTable = {
		[SPELL_POWER_MANA] = "manaspells",
		[SPELL_POWER_RAGE] = "ragespells",
		[SPELL_POWER_ENERGY] = "energyspells",
		[SPELL_POWER_RUNIC_POWER] = "runicspells"
	}

	-- used to record other power types.
	local powerTable = nil -- only for retail (not classic wotlk)

	local ignored_spells = Skada.ignored_spells.power -- Edit Skada\Core\Tables.lua

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Amount and Skada:FormatNumber(d.value),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local gain = {}
	local function log_gain(set)
		local key = gain.type and gainTable[gain.type]
		if not key then return end

		local actor = Skada:GetActor(set, gain.actorname, gain.actorid, gain.actorflags)
		if not actor then return end

		actor[key] = (actor[key] or 0) + gain.amount
		set[key] = (set[key] or 0) + gain.amount

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not gain.spellid then return end

		key = spellTable[gain.type]
		actor[key] = actor[key] or {}
		actor[key][gain.spellid] = (actor[key][gain.spellid] or 0) + gain.amount
	end

	local function spell_energize(t)
		if t.spellid and not ignored_spells[t.spellid] then
			local powertype, spellstring = t.powertype, t.spellstring
			if powerTable and powerTable[powertype] then
				spellstring = powerTable[powertype]
				powertype = -1
			end

			gain.actorid = t.dstGUID
			gain.actorname = t.dstName
			gain.actorflags = t.dstFlags

			gain.spellid = spellstring
			gain.amount = t.amount
			gain.type = powertype

			Skada:FixPets(gain)
			Skada:DispatchSets(log_gain)
		end
	end

	-- a base module used to create our power modules.
	local mode_base = {}
	local mode_base_mt = {__index = mode_base}

	-- a base actor module used to create power gained per actor modules.
	local mode_actor = {}
	local mode_actor_mt = {__index = mode_actor}

	-- allows us to create a module for each power type.
	function mode_base:Create(power, name)
		if not power or not gainTable[power] then return end

		local instance = Skada:NewModule(name)
		setmetatable(instance, mode_base_mt)

		local pmode = instance:NewModule("Spell List")
		setmetatable(pmode, mode_actor_mt)

		pmode.powerid = power
		pmode.power = gainTable[power]
		pmode.spells = spellTable[power]
		instance.power = gainTable[power]
		instance.metadata = {showspots = true, filterclass = true, click1 = pmode}

		-- no total click.
		pmode.nototal = true

		return instance
	end

	-- this is the main module update function that shows the list
	-- of actors depending on the selected power gain type.
	function mode_base:Update(win, set)
		win.title = self.localeName or self.moduleName or L["Unknown"]
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local total = set and set:GetTotal(win.class, nil, self.power)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor[self.power] then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor[self.power]
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	-- base function used to return sets summaries
	function mode_base:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, self.power) or 0
		return value, Skada:FormatNumber(value)
	end

	-- actor mods common Enter function.
	function mode_actor:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's spells"], classfmt(class, label))
	end

	-- actor mods main update function
	function mode_actor:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor and self.power and actor[self.power]
		local spells = (total and total > 0) and actor[self.spells]

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, amount in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, false)
			d.value = amount
			format_valuetext(d, total, win.metadata, true)
		end
	end

	-- we create the modules now
	-- power gained: mana
	local mode_mana = mode_base:Create(SPELL_POWER_MANA, "Mana Restored")
	local mode_rage = mode_base:Create(SPELL_POWER_RAGE, "Rage Generated")
	local mode_energy = mode_base:Create(SPELL_POWER_ENERGY, "Energy Generated")
	local mode_runic = mode_base:Create(SPELL_POWER_RUNIC_POWER, "Runic Power Generated")
	local mode_power = nil

	function mode:OnEnable()
		self.metadata = {columns = {Amount = true, Percent = false, sPercent = true}}
		mode_cols = self.metadata.columns
		Skada:AddColumnOptions(self)

		Skada:RegisterForCL(spell_energize, {src_is_interesting = true}, "SPELL_ENERGIZE", "SPELL_PERIODIC_ENERGIZE")

		mode_mana.metadata.icon = [[Interface\ICONS\spell_frost_summonwaterelemental]]
		mode_rage.metadata.icon = [[Interface\ICONS\spell_nature_shamanrage]]
		mode_energy.metadata.icon = [[Interface\ICONS\spell_holy_circleofrenewal]]
		mode_runic.metadata.icon = [[Interface\ICONS\inv_sword_62]]

		Skada:AddMode(mode_mana, "Resources")
		Skada:AddMode(mode_rage, "Resources")
		Skada:AddMode(mode_energy, "Resources")
		Skada:AddMode(mode_runic, "Resources")

		-- other resources mode
		if mode_power then
			mode_power.metadata.icon = [[Interface\ICONS\spell_fire_fire]]
			Skada:AddMode(mode_power, "Resources")
		end
	end

	function mode:OnDisable()
		Skada:RemoveMode(mode_mana)
		Skada:RemoveMode(mode_rage)
		Skada:RemoveMode(mode_energy)
		Skada:RemoveMode(mode_runic)
		if mode_power then
			Skada:RemoveMode(mode_power)
		end
	end

	function mode:OnInitialize()
		if Private.IsWotLK() then
			local SPELL_POWER_FOCUS = SPELL_POWER_FOCUS or (PowerEnum and PowerEnum.Focus) or 2
			local SPELL_POWER_HAPPINESS = SPELL_POWER_HAPPINESS or (PowerEnum and PowerEnum.ComboPoints) or 4

			-- treat Focus & Happiness as Energy.
			gainTable[SPELL_POWER_FOCUS] = "energy"
			gainTable[SPELL_POWER_HAPPINESS] = "energy"
			spellTable[SPELL_POWER_FOCUS] = "energyspells"
			spellTable[SPELL_POWER_HAPPINESS] = "energyspells"

			return
		end

		-- record all other resources.
		gainTable[-1] = "power"
		spellTable[-1] = "powerspells"

		-- create "Other Resources" mode.
		mode_power = mode_base:Create(-1, "Other Resources")

		-- other resources
		local SPELL_POWER_COMBO_POINTS2 = _G.SPELL_POWER_COMBO_POINTS or (PowerEnum and PowerEnum.ComboPoints) or 4
		local SPELL_POWER_RUNES = _G.SPELL_POWER_RUNES or (PowerEnum and PowerEnum.Runes) or 5
		local SPELL_POWER_SOUL_SHARDS = _G.SPELL_POWER_SOUL_SHARDS or (PowerEnum and PowerEnum.SoulShards) or 7
		local SPELL_POWER_LUNAR_POWER = _G.SPELL_POWER_LUNAR_POWER or (PowerEnum and PowerEnum.LunarPower) or 8
		local SPELL_POWER_HOLY_POWER = _G.SPELL_POWER_HOLY_POWER  or (PowerEnum and PowerEnum.HolyPower) or 9
		local SPELL_POWER_MAELSTROM = _G.SPELL_POWER_MAELSTROM or (PowerEnum and PowerEnum.Maelstrom) or 11
		local SPELL_POWER_CHI = _G.SPELL_POWER_CHI or (PowerEnum and PowerEnum.Chi) or 12
		local SPELL_POWER_INSANITY = _G.SPELL_POWER_INSANITY or (PowerEnum and PowerEnum.Insanity) or 13
		local SPELL_POWER_ARCANE_CHARGES = _G.SPELL_POWER_ARCANE_CHARGES or (PowerEnum and PowerEnum.ArcaneCharges) or 16
		local SPELL_POWER_FURY = _G.SPELL_POWER_FURY or (PowerEnum and PowerEnum.Fury) or 17
		local SPELL_POWER_PAIN = _G.SPELL_POWER_PAIN or (PowerEnum and PowerEnum.Pain) or 18

		powerTable = {
			[SPELL_POWER_COMBO_POINTS2] = "9999001",
			[SPELL_POWER_RUNES] = "9999002",
			[SPELL_POWER_SOUL_SHARDS] = "9999003",
			[SPELL_POWER_LUNAR_POWER] = "9999004",
			[SPELL_POWER_HOLY_POWER] = "9999005",
			[SPELL_POWER_MAELSTROM] = "9999006",
			[SPELL_POWER_CHI] = "9999007",
			[SPELL_POWER_INSANITY] = "9999008",
			[SPELL_POWER_ARCANE_CHARGES] = "9999009",
			[SPELL_POWER_FURY] = "9999010",
			[SPELL_POWER_PAIN] = "9999011",
		}
	end
end)
