#==============================================================================
# Party Pause HUD Plugin (Standalone Integration)
#------------------------------------------------------------------------------
# Pokémon Essentials v21.1 & v21.1 Hotfixes 1.0.9
#
# This plugin injects a Party HUD display into your default pause menu by
# aliasing its key methods. It does not require you to modify any core files.
#
# Place this folder (PARTYPAUSE) in your Plugins folder.
# Place ppui in your UI folder (in Graphics).
#==============================================================================

# Ensure MENU_FILE_PATH is defined (adjust the path if needed)
MENU_FILE_PATH = "Graphics/UI/ppui/" unless defined?(MENU_FILE_PATH)
# Set SEE_ITEM to either true or false. When false the default graphic is used.
SEE_ITEM = false unless defined?(SEE_ITEM)

#----------------------------------------------------------------------------
# Helper Methods (if not already defined)
#----------------------------------------------------------------------------
unless defined?(pbUpdateSpriteHash)
  def pbUpdateSpriteHash(hash)
    hash.each_value { |sprite| sprite.update if sprite.respond_to?(:update) }
  end
end

unless defined?(pbDisposeSpriteHash)
  def pbDisposeSpriteHash(hash)
    hash.each_value { |sprite| sprite.dispose if sprite.respond_to?(:dispose) }
    hash.clear
  end
end

#----------------------------------------------------------------------------
# Define a Base Component Class if one isn't already defined
#----------------------------------------------------------------------------
unless defined?(Component)
  class Component
    attr_accessor :viewport, :sprites
    def start_component(viewport, menu)
      @viewport = viewport
      @menu     = menu   # Reference to the pause menu scene
      @sprites  = {}
    end
    def should_draw?; false; end
    def refresh; end
    def update; pbUpdateSpriteHash(@sprites); end
    def dispose; pbDisposeSpriteHash(@sprites); end
  end
end

#----------------------------------------------------------------------------
# Party HUD Component
#
# This component draws the party HUD using graphic files in MENU_FILE_PATH.
#----------------------------------------------------------------------------
class VPM_PokemonPartyHud < Component
  # Positioning constants – adjust these to fine-tune the layout.
  OVERLAY_BOTTOM_OFFSET = -120    # Distance from the bottom of the screen.
  ICON_MARGIN           = 10       # Vertical margin for Pokémon icons within the overlay.
  BAR_Y_OFFSET          = 10       # Y offset within the overlay for the info bars.
  HP_BAR_Y_OFFSET       = BAR_Y_OFFSET + 2
  EXP_BAR_Y_OFFSET      = BAR_Y_OFFSET + 8
  ITEM_Y_OFFSET         = BAR_Y_OFFSET + 40
  STATUS_Y_OFFSET       = BAR_Y_OFFSET - 2
  SHINY_Y_OFFSET        = BAR_Y_OFFSET + 40

  def start_component(viewport, menu)
    super(viewport, menu)
    # Create an overlay sprite covering part of the screen.
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height / 2, @viewport)
    # Position the overlay at the bottom of the screen with an offset.
    @sprites["overlay"].y = Graphics.height - @sprites["overlay"].bitmap.height - OVERLAY_BOTTOM_OFFSET
    @sprites["overlay"].z = 1000  # This layer sits on top.
    # Load the graphic overlays.
    @info_bar_bmp = RPG::Cache.load_bitmap(MENU_FILE_PATH, "overlay_info")
    @hp_bar_bmp   = RPG::Cache.load_bitmap(MENU_FILE_PATH, "overlay_hp")
    @exp_bar_bmp  = RPG::Cache.load_bitmap(MENU_FILE_PATH, "overlay_exp")
    @status_bmp   = RPG::Cache.load_bitmap(MENU_FILE_PATH, "overlay_status")
    @item_bmp     = RPG::Cache.load_bitmap(MENU_FILE_PATH, "overlay_item")
    @shiny_bmp    = RPG::Cache.load_bitmap(MENU_FILE_PATH, "overlay_shiny")
    # Initialize a cache for custom item bitmaps.
    @custom_item_bitmaps = {}
  end

  def should_draw?
    $player && $player.party_count > 0
  end

  def refresh
    # Clear the overlay bitmap each refresh.
    @sprites["overlay"].bitmap.clear

    # Dispose any existing Pokémon icon sprites.
    Settings::MAX_PARTY_SIZE.times do |i|
      if @sprites["pokemon_#{i}"]
        @sprites["pokemon_#{i}"].dispose
        @sprites.delete("pokemon_#{i}")
      end
    end

    # Draw each party Pokémon and their associated info bars.
    $player.party.each_with_index do |pokemon, i|
      next unless pokemon.is_a?(Pokemon)
      spacing = (Graphics.width / 8) * i

      # Set up Pokémon icon sprite.
      if !@sprites["pokemon_#{i}"] || @sprites["pokemon_#{i}"].disposed?
        @sprites["pokemon_#{i}"] = PokemonIconSprite.new(pokemon, @viewport)
      end
      # Position the Pokémon icon inside the overlay.
      @sprites["pokemon_#{i}"].x = spacing + (Graphics.width / 8)
      @sprites["pokemon_#{i}"].y = @sprites["overlay"].y + ICON_MARGIN
      @sprites["pokemon_#{i}"].z = 999  # Draw icons below the overlay.
      
      # Draw the main info bar.
      @sprites["overlay"].bitmap.blt(
         spacing + (Graphics.width / 8) + 16,
         BAR_Y_OFFSET,
         @info_bar_bmp,
         Rect.new(0, 0, @info_bar_bmp.width, @info_bar_bmp.height)
      )

      unless pokemon.egg?
        # Draw HP bar.
        if pokemon.hp > 0
          w = (pokemon.hp * 32.0) / pokemon.totalhp
          w = 1 if w < 1
          w = ((w / 2).round) * 2
          hpzone = 0
          hpzone = 1 if pokemon.hp <= (pokemon.totalhp / 2).floor
          hpzone = 2 if pokemon.hp <= (pokemon.totalhp / 4).floor
          hprect = Rect.new(0, hpzone * 4, w, 4)
          @sprites["overlay"].bitmap.blt(
             spacing + (Graphics.width / 8) + 18,
             HP_BAR_Y_OFFSET,
             @hp_bar_bmp, hprect
          )
        end

        # Draw EXP bar.
        if pokemon.exp > 0
          minexp    = pokemon.growth_rate.minimum_exp_for_level(pokemon.level)
          currentexp = minexp - pokemon.exp
          maxexp    = minexp - pokemon.growth_rate.minimum_exp_for_level(pokemon.level + 1)
          w = (currentexp * 24.0) / maxexp
          w = 1 if w < 1.0
          w = 0 if w.is_a?(Float) && w.nan?
          w = ((w / 2).round) * 2 if w > 0
          exprect = Rect.new(0, 0, w, 2)
          @sprites["overlay"].bitmap.blt(
             spacing + (Graphics.width / 8) + 22,
             EXP_BAR_Y_OFFSET,
             @exp_bar_bmp, exprect
          )
        end

        # Draw held item icon.
        if pokemon.hasItem?
          item_bmp_custom = @item_bmp
          if SEE_ITEM
            # Remove spaces from the item name for the filename.
            item_name = pokemon.item.name.gsub(" ", "")
            filename = "overlay_#{item_name}"
            # Check if the custom graphic exists.
            if File.exist?("Graphics/UI/ppui/#{filename}.png")
              # Cache the bitmap if not already loaded.
              unless @custom_item_bitmaps[filename]
                @custom_item_bitmaps[filename] = RPG::Cache.load_bitmap(MENU_FILE_PATH, filename)
              end
              item_bmp_custom = @custom_item_bitmaps[filename]
            end
          end
          @sprites["overlay"].bitmap.blt(
             spacing + (Graphics.width / 8) + 52,
             ITEM_Y_OFFSET,
             item_bmp_custom,
             Rect.new(0, 0, item_bmp_custom.width, item_bmp_custom.height)
          )
        end

        # Draw status icon.
        status = 0
        if pokemon.fainted?
          status = GameData::Status.count - 1
        elsif pokemon.status != :NONE
          status = GameData::Status.get(pokemon.status).icon_position
        elsif pokemon.pokerusStage == 1
          status = GameData::Status.count
        end
        if status > 0
          statusrect = Rect.new(0, 8 * status, 8, 8)
          @sprites["overlay"].bitmap.blt(
             spacing + (Graphics.width / 8) + 48,
             STATUS_Y_OFFSET,
             @status_bmp, statusrect
          )
        end

        # Draw shiny icon.
        if pokemon.shiny?
          @sprites["overlay"].bitmap.blt(
             spacing + (Graphics.width / 8) + 52,
             SHINY_Y_OFFSET,
             @shiny_bmp,
             Rect.new(0, 0, @shiny_bmp.width, @shiny_bmp.height)
          )
        end
      end
    end
  end

  def dispose
    super
    @info_bar_bmp.dispose
    @hp_bar_bmp.dispose
    @exp_bar_bmp.dispose
    @status_bmp.dispose
    @item_bmp.dispose
    @shiny_bmp.dispose
    # Dispose any custom item bitmaps that were loaded.
    @custom_item_bitmaps.each_value { |bmp| bmp.dispose }
    @custom_item_bitmaps.clear
  end
end

#----------------------------------------------------------------------------
# Plugin Integration into the Default Pause Menu
#
# This section hooks into the pause menu's lifecycle so that the Party HUD is
# created when the pause menu starts, updated every frame, and disposed when
# the menu ends.
#----------------------------------------------------------------------------
if defined?(PokemonPauseMenu_Scene)
  class PokemonPauseMenu_Scene
    alias partypause_pbStartScene pbStartScene
    def pbStartScene
      partypause_pbStartScene
      @party_hud = VPM_PokemonPartyHud.new
      @party_hud.start_component(@viewport, self)
      @party_hud.refresh if @party_hud.should_draw?
    end

    if instance_methods.include?(:update)
      alias partypause_update update
      def update
        partypause_update
        @party_hud.update if @party_hud && @party_hud.should_draw?
      end
    else
      def update
        @party_hud.update if @party_hud && @party_hud.should_draw?
      end
    end

    alias partypause_pbEndScene pbEndScene
    def pbEndScene
      @party_hud.dispose if @party_hud
      partypause_pbEndScene
    end
  end
end
