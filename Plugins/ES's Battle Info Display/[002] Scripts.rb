class Battle_Info_Display
  
  def initialize(battle)
    @dir        = Settings::ESBID_DIR
    @show_type = Settings::ESBID_SHOW_TYPE
    @type_ox    = Settings::ESBID_TYPE_OFFSET_X
    @type_oy    = Settings::ESBID_TYPE_OFFSET_Y
    @show_item = Settings::ESBID_SHOW_ITEM
    @up        = Settings::ESBID_STAT_UP
    @down      = Settings::ESBID_STAT_DOWN
    
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 999998
    @battle     = battle
    @sprites    = {}
    @sprites["bg"]         = Sprite.new(@viewport)
    @sprites["bg"].bitmap = Bitmap.new(@dir + "bg_m")
    @sprites["bg"].bitmap = Bitmap.new(@dir + "bg_f") if $player&.female?
    @sprites["bg"].x       = 0
    @sprites["bg"].y       = 0
    @sprites["bg"].z       = @viewport.z
    
    @sprites["names"]   = BitmapSprite.new(Graphics.width, Graphics.height)
    @sprites["names"].x = 0
    @sprites["names"].y = 0
    @sprites["names"].z = @viewport.z + 1
    pbSetNarrowFont(@sprites["names"].bitmap)
    
    @sprites["stats"]   = BitmapSprite.new(Graphics.width, Graphics.height)
    @sprites["stats"].x = 0
    @sprites["stats"].y = 0
    @sprites["stats"].z = @viewport.z + 1
    pbSetNarrowFont(@sprites["stats"].bitmap)
    
    @sprites["field"]   = BitmapSprite.new(Graphics.width, Graphics.height)
    @sprites["field"].x = 0
    @sprites["field"].y = 0
    @sprites["field"].z = @viewport.z + 1
    pbSetNarrowFont(@sprites["field"].bitmap)
    
    @arrow              = AnimatedBitmap.new(@dir + "arrow")
    @sprites["arrow"]   = BitmapSprite.new(Graphics.width, Graphics.height)
    @sprites["arrow"].bitmap.blt(0, 0, @arrow.bitmap, Rect.new(0, 0, 20, 12))
    @sprites["arrow"].z = @viewport.z + 2
    
    @oys = [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1]
    @oy  = 0
  end
  
  def pbStartScreen
    fontColor   = Color.new(248, 248, 248)
    shadowColor = Color.new( 64,  64,  64)
    shadowAlly  = Color.new(  0, 128, 248)
    shadowFoe   = Color.new(248, 128,  96)
    shadowRaise = Color.new(  0, 216,  24)
    shadowLoss  = Color.new(248,  48,  48)
    namepos = []
    allies = 0
    foes   = 0
    @battle.battlers.each_with_index do |battler, i|
      next if !battler
      if i % 2 == 0
        allies += 1
      else
        foes += 1
      end
    end
    arrow_x = [
        Graphics.width / (allies * 2), Graphics.width / (foes * 2),
        Graphics.width / (allies * 2) * 3, Graphics.width / (foes * 2) * 3,
        Graphics.width / (allies * 2) * 5, Graphics.width / (foes * 2) * 5
    ]
    arrow_y = [
        Graphics.height - 160, 24, Graphics.height - 160, 24,
        Graphics.height - 160, 24
    ]
    @sprites["arrow"].x = arrow_x[0] - 10
    @sprites["arrow"].y = arrow_y[0] - 16
    @battle.battlers.each_with_index do |battler, i|
      next if !battler
      if i % 2 == 0
        shadow = shadowAlly
        x = Graphics.width / (allies * 2) * (i + 1)
        y = Graphics.height - 160
      else
        shadow = shadowFoe
        x = Graphics.width / (foes * 2) * i
        y = 24
      end
      shadow = shadowColor if battler.fainted?
      namepos.push([
        _INTL("{1}", battler.name), x, y, 2, fontColor, shadow
      ])
      # 显示宝可梦图标
      pkmn = battler.pokemon.clone
      if battler.effects[PBEffects::Illusion]
        pkmn.species = battler.effects[PBEffects::Illusion].species
      elsif battler.effects[PBEffects::Transform]
        pkmn.species = battler.effects[PBEffects::TransformSpecies]
      end
      @sprites["pokeicon#{i}"]   = PokemonIconSprite.new(pkmn)
      @sprites["pokeicon#{i}"].x = x - 16
      @sprites["pokeicon#{i}"].y = y + 16
      @sprites["pokeicon#{i}"].z = @viewport.z + 1
      @sprites["pokeicon#{i}"].zoom_x = 0.5
      @sprites["pokeicon#{i}"].zoom_y = 0.5
      tone = battler.fainted? ? Tone.new(0, 0, 0, 255) : Tone.new(0, 0, 0, 0)
      @sprites["pokeicon#{i}"].tone   = tone
      # 显示属性图标
      if @show_type ||  battler.ownedEx?
        offset_size = @sprites["names"].bitmap.font.size
        namepos[-1][1] -= offset_size * @type_ox
        offset_x = battler.name.length / 3.0 * offset_size
        @sprites["type#{i}1"] = IconSprite.new(x + offset_x, y + @type_oy)
        @sprites["type#{i}1"].setBitmap(@dir + "type#{battler.types[0]}")
        @sprites["type#{i}1"].z = @viewport.z + 1
        if battler.types[1] && battler.types[0] != battler.types[1]
          @sprites["type#{i}2"] = IconSprite.new(x + offset_x + 16, y + @type_oy)
          @sprites["type#{i}2"].setBitmap(@dir + "type#{battler.types[1]}")
          @sprites["type#{i}2"].z = @viewport.z + 1
        end
      end
      # 显示携带道具
      if @show_item == 2 || @show_item == 1 && @battle.wildBattle? || @show_item == 0 && i % 2 == 0
        @sprites["itemicon#{i}"]          = HeldItemIconSprite.new(0, 0, pkmn)
        @sprites["itemicon#{i}"].x      = x + 8
        @sprites["itemicon#{i}"].y      = y + 28
        @sprites["itemicon#{i}"].z      = @viewport.z + 1
        @sprites["itemicon#{i}"].zoom_x = 0.5
        @sprites["itemicon#{i}"].zoom_y = 0.5
        @sprites["pokeicon#{i}"].x     -= 8 if @sprites["itemicon#{i}"].bitmap
      end
      # 显示HP数字
      if $DEBUG || battler.pbOwnedByPlayer?
        if battler.fainted?
          namepos.push([
            "濒死", x, y+50, 2, fontColor, shadowColor
          ])
        else
          namepos.push([
            _INTL("{1}/{2}", battler.hp, battler.totalhp), x, y+50, 2, fontColor, shadow
          ])
        end
      end
    end
    pbDrawTextPositions(@sprites["names"].bitmap, namepos)
    
    statpos = []
    x_right = Graphics.width / 2 + 16
    xs = {
          :ATTACK          => 16,
          :DEFENSE         => 16,
          :SPECIAL_ATTACK  => 16,
          :SPECIAL_DEFENSE => 16,
          :SPEED           => x_right,
          :ACCURACY        => x_right,
          :EVASION         => x_right,
          :FocusEnergy     => x_right
    }
    ys = {
          :ATTACK          => 94,
          :DEFENSE         => 124,
          :SPECIAL_ATTACK  => 154,
          :SPECIAL_DEFENSE => 184,
          :SPEED           => 94,
          :ACCURACY        => 124,
          :EVASION         => 154,
          :FocusEnergy     => 184
    }
    @battle.battlers[0].stages.each do |key, stat|
      next if key == :HP
      if stat > 0
        str = @up * stat
        statpos.push([
          _INTL("{1}：{2}", GameData::Stat.get(key).name_brief, str),
              xs[key], ys[key], 0, fontColor, shadowRaise
        ])
      elsif stat < 0
        str = @down * (0 - stat)
        statpos.push([
          _INTL("{1}：{2}", GameData::Stat.get(key).name_brief, str),
              xs[key], ys[key], 0, fontColor, shadowLoss
        ])
      else
        statpos.push([
          _INTL("{1}：", GameData::Stat.get(key).name_brief),
              xs[key], ys[key], 0, fontColor, shadowColor
        ])
      end
    end
    if @battle.battlers[0].effects[PBEffects::FocusEnergy] > 0
      statpos.push([
        _INTL("会心：{1}", @up * @battle.battlers[0].effects[PBEffects::FocusEnergy]),
            xs[:FocusEnergy], ys[:FocusEnergy], 0, fontColor, shadowRaise
      ])
    else
      statpos.push([
        _INTL("会心："),  xs[:FocusEnergy], ys[:FocusEnergy], 0, fontColor, shadowColor
      ])
    end
    pbDrawTextPositions(@sprites["stats"].bitmap, statpos)
    
    fieldpos = []
    fieldpos.push([
      _INTL("当前回合数：{1}", @battle.turnCount + 1), 16, Graphics.height - 80, 0, 
            fontColor, shadowColor
    ])
    weather = @battle.pbWeather
    weather_name = GameData::BattleWeather.try_get(weather).name
    fieldpos.push([
      _INTL("天气：{1}", weather_name), 16, Graphics.height - 48, 0, 
            fontColor, shadowColor
    ])
    if weather != :None
      if @battle.field.weatherDuration > 0
        fieldpos.push([
          _INTL("{1}回合", @battle.field.weatherDuration), 
            Graphics.width / 2 - 16, Graphics.height - 48, 1, fontColor, shadowColor
        ])
      else
        fieldpos.push([
          _INTL("持续存在"), Graphics.width / 2 - 16, Graphics.height - 48, 1, fontColor, shadowColor
        ])
      end
    end
    terrain = @battle.field.terrain
    terrain_name = GameData::BattleTerrain.try_get(terrain).name
    fieldpos.push([
      _INTL("场地：{1}", terrain_name), 
        Graphics.width / 2 + 16, Graphics.height - 48, 0, fontColor, shadowColor
    ])
    if terrain != :None
      fieldpos.push([
        _INTL("{1}回合", @battle.field.terrainDuration),
          Graphics.width - 16, Graphics.height - 48, 1, fontColor, shadowColor
      ])
    end
    pbDrawTextPositions(@sprites["field"].bitmap, fieldpos)
    
    index = 0
    loop do
      Graphics.update
      Input.update
      break if Input.trigger?(Input::SPECIAL) || Input.trigger?(Input::BACK)
      @sprites["bg"].ox += 1
      @sprites["bg"].ox = 0 if @sprites["bg"].ox > 32
      if @battle.battlers.length > 1
        @sprites["arrow"].oy = @oys[@oy]
        @oy += 1
        @oy = 0 if @oy >= @oys.length
        old_index = index
        if Input.trigger?(Input::RIGHT)
          index += 2 if index < @battle.battlers.length - 2
        elsif Input.trigger?(Input::LEFT)
          index -= 2 if index > 1
        elsif Input.trigger?(Input::UP)
          index += 1 if index < @battle.battlers.length - 1 && index % 2 == 0
          index = 1 if foes == 1
        elsif Input.trigger?(Input::DOWN)
          index -= 1 if index % 2 != 0
        end
        index = old_index if !@battle.battlers[index]
        next if old_index == index
        pbSEPlay("GUI sel decision")
        @sprites["arrow"].x = arrow_x[index] - 10
        @sprites["arrow"].y = arrow_y[index] - 12
        
        @sprites["stats"].bitmap.clear
        next if @battle.battlers[index].fainted?
        statpos = []
        @battle.battlers[index].stages.each do |key, stat|
          next if key == :HP
          if stat > 0
            str = @up * stat
            statpos.push([
              _INTL("{1}：{2}", GameData::Stat.get(key).name_brief, str),
                  xs[key], ys[key], 0, fontColor, shadowRaise
            ])
          elsif stat < 0
            str = @down * (0 - stat)
            statpos.push([
              _INTL("{1}：{2}", GameData::Stat.get(key).name_brief, str),
                  xs[key], ys[key], 0, fontColor, shadowLoss
            ])
          else
            statpos.push([
              _INTL("{1}：", GameData::Stat.get(key).name_brief),
                  xs[key], ys[key], 0, fontColor, shadowColor
            ])
          end
        end
        if @battle.battlers[index].effects[PBEffects::FocusEnergy] > 0
          statpos.push([
            _INTL("会心：{1}", @up * @battle.battlers[index].effects[PBEffects::FocusEnergy]),
                xs[:FocusEnergy], ys[:FocusEnergy], 0, fontColor, shadowRaise
          ])
        else
          statpos.push([
            _INTL("会心："), xs[:FocusEnergy], ys[:FocusEnergy], 0, fontColor, shadowColor
          ])
        end
        pbDrawTextPositions(@sprites["stats"].bitmap, statpos)
      end
    end
  end
  
  def pbEndScreen
    @arrow.dispose
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class BattlerInfoScreen
  def initialize(scene)
    @scene = scene
  end

  def pbShowScreen
    @scene.pbStartScreen
    @scene.pbEndScreen
  end
end