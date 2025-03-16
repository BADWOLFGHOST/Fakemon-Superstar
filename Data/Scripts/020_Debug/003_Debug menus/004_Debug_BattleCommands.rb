#===============================================================================
# Battler Options
#===============================================================================
MenuHandlers.add(:battle_debug_menu, :battlers, {
  "name"        => _INTL("战斗精灵……"),
  "parent"      => :main,
  "description" => _INTL("设置战斗精灵的属性。")
})

MenuHandlers.add(:battle_debug_menu, :list_player_battlers, {
  "name"        => _INTL("玩家方战斗精灵"),
  "parent"      => :battlers,
  "description" => _INTL("编辑玩家方战斗中的精灵。"),
  "effect"      => proc { |battle|
    battlers = []
    cmds = []
    battle.allSameSideBattlers.each do |b|
      battlers.push(b)
      text = "[#{b.index}] #{b.name}"
      if b.pbOwnedByPlayer?
        text += " (yours)"
      else
        text += " (ally's)"
      end
      cmds.push(text)
    end
    cmd = 0
    loop do
      cmd = pbMessage("\\ts[]" + _INTL("选择一只精灵。"), cmds, -1, nil, cmd)
      break if cmd < 0
      battle.pbBattlePokemonDebug(battlers[cmd].pokemon, battlers[cmd])
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :list_foe_battlers, {
  "name"        => _INTL("敌方战斗精灵"),
  "parent"      => :battlers,
  "description" => _INTL("编辑敌方战斗中的精灵。"),
  "effect"      => proc { |battle|
    battlers = []
    cmds = []
    battle.allOtherSideBattlers.each do |b|
      battlers.push(b)
      cmds.push("[#{b.index}] #{b.name}")
    end
    cmd = 0
    loop do
      cmd = pbMessage("\\ts[]" + _INTL("选择一只精灵。"), cmds, -1, nil, cmd)
      break if cmd < 0
      battle.pbBattlePokemonDebug(battlers[cmd].pokemon, battlers[cmd])
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :speed_order, {
  "name"        => _INTL("查看精灵速度排列"),
  "parent"      => :battlers,
  "description" => _INTL("按速度快慢顺序列出战斗中的精灵。"),
  "effect"      => proc { |battle|
    battlers = battle.allBattlers.map { |b| [b, b.pbSpeed] }
    battlers.sort! { |a, b| b[1] <=> a[1] }
    commands = []
    battlers.each do |value|
      b = value[0]
      commands.push(sprintf("[%d] %s (speed: %d)", b.index, b.pbThis, value[1]))
    end
    pbMessage("\\ts[]" + _INTL("按最快到最慢列出战斗中的精灵，排列考虑有关速度的修改。"),
              commands, -1)
  }
})

#===============================================================================
# Pokémon
#===============================================================================
MenuHandlers.add(:battle_debug_menu, :pokemon_teams, {
  "name"        => _INTL("队伍"),
  "parent"      => :main,
  "description" => _INTL("查看并编辑各队伍中的精灵。"),
  "effect"      => proc { |battle|
    player_party_starts = battle.pbPartyStarts(0)
    foe_party_starts = battle.pbPartyStarts(1)
    cmd = 0
    loop do
      # Find all teams and how many Pokémon they have
      commands = []
      team_indices = []
      if battle.opponent
        battle.opponent.each_with_index do |trainer, i|
          first_index = foe_party_starts[i]
          last_index = (i < foe_party_starts.length - 1) ? foe_party_starts[i + 1] : battle.pbParty(1).length
          num_pkmn = last_index - first_index
          commands.push(_INTL("敌方 {1}：{2}（{3}精灵）", i + 1, trainer.full_name, num_pkmn))
          team_indices.push([1, i, first_index])
        end
      else
        commands.push(_INTL("敌方：{1}野生精灵", battle.pbParty(1).length))
        team_indices.push([1, 0, 0])
      end
      battle.player.each_with_index do |trainer, i|
        first_index = player_party_starts[i]
        last_index = (i < player_party_starts.length - 1) ? player_party_starts[i + 1] : battle.pbParty(0).length
        num_pkmn = last_index - first_index
        if i == 0   # Player
          commands.push(_INTL("你：{1}（{2}精灵）", trainer.full_name, num_pkmn))
        else
          commands.push(_INTL("友方 {1}：{2}（{3}精灵）", i, trainer.full_name, num_pkmn))
        end
        team_indices.push([0, i, first_index])
      end
      # Choose a team
      cmd = pbMessage("\\ts[]" + _INTL("选择一个队伍。"), commands, -1, nil, cmd)
      break if cmd < 0
      # Pick a Pokémon to look at
      pkmn_cmd = 0
      loop do
        pkmn = []
        pkmn_cmds = []
        battle.eachInTeam(team_indices[cmd][0], team_indices[cmd][1]) do |p|
          pkmn.push(p)
          pkmn_cmds.push("[#{pkmn_cmds.length + 1}] #{p.name} Lv.#{p.level} (HP: #{p.hp}/#{p.totalhp})")
        end
        pkmn_cmd = pbMessage("\\ts[]" + _INTL("选择一只精灵"), pkmn_cmds, -1, nil, pkmn_cmd)
        break if pkmn_cmd < 0
        battle.pbBattlePokemonDebug(pkmn[pkmn_cmd],
                                    battle.pbFindBattler(team_indices[cmd][2] + pkmn_cmd, team_indices[cmd][0]))
      end
    end
  }
})

#===============================================================================
# Trainer Options
#===============================================================================
MenuHandlers.add(:battle_debug_menu, :trainers, {
  "name"        => _INTL("训练家选项..."),
  "parent"      => :main,
  "description" => _INTL("修改训练家的变量。")
})

MenuHandlers.add(:battle_debug_menu, :trainer_items, {
  "name"        => _INTL("训练家道具"),
  "parent"      => :trainers,
  "description" => _INTL("查看和修改NPC训练家有能力使用的道具。"),
  "effect"      => proc { |battle|
    cmd = 0
    loop do
      # Find all NPC trainers and their items
      commands = []
      item_arrays = []
      trainer_indices = []
      if battle.opponent
        battle.opponent.each_with_index do |trainer, i|
          items = battle.items ? battle.items[i].clone : []
          commands.push(_INTL("敌方 {1}：{2}（{3}道具）", i + 1, trainer.full_name, items.length))
          item_arrays.push(items)
          trainer_indices.push([1, i])
        end
      end
      if battle.player.length > 1
        battle.player.each_with_index do |trainer, i|
          next if i == 0   # Player
          items = battle.ally_items ? battle.ally_items[i].clone : []
          commands.push(_INTL("友方 {1}：{2}（{3}道具）", i, trainer.full_name, items.length))
          item_arrays.push(items)
          trainer_indices.push([0, i])
        end
      end
      if commands.length == 0
        pbMessage("\\ts[]" + _INTL("这场战斗没有NPC训练家。"))
        break
      end
      # Choose a trainer
      cmd = pbMessage("\\ts[]" + _INTL("选择训练家。"), commands, -1, nil, cmd)
      break if cmd < 0
      # Get trainer's items
      items = item_arrays[cmd]
      indices = trainer_indices[cmd]
      # Edit trainer's items
      item_list_property = GameDataPoolProperty.new(:Item)
      new_items = item_list_property.set(nil, items)
      if indices[0] == 0   # Ally
        battle.ally_items = [] if !battle.ally_items
        battle.ally_items[indices[1]] = new_items
      else   # Opponent
        battle.items = [] if !battle.items
        battle.items[indices[1]] = new_items
      end
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :mega_evolution, {
  "name"        => _INTL("超进化"),
  "parent"      => :trainers,
  "description" => _INTL("决定是否允许训练家使用超进化。"),
  "effect"      => proc { |battle|
    cmd = 0
    loop do
      commands = []
      cmds = []
      battle.megaEvolution.each_with_index do |side_values, side|
        trainers = (side == 0) ? battle.player : battle.opponent
        next if !trainers
        side_values.each_with_index do |value, i|
          next if !trainers[i]
          text = (side == 0) ? "Your side:" : "Foe side:"
          text += sprintf(" %d: %s", i, trainers[i].name)
          text += " [ABLE]" if value == -1
          text += " [UNABLE]" if value == -2
          commands.push(text)
          cmds.push([side, i])
        end
      end
      cmd = pbMessage("\\ts[]" + _INTL("选择训练家来决定他是否可以使用超进化。"),
                      commands, -1, nil, cmd)
      break if cmd < 0
      real_cmd = cmds[cmd]
      if battle.megaEvolution[real_cmd[0]][real_cmd[1]] == -1
        battle.megaEvolution[real_cmd[0]][real_cmd[1]] = -2   # Make unable
      else
        battle.megaEvolution[real_cmd[0]][real_cmd[1]] = -1   # Make able
      end
    end
  }
})

#===============================================================================
# Field Options
#===============================================================================
MenuHandlers.add(:battle_debug_menu, :field, {
  "name"        => _INTL("场地效果…"),
  "parent"      => :main,
  "description" => _INTL("对战场有影响的效果。")
})

MenuHandlers.add(:battle_debug_menu, :weather, {
  "name"        => _INTL("天气"),
  "parent"      => :field,
  "description" => _INTL("设置天气和持续时间。"),
  "effect"      => proc { |battle|
    weather_types = []
    weather_cmds = []
    GameData::BattleWeather.each do |weather|
      next if weather.id == :None
      weather_types.push(weather.id)
      weather_cmds.push(weather.name)
    end
    cmd = 0
    loop do
      weather_data = GameData::BattleWeather.try_get(battle.field.weather)
      msg = _INTL("当前天气：{1}", weather_data.name || _INTL("未知"))
      if weather_data.id != :None
        if battle.field.weatherDuration > 0
          msg += "\n"
          msg += _INTL("持续时间：{1}轮", battle.field.weatherDuration)
        elsif battle.field.weatherDuration < 0
          msg += "\n"
          msg += _INTL("持续时间：永久")
        end
      end
      cmd = pbMessage("\\ts[]" + msg, [_INTL("更改类型"),
                                       _INTL("更改持续时间"),
                                       _INTL("清除天气")], -1, nil, cmd)
      break if cmd < 0
      case cmd
      when 0   # Change type
        weather_cmd = weather_types.index(battle.field.weather) || 0
        new_weather = pbMessage(
          "\\ts[]" + _INTL("选择天气类型。"), weather_cmds, -1, nil, weather_cmd
        )
        if new_weather >= 0
          battle.field.weather = weather_types[new_weather]
          battle.field.weatherDuration = 5 if battle.field.weatherDuration == 0
        end
      when 1   # Change duration
        if battle.field.weather == :None
          pbMessage("\\ts[]" + _INTL("没有天气。"))
          next
        end
        params = ChooseNumberParams.new
        params.setRange(0, 99)
        params.setInitialValue([battle.field.weatherDuration, 0].max)
        params.setCancelValue([battle.field.weatherDuration, 0].max)
        new_duration = pbMessageChooseNumber(
          "\\ts[]" + _INTL("选择天气持续时间（0=永久）。"), params
        )
        if new_duration != [battle.field.weatherDuration, 0].max
          battle.field.weatherDuration = (new_duration == 0) ? -1 : new_duration
        end
      when 2   # Clear weather
        battle.field.weather = :None
        battle.field.weatherDuration = 0
      end
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :terrain, {
  "name"        => _INTL("场地"),
  "parent"      => :field,
  "description" => _INTL("设置场地和持续时间。"),
  "effect"      => proc { |battle|
    terrain_types = []
    terrain_cmds = []
    GameData::BattleTerrain.each do |terrain|
      next if terrain.id == :None
      terrain_types.push(terrain.id)
      terrain_cmds.push(terrain.name)
    end
    cmd = 0
    loop do
      terrain_data = GameData::BattleTerrain.try_get(battle.field.terrain)
      msg = _INTL("当前场地：{1}", terrain_data.name || _INTL("未知"))
      if terrain_data.id != :None
        if battle.field.terrainDuration > 0
          msg += "\n"
          msg += _INTL("持续时间：{1}轮", battle.field.terrainDuration)
        elsif battle.field.terrainDuration < 0
          msg += "\n"
          msg += _INTL("持续时间：永久")
        end
      end
      cmd = pbMessage("\\ts[]" + msg, [_INTL("更改类型"),
                                       _INTL("更改持续时间"),
                                       _INTL("清除场地")], -1, nil, cmd)
      break if cmd < 0
      case cmd
      when 0   # Change type
        terrain_cmd = terrain_types.index(battle.field.terrain) || 0
        new_terrain = pbMessage(
          "\\ts[]" + _INTL("选择场地类型。"), terrain_cmds, -1, nil, terrain_cmd
        )
        if new_terrain >= 0
          battle.field.terrain = terrain_types[new_terrain]
          battle.field.terrainDuration = 5 if battle.field.terrainDuration == 0
        end
      when 1   # Change duration
        if battle.field.terrain == :None
          pbMessage("\\ts[]" + _INTL("现在没有任何场地。"))
          next
        end
        params = ChooseNumberParams.new
        params.setRange(0, 99)
        params.setInitialValue([battle.field.terrainDuration, 0].max)
        params.setCancelValue([battle.field.terrainDuration, 0].max)
        new_duration = pbMessageChooseNumber(
          "\\ts[]" + _INTL("选择场地持续时间（0=永久）。"), params
        )
        if new_duration != [battle.field.terrainDuration, 0].max
          battle.field.terrainDuration = (new_duration == 0) ? -1 : new_duration
        end
      when 2   # Clear terrain
        battle.field.terrain = :None
        battle.field.terrainDuration = 0
      end
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :environment_time, {
  "name"        => _INTL("环境/时间"),
  "parent"      => :field,
  "description" => _INTL("设置战斗的环境和时间。"),
  "effect"      => proc { |battle|
    environment_types = []
    environment_cmds = []
    GameData::Environment.each do |environment|
      environment_types.push(environment.id)
      environment_cmds.push(environment.name)
    end
    cmd = 0
    loop do
      environment_data = GameData::Environment.try_get(battle.environment)
      msg = _INTL("环境：{1}", environment_data.name || _INTL("未知"))
      msg += "\n"
      msg += _INTL("时间：{1}", [_INTL("白昼"), _INTL("傍晚"), _INTL("夜晚")][battle.time])
      cmd = pbMessage("\\ts[]" + msg, [_INTL("更改环境"),
                                       _INTL("更改时间")], -1, nil, cmd)
      break if cmd < 0
      case cmd
      when 0   # Change environment
        environment_cmd = environment_types.index(battle.environment) || 0
        new_environment = pbMessage(
          "\\ts[]" + _INTL("选择新的环境。"), environment_cmds, -1, nil, environment_cmd
        )
        if new_environment >= 0
          battle.environment = environment_types[new_environment]
        end
      when 1   # Change time of day
        new_time = pbMessage("\\ts[]" + _INTL("选择新的时间。"),
                             [_INTL("白昼"), _INTL("傍晚"), _INTL("夜晚")], -1, nil, battle.time)
        battle.time = new_time if new_time >= 0 && new_time != battle.time
      end
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :backdrop, {
  "name"        => _INTL("背景"),
  "parent"      => :field,
  "description" => _INTL("设置背景和底座图形。"),
  "effect"      => proc { |battle|
    loop do
      cmd = pbMessage("\\ts[]" + _INTL("设置哪个图形？"),
                      [_INTL("背景"),
                       _INTL("底座")], -1)
      break if cmd < 0
      case cmd
      when 0   # Backdrop
        text = pbMessageFreeText("\\ts[]" + _INTL("输入图形名字更改背景。"),
                                 battle.backdrop, false, 100, Graphics.width)
        battle.backdrop = (nil_or_empty?(text)) ? "Indoor1" : text
      when 1   # Base modifier
        text = pbMessageFreeText("\\ts[]" + _INTL("输入图形名字更改底座。"),
                                 battle.backdropBase, false, 100, Graphics.width)
        battle.backdropBase = (nil_or_empty?(text)) ? nil : text
      end
    end
  }
})

MenuHandlers.add(:battle_debug_menu, :set_field_effects, {
  "name"        => _INTL("其他场地效果……"),
  "parent"      => :field,
  "description" => _INTL("查看或设置对两方都适用的效果。"),
  "effect"      => proc { |battle|
    editor = Battle::DebugSetEffects.new(battle, :field)
    editor.update
    editor.dispose
  }
})

MenuHandlers.add(:battle_debug_menu, :player_side, {
  "name"        => _INTL("玩家方效果……"),
  "parent"      => :field,
  "description" => _INTL("适用于玩家方的效果。"),
  "effect"      => proc { |battle|
    editor = Battle::DebugSetEffects.new(battle, :side, 0)
    editor.update
    editor.dispose
  }
})

MenuHandlers.add(:battle_debug_menu, :opposing_side, {
  "name"        => _INTL("敌方效果……"),
  "parent"      => :field,
  "description" => _INTL("适用于对方的效果。"),
  "effect"      => proc { |battle|
    editor = Battle::DebugSetEffects.new(battle, :side, 1)
    editor.update
    editor.dispose
  }
})

MenuHandlers.add(:battle_debug_menu, :position_effects, {
  "name"        => _INTL("位置效果……"),
  "parent"      => :field,
  "description" => _INTL("与精灵位置有关的效果。"),
  "effect"      => proc { |battle|
    positions = []
    cmds = []
    battle.positions.each_with_index do |position, i|
      next if !position
      positions.push(i)
      battler = battle.battlers[i]
      if battler && !battler.fainted?
        text = "[#{i}] #{battler.name}"
      else
        text = "[#{i}] " + _INTL("（空）")
      end
      if battler.pbOwnedByPlayer?
        text += " " + _INTL("(你的)")
      elsif battle.opposes?(i)
        text += " " + _INTL("(敌方的)")
      else
        text += " " + _INTL("(友方的)")
      end
      cmds.push(text)
    end
    cmd = 0
    loop do
      cmd = pbMessage("\\ts[]" + _INTL("选择战斗位置。"), cmds, -1, nil, cmd)
      break if cmd < 0
      editor = Battle::DebugSetEffects.new(battle, :position, positions[cmd])
      editor.update
      editor.dispose
    end
  }
})
