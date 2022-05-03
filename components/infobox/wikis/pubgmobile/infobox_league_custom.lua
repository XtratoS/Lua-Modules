---
-- @Liquipedia
-- wiki=pubgmobile
-- page=Module:Infobox/League/Custom
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local League = require('Module:Infobox/League')
local String = require('Module:StringUtils')
local Variables = require('Module:Variables')
local Tier = require('Module:Tier')
local Template = require('Module:Template')
local Class = require('Module:Class')
local Injector = require('Module:Infobox/Widget/Injector')
local Cell = require('Module:Infobox/Widget/Cell')
local Title = require('Module:Infobox/Widget/Title')
local PrizePoolCurrency = require('Module:Prize pool currency')
local Table = require('Module:Table')

local CustomLeague = Class.new()
local CustomInjector = Class.new(Injector)

local _args
local _game

local _TODAY = os.date('%Y-%m-%d', os.time())
local _GAME = mw.loadData('Module:GameVersion')

local _MODES = {
	solo = 'Solos[[Category:Solos Mode Tournaments]]',
	duo = 'Duos[[Category:Duos Mode Tournaments]]',
	squad = 'Squads[[Category:Squads Mode Tournaments]]',
	['2v2'] = '2v2 TDM[[Category:2v2 TDM Tournaments]]',
	['4v4'] = '4v4 TDM[[Category:4v4 TDM Tournaments]]',
	['war mode'] = 'War Mode[[Category:War Mode Tournaments]]',
	default = '[[Category:Unknown Mode Tournaments]]',
}
_MODES.solos = _MODES.solo
_MODES.duos = _MODES.duo
_MODES.squads = _MODES.squad
_MODES.tdm = _MODES['2v2']

local _PERSPECTIVES = {
	fpp = {'FPP'},
	tpp = {'TPP'},
	mixed = {'FPP', 'TPP'},
}
_PERSPECTIVES.first = _PERSPECTIVES.fpp
_PERSPECTIVES.third = _PERSPECTIVES.tpp

local _PLATFORMS = {
	mobile = '[[Mobile]][[Category:Mobile Competitions]]',
	newstate = '[[New State]][[Category:Mobile Competitions]]',
	peace = '[[Peacekeeper Elite|Peace Elite]][[Category:Peacekeeper Elite Competitions]][[Category:Mobile Competitions]]',
	bgmi = '[[Battlegrounds Mobile India|BGMI]]' ..
		'[[Category:Battlegrounds Mobile India Competitions]][[Category:Mobile Competitions]]',
	default = '[[Category:Unknown Platform Competitions]]',
}

function CustomLeague.run(frame)
	local league = League(frame)
	_args = league.args

	league.addToLpdb = CustomLeague.addToLpdb
	league.createWidgetInjector = CustomLeague.createWidgetInjector
	league.defineCustomPageVariables = CustomLeague.defineCustomPageVariables

	return league:createInfobox(frame)
end

function CustomLeague:createWidgetInjector()
	return CustomInjector()
end

function CustomInjector:parse(id, widgets)
	if id == 'gamesettings' then
		return {
			Cell{name = 'Game version', content = {
					CustomLeague._getGameVersion()
				}
			},
			Cell{name = 'Game mode', content = {
					CustomLeague:_getGameMode()
				}
			},
			Cell{name = 'Platform', content = {
					CustomLeague:_getPlatform()
				}
			},
		}
	elseif id == 'prizepool' then
		return {
			Cell{
				name = 'Prize pool',
				content = {CustomLeague:_createPrizepool()}
			},
		}
	elseif id == 'liquipediatier' then
		return {
			Cell{
				name = 'Liquipedia tier',
				content = {CustomLeague:_createTierDisplay()},
				classes = {_args['pubgpremier'] == 'true' and 'valvepremier-highlighted' or ''},
			},
		}
	elseif id == 'customcontent' then
		if _args.player_number then
			table.insert(widgets, Title{name = 'Players'})
			table.insert(widgets, Cell{name = 'Number of players', content = {_args.player_number}})
		end

		--teams section
		if _args.team_number then
			table.insert(widgets, Title{name = 'Teams'})
			table.insert(widgets, Cell{name = 'Number of teams', content = {_args.team_number}})
		end
	end
	return widgets
end

function CustomLeague:addToLpdb(lpdbData, args)
	lpdbData.game = args.platform
	lpdbData.participantsnumber = args.player_number or args.team_number
	lpdbData.publishertier = args.pubgpremier
	lpdbData.extradata = {
		individual = String.isNotEmpty(args.player_number) and 'true' or '',
	}

	return lpdbData
end

function CustomLeague:defineCustomPageVariables()
	Variables.varDefine('tournament_game', _game or _args.game)
	Variables.varDefine('tournament_publishertier', _args['pubgpremier'])
	--Legacy Vars:
	Variables.varDefine('tournament_edate', Variables.varDefault('tournament_enddate'))
end

function CustomLeague._getGameVersion()
	local game = string.lower(_args.game or '')
	_game = _GAME[game]
	return _game
end

function CustomLeague:_createPrizepool()
	if String.isEmpty(_args.prizepool) and String.isEmpty(_args.prizepoolusd) then
		return nil
	end
	local date
	if String.isNotEmpty(_args.currency_rate) then
		date = _args.currency_date
	end

	return PrizePoolCurrency._get({
		prizepool = _args.prizepool,
		prizepoolusd = _args.prizepoolusd,
		currency = _args.localcurrency,
		rate = _args.currency_rate,
		date = date or Variables.varDefault('tournament_enddate', _TODAY),
	})
end

function CustomLeague:_createTierDisplay()
	local tier = _args.liquipediatier or ''
	local tierType = _args.liquipediatiertype or _args.tiertype or ''
	if String.isEmpty(tier) then
		return nil
	end

	local tierText = Tier['text'][tier]
	local hasInvalidTier = tierText == nil
	tierText = tierText or tier

	local hasInvalidTierType = false

	local output = '[[' .. tierText .. ' Tournaments|' .. tierText .. ']]'
		.. '[[Category:' .. tierText .. ' Tournaments]]'

	if not String.isEmpty(tierType) then
		tierType = Tier['types'][string.lower(tierType or '')] or tierType
		hasInvalidTierType = Tier['types'][string.lower(tierType or '')] == nil
		tierType = '[[' .. tierType .. ' Tournaments|' .. tierType .. ']]'
			.. '[[Category:' .. tierType .. ' Tournaments]]'
		output = tierType .. '&nbsp;(' .. output .. ')'
	end

	output = output ..
		(hasInvalidTier and '[[Category:Pages with invalid Tier]]' or '') ..
		(hasInvalidTierType and '[[Category:Pages with invalid Tiertype]]' or '')
	return output
end

function CustomLeague:_getGameMode()
	if String.isEmpty(_args.perspective) and String.isEmpty(_args.mode) then
		return nil
	end

	local getPerspectives = function(perspectiveInput)
		local perspective = string.lower(perspectiveInput or '')
		-- Clean unnecessary data from the input
		perspective = string.gsub(perspective, ' person', '')
		perspective = string.gsub(perspective, ' perspective', '')
		return _PERSPECTIVES[perspective] or {}
	end
	local getPerspectiveDisplay = function(perspective)
		return Template.safeExpand(mw.getCurrentFrame(), 'Abbr/' .. perspective)
	end
	local displayPerspectives = Table.mapValues(getPerspectives(_args.perspective), getPerspectiveDisplay)

	local mode = _MODES[string.lower(_args.mode or '')] or _MODES['default']

	return mode .. '&nbsp;' .. table.concat(displayPerspectives, '&nbsp;')
end

function CustomLeague:_getPlatform()
	if String.isEmpty(_args.platform) then
		return nil
	end

	local platform = string.lower(_args.platform or '')

	return _PLATFORMS[platform] or _PLATFORMS['default']
end

return CustomLeague