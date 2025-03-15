#===============================================================================
# SCRIPT DE RAYO DE SOL - CREATED BY POLECTRON
#===============================================================================
# * Settings
#===============================================================================
module SunSettings
  BGPATH = "Graphics/Fogs/sun.png" # Make sure the path and file extension are correct
  UPDATESPERSECONDS = 5
end

#===============================================================================
# * Main
#===============================================================================
class Spriteset_Map
  include SunSettings

  alias :initializeSun :initialize
  alias :updateOldSun :update

  def initialize(*args)
    @sun = []
    initializeSun(*args)
    $sun_need_refresh = true
    $sun_switch = true
  end

  def dispose
    disposeSun
    super if defined?(super)
  end

  def update
    updateOldSun
    updateSun
  end

  #===============================================================================
  # * HUD Data
  #===============================================================================
  def createSun
    map_metadata = GameData::MapMetadata.try_get($game_map.map_id)

    # Ensure map_metadata exists and contains outdoor_map
    if map_metadata && map_metadata.outdoor_map
      @hideSun = PBDayNight.isNight? || !$sun_switch || !map_metadata.outdoor_map
      @correctWeather = $game_screen.weather_type == :None

      return if @hideSun || !@correctWeather || $game_map.fog_name != ""
      yposition = 0
      @sun = []
      #===============================================================================
      # * Image
      #===============================================================================
      if BGPATH != "" # Ensure the path is not empty
        bgbar = IconSprite.new(0, yposition, @viewport1)
        if !pbResolveBitmap(BGPATH).nil?
          bgbar.setBitmap(BGPATH)
          bgbar.z = 9999
          bgbar.blend_type = 1
          @sun.push(bgbar)
        end
      end
    else
      @hideSun = true
    end
  end
  #===============================================================================

  def updateSun
    sun_alpha = calculateSunAlpha
    @sun.each do |sprite|
      sprite.opacity = sun_alpha
      sprite.update
    end

    # Check if the sun should be hidden
    if sun_alpha == 0
      disposeSun unless @sun.empty?
    else
      createSun if @sun.empty?
    end
  end

  def disposeSun
    @sun.each(&:dispose)
    @sun.clear
  end

  # Calculate the alpha value based on the time of day
  def calculateSunAlpha
    current_time = pbGetTimeNow
    hour = current_time.hour
    alpha = 255

    if hour >= 6 && hour <= 18
      # Full visibility during the day
      alpha = 255
    elsif hour > 18 && hour <= 20
      # Gradually fade out between 6 PM and 8 PM
      alpha = 255 - ((hour - 18) * 127.5).to_i
    elsif hour >= 4 && hour < 6
      # Gradually become visible between 4 AM and 6 AM
      alpha = ((hour - 4) * 127.5).to_i
    else
      # Invisible at night
      alpha = 0
    end

    return alpha
  end
end

#===============================================================================

class Scene_Map
  include SunSettings

  alias :updateOldSun :update
  alias :miniupdateOldSun :miniupdate
  alias :createSpritesetsOldSun :createSpritesets

  UPDATERATE = (UPDATESPERSECONDS > 0) ? 
               (Graphics.frame_rate / UPDATESPERSECONDS).floor : 0x3FFF

  def update
    updateOldSun
    checkAndUpdateSun
  end

  def miniupdate
    miniupdateOldSun
    checkAndUpdateSun
  end

  def createSpritesets
    createSpritesetsOldSun
    checkAndUpdateSun
  end

  def checkAndUpdateSun
    if $sun_need_refresh
      @spritesets.each_value do |s|
        s.disposeSun
        s.createSun
      end
      $sun_need_refresh = false
    end
  end
end