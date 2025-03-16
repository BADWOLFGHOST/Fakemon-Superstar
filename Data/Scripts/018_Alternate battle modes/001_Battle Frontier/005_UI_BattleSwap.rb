#===============================================================================
#
#===============================================================================
class BattleSwapScene
  RED_TEXT_BASE   = Color.new(232, 32, 16)
  RED_TEXT_SHADOW = Color.new(248, 168, 184)

  def pbStartRentScene(rentals)
    @rentals = rentals
    @mode = 0   # rental (pick 3 out of 6 initial Pokémon)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    addBackgroundPlane(@sprites, "bg", "rentbg", @viewport)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("出租精灵"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["list"] = Window_AdvancedCommandPokemonEx.newWithSize(
      [], 0, 64, Graphics.width, Graphics.height - 128, @viewport
    )
    @sprites["help"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.height, 64, @viewport
    )
    @sprites["msgwindow"].visible = false
    pbUpdateChoices([])
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbStartSwapScene(currentPokemon, newPokemon)
    @currentPokemon = currentPokemon
    @newPokemon = newPokemon
    @mode = 1   # swap (pick 1 out of 3 opponent's Pokémon to take)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    addBackgroundPlane(@sprites, "bg", "swapbg", @viewport)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("精灵交换"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["list"] = Window_AdvancedCommandPokemonEx.newWithSize(
      [], 0, 64, Graphics.width, Graphics.height - 128, @viewport
    )
    @sprites["help"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["msgwindow"].visible = false
    pbInitSwapScreen
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbInitSwapScreen
    commands = pbGetCommands(@currentPokemon, [])
    commands.push(_INTL("取消"))
    @sprites["help"].text = _INTL("选择精灵交换。")
    @sprites["list"].commands = commands
    @sprites["list"].index = 0
    @mode = 1
  end

  # End the scene here
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbShowCommands(commands)
    UIHelper.pbShowCommands(@sprites["msgwindow"], nil, commands) { pbUpdate }
  end

  def pbConfirm(message)
    UIHelper.pbConfirm(@sprites["msgwindow"], message) { pbUpdate }
  end

  def pbGetCommands(list, choices)
    red_text_tag = shadowc3tag(RED_TEXT_BASE, RED_TEXT_SHADOW)
    commands = []
    list.length.times do |i|
      pkmn = list[i]
      category = pkmn.species_data.category
      cmd = _INTL("{1}-{2}精灵", pkmn.speciesName, category)
      cmd = red_text_tag + cmd if choices.include?(i)   # Red text
      commands.push(cmd)
    end
    return commands
  end

  # Processes the scene
  def pbChoosePokemon(canCancel)
    pbActivateWindow(@sprites, "list") do
      loop do
        Graphics.update
        Input.update
        pbUpdate
        if Input.trigger?(Input::BACK) && canCancel
          return -1
        elsif Input.trigger?(Input::USE)
          index = @sprites["list"].index
          if index == @sprites["list"].commands.length - 1 && canCancel
            return -1
          elsif index == @sprites["list"].commands.length - 2 && canCancel && @mode == 2
            return -2
          else
            return index
          end
        end
      end
    end
  end

  def pbUpdateChoices(choices)
    commands = pbGetCommands(@rentals, choices)
    @choices = choices
    case choices.length
    when 0
      @sprites["help"].text = _INTL("选择第一只精灵。")
    when 1
      @sprites["help"].text = _INTL("选择第二只精灵。")
    else
      @sprites["help"].text = _INTL("选择第三只精灵。")
    end
    @sprites["list"].commands = commands
  end

  def pbSwapChosen(_pkmnindex)
    commands = pbGetCommands(@newPokemon, [])
    commands.push(_INTL("交换用精灵"))
    commands.push(_INTL("取消"))
    @sprites["help"].text = _INTL("选择精灵。")
    @sprites["list"].commands = commands
    @sprites["list"].index = 0
    @mode = 2
  end

  def pbSwapCanceled
    pbInitSwapScreen
  end

  def pbSummary(list, index)
    visibleSprites = pbFadeOutAndHide(@sprites) { pbUpdate }
    scene = PokemonSummary_Scene.new
    screen = PokemonSummaryScreen.new(scene)
    @sprites["list"].index = screen.pbStartScreen(list, index)
    pbFadeInAndShow(@sprites, visibleSprites) { pbUpdate }
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
end

#===============================================================================
#
#===============================================================================
class BattleSwapScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartRent(rentals)
    @scene.pbStartRentScene(rentals)
    chosen = []
    loop do
      index = @scene.pbChoosePokemon(false)
      commands = []
      commands.push(_INTL("信息"))
      if chosen.include?(index)
        commands.push(_INTL("取消选择"))
      else
        commands.push(_INTL("出租"))
      end
      commands.push(_INTL("其他"))
      command = @scene.pbShowCommands(commands)
      case command
      when 0
        @scene.pbSummary(rentals, index)
      when 1
        if chosen.include?(index)
          chosen.delete(index)
          @scene.pbUpdateChoices(chosen.clone)
        else
          chosen.push(index)
          @scene.pbUpdateChoices(chosen.clone)
          if chosen.length == 3
            if @scene.pbConfirm(_INTL("确定是这些精灵吗？"))
              retval = []
              chosen.each { |i| retval.push(rentals[i]) }
              @scene.pbEndScene
              return retval
            else
              chosen.delete(index)
              @scene.pbUpdateChoices(chosen.clone)
            end
          end
        end
      end
    end
  end

  def pbStartSwap(currentPokemon, newPokemon)
    @scene.pbStartSwapScene(currentPokemon, newPokemon)
    loop do
      pkmn = @scene.pbChoosePokemon(true)
      if pkmn >= 0
        commands = [_INTL("信息"), _INTL("交换"), _INTL("重新选择")]
        command = @scene.pbShowCommands(commands)
        case command
        when 0
          @scene.pbSummary(currentPokemon, pkmn)
        when 1
          @scene.pbSwapChosen(pkmn)
          yourPkmn = pkmn
          loop do
            pkmn = @scene.pbChoosePokemon(true)
            if pkmn >= 0
              if @scene.pbConfirm(_INTL("接受这个精灵吗？"))
                @scene.pbEndScene
                currentPokemon[yourPkmn] = newPokemon[pkmn]
                return true
              end
            elsif pkmn == -2
              @scene.pbSwapCanceled
              break   # Back to first screen
            elsif pkmn == -1
              if @scene.pbConfirm(_INTL("取消交换？"))
                @scene.pbEndScene
                return false
              end
            end
          end
        end
      elsif @scene.pbConfirm(_INTL("取消交换？"))
        # Canceled
        @scene.pbEndScene
        return false
      end
    end
  end
end
