# 重写携带道具图标
class HeldItemIconSprite < Sprite
  def initialize(x, y, pokemon, viewport = nil)
    super(viewport)
    self.x = x
    self.y = y
		self.zoom_x = 0.5
		self.zoom_y = 0.5
    @pokemon = pokemon
    @item = nil
    self.item = @pokemon.item_id
  end
end
module GameData
  class Item
		def self.held_icon_filename(item)
			item_data = self.try_get(item)
			return nil if !item_data
			if item_data.is_mail? 
				return sprintf("Graphics/UI/Party/icon_mail") if Essentials::VERSION && (Essentials::VERSION).to_f >= 21
				return sprintf("Graphics/Pictures/Party/icon_mail")
			end
			# Check for files
			ret = sprintf("Graphics/Items/%s", item)
			return ret || "000"
		end
	end
end
# 添加一个用于判断是否已获得的方法,
# 和原版方法相比忽略训练家
class Battle::Battler
  def ownedEx?
    return $player.owned?(displaySpecies)
  end
  alias ownedEx ownedEx?
end
# 此方法大部分没有改动
# 只添加了一个分支判断
class Battle::Scene
	def pbCommandMenuEx(idxBattler, texts, mode = 0)
    pbShowWindow(COMMAND_BOX)
    cw = @sprites["commandWindow"]
    cw.setTexts(texts)
    cw.setIndexAndMode(@lastCmd[idxBattler], mode)
    pbSelectBattler(idxBattler)
    ret = -1
    loop do
      oldIndex = cw.index
      pbUpdate(cw)
      # Update selected command
      if Input.trigger?(Input::LEFT)
        cw.index -= 1 if (cw.index & 1) == 1
      elsif Input.trigger?(Input::RIGHT)
        cw.index += 1 if (cw.index & 1) == 0
      elsif Input.trigger?(Input::UP)
        cw.index -= 2 if (cw.index & 2) == 2
      elsif Input.trigger?(Input::DOWN)
        cw.index += 2 if (cw.index & 2) == 0
      end
      pbPlayCursorSE if cw.index != oldIndex
      # Actions
      if Input.trigger?(Input::USE)                 # Confirm choice
        pbPlayDecisionSE
        ret = cw.index
        @lastCmd[idxBattler] = ret
        break
      elsif Input.trigger?(Input::BACK) && mode == 1   # Cancel
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::F9) && $DEBUG    # Debug menu
        pbPlayDecisionSE
        ret = -2
        break
			#======================================
      elsif Input.trigger?(Input::SPECIAL)   				# 对战信息显示
        scene = Battle_Info_Display.new(@battle)
				screen = BattlerInfoScreen.new(scene)
				screen.pbShowScreen
        break
			#======================================
      end
    end
    return ret
  end
end