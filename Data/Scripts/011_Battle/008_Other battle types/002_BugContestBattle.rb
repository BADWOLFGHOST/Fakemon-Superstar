#===============================================================================
# Bug-Catching Contest battle scene (the visuals of the battle)
#===============================================================================
class Battle::Scene
  alias _bugContest_pbInitSprites pbInitSprites unless method_defined?(:_bugContest_pbInitSprites)

  def pbInitSprites
    _bugContest_pbInitSprites
    # "helpwindow" shows the currently caught Pokémon's details when asking if
    # you want to replace it with a newly caught Pokémon.
    @sprites["helpwindow"] = Window_UnformattedTextPokemon.newWithSize("", 0, 0, 32, 32, @viewport)
    @sprites["helpwindow"].z       = 90
    @sprites["helpwindow"].visible = false
  end

  def pbShowHelp(text)
    @sprites["helpwindow"].resizeToFit(text, Graphics.width)
    @sprites["helpwindow"].y       = 0
    @sprites["helpwindow"].x       = 0
    @sprites["helpwindow"].text    = text
    @sprites["helpwindow"].visible = true
  end

  def pbHideHelp
    @sprites["helpwindow"].visible = false
  end
end

#===============================================================================
# Bug-Catching Contest battle class
#===============================================================================
class BugContestBattle < Battle
  attr_accessor :ballCount

  def initialize(*arg)
    @ballCount = 0
    @ballConst = GameData::Item.get(:SPORTBALL).id
    super(*arg)
  end

  def pbItemMenu(idxBattler, _firstAction)
    return pbRegisterItem(idxBattler, @ballConst, 1)
  end

  def pbCommandMenu(idxBattler, _firstAction)
    return @scene.pbCommandMenuEx(idxBattler,
                                  [_INTL("竞赛球：{1}", @ballCount),
                                   _INTL("战斗"),
                                   _INTL("球"),
                                   _INTL("精灵"),
                                   _INTL("逃跑")], 4)
  end

  def pbConsumeItemInBag(_item, _idxBattler)
    @ballCount -= 1 if @ballCount > 0
  end

  def pbStorePokemon(pkmn)
    if pbBugContestState.lastPokemon
      lastPokemon = pbBugContestState.lastPokemon
      pbDisplayPaused(_INTL("你已经捉到了{1}。", lastPokemon.name))
      helptext = _INTL("已捕精灵：\n{1} Lv.{2} 最大HP：{3}\n此精灵：\n{4} Lv.{5} 最大HP：{6}",
                       lastPokemon.name, lastPokemon.level, lastPokemon.totalhp,
                       pkmn.name, pkmn.level, pkmn.totalhp)
      @scene.pbShowHelp(helptext)
      if pbDisplayConfirm(_INTL("替换精灵吗？"))
        pbBugContestState.lastPokemon = pkmn
        @scene.pbHideHelp
      else
        @scene.pbHideHelp
        return
      end
    else
      pbBugContestState.lastPokemon = pkmn
    end
    pbDisplay(_INTL("捉到了{1}！", pkmn.name))
  end

  def pbEndOfRoundPhase
    super
    @decision = 3 if @ballCount <= 0 && @decision == 0
  end
end
