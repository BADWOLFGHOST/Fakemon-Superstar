module Settings
#==========================================================================
# 宝可梦能力值、个体值、努力值雷达图的颜色。
#==========================================================================
  COLOR_STATS = Color.new(136, 195, 243)
  COLOR_IV = Color.new(206, 182, 245)
  COLOR_EV = Color.new(216, 217, 107)
#==========================================================================
# 是否使用小字号的特性描述。（此设定纯属个人喜好）
#==========================================================================
  ABILITY_SMALL_FONT = false
end
#==========================================================================
# 插件的主要部分。
#==========================================================================
class PokemonSummary_Scene
  MUI = PluginManager.installed?("Modular UI Scenes")
  EPUI = PluginManager.installed?("[MUI] Enhanced Pokemon UI")
  alias radar_pbStartScene pbStartScene
    def pbStartScene(*args)
      radar_pbStartScene(*args)
      @sprites["hexagon"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["hexagon"].visible = false
      if EPUI
      @sprites["hexagoniv"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["hexagoniv"].visible = false   
      @sprites["hexagonev"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["hexagonev"].visible = false   
      end
    end
  
  alias radar_drawPage drawPage
    def drawPage(page)
      radar_drawPage(page)  
      if MUI
        is_skills_page = (@page_id == :page_skills)
      else
        is_skills_page = (@page == 3)
      end
      @sprites["hexagon"].visible = is_skills_page if @sprites["hexagon"]
      if EPUI
      @sprites["hexagon"].visible = (is_skills_page && !@statToggle) if @sprites["hexagon"]
      @sprites["hexagoniv"].visible = (is_skills_page && @statToggle) if @sprites["hexagoniv"]
      @sprites["hexagonev"].visible = (is_skills_page && @statToggle) if @sprites["hexagonev"]
      end
    end

  def drawPageThree
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    statshadows = {}
    GameData::Stat.each_main { |s| statshadows[s.id] = shadow }
    if !@pokemon.shadowPokemon? || @pokemon.heartStage <= 3
      @pokemon.nature_for_stats.stat_changes.each do |change|
        statshadows[change[0]] = Color.new(136, 96, 72) if change[1] > 0
        statshadows[change[0]] = Color.new(64, 120, 152) if change[1] < 0
      end
    end 
    # Write various bits of text
    textpos = [
    [_INTL("HP"), 363, 75, :center, base, statshadows[:HP]],
    [sprintf("%d/%d", @pokemon.hp, @pokemon.totalhp), 363, 97,
                 :center, Color.new(64, 64, 64), Color.new(176, 176, 176)],
    [_INTL("攻击"), 420, 120, :left, base, statshadows[:ATTACK]],      
    [@pokemon.attack.to_s, 425, 142, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)],
    [_INTL("防御"), 420, 170, :left, base, statshadows[:DEFENSE]],
    [@pokemon.defense.to_s, 425, 192, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)],
    [_INTL("特攻"), 305, 120, :right, base, statshadows[:SPECIAL_ATTACK]],
    [@pokemon.spatk.to_s, 300, 142, :right, Color.new(64, 64, 64), Color.new(176, 176, 176)],
    [_INTL("特防"), 305, 170, :right, base, statshadows[:SPECIAL_DEFENSE]],
    [@pokemon.spdef.to_s, 300, 192, :right, Color.new(64, 64, 64), Color.new(176, 176, 176)],
    [_INTL("速度"), 363, 225, :center, base, statshadows[:SPEED]],
    [@pokemon.speed.to_s, 363, 245, :center, Color.new(64, 64, 64), Color.new(176, 176, 176)],
    [_INTL("特性"), 224, 290, :left, base, shadow]
    ]
    # Draw ability name and description
    ability = @pokemon.ability
    if ability
      textpos.push([ability.name, 358, 290, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)])
      if Settings::ABILITY_SMALL_FONT
      pbSetSmallFont(overlay)
      drawFormattedTextEx(overlay, 224, 322, 294, ability.description, Color.new(64, 64, 64), Color.new(176, 176, 176), 20)
      pbSetSystemFont(overlay)
      else
      drawTextEx(overlay, 224, 322, 282, 2, ability.description, Color.new(64, 64, 64), Color.new(176, 176, 176))
      end
    end
    # Draw all text
    pbDrawTextPositions(overlay, textpos)
    # Dynamax Compatibility.(DBK for v21.1 and ZUD for v20.1)
    if PluginManager.installed?("[DBK] Dynamax")
      if @pokemon.dynamax_able? && !$game_switches[Settings::NO_DYNAMAX]
        imagepos = [[sprintf(Settings::DYNAMAX_GRAPHICS_PATH + "dynamax_meter"), 56, 308]]
        overlay = @sprites["dynamax_overlay"].bitmap
        pbDrawImagePositions(overlay, imagepos)
        dlevel = @pokemon.dynamax_lvl
        levels = AnimatedBitmap.new(_INTL(Settings::DYNAMAX_GRAPHICS_PATH + "dynamax_levels"))
        overlay.blt(69, 325, levels.bitmap, Rect.new(0, 0, dlevel * 12, 21))
      end
    end
    if PluginManager.installed?("ZUD Mechanics") 
      if @pokemon.dynamax_able? && !@pokemon.isSpecies?(:ETERNATUS) && !$game_switches[Settings::NO_DYNAMAX]
        path = "Graphics/Plugins/ZUD/UI/"
        imagepos = [[sprintf(path + "dynamax_meter"), 56, 308]]
        overlay = @sprites["zud_overlay"].bitmap
        pbDrawImagePositions(overlay, imagepos)
        dlevel = @pokemon.dynamax_lvl
        levels = AnimatedBitmap.new(_INTL(path + "dynamax_levels"))
        overlay.blt(69, 325, levels.bitmap, Rect.new(0, 0, dlevel * 12, 21))
      end
    end
    # Draw Radar Chart.
    stats = [@pokemon.totalhp, @pokemon.attack, @pokemon.defense,
    [1, 50 + 2.5 * @pokemon.level - @pokemon.speed].max, @pokemon.spdef, @pokemon.spatk]
    @sprites["hexagon"].bitmap.clear
    @sprites["hexagon"].opacity = 160
    @sprites["hexagon"].draw_hexagon_with_values(
      363, 171, 50 * Math.sqrt(3), 50 * 2, Settings::COLOR_STATS, 50 + 2.5 * @pokemon.level, stats, nil, true, false)
  end
#==========================================================================
# Compatibility/Adaptation with Enhanced Pokemon UI.
#==========================================================================  
  if EPUI
    alias enhanced_drawPageThree drawPageThree
    def drawPageThree
      (@statToggle) ? drawEnhancedStats : enhanced_drawPageThree
      return if !Settings::SUMMARY_IV_RATINGS
      overlay = @sprites["overlay"].bitmap
      pbDisplayIVRatings(@pokemon, overlay)
    end

    def drawEnhancedStats
      overlay = @sprites["overlay"].bitmap
      base   = Color.new(248, 248, 248)
      shadow = Color.new(104, 104, 104)
      base2 = Color.new(64, 64, 64)
      shadow2 = Color.new(176, 176, 176)
      index = 0
      statshadows = {}
      GameData::Stat.each_main { |s| statshadows[s.id] = shadow }
      if !@pokemon.shadowPokemon? || @pokemon.heartStage <= 3
        @pokemon.nature_for_stats.stat_changes.each do |change|
          statshadows[change[0]] = Color.new(136, 96, 72) if change[1] > 0
          statshadows[change[0]] = Color.new(64, 120, 152) if change[1] < 0
        end
      end       
      ev_total = @pokemon.ev[:HP] + @pokemon.ev[:ATTACK] + @pokemon.ev[:DEFENSE] + @pokemon.ev[:SPECIAL_ATTACK] +
      @pokemon.ev[:SPECIAL_DEFENSE] + @pokemon.ev[:SPEED]
      iv_total = @pokemon.iv[:HP] + @pokemon.iv[:ATTACK] + @pokemon.iv[:DEFENSE] + @pokemon.iv[:SPECIAL_ATTACK] +
      @pokemon.iv[:SPECIAL_DEFENSE] + @pokemon.iv[:SPEED]
      textpos = [
        [_INTL("HP"), 363, 75, :center, base, statshadows[:HP]],
        [sprintf("%d|%d", @pokemon.iv[:HP], @pokemon.ev[:HP]), 363, 97,
            :center, Color.new(64, 64, 64), Color.new(176, 176, 176)],
        [_INTL("攻击"), 420, 120, :left, base, statshadows[:ATTACK]],      
        [sprintf("%d|%d", @pokemon.iv[:ATTACK], @pokemon.ev[:ATTACK]),
         425, 142, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)],
        [_INTL("防御"), 420, 170, :left, base, statshadows[:DEFENSE]],
        [sprintf("%d|%d", @pokemon.iv[:DEFENSE], @pokemon.ev[:DEFENSE]),
         425, 192, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)],
        [_INTL("特攻"), 305, 120, :right, base, statshadows[:SPECIAL_ATTACK]],
        [sprintf("%d|%d", @pokemon.iv[:SPECIAL_ATTACK], @pokemon.ev[:SPECIAL_ATTACK]),
         300, 142, :right, Color.new(64, 64, 64), Color.new(176, 176, 176)],
        [_INTL("特防"), 305, 170, :right, base, statshadows[:SPECIAL_DEFENSE]],
        [sprintf("%d|%d", @pokemon.iv[:SPECIAL_DEFENSE], @pokemon.ev[:SPECIAL_DEFENSE]),
         300, 192, :right, Color.new(64, 64, 64), Color.new(176, 176, 176)],
        [_INTL("速度"), 363, 225, :center, base, statshadows[:SPEED]],
        [sprintf("%d|%d", @pokemon.iv[:SPEED], @pokemon.ev[:SPEED]),
         363, 245, :center, Color.new(64, 64, 64), Color.new(176, 176, 176)],        
        [_INTL("总努力/个体"), 224, 290, :left, base, shadow],
        [sprintf("%d  |  %d", ev_total, iv_total), 434, 290, :center, base2, shadow2],
        [_INTL("剩余努力值："), 224, 322, :left, base2, shadow2],
        [sprintf("%d/%d", Pokemon::EV_LIMIT - ev_total, Pokemon::EV_LIMIT), 444, 322, :center, base2, shadow2],
        [_INTL("觉醒力量属性："), 224, 354, :left, base2, shadow2]]
      iv = [@pokemon.iv[:HP], @pokemon.iv[:ATTACK], @pokemon.iv[:DEFENSE],
      [1,Pokemon::IV_STAT_LIMIT - @pokemon.iv[:SPEED]].max, @pokemon.iv[:SPECIAL_DEFENSE], @pokemon.iv[:SPECIAL_ATTACK]]
      @sprites["hexagoniv"].bitmap.clear
      @sprites["hexagoniv"].opacity = 150
      @sprites["hexagoniv"].draw_hexagon_with_values(
        363, 171, 50 * Math.sqrt(3), 50 * 2, Settings::COLOR_IV, Pokemon::IV_STAT_LIMIT, iv, nil, true, false)
      ev = [@pokemon.ev[:HP], @pokemon.ev[:ATTACK], @pokemon.ev[:DEFENSE],
      [4, Pokemon::EV_STAT_LIMIT - @pokemon.ev[:SPEED]].max, @pokemon.ev[:SPECIAL_DEFENSE], @pokemon.ev[:SPECIAL_ATTACK]]
      @sprites["hexagonev"].bitmap.clear
      @sprites["hexagonev"].opacity = 140
      @sprites["hexagonev"].draw_hexagon_with_values(
        363, 171, 50 * Math.sqrt(3), 50 * 2, Settings::COLOR_EV, Pokemon::EV_STAT_LIMIT, ev, nil, true, false)
      pbDrawTextPositions(overlay, textpos)
      hiddenpower = pbHiddenPower(@pokemon)
      type_number = GameData::Type.get(hiddenpower[0]).icon_position
      type_rect = Rect.new(0, type_number * 28, 64, 28)
      overlay.blt(428, 351, @typebitmap.bitmap, type_rect)
    end

    def pbDisplayIVRatings(pokemon, overlay)
      return if !pokemon
      imagepos = []
      path  = Settings::POKEMON_UI_GRAPHICS_PATH
      style = (Settings::IV_DISPLAY_STYLE == 0) ? 0 : 16
      maxIV = Pokemon::IV_STAT_LIMIT
      icon = []
      GameData::Stat.each_main do |s|
        stat = pokemon.iv[s.id]
        case stat
        when maxIV     then icon.push(5)  # 31 IV
        when maxIV - 1 then icon.push(4)  # 30 IV
        when 0         then icon.push(0)  #  0 IV
        else
          if stat > (maxIV - (maxIV / 4).floor)
            icon.push(3) # 25-29 IV
          elsif stat > (maxIV - (maxIV / 2).floor)
            icon.push(2) # 16-24 IV
          else
            icon.push(1) #  1-15 IV
          end
        end
      end
      imagepos.push([path + "iv_ratings", 398, 75, icon[0] * 16, style, 16, 16])
      imagepos.push([path + "iv_ratings", 475, 120, icon[1] * 16, style, 16, 16])
      imagepos.push([path + "iv_ratings", 475, 170, icon[2] * 16, style, 16, 16])
      imagepos.push([path + "iv_ratings", 240, 120, icon[3] * 16, style, 16, 16])
      imagepos.push([path + "iv_ratings", 240, 170, icon[4] * 16, style, 16, 16])
      imagepos.push([path + "iv_ratings", 398, 225, icon[5] * 16, style, 16, 16])
      pbDrawImagePositions(overlay, imagepos)
    end      
  end
end