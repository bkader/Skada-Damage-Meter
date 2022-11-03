local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Activity", function(L, P, _, C)
	local mod = Skada:NewModule("Activity")
	local targetmod = mod:NewModule("Activity per Target")
	local date, pairs, format = date, pairs, string.format
	local uformat, new, clear = Private.uformat, Private.newTable, Private.clearTable
	local get_activity_targets = nil
	local mod_cols = nil

	local function format_valuetext(d, columns, maxtime, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns["Active Time"] and Skada:FormatTime(d.value),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, maxtime)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(id, label)
		if not actor then return end

		local settime = set:GetTime()
		if settime == 0 then return end

		local activetime = actor:GetTime(set, true)
		tooltip:AddLine(actor.name .. ": " .. L["Activity"])
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, settime), nil, nil, nil, 1, 1, 1)
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's activity"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's activity"], win.actorname)
		if not win.actorname then return end

		local actor = set:GetActor(win.actorid, win.actorname)
		local maxtime = actor and actor:GetTime(set, true)
		local targets = maxtime and get_activity_targets(actor, set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for name, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, name)
			d.value = target.time
			format_valuetext(d, mod_cols, maxtime, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Activity"], L[win.class]) or L["Activity"]

		local settime = set and set:GetTime()
		if not settime or settime == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) then
				local activetime = actor:GetTime(set, true)
				if activetime > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = activetime
					format_valuetext(d, mod_cols, settime, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mod:GetSetSummary(set)
		if not set or not set.time then return end
		local valuetext = Skada:FormatValueCols(
			mod_cols["Active Time"] and Skada:FormatTime(set.time),
			mod_cols.Percent and format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime))
		)
		return set.time, valuetext
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			tooltip = activity_tooltip,
			click1 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {["Active Time"] = true, Percent = true, sPercent = true},
			icon = [[Interface\Icons\spell_holy_borrowedtime]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		targetmod.nototal = true

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_activity_targets = function(self, set, tbl)
		if not set or not self.timespent then return end

		tbl = clear(tbl or C)
		for name, timespent in pairs(self.timespent) do
			tbl[name] = new()
			tbl[name].time = timespent
			set:_fill_actor_table(tbl[name], name)
		end
		return tbl
	end
end)
