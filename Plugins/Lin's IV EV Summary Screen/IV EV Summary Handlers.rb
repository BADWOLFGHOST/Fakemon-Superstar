#===============================================================================
# Pokemon Summary handlers.
#===============================================================================
UIHandlers.add(:summary, :page_baseivev, { 
  "name"      => "SS、IV、EV",
  "suffix"    => "baseivev",
  "order"     => 34,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageBaseIVEV }
})