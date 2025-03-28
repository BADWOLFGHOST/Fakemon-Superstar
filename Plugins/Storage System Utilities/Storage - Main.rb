#===============================================================================
# Storage System Utilities
# By Swdfm
# Works For Both Essentials Version 20 and 21
#===============================================================================
STORAGE_ARROW_PATH = "Graphics/UI/Storage/"

# Can Boxes be quickly swapped by selecting "Swap" from the Box Heading?
CAN_SWAP_BOXES   = true

# Can multiple Pokemon be selected/moved at the same time using the green hand?
CAN_MULTI_SELECT = true

# Can Pokemon be mass released by pressing the Action Key while having multiple Pokemon grabed? 
# Need to have CAN_MULTI_SELECT selected
CAN_MASS_RELEASE = true

# Can one "pour" Pokemon into a box?
# This lets you quickly store held Pokemon into a box by clicking Use button on page header while moving held Pokemon
CAN_BOX_POUR     = true

#===============================================================================
# Using Version 21 or not?
#===============================================================================
def pbVersion21?
  return Essentials::VERSION.include?("21")
end

#===============================================================================
# Nitty Gritty below here!
# Don't touch unless you knwo what you're doing!
#===============================================================================
# PokemonBoxIcon Overrides
#===============================================================================
class PokemonBoxIcon < IconSprite
  #===============================================================================
  # Turns the sprite(s) into a certain colour
  #===============================================================================
  def make_clear
    @type = :Clear
  end
  def make_green
    @type = :Green
  end
  def make_grey
    @type = :Grey
  end
  
  #===============================================================================
  # update Override
  #===============================================================================
  def update
    super
    @type = :Clear if !@type
	return update_21 if pbVersion21?
    @release.update
    do_colours
    dispose if @startRelease && !releasing?
  end
  
  def update_21
    do_colours
    if releasing?
      time_now = System.uptime
      self.zoom_x = lerp(1.0, 0.0, 1.5, @release_timer_start, System.uptime)
      self.zoom_y = self.zoom_x
      self.opacity = lerp(255, 0, 1.5, @release_timer_start, System.uptime)
      if self.opacity == 0
        @release_timer_start = nil
        dispose
      end
    end
  end
  
  def do_colours
    case @type
    when :Clear
      self.color = Color.new(0, 0, 0, 0)
    when :Green
      self.color = Color.new(131, 180, 255, 192)
    when :Grey
      self.color = Color.new(128, 128, 128, 255)
    end
  end
end

#===============================================================================
# PokemonBoxArrow Override
#===============================================================================
class PokemonBoxArrow < Sprite
  attr_accessor :multi
  
  #===============================================================================
  # initialize Add On
  #===============================================================================
  alias swdfm_init initialize
  def initialize(viewport = nil)
    swdfm_init(viewport)
	@path  = STORAGE_ARROW_PATH
	if @path == ""
      @path  = "Graphics/Pictures/Storage/"
      @path  = "Graphics/UI/Storage/" if pbVersion21?
	end
    @multi = false
    @handsprite.addBitmap("point1g", @path + "cursor_point_1_g")
    @handsprite.addBitmap("point2g", @path + "cursor_point_2_g")
    @handsprite.addBitmap("grabg", @path + "cursor_grab_g")
    @handsprite.addBitmap("fistg", @path + "cursor_fist_g")
  end
  
  #===============================================================================
  # update Override (v20)
  #===============================================================================
  def update
    @updating = true
    super
	return update_21 if pbVersion21?
    heldpkmn = heldPokemon
    heldpkmn&.update
    @handsprite.update
    @holding = false if !heldpkmn
    t = @tension
    b = @multi ? "g" : (@quickswap ? "q" : "")
    if @grabbingState > 0
      if @grabbingState <= 4 * Graphics.frame_rate / 20
        @handsprite.changeBitmap("grab" + b)
        self.y = @spriteY + (4.0 * @grabbingState * 20 / Graphics.frame_rate)
        @grabbingState += 1
      elsif @grabbingState <= 8 * Graphics.frame_rate / 20
        @holding = true
        @handsprite.changeBitmap("fist" + b)
        self.y = @spriteY + (4 * ((8 * Graphics.frame_rate / 20) - @grabbingState) * 20 / Graphics.frame_rate)
        @grabbingState += 1
      else
        @grabbingState = 0
      end
    elsif @placingState > 0
      if @placingState <= 4 * Graphics.frame_rate / 20
        @handsprite.changeBitmap("fist" + b)
        self.y = @spriteY + (4.0 * @placingState * 20 / Graphics.frame_rate)
		@placingState += 1
      elsif @placingState <= 8 * Graphics.frame_rate / 20
        @holding = false
        @heldpkmn = nil
        @handsprite.changeBitmap("grab" + b)
        self.y = @spriteY + (4 * ((8 * Graphics.frame_rate / 20) - @placingState) * 20 / Graphics.frame_rate)
		@placingState += 1
	  else
        @placingState = 0
      end
    elsif holding?
      @handsprite.changeBitmap("fist" + b)
    elsif t == :Selecting
      @handsprite.changeBitmap("grab" + b)
    elsif t == :Moving
      @handsprite.changeBitmap("fist" + b)
    else   # Idling
      self.x = @spriteX
      self.y = @spriteY
      if @frame < Graphics.frame_rate / 2
        @handsprite.changeBitmap("point1" + b)
      else
        @handsprite.changeBitmap("point2" + b)
      end
    end
    @frame += 1
    @frame = 0 if @frame >= Graphics.frame_rate
    @updating = false
  end
  
  #===============================================================================
  # update Override (v21)
  #===============================================================================
  def update_21
    heldpkmn = heldPokemon
    heldpkmn&.update
    @handsprite.update
    @holding = false if !heldpkmn
    t = @tension
    b = @multi ? "g" : (@quickswap ? "q" : "")
    if @grabbing_timer_start
      if System.uptime - @grabbing_timer_start <= GRAB_TIME / 2
        @handsprite.changeBitmap("grab" + b)
        self.y = @spriteY + lerp(0, 16, GRAB_TIME / 2, @grabbing_timer_start, System.uptime)
      else
        @holding = true
        @handsprite.changeBitmap("fist" + b)
        delta_y = lerp(16, 0, GRAB_TIME / 2, @grabbing_timer_start + (GRAB_TIME / 2), System.uptime)
        self.y = @spriteY + delta_y
        @grabbing_timer_start = nil if delta_y == 0
      end
    elsif @placing_timer_start
      if System.uptime - @placing_timer_start <= GRAB_TIME / 2
        @handsprite.changeBitmap("fist" + b)
        self.y = @spriteY + lerp(0, 16, GRAB_TIME / 2, @placing_timer_start, System.uptime)
      else
        @holding = false
        @heldpkmn = nil
        @handsprite.changeBitmap("grab" + b)
        delta_y = lerp(16, 0, GRAB_TIME / 2, @placing_timer_start + (GRAB_TIME / 2), System.uptime)
        self.y = @spriteY + delta_y
        @placing_timer_start = nil if delta_y == 0
      end
    elsif holding?
      @handsprite.changeBitmap("fist" + b)
    elsif t == :Selecting
      @handsprite.changeBitmap("grab" + b)
    elsif t == :Moving
      @handsprite.changeBitmap("fist" + b)
    else   # Idling
      self.x = @spriteX
      self.y = @spriteY
      if (System.uptime / 0.5).to_i.even?   # Changes every 0.5 seconds
        @handsprite.changeBitmap("point1" + b)
      else
        @handsprite.changeBitmap("point2" + b)
      end
    end
    @updating = false
  end
  
  #===============================================================================
  # Additional methods: Tension
  # Used For Multiple Grabbing
  #===============================================================================
  def set_tension
    @tension = :Selecting # 1
  end
  
  def start_tension
    @tension = :Moving # 2
  end
  
  def release_tension
    @tension = :None # 0
  end
end

#===============================================================================
# PokemonStorageScene Override
#===============================================================================
class PokemonStorageScene
  attr_reader :multi
  
  #===============================================================================
  # pbStartBox Addition
  #===============================================================================
  alias swdfm_start_box pbStartBox
  def pbStartBox(*args)
    @grabber = StorageGrabber.new
    swdfm_start_box(*args)
  end
  
  #===============================================================================
  # pbSetArrow Addition
  #===============================================================================
  alias swdfm_set_arrow pbSetArrow
  def pbSetArrow(arrow, selection)
    swdfm_set_arrow(arrow, selection)
    return unless selection >= 0
    t = @multi && @grabber.holding_anything? && !@grabber.carrying
    return unless t
    @grabber.do_with(selection)
    do_green
  end
  
  #===============================================================================
  # pbChangeSelection Addition
  #===============================================================================
  alias swdfm_change_sel pbChangeSelection
  def pbChangeSelection(key, selection)
    skip = @multi && @grabber.holding_anything? && !@grabber.carrying
    case key
    when Input::UP
      case selection
      when -1   # Box name
        selection = -2
      when -2   # Party
        selection = PokemonBox::BOX_SIZE - 1 - (PokemonBox::BOX_WIDTH * 2 / 3)   # 25
      when -3   # Close Box
        selection = PokemonBox::BOX_SIZE - (PokemonBox::BOX_WIDTH / 3)   # 28
      else
        selection -= PokemonBox::BOX_WIDTH
		if skip && selection < 0
          selection += PokemonBox::BOX_SIZE
		elsif selection < 0
          selection = -1
        end
      end
    when Input::DOWN
      case selection
      when -1   # Box name
        selection = PokemonBox::BOX_WIDTH / 3   # 2
      when -2   # Party
        selection = -1
      when -3   # Close Box
        selection = -1
      else
        selection += PokemonBox::BOX_WIDTH
        if skip && selection >= PokemonBox::BOX_SIZE
          selection -= PokemonBox::BOX_SIZE
        elsif selection >= PokemonBox::BOX_SIZE
          if selection < PokemonBox::BOX_SIZE + (PokemonBox::BOX_WIDTH / 2)
            selection = -2   # Party
          else
            selection = -3   # Close Box
          end
        end
      end
    when Input::LEFT, Input::RIGHT
      selection = swdfm_change_sel(key, selection)
    end
    return selection
  end
  
  #===============================================================================
  # pbSelectBoxInternal Override
  #===============================================================================
  def pbSelectBoxInternal(_party)
    selection = @selection
    pbSetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
    loop do
      Graphics.update
      Input.update
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        pbPlayCursorSE
        selection = pbChangeSelection(key, selection)
        pbSetArrow(@sprites["arrow"], selection)
        case selection
        when -4
          nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
          pbSwitchBoxToLeft(nextbox)
          @storage.currentBox = nextbox
        when -5
          nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
          pbSwitchBoxToRight(nextbox)
          @storage.currentBox = nextbox
        end
        selection = -1 if [-4, -5].include?(selection)
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      end
      self.update
      t = @grabber.holding_anything? && !@grabber.carrying
      if Input.trigger?(Input::JUMPUP) && !t
        pbPlayCursorSE
        nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
        pbSwitchBoxToLeft(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::JUMPDOWN) && !t
        pbPlayCursorSE
        nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
        pbSwitchBoxToRight(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::SPECIAL) && !t   # Jump to box name
        if selection != -1
          pbPlayCursorSE
          selection = -1
          pbSetArrow(@sprites["arrow"], selection)
          pbUpdateOverlay(selection)
          pbSetMosaic(selection)
        end
      elsif Input.trigger?(Input::ACTION) && @command == 0   # Organize only
        if !t && !@grabber.carrying
          pbPlayDecisionSE
          pbSetQuickSwap(!@quickswap)
        elsif @grabber.carrying && CAN_MASS_RELEASE
          pbMassRelease
        end
      elsif Input.trigger?(Input::BACK)
        @selection = selection
        return nil
      elsif Input.trigger?(Input::USE)
        @selection = selection
        if selection >= 0
          return [@storage.currentBox, selection]
        elsif selection == -1   # Box name
          return [-4, -1]
        elsif selection == -2   # Party Pokémon
          return [-2, -1] if !@multi
        elsif selection == -3   # Close Box
          return [-3, -1]
        end
      end
    end
  end
  
  #===============================================================================
  # pbSelectPartyInternal Override
  #===============================================================================
  def pbSelectPartyInternal(party, depositing)
    selection = @selection
    pbPartySetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection, party)
    pbSetMosaic(selection)
    lastsel = 1
    loop do
      Graphics.update
      Input.update
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        pbPlayCursorSE
        newselection = pbPartyChangeSelection(key, selection)
        case newselection
        when -1
          return -1 if !depositing
        when -2
          selection = lastsel
        else
          selection = newselection
        end
        pbPartySetArrow(@sprites["arrow"], selection)
        lastsel = selection if selection > 0
        pbUpdateOverlay(selection, party)
        pbSetMosaic(selection)
      end
      self.update
      if Input.trigger?(Input::ACTION) && @command == 0   # Organize only
        pbPlayDecisionSE
        pbSetQuickSwap(!@quickswap, true)
      elsif Input.trigger?(Input::BACK)
        @selection = selection
        return -1
      elsif Input.trigger?(Input::USE)
        if selection >= 0 && selection < Settings::MAX_PARTY_SIZE
          @selection = selection
          return selection
        elsif selection == Settings::MAX_PARTY_SIZE   # Close Box
          @selection = selection
          return (depositing) ? -3 : -1
        end
      end
    end
  end
  
  #===============================================================================
  # New Method To Swap Boxes
  #===============================================================================
  def pbSwapBoxes(newbox)
    return if @storage.currentBox == newbox
	@storage.swap(newbox, @storage.currentBox)
	@sprites["box"].update
	refresh_box_sprites
  end
  
  #===============================================================================
  # pbSetQuickSwap Override
  #===============================================================================
  def pbSetQuickSwap(value, ignore_multi = false)
    ignore_multi = true if !CAN_MULTI_SELECT
    # Set to Quickswap
    if !@quickswap && !@multi
      @quickswap = true
      @multi     = false
    elsif @quickswap && !@multi && !ignore_multi
      @quickswap = false
      @multi     = true
    # Set to white
    else
      @quickswap = false
      @multi     = false
    end
    @sprites["arrow"].quickswap = @quickswap
    @sprites["arrow"].multi = @multi
  end
  
  #===============================================================================
  # pbChooseBox
  #===============================================================================
  def pbChooseBox(msg, swapping = false)
    commands = []
    @storage.maxBoxes.times do |i|
      box = @storage[i]
      if box
	    if swapping  && i == @storage.currentBox
          commands.push("Don't Swap")
		  next
		end
		commands.push(_INTL("{1} ({2}/{3})", box.name, box.nitems, box.length))
      end
    end
    return pbShowCommands(msg, commands, @storage.currentBox)
  end
  
  #===============================================================================
  # Additional methods
  #===============================================================================  
  # Tension: Used For Multiple Grabbing
  #===============================================================================
  def grabber
    return @grabber
  end
  
  def set_tension
    @sprites["arrow"].set_tension
  end
  
  def start_tension
    @sprites["arrow"].start_tension
  end
  
  def release_tension
    @sprites["arrow"].release_tension
  end
  
  #===============================================================================
  # Sets all necessary sprites to green
  #===============================================================================
  def do_green
    piv   = @grabber.mock_pivot
    piv_x = piv % PokemonBox::BOX_WIDTH
    piv_y = (piv / PokemonBox::BOX_WIDTH).floor
    sels = []
    for i in @grabber.mons
      x = i[0] + piv_x
      y = i[1] + piv_y
      sel = x + PokemonBox::BOX_WIDTH * y
      sels.push(sel)
    end
    for i in 0...PokemonBox::BOX_SIZE
      boxpokesprite = @sprites["box"].getPokemon(i)
      if sels.include?(i)
        boxpokesprite.make_green
      else
        boxpokesprite.make_clear
      end
    end
  end
  
  #===============================================================================
  # Method to refresh all box sprites
  #===============================================================================
  def refresh_box_sprites
    @sprites["box"].refreshSprites = true
    @sprites["box"].refreshBox = true
    pbHardRefresh
  end
  
  #===============================================================================
  # Changes from wherever the anchor is to the top left of the selection
  #===============================================================================
  def quick_change(selection)
    pbSetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
    @selection = selection
  end
  
  #===============================================================================
  # Shortcut to mass release
  #===============================================================================
  def pbMassRelease
    @screen.pbMassRelease
  end
  
  #===============================================================================
  # Greys all necessary sprites
  #===============================================================================
  def do_greys(ableProc = nil)
    return if !ableProc
    for i in 0...(PokemonBox::BOX_SIZE + PokemonBox::BOX_WIDTH)
      if i < PokemonBox::BOX_SIZE
        boxpokesprite = @sprites["box"].getPokemon(i)
      else
        boxpokesprite = @sprites["boxparty"].getPokemon(i-30)
      end
      next if !boxpokesprite
      next if !boxpokesprite.getPokemon
      if ableProc.call(boxpokesprite.getPokemon)
        boxpokesprite.make_clear
      else
        boxpokesprite.make_grey
      end
    end
  end
end

#===============================================================================
# PokemonStorageScreen Override
#===============================================================================
class PokemonStorageScreen
  #===============================================================================
  # pbStartScreen Override
  #===============================================================================
  def pbStartScreen(command)
    $game_temp.in_storage = true
    @heldpkmn = nil
    case command
    when 0   # Organise
      @scene.pbStartBox(self, command)
      loop do
        selected = @scene.pbSelectBox(@storage.party)
        if selected.nil?
          if pbHeldPokemon
            pbDisplay(_INTL("正拿着精灵！"))
            next
          elsif @scene.grabber.carrying
            pbDisplay(_INTL("正拿着精灵们！"))
            next
          end
          next if pbConfirm(_INTL("继续操作吗？"))
          break
        elsif selected[0] == -3   # Close box
          if pbHeldPokemon
            pbDisplay(_INTL("正拿着精灵！"))
            next
          elsif @scene.grabber.carrying
            pbDisplay(_INTL("正拿着精灵们！"))
            next
          end
          if pbConfirm(_INTL("退出存储系统？"))
            pbSEPlay("PC close")
            break
          end
          next
        elsif selected[0] == -4   # Box name
          if @scene.grabber.carrying && CAN_BOX_POUR
			if pbPour(selected)
              @scene.grabber.carrying = false
              @scene.grabber.clear
              @scene.release_tension
			end
          else
            pbBoxCommands
          end
        else
          pokemon = @storage[selected[0], selected[1]]
          heldpoke = pbHeldPokemon
          next if !pokemon && !heldpoke && !@scene.grabber.carrying
          if @scene.quickswap
            if @heldpkmn
              (pokemon) ? pbSwap(selected) : pbPlace(selected)
            else
              pbHold(selected)
            end
          elsif @scene.multi
            if !@scene.grabber.carrying
              if @scene.grabber.holding_anything?
                @scene.grabber.carrying = true
                # Gathers held mons data in @carried_mons in the grabber
                @scene.grabber.pack_up(@storage, selected[0])
                # Deletes mon off storage
                pbHold_Multi(selected)
                @scene.start_tension
                # Moves the hand to mock pivot position
                @scene.quick_change(@scene.grabber.mock_pivot)
                selected[1] = @scene.grabber.mock_pivot
              else
                # Start tension here
                @scene.grabber.setPivot(selected[1])
                @scene.grabber.do_with(selected[1])
                @scene.do_green
                @scene.set_tension
              end
            else
              # Drop Off If Possible
              if @scene.grabber.place_with_positions(@storage, selected[0], selected[1])
                pbPlace_Multi(selected)
                # @scene.grabber.get_new_carried_mons
                @scene.grabber.carrying = false
                @scene.grabber.clear
                @scene.release_tension
              else
                next
              end
            end
          else
            commands = []
            cmdMove     = -1
            cmdSummary  = -1
            cmdWithdraw = -1
            cmdItem     = -1
            cmdMark     = -1
            cmdRelease  = -1
            cmdDebug    = -1
            if heldpoke
              helptext = _INTL("已选择{1}。", heldpoke.name)
              commands[cmdMove = commands.length] = (pokemon) ? _INTL("交换") : _INTL("放置")
            elsif pokemon
              helptext = _INTL("已选择{1}。", pokemon.name)
              commands[cmdMove = commands.length] = _INTL("移动")
            end
            commands[cmdSummary = commands.length]  = _INTL("信息")
            commands[cmdWithdraw = commands.length] = (selected[0] == -1) ? _INTL("存放") : _INTL("取出")
            commands[cmdItem = commands.length]     = _INTL("道具")
            commands[cmdMark = commands.length]     = _INTL("标记")
            commands[cmdRelease = commands.length]  = _INTL("传送")
            commands[cmdDebug = commands.length]    = _INTL("调试") if $DEBUG
            commands[commands.length]               = _INTL("取消")
            command = pbShowCommands(helptext, commands)
            if cmdMove >= 0 && command == cmdMove   # Move/Shift/Place
              if @heldpkmn
                (pokemon) ? pbSwap(selected) : pbPlace(selected)
              else
                pbHold(selected)
              end
            elsif cmdSummary >= 0 && command == cmdSummary   # Summary
              pbSummary(selected, @heldpkmn)
            elsif cmdWithdraw >= 0 && command == cmdWithdraw   # Store/Withdraw
              (selected[0] == -1) ? pbStore(selected, @heldpkmn) : pbWithdraw(selected, @heldpkmn)
            elsif cmdItem >= 0 && command == cmdItem   # Item
              pbItem(selected, @heldpkmn)
            elsif cmdMark >= 0 && command == cmdMark   # Mark
              pbMark(selected, @heldpkmn)
            elsif cmdRelease >= 0 && command == cmdRelease   # Release
              pbRelease(selected, @heldpkmn)
            elsif cmdDebug >= 0 && command == cmdDebug   # Debug
              pbPokemonDebug((@heldpkmn) ? @heldpkmn : pokemon, selected, heldpoke)
            end
          end
        end
      end
      @scene.pbCloseBox
    when 1   # Withdraw
      @scene.pbStartBox(self, command)
      loop do
        selected = @scene.pbSelectBox(@storage.party)
        if selected.nil?
          next if pbConfirm(_INTL("继续操作吗？"))
          break
        else
          case selected[0]
          when -2   # Party Pokémon
            pbDisplay(_INTL("要选择哪只精灵？"))
            next
          when -3   # Close box
            if pbConfirm(_INTL("退出存储系统？"))
              pbSEPlay("PC close")
              break
            end
            next
          when -4   # Box name
            pbBoxCommands
            next
          end
          pokemon = @storage[selected[0], selected[1]]
          next if !pokemon
          command = pbShowCommands(_INTL("已选择{1}。", pokemon.name),
                                   [_INTL("取出"),
                                    _INTL("信息"),
                                    _INTL("标记"),
                                    _INTL("传送"),
                                    _INTL("取消")])
          case command
          when 0 then pbWithdraw(selected, nil)
          when 1 then pbSummary(selected, nil)
          when 2 then pbMark(selected, nil)
          when 3 then pbRelease(selected, nil)
          end
        end
      end
      @scene.pbCloseBox
    when 2   # Deposit
      @scene.pbStartBox(self, command)
      loop do
        selected = @scene.pbSelectParty(@storage.party)
        if selected == -3   # Close box
          if pbConfirm(_INTL("退出存储系统？"))
            pbSEPlay("PC close")
            break
          end
          next
        elsif selected < 0
          next if pbConfirm(_INTL("继续操作吗？"))
          break
        else
          pokemon = @storage[-1, selected]
          next if !pokemon
          command = pbShowCommands(_INTL("已选择{1}。", pokemon.name),
                                   [_INTL("存放"),
                                    _INTL("信息"),
                                    _INTL("标记"),
                                    _INTL("传送"),
                                    _INTL("取消")])
          case command
          when 0 then pbStore([-1, selected], nil)
          when 1 then pbSummary([-1, selected], nil)
          when 2 then pbMark([-1, selected], nil)
          when 3 then pbRelease([-1, selected], nil)
          end
        end
      end
      @scene.pbCloseBox
    when 3
      @scene.pbStartBox(self, command)
      @scene.pbCloseBox
    end
    $game_temp.in_storage = false
  end
  
  #===============================================================================
  # pbBoxCommands Override
  #===============================================================================
  def pbBoxCommands
    c_consts = [:JUMP]
	c_consts.push(:SWAP) if CAN_SWAP_BOXES
	c_consts.push(:WALL, :NAME, :CANCEL)
    commands = [
      _INTL("跳转")
	]
    commands.push(_INTL("交换")) if CAN_SWAP_BOXES
    commands.push(
      _INTL("壁纸"),
      _INTL("名字"),
      _INTL("取消")
    )
    command = pbShowCommands(_INTL("想要做什么？"), commands)
    case c_consts[command]
    when :JUMP
      destbox = @scene.pbChooseBox(_INTL("跳转到哪个盒子？"))
      @scene.pbJumpToBox(destbox) if destbox >= 0
    when :SWAP
      destbox = @scene.pbChooseBox(_INTL("和哪个盒子交换？"), true)
      @scene.pbSwapBoxes(destbox) if destbox >= 0
    when :WALL
      papers = @storage.availableWallpapers
      index = 0
      papers[1].length.times do |i|
        if papers[1][i] == @storage[@storage.currentBox].background
          index = i
          break
        end
      end
      wpaper = pbShowCommands(_INTL("选择壁纸。"), papers[0], index)
      @scene.pbChangeBackground(papers[1][wpaper]) if wpaper >= 0
    when :NAME
      @scene.pbBoxName(_INTL("盒子的名字是？"), 0, 12)
    end
  end
  
  #===============================================================================
  # ***Additional methods***
  #===============================================================================
  def pbHold_Multi(selected)
    box, index = selected
    if box == -1 && pbAble?(@storage[box, index]) && pbAbleCount <= 1
      pbPlayBuzzerSE
      pbDisplay(_INTL("这是最后的精灵了！"))
      return
    end
    for i in @scene.grabber.get_carried_mons
      @storage.pbDelete(box, i)
    end
    index = @scene.grabber.get_carried_mons[0]
    @heldpkmn = @storage[box, index]
    @scene.refresh_box_sprites
    @scene.pbRefresh
  end
  
  def pbPlace_Multi(selected)
    box, index = selected
    for i in @scene.grabber.get_new_carried_mons(index)
      this_index = i[0]
      if @storage[box, this_index]
        raise _INTL("位置{1}，{2}不为空……", box, this_index)
      end
      if box != -1 && this_index >= @storage.maxPokemon(box)
        pbDisplay("Can't place that there.")
        return
      end
      this_pkmn = i[1]
      if box >= 0 && this_pkmn
        this_pkmn.formTime = nil if this_pkmn.respond_to?("formTime")
        this_pkmn.form     = 0 if this_pkmn.isSpecies?(:SHAYMIN)
        this_pkmn.heal
      end
      @storage[box,this_index] = this_pkmn
      if box==-1
        @storage.party.compact!
      end
    end
    @scene.refresh_box_sprites
    @scene.pbRefresh
    @heldpkmn = nil
  end
  
  #===============================================================================
  # Puts all held Pokemon into available slots in a box
  #===============================================================================
  def pbPour(selected)
    box = @storage.currentBox
	mons_to_place = @scene.grabber.carried_mons.clone
	count = 0
	for i in 0...PokemonBox::BOX_SIZE
	  next if @storage[box, i]
	  m_t_p = mons_to_place.pop
	  @storage[box, i] = m_t_p[0]
	  count += 1
	  break if mons_to_place.empty?
	end
	emptied = mons_to_place.empty?
	@scene.grabber.pour(count)
    @scene.refresh_box_sprites
    @scene.pbRefresh
	@heldpkmn = nil if emptied
	return emptied
  end
  
  #===============================================================================
  # Releases all held Pokemon
  #===============================================================================
  def pbMassRelease
    if @scene.grabber.contains_an_egg?
      pbDisplay(_INTL("蛋不能传送！"))
      return false
    end
    # NOTE: No need to stop if last mon because this cannot be done in party!
    command = pbShowCommands(_INTL("要将精灵们传送给博士？"), [_INTL("否"), _INTL("是")])
    return unless command == 1
    pbDisplay(_INTL("精灵们已传送完毕。"))
    pbDisplay(_INTL("保重，精灵们！"))
    pbDisplay(_INTL("博士给了你一些糖果！"))
    @scene.grabber.release_pokemon
    @scene.grabber.clear
    @scene.pbRefresh
    @scene.pbRefresh
    @scene.grabber.carrying = false
    @scene.release_tension
  end
end
