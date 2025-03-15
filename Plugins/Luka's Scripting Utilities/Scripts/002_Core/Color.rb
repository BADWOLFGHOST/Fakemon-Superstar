#===============================================================================
#  Extensions for the `Color` class
#===============================================================================
class ::Color
  include ::LUTS::Concerns::Animatable
  #-----------------------------------------------------------------------------
  #  returns darkened color
  #-----------------------------------------------------------------------------
  def darken(amt = 0.2)
    r = red - red * amt
    g = green - green * amt
    b = blue - blue * amt

    Color.new(r, g, b)
  end
  #-----------------------------------------------------------------------------
  def blank?
    red.zero? && green.zero? && blue.zero? && alpha.zero?
  end

  def present?
    !blank?
  end
end
