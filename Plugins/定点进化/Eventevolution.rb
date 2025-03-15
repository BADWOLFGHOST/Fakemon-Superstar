class Trainer
  def each_pkmn
    @party.each_with_index { |pkmn, index| yield pkmn, index if pkmn && !pkmn.egg? }
  end

  def pbGetPartyIndex(species, form = 0)
    each_pkmn { |pkmn, index| return index if pkmn.isSpecies?(species) && pkmn.form == form }
  end
end

class Pokemon
  def trigger_evolution(species, evo_form = nil, can_cancel = true)
    @form = evo_form if evo_form
    pbFadeOutInWithMusic do
      evo = PokemonEvolutionScene.new
      evo.pbStartScreen(self, species)
      evo.pbEvolution(can_cancel)
      evo.pbEndScreen
    end
  end
end

def pbGetPartyIndex(species, form = 0)
  $player&.pbGetPartyIndex(species, form)
end

def pbGetPartyPokemon(index = 0)
  $player&.party[index]
end

def trigger_evolution(species, evo_species, species_form = 0, evo_form = nil, can_cancel = true)
  index = pbGetPartyIndex(species, species_form)
  pkmn = pbGetPartyPokemon(index)
  pkmn.trigger_evolution(evo_species, evo_form, can_cancel)
end