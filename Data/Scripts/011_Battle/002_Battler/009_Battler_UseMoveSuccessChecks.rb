class Battle::Battler
  #=============================================================================
  # Decide whether the trainer is allowed to tell the Pokémon to use the given
  # move. Called when choosing a command for the round.
  # Also called when processing the Pokémon's action, because these effects also
  # prevent Pokémon action. Relevant because these effects can become active
  # earlier in the same round (after choosing the command but before using the
  # move) or an unusable move may be called by another move such as Metronome.
  #=============================================================================
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    # Disable
    if @effects[PBEffects::DisableMove] == move.id && !specialUsage
      if showMessages
        msg = _INTL("{1}因定身法而无法使出{2}！", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Heal Block
    if @effects[PBEffects::HealBlock] > 0 && move.healingMove?
      if showMessages
        msg = _INTL("{1}因回复封锁而无法使出{2}！", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Gravity
    if @battle.field.effects[PBEffects::Gravity] > 0 && move.unusableInGravity?
      if showMessages
        msg = _INTL("{1}因重力太强而无法使出{2}！", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Throat Chop
    if @effects[PBEffects::ThroatChop] > 0 && move.soundMove?
      if showMessages
        msg = _INTL("{1}因深渊突刺的效果无法使出{2}！", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Choice Band/Gorilla Tactics
    @effects[PBEffects::ChoiceBand] = nil if !pbHasMove?(@effects[PBEffects::ChoiceBand])
    if @effects[PBEffects::ChoiceBand] && move.id != @effects[PBEffects::ChoiceBand]
      choiced_move = GameData::Move.try_get(@effects[PBEffects::ChoiceBand])
      if choiced_move
        if hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF])
          if showMessages
            msg = _INTL("因为{1}的效果，只能使出{2}！", itemName, choiced_move.name)
            (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
          end
          return false
        elsif hasActiveAbility?(:GORILLATACTICS)
          if showMessages
            msg = _INTL("{1}只能使出{2}！", pbThis, choiced_move.name)
            (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
          end
          return false
        end
      end
    end
    # Taunt
    if @effects[PBEffects::Taunt] > 0 && move.statusMove? && !specialUsage
      if showMessages
        msg = _INTL("{1}受到了挑衅，无法使出{2}！", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Torment
    if @effects[PBEffects::Torment] && !@effects[PBEffects::Instructed] && !specialUsage &&
       @lastMoveUsed && move.id == @lastMoveUsed && move.id != @battle.struggle.id
      if showMessages
        msg = _INTL("{1}遭到了无理取闹，因此无法继续使出相同的招式！", pbThis)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Imprison
    if @battle.allOtherSideBattlers(@index).any? { |b| b.effects[PBEffects::Imprison] && b.pbHasMove?(move.id) }
      if showMessages
        msg = _INTL("{1}因封印而无法使出{2}！", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Assault Vest (prevents choosing status moves but doesn't prevent
    # executing them)
    if hasActiveItem?(:ASSAULTVEST) && move.statusMove? && move.function_code != "UseMoveTargetIsAboutToUse" && commandPhase
      if showMessages
        msg = _INTL("{1}阻止了使出变化招式！", itemName)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Belch
    return false if !move.pbCanChooseMove?(self, commandPhase, showMessages)
    return true
  end

  #=============================================================================
  # Obedience check
  #=============================================================================
  # Return true if Pokémon continues attacking (although it may have chosen to
  # use a different move in disobedience), or false if attack stops.
  def pbObedienceCheck?(choice)
    return true if usingMultiTurnAttack?
    return true if choice[0] != :UseMove
    return true if !@battle.internalBattle
    return true if !@battle.pbOwnedByPlayer?(@index)
    disobedient = false
    # Pokémon may be disobedient; calculate if it is
    badge_level = 10 * (@battle.pbPlayer.badge_count + 1)
    badge_level = GameData::GrowthRate.max_level if @battle.pbPlayer.badge_count >= 8
    if Settings::ANY_HIGH_LEVEL_POKEMON_CAN_DISOBEY ||
       (Settings::FOREIGN_HIGH_LEVEL_POKEMON_CAN_DISOBEY && @pokemon.foreign?(@battle.pbPlayer))
      if @level > badge_level
        a = ((@level + badge_level) * @battle.pbRandom(256) / 256).floor
        disobedient |= (a >= badge_level)
      end
    end
    disobedient |= !pbHyperModeObedience(choice[2])
    return true if !disobedient
    # Pokémon is disobedient; make it do something else
    return pbDisobey(choice, badge_level)
  end

  def pbDisobey(choice, badge_level)
    move = choice[2]
    PBDebug.log("[Disobedience] #{pbThis} disobeyed")
    @effects[PBEffects::Rage] = false
    # Do nothing if using Snore/Sleep Talk
    if @status == :SLEEP && move.usableWhenAsleep?
      @battle.pbDisplay(_INTL("{1}仍在睡觉，没有服从命令！", pbThis))
      return false
    end
    b = ((@level + badge_level) * @battle.pbRandom(256) / 256).floor
    # Use another move
    if b < badge_level
      @battle.pbDisplay(_INTL("{1}没有服从命令！", pbThis))
      return false if !@battle.pbCanShowFightMenu?(@index)
      otherMoves = []
      eachMoveWithIndex do |_m, i|
        next if i == choice[1]
        otherMoves.push(i) if @battle.pbCanChooseMove?(@index, i, false)
      end
      return false if otherMoves.length == 0   # No other move to use; do nothing
      newChoice = otherMoves[@battle.pbRandom(otherMoves.length)]
      choice[1] = newChoice
      choice[2] = @moves[newChoice]
      choice[3] = -1
      return true
    end
    c = @level - badge_level
    r = @battle.pbRandom(256)
    # Fall asleep
    if r < c && pbCanSleep?(self, false)
      pbSleepSelf(_INTL("开始睡觉了！", pbThis))
      return false
    end
    # Hurt self in confusion
    r -= c
    if r < c && @status != :SLEEP
      pbConfusionDamage(_INTL("{1}不听话！不知所以地攻击了自己！", pbThis))
      return false
    end
    # Show refusal message and do nothing
    case @battle.pbRandom(4)
    when 0 then @battle.pbDisplay(_INTL("{1}不听话！", pbThis))
    when 1 then @battle.pbDisplay(_INTL("{1}把头转向了一旁！", pbThis))
    when 2 then @battle.pbDisplay(_INTL("{1}在偷懒！", pbThis))
    when 3 then @battle.pbDisplay(_INTL("{1}在装傻！", pbThis))
    end
    return false
  end

  #=============================================================================
  # Check whether the user (self) is able to take action at all.
  # If this returns true, and if PP isn't a problem, the move will be considered
  # to have been used (even if it then fails for whatever reason).
  #=============================================================================
  def pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
    # Check whether it's possible for self to use the given move
    # NOTE: Encore has already changed the move being used, no need to have a
    #       check for it here.
    if !pbCanChooseMove?(move, false, true, specialUsage)
      @lastMoveFailed = true
      return false
    end
    # Check whether it's possible for self to do anything at all
    if @effects[PBEffects::SkyDrop] >= 0   # Intentionally no message here
      PBDebug.log("[Move failed] #{pbThis} can't use #{move.name} because of being Sky Dropped")
      return false
    end
    if @effects[PBEffects::HyperBeam] > 0   # Intentionally before Truant
      PBDebug.log("[Move failed] #{pbThis} is recharging after using #{move.name}")
      @battle.pbDisplay(_INTL("{1}需要休息！", pbThis))
      @effects[PBEffects::Truant] = !@effects[PBEffects::Truant] if hasActiveAbility?(:TRUANT)
      return false
    end
    if choice[1] == -2   # Battle Palace
      PBDebug.log("[Move failed] #{pbThis} can't act in the Battle Palace somehow")
      @battle.pbDisplay(_INTL("{1}似乎无法发挥力量！", pbThis))
      return false
    end
    # Skip checking all applied effects that could make self fail doing something
    return true if skipAccuracyCheck
    # Check status problems and continue their effects/cure them
    case @status
    when :SLEEP
      self.statusCount -= 1
      if @statusCount <= 0
        pbCureStatus
      else
        pbContinueStatus
        if !move.usableWhenAsleep?   # Snore/Sleep Talk
          PBDebug.log("[Move failed] #{pbThis} is asleep")
          @lastMoveFailed = true
          return false
        end
      end
    when :FROZEN
      if !move.thawsUser?
        if @battle.pbRandom(100) < 20
          pbCureStatus
        else
          pbContinueStatus
          PBDebug.log("[Move failed] #{pbThis} is frozen")
          @lastMoveFailed = true
          return false
        end
      end
    end
    # Obedience check
    return false if !pbObedienceCheck?(choice)
    # Truant
    if hasActiveAbility?(:TRUANT)
      @effects[PBEffects::Truant] = !@effects[PBEffects::Truant]
      if !@effects[PBEffects::Truant]   # True means loafing, but was just inverted
        @battle.pbShowAbilitySplash(self)
        @battle.pbDisplay(_INTL("{1}正在偷懒。", pbThis))
        @lastMoveFailed = true
        @battle.pbHideAbilitySplash(self)
        PBDebug.log("[Move failed] #{pbThis} can't act because of #{abilityName}")
        return false
      end
    end
    # Flinching
    if @effects[PBEffects::Flinch]
      @battle.pbDisplay(_INTL("{1}畏缩了，无法使出招式！", pbThis))
      PBDebug.log("[Move failed] #{pbThis} flinched")
      if abilityActive?
        Battle::AbilityEffects.triggerOnFlinch(self.ability, self, @battle)
      end
      @lastMoveFailed = true
      return false
    end
    # Confusion
    if @effects[PBEffects::Confusion] > 0
      @effects[PBEffects::Confusion] -= 1
      if @effects[PBEffects::Confusion] <= 0
        pbCureConfusion
        @battle.pbDisplay(_INTL("{1}的混乱解除了！", pbThis))
      else
        @battle.pbCommonAnimation("Confusion", self)
        @battle.pbDisplay(_INTL("{1}混乱了！", pbThis))
        threshold = (Settings::MECHANICS_GENERATION >= 7) ? 33 : 50   # % chance
        if @battle.pbRandom(100) < threshold
          pbConfusionDamage(_INTL("不知所以地攻击了自己！"))
          PBDebug.log("[Move failed] #{pbThis} hurt itself in its confusion")
          @lastMoveFailed = true
          return false
        end
      end
    end
    # Paralysis
    if @status == :PARALYSIS && @battle.pbRandom(100) < 25
      pbContinueStatus
      PBDebug.log("[Move failed] #{pbThis} is paralyzed")
      @lastMoveFailed = true
      return false
    end
    # Infatuation
    if @effects[PBEffects::Attract] >= 0
      @battle.pbCommonAnimation("Attract", self)
      @battle.pbDisplay(_INTL("{2}让{1}着迷了！", pbThis,
                              @battle.battlers[@effects[PBEffects::Attract]].pbThis(true)))
      if @battle.pbRandom(100) < 50
        @battle.pbDisplay(_INTL("{1}因着迷了而无法使出招式！", pbThis))
        PBDebug.log("[Move failed] #{pbThis} is immobilized by love")
        @lastMoveFailed = true
        return false
      end
    end
    return true
  end

  #=============================================================================
  # Initial success check against the target. Done once before the first hit.
  # Includes move-specific failure conditions, protections and type immunities.
  #=============================================================================
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    show_message = move.pbShowFailMessages?(targets)
    typeMod = move.pbCalcTypeMod(move.calcType, user, target)
    target.damageState.typeMod = typeMod
    # Two-turn attacks can't fail here in the charging turn
    return true if user.effects[PBEffects::TwoTurnAttack]
    # Move-specific failures
    if move.pbFailsAgainstTarget?(user, target, show_message)
      PBDebug.log(sprintf("[Move failed] In function code %s's def pbFailsAgainstTarget?", move.function_code))
      return false
    end
    # Immunity to priority moves because of Psychic Terrain
    if @battle.field.terrain == :Psychic && target.affectedByTerrain? && target.opposes?(user) &&
       @battle.choices[user.index][4] > 0   # Move priority saved from pbCalculatePriority
      @battle.pbDisplay(_INTL("{1}正受到精神场地的保护！", target.pbThis)) if show_message
      return false
    end
    # Crafty Shield
    if target.pbOwnSide.effects[PBEffects::CraftyShield] && user.index != target.index &&
       move.statusMove? && !move.pbTarget(user).targets_all
      if show_message
        @battle.pbCommonAnimation("CraftyShield", target)
        @battle.pbDisplay(_INTL("{1}受到了戏法防守的保护！", target.pbThis(true)))
      end
      target.damageState.protected = true
      @battle.successStates[user.index].protected = true
      return false
    end
    if !(user.hasActiveAbility?(:UNSEENFIST) && move.contactMove?)
      # Wide Guard
      if target.pbOwnSide.effects[PBEffects::WideGuard] && user.index != target.index &&
         move.pbTarget(user).num_targets > 1 &&
         (Settings::MECHANICS_GENERATION >= 7 || move.damagingMove?)
        if show_message
          @battle.pbCommonAnimation("WideGuard", target)
          @battle.pbDisplay(_INTL("{1}受到了广域防守的保护！", target.pbThis(true)))
        end
        target.damageState.protected = true
        @battle.successStates[user.index].protected = true
        return false
      end
      if move.canProtectAgainst?
        # Quick Guard
        if target.pbOwnSide.effects[PBEffects::QuickGuard] &&
           @battle.choices[user.index][4] > 0   # Move priority saved from pbCalculatePriority
          if show_message
            @battle.pbCommonAnimation("QuickGuard", target)
            @battle.pbDisplay(_INTL("{1}受到了快速防守的保护！", target.pbThis(true)))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          return false
        end
        # Protect
        if target.effects[PBEffects::Protect]
          if show_message
            @battle.pbCommonAnimation("Protect", target)
            @battle.pbDisplay(_INTL("{1}在攻击中守护住了自己！", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          return false
        end
        # King's Shield
        if target.effects[PBEffects::KingsShield] && move.damagingMove?
          if show_message
            @battle.pbCommonAnimation("KingsShield", target)
            @battle.pbDisplay(_INTL("{1}在攻击中守护住了自己！", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanLowerStatStage?(:ATTACK, target)
            user.pbLowerStatStage(:ATTACK, (Settings::MECHANICS_GENERATION >= 8) ? 1 : 2, target)
          end
          return false
        end
        # Spiky Shield
        if target.effects[PBEffects::SpikyShield]
          if show_message
            @battle.pbCommonAnimation("SpikyShield", target)
            @battle.pbDisplay(_INTL("{1}在攻击中守护住了自己！", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? && user.takesIndirectDamage?
            @battle.scene.pbDamageAnimation(user)
            user.pbReduceHP(user.totalhp / 8, false)
            @battle.pbDisplay(_INTL("{1}受到了伤害！", user.pbThis))
            user.pbItemHPHealCheck
          end
          return false
        end
        # Baneful Bunker
        if target.effects[PBEffects::BanefulBunker]
          if show_message
            @battle.pbCommonAnimation("BanefulBunker", target)
            @battle.pbDisplay(_INTL("{1}在攻击中守护住了自己！", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanPoison?(target, false)
            user.pbPoison(target)
          end
          return false
        end
        # Obstruct
        if target.effects[PBEffects::Obstruct] && move.damagingMove?
          if show_message
            @battle.pbCommonAnimation("Obstruct", target)
            @battle.pbDisplay(_INTL("{1}在攻击中守护住了自己！", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanLowerStatStage?(:DEFENSE, target)
            user.pbLowerStatStage(:DEFENSE, 2, target)
          end
          return false
        end
        # Mat Block
        if target.pbOwnSide.effects[PBEffects::MatBlock] && move.damagingMove?
          # NOTE: Confirmed no common animation for this effect.
          @battle.pbDisplay(_INTL("{1}被掀榻榻米保护住了！", move.name)) if show_message
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          return false
        end
      end
    end
    # Magic Coat/Magic Bounce
    if move.statusMove? && move.canMagicCoat? && !target.semiInvulnerable? && target.opposes?(user)
      if target.effects[PBEffects::MagicCoat]
        target.damageState.magicCoat = true
        target.effects[PBEffects::MagicCoat] = false
        return false
      end
      if target.hasActiveAbility?(:MAGICBOUNCE) && !@battle.moldBreaker &&
         !target.effects[PBEffects::MagicBounce]
        target.damageState.magicBounce = true
        target.effects[PBEffects::MagicBounce] = true
        return false
      end
    end
    # Immunity because of ability (intentionally before type immunity check)
    return false if move.pbImmunityByAbility(user, target, show_message)
    # Type immunity
    if move.pbDamagingMove? && Effectiveness.ineffective?(typeMod)
      PBDebug.log("[Target immune] #{target.pbThis}'s type immunity")
      @battle.pbDisplay(_INTL("对于{1}，好像没有效果……", target.pbThis(true))) if show_message
      return false
    end
    # Dark-type immunity to moves made faster by Prankster
    if Settings::MECHANICS_GENERATION >= 7 && user.effects[PBEffects::Prankster] &&
       target.pbHasType?(:DARK) && target.opposes?(user)
      PBDebug.log("[Target immune] #{target.pbThis} is Dark-type and immune to Prankster-boosted moves")
      @battle.pbDisplay(_INTL("对于{1}，好像没有效果……", target.pbThis(true))) if show_message
      return false
    end
    # Airborne-based immunity to Ground moves
    if move.damagingMove? && move.calcType == :GROUND &&
       target.airborne? && !move.hitsFlyingTargets?
      if target.hasActiveAbility?(:LEVITATE) && !@battle.moldBreaker
        if show_message
          @battle.pbShowAbilitySplash(target)
          if Battle::Scene::USE_ABILITY_SPLASH
            @battle.pbDisplay(_INTL("没有击中{1}！", target.pbThis))
          else
            @battle.pbDisplay(_INTL("因为{2}，没有击中{1}！", target.pbThis, target.abilityName))
          end
          @battle.pbHideAbilitySplash(target)
        end
        return false
      end
      if target.hasActiveItem?(:AIRBALLOON)
        @battle.pbDisplay(_INTL("因为{1}的{2}，地面招式失效了！", target.pbThis, target.itemName)) if show_message
        return false
      end
      if target.effects[PBEffects::MagnetRise] > 0
        @battle.pbDisplay(_INTL("因为电磁飘浮，地面招式失效了！", target.pbThis)) if show_message
        return false
      end
      if target.effects[PBEffects::Telekinesis] > 0
        @battle.pbDisplay(_INTL("因为意念移物，地面招式失效了！", target.pbThis)) if show_message
        return false
      end
    end
    # Immunity to powder-based moves
    if move.powderMove?
      if target.pbHasType?(:GRASS) && Settings::MORE_TYPE_EFFECTS
        PBDebug.log("[Target immune] #{target.pbThis} is Grass-type and immune to powder-based moves")
        @battle.pbDisplay(_INTL("对于{1}，好像没有效果……", target.pbThis(true))) if show_message
        return false
      end
      if Settings::MECHANICS_GENERATION >= 6
        if target.hasActiveAbility?(:OVERCOAT) && !@battle.moldBreaker
          if show_message
            @battle.pbShowAbilitySplash(target)
            if Battle::Scene::USE_ABILITY_SPLASH
              @battle.pbDisplay(_INTL("对于{1}，好像没有效果……", target.pbThis(true)))
            else
              @battle.pbDisplay(_INTL("因为{2}，对{1}没有效果！", target.pbThis(true), target.abilityName))
            end
            @battle.pbHideAbilitySplash(target)
          end
          return false
        end
        if target.hasActiveItem?(:SAFETYGOGGLES)
          PBDebug.log("[Item triggered] #{target.pbThis} has Safety Goggles and is immune to powder-based moves")
          @battle.pbDisplay(_INTL("对于{1}，好像没有效果……", target.pbThis(true))) if show_message
          return false
        end
      end
    end
    # Substitute
    if target.effects[PBEffects::Substitute] > 0 && move.statusMove? &&
       !move.ignoresSubstitute?(user) && user.index != target.index
      PBDebug.log("[Target immune] #{target.pbThis} is protected by its Substitute")
      @battle.pbDisplay(_INTL("没有击中{1}！", target.pbThis(true))) if show_message
      return false
    end
    return true
  end

  #=============================================================================
  # Per-hit success check against the target.
  # Includes semi-invulnerable move use and accuracy calculation.
  #=============================================================================
  def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
    # Two-turn attacks can't fail here in the charging turn
    return true if user.effects[PBEffects::TwoTurnAttack]
    # Lock-On
    return true if user.effects[PBEffects::LockOn] > 0 &&
                   user.effects[PBEffects::LockOnPos] == target.index
    # Toxic
    return true if move.pbOverrideSuccessCheckPerHit(user, target)
    miss = false
    hitsInvul = false
    # No Guard
    hitsInvul = true if user.hasActiveAbility?(:NOGUARD) ||
                        target.hasActiveAbility?(:NOGUARD)
    # Future Sight
    hitsInvul = true if @battle.futureSight
    # Helping Hand
    hitsInvul = true if move.function_code == "PowerUpAllyMove"
    if !hitsInvul
      # Semi-invulnerable moves
      if target.effects[PBEffects::TwoTurnAttack]
        if target.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSky",
                                   "TwoTurnAttackInvulnerableInSkyParalyzeTarget",
                                   "TwoTurnAttackInvulnerableInSkyTargetCannotAct")
          miss = true if !move.hitsFlyingTargets?
        elsif target.inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderground")
          miss = true if !move.hitsDiggingTargets?
        elsif target.inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderwater")
          miss = true if !move.hitsDivingTargets?
        elsif target.inTwoTurnAttack?("TwoTurnAttackInvulnerableRemoveProtections")
          miss = true
        end
      end
      if target.effects[PBEffects::SkyDrop] >= 0 &&
         target.effects[PBEffects::SkyDrop] != user.index && !move.hitsFlyingTargets?
        miss = true
      end
    end
    if miss
      target.damageState.invulnerable = true
      PBDebug.log("[Move failed] Target is semi-invulnerable")
    else
      # Called by another move
      return true if skipAccuracyCheck
      # Accuracy check
      return true if move.pbAccuracyCheck(user, target)   # Includes Counter/Mirror Coat
      PBDebug.log("[Move failed] Failed pbAccuracyCheck")
    end
    # Missed
    return false
  end

  #=============================================================================
  # Message shown when a move fails the per-hit success check above.
  #=============================================================================
  def pbMissMessage(move, user, target)
    if target.damageState.affection_missed
      @battle.pbDisplay(_INTL("{1}回应着你的呼喊躲过了招式！", target.pbThis))
    elsif move.pbTarget(user).num_targets > 1 || target.effects[PBEffects::TwoTurnAttack]
      @battle.pbDisplay(_INTL("没有击中{1}！", target.pbThis))
    elsif !move.pbMissMessage(user, target)
      @battle.pbDisplay(_INTL("{1}的攻击没有命中！", user.pbThis))
    end
  end
end
