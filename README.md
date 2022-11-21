# Skada Damage Meter (_Revisited - v1.8.82_)

![Discord](https://img.shields.io/discord/795698054371868743?label=discord)
![GitHub last commit](https://img.shields.io/github/last-commit/bkader/Skada-Damage-Meter)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/bkader/Skada-Damage-Meter?label=version)

_This version is a total **Rewrite** of Skada `r301` for `3.3.5` and not a **Backport** like some believe._

Skada is a modular damage meter with various viewing modes, segmented fights and customizable windows. It aims to be highly efficient with memory and CPU.

<p align="center"><img src="https://user-images.githubusercontent.com/4732702/203091996-2282a6ba-5d28-475b-a7bf-550e23e60951.png" alt="Skada Damage Meter"></p>

_**FOR PRIVATE SERVERS**_:
* _[Wrath of the Lich King](https://github.com/bkader/Skada-WoTLK)_
* _[Cataclysm](https://github.com/bkader/Skada-Cata)_
* _[Mists of Pandaria](https://github.com/bkader/Skada-MoP)_

## IMPORTANT: How to install

1. If you used the default on **Skada** before, please make sure to delete all its files from `Interface\AddOns` folder as well as all its _SavedVariables_ from `WTF` folder (_just delete all `Skada.lua` and `Skada.lua.bak` for this folder. Use the search box for quick delete_). If you are new, skip this step.
2. [Download the package](https://github.com/bkader/Skada-Damage-Meter/archive/refs/heads/main.zip).
3. Open the Zip package inside which you will find a single folder named `Skada-Damage-Meter-main`.
4. Extract or drag and drop the unique folder `Skada` into your `Interface\AddOns` folder.
5. If you want to use `SkadaImprovement` and/or `SkadaStorage` modules, drop them there as well.

## Show Love & Support

Though it's not required, **PayPal** donations are most welcome at **bkader[at]mail.com**, or via Discord [Donate Bot](https://donatebot.io/checkout/795698054371868743).

## What's the difference?

This version of Skada is a mix between the old default version available for **WotLK** and the **latest retail** version. Everything was fully rewritten to provide more detailed spell breakdowns and more. Here is why it is better than the old default version:

- An **All-In-One** addon instead of having modules seperated into addons. Most of the modules can be enable or disabled on the options panel.
- Lots of new modules were added, some found on the internet and others were requested by the community.
- Windows are resizable using the resize grips/handles found at both bottom corners. Holding **SHIFT** when resizing changes widths while holding **ALT** changes heights.
- Bars are more fancy, colored by not only class but also spell school colors.
- Bars can display players/enemies classes, roles or specializations unlike the default old version. Spells also had their icons changed to display info tooltips (_spells tooltips_).
- The **most (*if not the only*) accurate** combat log parser for WotLK, whether it is for damage, healing or absorbs. Since absorbs aren't really available in this expansion, this Skada is best at estimating amounts with lots of calculations and logics implemented after months and gigabytes of combat log parsing.
- Profiles importation/exportation as well as dual-spec profiles.
- Under consistent, free and solo development thanks to WotLK community and their feedbacks (_helps and pull requests are most welcome_).
- An annoying number of options available for more advanced players.

### API

This concept was added as of version **1.8.72** and allows the player to access and use data provided by Skada externally. It can be used for example by **WeakAuras** to display things you want.

#### Segments/Sets functions

```lua
-- to retrieve a segment (current for example):
local set = Skada:GetSet("current")

-- After the segment is found, you have access to the following functions
-- called like so: set:Func(...)
set:GetTime() -- returns the segment time

set:GetActor(name, guid) -- attempts to retrieve a player or an enemy.
set:GetPlayer(guid, name) -- attempts to retrieve a player.
set:GetEnemy(name, guid) -- attempts to retrieve an enemy.
set:GetActorTime(guid, name, active) -- returns the actor's time if found or 0.

set:GetDamage(useful) -- returns the segment damage amount, exlucing overkill if "useful" is true
set:GetDPS(useful) -- returns the dps and damage amount, excluding overkill if "useful" is true

set:GetDamageTaken() -- returns the damage taken by players.
set:GetDTPS() -- returns the damage taken by players per second and damage amount.

set:GetActorDamage(guid, name, useful) -- returns the damage done by the given actor.
set:GetActorDPS(guid, name, useful, active) -- returns the dps and damage for the given actor.
set:GetActorDamageTargets(guid, name, tbl) -- returns the table of damage targets.
set:GetActorDamageSpells(guid, name) -- returns the table of damage spells.
set:GetActorDamageOnTarget(guid, name, targetname) -- returns the damage, overkill [and useful for enemies]

set:GetActorDamageTaken(guid, name) -- returns the damage taken by the actor.
set:GetActorDTPS(guid, name, active) -- returns the damage taken by the actor per second and damage amount.
set:GetActorDamageSources(guid, name, tbl) -- returns the table of damage taken sources.
set:GetActorDamageTakenSpells(guid, name) -- returns the table of damage taken spells.
set:GetActorDamageFromSource(guid, name, targetname) -- returns the damage, overkill [and useful for enemies].

set:GetOverkill() -- returns the amount of overkill

set:GetHeal() -- returns the amount of heal.
set:GetHPS() -- returns the amount of heal per second and the heal amount.

set:GetOverheal() -- returns the amount of overheal.
set:GetOHPS() -- returns the amount of overheal per second and the overheal amount.

set:GetTotalHeal() -- returns the amount of heal, including the overheal
set:GetTHPS() -- returns the amount of heal+overheal per second

set:GetAbsorb() -- returns the amount of absorbs.
set:GetAPS() -- returns the amount of absorbs per second and the absorb amount.

set:GetAbsorbHeal() -- returns the amount of heals and absorbs combined.
set:GetAHPS() -- returns the amount of heals and absorbs combined per second.

--
-- below are functions available only if certain modules are enabled.
--

-- requires Enemies modules
set:GetEnemyDamage() -- returns the damage done by enemeies.
set:GetEnemyDPS() -- returns enemies DPS and damage amount.
set:GetEnemyDamageTaken() -- returns the damage taken by enemeies.
set:GetEnemyDTPS() -- returns enemies DTPS and damage taken amount.
set:GetEnemyOverkill() -- returns enemies overkill amount.
set:GetEnemyHeal(absorb) -- returns enemies heal amount [including absorbs]
set:GetEnemyHPS(absorb, active) -- returns enemies HPS and heal amount.

-- requires Absorbed Damage module
set:GetAbsorbedDamage() -- returns the amount of absorbed damage.
```

#### Actors functions (_Common to both players and enemies_)

First, you would want to get the segment, then the actor. After, you will have access to a set of predefined functions:

```lua
-- After retrieving and actor like so:
local set = Skada:GetSet("current")
local actor = set:GetActor(name, guid)

-- here is the list of common functions.
actor:GetTime(active) -- returns actor's active/effective time.

actor:GetDamage(useful) -- returns actor's damage, excluding overkill if "useful" is true
actor:GetDPS(useful, active) -- returns the actor's active/effective DPS and damage amount
actor:GetDamageTargets(tbl) -- returns the actor's damage targets table and the damage amount.
actor:GetDamageOnTarget(name) -- returns the damage, overkill [and userful] on the given target

actor:GetOverkill() -- returns the amount of overkill

actor:GetDamageTaken() -- returns the amount of damage taken
actor:GetDTPS(active) -- returns the DTPS and the amount of damage taken
actor:GetDamageSources(tbl) -- returns the table of damage taken sources and damage amount.
actor:GetDamageFromSource(name) -- returns the damage, overkill [and useful for enemies]

actor:GetHeal() -- returns the actor's heal amount.
actor:GetHPS(active) -- returns the actor's HPS and heal amount.
actor:GetHealTargets(tbl) -- returns the actor's heal targets table.
actor:GetHealOnTarget(name, inc_overheal) -- returns the actor's heal and overheal amount on the target.

actor:GetOverheal() -- returns the actor's overheal amount.
actor:GetOHPS(active) -- returns the actor's overheal per second and overheal amount.
actor:GetOverhealTargets(tbl) -- returns the table of actor's overheal targets.
actor:GetOverhealSpellsOnTarget(name) -- returns the spells and amount of overheal on the given target.

actor:GetTotalHeal() -- returns the actor's heal amount including overheal.
actor:GetTHPS(active) -- returns the actor's total heal per second and total heal amount.
actor:GetTotalHealTargets(tbl) -- returns the table of actor's total heal targets.
actor:GetTotalHealOnTarget(name) -- returns the total heal amount on the given target.

actor:GetAbsorb() -- returns the amount of absorbs.
actor:GetAPS(active) -- returns the absorbs per second and absorbs amount.
actor:GetAbsorbTargets(tbl) -- returns the table of actor's absorbed targets.

actor:GetAbsorbHeal() -- returns the amounts of heal and absorb combined.
actor:GetAHPS(active) -- returns the heal and absorb combined, per second and their combined amount.
actor:GetAbsorbHealTargets(tbl) -- returns the table of actor's healed and absorbed targets.
actor:GetAbsorbHealOnTarget(name, inc_overheal) -- returns the actor's heal (including absorbs) and overheal on the target.
```

#### Extending Players functions

If you wish to extend players API, you only need to add whatever function you want to the **playerPrototype** table like so:

```lua
local playerPrototype = Skada.playerPrototype

-- example of getting the uptime of the given aura
function playerPrototype:GetAuraUptime(spellid)
  if self.auras and spellid and self.auras[spellid] then
    return self.auras[spellid].uptime or 0
  end
end
```

Now in order to use the function, you simply do like so:

```lua
local set = Skada:GetSet("current")
local player = set:GetPlayer(UnitGUID("player"), UnitName("player")) -- get my own table

-- dummy aura: 12345
local uptime = player:GetAuraUptime(12345)

```

#### Extending Enemies functions

The same thing mentioned above can be added to enemies, but this time by adding it to the **enemyPrototype** object/table.

Skada comes with a set of predefined enemies functions that you can use:

```lua
local set = Skada:GetSet("current")
local enemy = set:GetEnemy("The Lich King") -- example

-- requires: Enemy Damage Taken module
enemy:GetDamageTakenBreakdown() -- returns damage, total and useful.
enemy:GetDamageSpellSources() -- returns the list of players by the given spell.

-- require Enemy Damage Done module
enemy:GetDamageTargetSpells(name) -- returns the table of enemy's damage spells on the target.
enemy:GetDamageSpellTargets(spellid) -- returns the targets of the enemy's given damage spell.
```

#### RECAP: Extending the API

You can easily extend the API if you know the table structure of course:

```lua
-- To extend segments functions:
local setPrototype = Skada.setPrototype -- use the prototype
function setPrototype:MyOwnSetFunction()
  -- do your thing
end

-- to extend common functions to both players and enemies
local actorPrototype = Skada.actorPrototype
function actorPrototype:MyOwnActorFunction()
  -- do your thing
end

-- To extend players functions
local playerPrototype = Skada.playerPrototype
function playerPrototype:MyOwnPlayerFunction()
  -- do your thing
end

-- To extend enemies functions:
local enemyPrototype = Skada.enemyPrototype
function enemyPrototype:MyOwnEnemyFunction()
  -- do your thing
end
```
