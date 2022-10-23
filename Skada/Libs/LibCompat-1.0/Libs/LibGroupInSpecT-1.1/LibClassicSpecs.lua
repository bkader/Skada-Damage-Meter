local MAJOR, MINOR = "LibClassicSpecs", 1000 + tonumber(strmatch("@project-revision@", "%d+") or 0)
local lib = LibStub:NewLibrary(MAJOR, MINOR)

-- luacov: disable
if not lib then
	return
end
-- luacov: enable

lib.MAX_TALENT_TIERS = 7
lib.NUM_TALENT_COLUMNS = 4

-- TODO(#4): displayName param should be i18n
local Warrior = {
	ID = 1,
	displayName = "Warrior",
	name = "WARRIOR",
	Arms = 71,
	Fury = 72,
	Prot = 73,
	specs = {71, 72, 73}
}
local Paladin = {
	ID = 2,
	displayName = "Paladin",
	name = "PALADIN",
	Holy = 65,
	Prot = 66,
	Ret = 70,
	specs = {65, 66, 70}
}
local Hunter = {
	ID = 3,
	displayName = "Hunter",
	name = "HUNTER",
	BM = 253,
	MM = 254,
	SV = 255,
	specs = {253, 254, 255}
}
local Rogue = {
	ID = 4,
	displayName = "Rogue",
	name = "ROGUE",
	Assasin = 259,
	Combat = 260,
	Sub = 261,
	specs = {259, 260, 261}
}
local Priest = {
	ID = 5,
	displayName = "Priest",
	name = "PRIEST",
	Disc = 256,
	Holy = 257,
	Shadow = 258,
	specs = {256, 257, 258}
}
local DK = {
	ID = 6,
	displayName = "Death knight",
	name = "DEATHKNIGHT",
	Blood = 250,
	Frost = 251,
	Unholy = 252,
	specs = {250, 251, 252}
}
local Shaman = {
	ID = 7,
	displayName = "Shaman",
	name = "SHAMAN",
	Ele = 262,
	Enh = 263,
	Resto = 264,
	specs = {262, 263, 264}
}
local Mage = {
	ID = 8,
	displayName = "Mage",
	name = "MAGE",
	Arcane = 62,
	Fire = 63,
	Frost = 64,
	specs = {62, 63, 64}
}
local Warlock = {
	ID = 9,
	displayName = "Warlock",
	name = "WARLOCK",
	Affl = 265,
	Demo = 266,
	Destro = 267,
	specs = {265, 266, 267}
}
local Monk = {
	ID = 10,
	displayName = "Monk",
	name = "MONK",
	BRM = 268,
	WW = 269,
	MW = 270,
	specs = {268, 269, 270}
}
local Druid = {
	ID = 11,
	displayName = "Druid",
	name = "DRUID",
	Balance = 102,
	Feral = 103,
	Guardian = 104,
	Resto = 105,
	specs = {102, 103, 104, 105}
}
local DH = {
	ID = 12,
	displayName = "Demon hunter",
	name = "DEMONHUNTER",
	Havoc = 577,
	Veng = 581,
	specs = {577, 581}
}

lib.Class = {
	Warrior = Warrior,
	Paladin = Paladin,
	Hunter = Hunter,
	Rogue = Rogue,
	Priest = Priest,
	DK = DK,
	Shaman = Shaman,
	Mage = Mage,
	Warlock = Warlock,
	Monk = Monk,
	Druid = Druid,
	DH = DH
}

local ClassByID = {
	Warrior,
	Paladin,
	Hunter,
	Rogue,
	Priest,
	DK,
	Shaman,
	Mage,
	Warlock,
	Monk,
	Druid,
	DH
}

local Stat = {
	Strength = 1,
	Agility = 2,
	Stamina = 3,
	Intellect = 4,
	Spirit = 5
}

lib.Stat = Stat

local Role = {
	Damager = "DAMAGER",
	Tank = "TANK",
	Healer = "HEALER"
}

lib.Role = Role

-- Map of spec (tab) index to spec id
local NAME_TO_SPEC_MAP = {
	[Warrior.name] = Warrior.specs,
	[Paladin.name] = Paladin.specs,
	[Hunter.name] = Hunter.specs,
	[Rogue.name] = Rogue.specs,
	[Priest.name] = Priest.specs,
	[DK.name] = DK.specs,
	[Shaman.name] = Shaman.specs,
	[Mage.name] = Mage.specs,
	[Warlock.name] = Warlock.specs,
	[Monk.name] = Monk.specs,
	[Druid.name] = Druid.specs,
	[DH.name] = DH.specs
}

-- Detailed info for each spec
local SpecInfo = {
	[Warrior.Arms] = {
		ID = Warrior.Arms,
		name = "Arms",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Strength
	},
	[Warrior.Fury] = {
		ID = Warrior.Fury,
		name = "Fury",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Strength
	},
	[Warrior.Prot] = {
		ID = Warrior.Prot,
		name = "Protection",
		description = "",
		icon = "",
		background = "",
		role = Role.Tank,
		isRecommended = false,
		primaryStat = Stat.Strength
	},
	[Paladin.Holy] = {
		ID = Paladin.Holy,
		name = "Holy",
		description = "",
		icon = "",
		background = "",
		role = Role.Healer,
		isRecommended = false,
		primaryStat = Stat.Intellect
	},
	[Paladin.Prot] = {
		ID = Paladin.Prot,
		name = "Protection",
		description = "",
		icon = "",
		background = "",
		role = Role.Tank,
		isRecommended = false,
		primaryStat = Stat.Strength
	},
	[Paladin.Ret] = {
		ID = Paladin.Ret,
		name = "Retribution",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Strength
	},
	[Hunter.BM] = {
		ID = Hunter.BM,
		name = "Beast Mastery",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Agility
	},
	[Hunter.MM] = {
		ID = Hunter.MM,
		name = "Marksman",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Agility
	},
	[Hunter.SV] = {
		ID = Hunter.SV,
		name = "Survival",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Agility
	},
	[Rogue.Assasin] = {
		ID = Rogue.Assasin,
		name = "Assasination",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Agility
	},
	[Rogue.Combat] = {
		ID = Rogue.Combat,
		name = "Combat",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Agility
	},
	[Rogue.Sub] = {
		ID = Rogue.Sub,
		name = "Subtlety",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Agility
	},
	[Priest.Disc] = {
		ID = Priest.Disc,
		name = "Discipline",
		description = "",
		icon = "",
		background = "",
		role = Role.Healer,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Priest.Holy] = {
		ID = Priest.Holy,
		name = "Holy",
		description = "",
		icon = "",
		background = "",
		role = Role.Healer,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Priest.Shadow] = {
		ID = Priest.Shadow,
		name = "Shadow",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Intellect
	},
	[Shaman.Ele] = {
		ID = Shaman.Ele,
		name = "Elemental",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Shaman.Enh] = {
		ID = Shaman.Enh,
		name = "Enhancement",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Strength
	},
	[Shaman.Resto] = {
		ID = Shaman.Resto,
		name = "Restoration",
		description = "",
		icon = "",
		background = "",
		role = Role.Healer,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Mage.Arcane] = {
		ID = Mage.Arcane,
		name = "Arcane",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Intellect
	},
	[Mage.Fire] = {
		ID = Mage.Fire,
		name = "Fire",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Mage.Frost] = {
		ID = Mage.Frost,
		name = "Frost",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Warlock.Affl] = {
		ID = Warlock.Affl,
		name = "Affliction",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Intellect
	},
	[Warlock.Demo] = {
		ID = Warlock.Demo,
		name = "Demonology",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Warlock.Destro] = {
		ID = Warlock.Destro,
		name = "Destruction",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = false,
		primaryStat = Stat.Intellect
	},
	[Druid.Balance] = {
		ID = Druid.Balance,
		name = "Balance",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Druid.Feral] = {
		ID = Druid.Feral,
		name = "Feral",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Strength
	},
	[Druid.Guardian] = {
		ID = Druid.Guardian,
		name = "Guardian",
		description = "",
		icon = "",
		background = "",
		role = Role.Tank,
		isRecommended = true,
		primaryStat = Stat.Strength
	},
	[Druid.Resto] = {
		ID = Druid.Resto,
		name = "Restoration",
		description = "",
		icon = "",
		background = "",
		role = Role.Healer,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[DK.Frost] = {
		ID = DK.Frost,
		name = "Frost",
		description = "",
		icon = "",
		background = "",
		role = Role.Tank,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[DK.Blood] = {
		ID = DK.Blood,
		name = "Blood",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[DK.Unholy] = {
		ID = DK.Unholy,
		name = "Unholy",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[DH.Havoc] = {
		ID = DH.Havoc,
		name = "Havoc",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[DH.Veng] = {
		ID = DH.Veng,
		name = "Vengeance",
		description = "",
		icon = "",
		background = "",
		role = Role.Tank,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Monk.BRM] = {
		ID = Monk.BRM,
		name = "Brewmaster",
		description = "",
		icon = "",
		background = "",
		role = Role.Tank,
		isRecommended = true,
		primaryStat = Stat.Agility
	},
	[Monk.MW] = {
		ID = Monk.MW,
		name = "Mistweaver",
		description = "",
		icon = "",
		background = "",
		role = Role.Healer,
		isRecommended = true,
		primaryStat = Stat.Intellect
	},
	[Monk.WW] = {
		ID = Monk.WW,
		name = "Windwalker",
		description = "",
		icon = "",
		background = "",
		role = Role.Damager,
		isRecommended = true,
		primaryStat = Stat.Agility
	}
}

lib.SpecInfo = SpecInfo

local ROLE_MAP = {}
for specId, v in pairs(SpecInfo) do
	ROLE_MAP[specId] = v.role
end

lib.GetClassInfo = function(classId)
	local info = ClassByID[classId]
	if (info == nil) then
		return nil
	end
	return info.displayName, info.name, info.ID
end

lib.GetNumSpecializationsForClassID = function(classId)
	if (classId <= 0 or classId > lib.GetNumClasses()) then
		return nil
	end
	local class = ClassByID[classId]
	local specs = NAME_TO_SPEC_MAP[class.name]
	return #specs
end

lib.GetInspectSpecialization = function(unit)
	return nil
end

lib.GetActiveSpecGroup = function()
	return 1 -- primary spec slot
end

local DRUID_FERAL_TAB = 2
local DRUID_FERAL_INSTINCT = 3
local DRUID_THICK_HIDE = 5
local DRUID_GUARDIAN_SPEC_INDEX = 3
local DRUID_RESTO_SPEC_INDEX = 4

lib.GetSpecialization = function(isInspect, isPet, groupId)
	if (isInspect or isPet) then
		return nil
	end
	local specIndex
	local max = 0
	for tabIndex = 1, GetNumTalentTabs() do
		local spent = select(3, GetTalentTabInfo(tabIndex))
		if (spent > max) then
			specIndex = tabIndex
			max = spent
		end
	end

	local classId = select(3, UnitClass("player"))
	if (classId == Druid.ID) then
		-- Return Druid.Guardian if certain talents are selected
		local feralInstinctPoints = select(5, GetTalentInfo(DRUID_FERAL_TAB, DRUID_FERAL_INSTINCT))
		local thickHidePoints = select(5, GetTalentInfo(DRUID_FERAL_TAB, DRUID_THICK_HIDE))
		if (feralInstinctPoints == 5 and thickHidePoints == 5) then
			return DRUID_GUARDIAN_SPEC_INDEX
		end

		-- return 4 if Resto (3rd tab has most points), because Guardian is 3
		if (specIndex == DRUID_GUARDIAN_SPEC_INDEX) then
			return DRUID_RESTO_SPEC_INDEX
		else
			return specIndex
		end
	end

	return specIndex
end

lib.GetSpecializationInfo = function(specIndex, isInspect, isPet, inspectTarget, sex)
	if (isInspect or isPet) then
		return nil
	end
	local _, className = UnitClass("player")
	local specId = NAME_TO_SPEC_MAP[className][specIndex]

	if not specId then
		return nil
	end

	--[===[@debug
		print("GetSpecializationInfo", specIndex, className, specId) --@end-debug]===]

	local spec = SpecInfo[specId]
	return spec.ID, spec.name, spec.description, spec.icon, spec.background, spec.role, spec.primaryStat
end

lib.GetSpecializationInfoForClassID = function(classId, specIndex)
	local class = ClassByID[classId]
	if not class then
		return nil
	end

	--[===[@debug
		print("GetSpecializationInfoForClassID", classId, class.name, specIndex) --@end-debug]===]
	local specId = NAME_TO_SPEC_MAP[class.name][specIndex]
	local info = SpecInfo[specId]

	if not info then
		return nil
	end

	local isAllowed = classId == select(3, UnitClass("player"))
	return info.ID, info.name, info.description, info.icon, info.role, info.isRecommended, isAllowed
end

lib.GetSpecializationRoleByID = function(specId)
	return ROLE_MAP[specId]
end

lib.GetSpecializationRole = function(specIndex, isInspect, isPet)
	if (isInspect or isPet) then
		return nil
	end
	local _, className = UnitClass("player")
	local specId = NAME_TO_SPEC_MAP[className][specIndex]
	return ROLE_MAP[specId]
end

lib.GetNumClasses = function()
	return #ClassByID
end
