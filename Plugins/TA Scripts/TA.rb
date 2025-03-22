module TA
  def self.calc_candies(pkmn)
    case pkmn.level
    when 0..10
      { :iv_candy_s => 2, :exp_candy_s => 2 }
    when 11..20
      { :iv_candy_s => 4, :exp_candy_s => 4 }
    when 21..30
      { :iv_candy_m => 6, :exp_candy_m => 6 }
    when 31..40
      { :iv_candy_m => 8, :exp_candy_m => 8 }
    when 41..50
      { :iv_candy_l => 10, :exp_candy_l => 10 }
    else
      { :iv_candy_l => 12, :exp_candy_l => 12 }
    end
  end

  def self.release_pokemon(pkmn)
    candy_data = calc_candies(pkmn)
    candy_data.each { |candy, amount| pbReceiveItem(candy, amount) }
  end

  def self.calc_ivs(candy_type)
    case candy_type
    when :iv_candy_s; 4
    when :iv_candy_m; 6
    when :iv_candy_l; 8
    else
      0
    end
  end

  def self.iv_candy(pkmn, candy_type)
    if pkmn.iv.values.all? { |iv| iv == 31 }
      pbMessage(_INTL("即便使用也没有效果，因为精灵的六项个体值均已达到最大值。"))
      return
    end

    total_increment = calc_ivs(candy_type)
    return if total_increment == 0
    available_stats = []
    GameData::Stat.each_main do |s|
      available_stats.push(s) if pkmn.iv[s.id] < 31
    end
    available_stats.shuffle!

    available_stats.each do |s|
      return if total_increment <= 0
      max_add = [31 - pkmn.iv[s.id], total_increment].min
      pkmn.iv[s.id] += max_add
      total_increment -= max_add
      pbMessage(_INTL("该精灵的{1}个体值已增加。", s.name))
    end
  end
end