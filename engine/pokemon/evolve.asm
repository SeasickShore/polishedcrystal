EvolvePokemon:
	ld hl, wEvolvableFlags
	xor a
	ld [hl], a
	ld a, [wCurPartyMon]
	ld c, a
	ld b, SET_FLAG
	call EvoFlagAction
EvolveAfterBattle:
	xor a
	ld [wMonTriedToEvolve], a
	dec a
	ld [wCurPartyMon], a
	push hl
	push bc
	push de
	ld a, [wPartyCount]
	and a
	jmp z, EvolveAfterBattle_ReturnToMap
	push af

EvolveAfterBattle_MasterLoop:
	ld hl, wCurPartyMon
	inc [hl]

	pop af
	cp [hl]
	jmp z, EvolveAfterBattle_ReturnToMap

	push af
	ld a, MON_SPECIES
	call GetPartyParamLocationAndValue
	ld [wEvolutionOldSpecies], a
	ld bc, MON_FORM - MON_SPECIES
	add hl, bc
	ld a, [hl]
	ld [wEvolutionOldForm], a
	ld a, [wCurPartyMon]
	ld c, a
	ld hl, wEvolvableFlags
	ld b, CHECK_FLAG
	call EvoFlagAction
	ld a, c
	and a
	jr z, EvolveAfterBattle_MasterLoop

	ld a, [wEvolutionOldSpecies]
	ld c, a
	ld a, [wEvolutionOldForm]
	ld b, a
	call GetEvosAttacksPointer

	push hl
	xor a
	ld [wMonType], a
	predef CopyPkmnToTempMon
	pop hl

.loop
	ld a, [hli]
	inc a
	jr z, EvolveAfterBattle_MasterLoop
	dec a
	ld b, a

	ld a, [wLinkMode]
	and a
	jmp nz, .dont_evolve_2

	ld a, b
	cp EVOLVE_ITEM
	jmp z, .item

	ld a, [wForceEvolution]
	and a
	jmp nz, .dont_evolve_2

	ld a, b
	cp EVOLVE_CRIT
	jmp z, .crit
	cp EVOLVE_HOLDING
	jmp z, .holding
	cp EVOLVE_LOCATION
	jmp z, .location
	cp EVOLVE_MOVE
	jmp z, .move
	cp EVOLVE_EVS
	jmp z, .evs
	cp EVOLVE_LEVEL
	jmp z, .level
	cp EVOLVE_PARTY
	jmp z, .party
	cp EVOLVE_HAPPINESS
	jr z, .happiness

; EVOLVE_STAT
	ld a, [wTempMonLevel]
	cp [hl]
	jmp c, .dont_evolve_1

	call IsMonHoldingEverstone
	jmp z, .dont_evolve_1

	push hl
	ld hl, wTempMonAttack
	ld de, wTempMonDefense
	ld c, 2
	call StringCmp ; set carry if atk > def
	ld a, ATK_EQ_DEF
	jr z, .got_tyrogue_evo
	; a = carry ? ATK_GT_DEF : ATK_LT_DEF
	assert ATK_GT_DEF + 1 == ATK_LT_DEF
	sbc a
	add ATK_LT_DEF
.got_tyrogue_evo
	pop hl

	inc hl
	cp [hl]
	jmp nz, .dont_evolve_2

	inc hl
	jmp .proceed

.happiness
	ld a, [wTempMonHappiness]
	cp HAPPINESS_TO_EVOLVE
	jmp c, .dont_evolve_2

	call IsMonHoldingEverstone
	jmp z, .dont_evolve_2

	; Spiky-eared Pichu cannot evolve
	ld a, [wTempMonSpecies]
	cp LOW(PICHU)
	jr nz, .not_spiky_eared_pichu
	ld a, [wTempMonForm]
	assert !HIGH(PICHU)
	and SPECIESFORM_MASK
	cp PICHU_SPIKY_EARED_FORM
	jmp z, .dont_evolve_2

.not_spiky_eared_pichu
	ld a, [hli]
	cp TR_ANYTIME
	jmp z, .proceed
	cp TR_MORNDAY
	jr z, .happiness_daylight

.happiness_nighttime
	ld a, [wTimeOfDay]
	cp NITE
	jmp c, .dont_evolve_3
	jmp .proceed

.happiness_daylight
	ld a, [wTimeOfDay]
	cp NITE
	jmp nc, .dont_evolve_3
	jmp .proceed

.item
	ld a, [hli]
	ld b, a
	ld a, [wCurItem]
	cp b
	jmp nz, .dont_evolve_3

	ld a, [wForceEvolution]
	and a
	jmp z, .dont_evolve_3
	ld a, [wLinkMode]
	and a
	jmp nz, .dont_evolve_3
	jmp .proceed

.party
	ld a, [hli]
	ld c, a
	push hl
	push de
	ld hl, wPartyMon1Species
	ld a, [wPartyCount]
	ld b, a
.party_loop
	ld a, [hl]
	cp c
	jr nz, .party_next
	ld de, MON_FORM - MON_SPECIES
	add hl, de
	ld a, [hl]
	and a
	jr z, .party_ok
.party_next
	dec b
	jr z, .party_no
	ld de, PARTYMON_STRUCT_LENGTH - MON_FORM
	add hl, de
	jr .party_loop

.party_no
	pop de
	pop hl
	jmp .dont_evolve_3

.party_ok
	pop de
	pop hl
	jmp .proceed

.holding
	ld a, [hli]
	ld b, a
	ld a, [wTempMonItem]
	cp b
	jmp nz, .dont_evolve_2
	ld a, [hli]
	cp TR_ANYTIME
	jr z, .ok
	cp TR_MORNDAY
	jr z, .happiness_daylight
	jr .happiness_nighttime
.ok
	xor a
	ld [wTempMonItem], a
	jr .proceed

.location
	ld a, [wMapGroup]
	ld b, a
	ld a, [wMapNumber]
	ld c, a
	push hl
	call GetWorldMapLocation
	pop hl
	ld b, a
	ld a, [hli]
	cp b
	jmp nz, .dont_evolve_3
	jr .proceed

.move
	ld a, [hli]
	push hl
	push bc
	ld b, a
	ld hl, wTempMonMoves
rept NUM_MOVES
	ld a, [hli]
	cp b
	jr z, .move_proceed
endr
	pop bc
	pop hl
	jmp .dont_evolve_3

.move_proceed
	pop bc
	pop hl
	jr .proceed

.evs
	ld a, [hli]
	push hl
	push bc
	ld hl, wTempMonSpecies
	ld c, a
	ld b, 0
	add hl, bc
	ld a, [hl]
	pop bc
	pop hl
	cp EVS_TO_EVOLVE
	jmp c, .dont_evolve_3
	jr .proceed

.crit
	inc hl
	push hl
	push bc
	ld hl, wCriticalCount
	ld a, [wCurPartyMon]
	ld c, a
	ld b, 0
	add hl, bc
	ld a, [hl]
	cp 3
	pop bc
	pop hl
	jmp c, .dont_evolve_3
	jr .proceed

.level
	ld a, [hli]
	ld b, a
	ld a, [wTempMonLevel]
	cp b
	jmp c, .dont_evolve_3
	call IsMonHoldingEverstone
	jmp z, .dont_evolve_3

.proceed
	ld a, [wTempMonLevel]
	ld [wCurPartyLevel], a
	ld a, $1
	ld [wMonTriedToEvolve], a

	ld a, [hli]
	ld [wEvolutionNewSpecies], a
	ld a, [hl]
	ld c, a
	and FORM_MASK
	ld a, [wTempMonForm]
	jr z, .keep_old_form
	and $ff - FORM_MASK
.keep_old_form
	and $ff - EXTSPECIES_MASK
	or c
	ld [wEvolutionNewForm], a
	and SPECIESFORM_MASK
	ld [wCurForm], a
	ld a, [wCurPartyMon]
	ld hl, wPartyMonNicknames
	call GetNickname
	call CopyName1
	ld hl, Text_WhatEvolving
	call PrintText

	ld c, 50
	call DelayFrames

	xor a
	ldh [hBGMapMode], a
	hlcoord 0, 0
	lb bc, 12, 20
	call ClearBox

	ld a, $1
	ldh [hBGMapMode], a
	call ClearSprites

	farcall EvolutionAnimation

	push af
	call ClearSprites
	pop af
	jmp c, CancelEvolution

	ld hl, Text_CongratulationsYourPokemon
	call PrintText

	ld hl, wEvolutionNewSpecies
	ld a, [hli]
	ld [wCurSpecies], a
	ld [wTempMonSpecies], a
	ld [wNamedObjectIndex], a

	ld a, [hl]
	ld [wCurForm], a
	ld [wTempMonForm], a
	ld [wNamedObjectIndex+1], a

	call GetPokemonName
	ld hl, Text_EvolvedIntoPKMN
	call PrintTextboxText

	ld de, MUSIC_NONE
	call PlayMusic
	ld de, SFX_CAUGHT_MON
	call PlayWaitSFX

	ld c, 40
	call DelayFrames

	call ClearTileMap
	call UpdateSpeciesNameIfNotNicknamed
	call GetBaseData

	ld hl, wTempMonEVs - 1
	ld de, wTempMonMaxHP
	farcall GetHyperTraining
	inc a ; factor in EVs
	ld b, a
	predef CalcPkmnStats

	ld a, [wCurPartyMon]
	ld hl, wPartyMons
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld e, l
	ld d, h
	ld bc, MON_MAXHP
	add hl, bc
	ld a, [hli]
	ld b, a
	ld c, [hl]
	ld hl, wTempMonMaxHP + 1
	ld a, [hld]
	sub c
	ld c, a
	ld a, [hl]
	sbc b
	ld b, a
	ld hl, wTempMonHP + 1
	ld a, [hl]
	add c
	ld [hld], a
	ld a, [hl]
	adc b
	ld [hl], a

	ld hl, wTempMonSpecies
	ld bc, PARTYMON_STRUCT_LENGTH
	rst CopyBytes

	xor a
	ld [wMonType], a
	ld a, [wCurSpecies]
	ld [wTempSpecies], a
	ld c, a
	ld a, [wCurForm]
	ld b, a
	call SetSeenAndCaughtMon

	call LearnEvolutionMove
	call LearnLevelMoves
	jmp EvolveAfterBattle_MasterLoop

.dont_evolve_1
	inc hl
.dont_evolve_2
	inc hl
.dont_evolve_3
	inc hl
	inc hl
	jmp .loop

EvolveAfterBattle_ReturnToMap:
	pop de
	pop bc
	pop hl
	ld a, [wLinkMode]
	and a
	ret nz
	ld a, [wBattleMode]
	and a
	ret nz
	ld a, [wMonTriedToEvolve]
	and a
	call nz, RestartMapMusic
	ret

UpdateSpeciesNameIfNotNicknamed:
	ld hl, wNamedObjectIndex
	ld a, [wEvolutionOldSpecies]
	ld [hli], a
	ld a, [wEvolutionOldForm]
	ld [hl], a
	call GetPokemonName
	ld hl, wStringBuffer1
	ld de, wStringBuffer2
.loop
	ld a, [de]
	inc de
	cp [hl]
	inc hl
	ret nz
	cp "@"
	jr nz, .loop

	ld a, [wCurPartyMon]
	ld bc, MON_NAME_LENGTH
	ld hl, wPartyMonNicknames
	rst AddNTimes
	push hl
	ld hl, wNamedObjectIndex
	ld a, [wCurSpecies]
	ld [hli], a
	ld a, [wCurForm]
	ld [hl], a
	call GetPokemonName
	ld hl, wStringBuffer1
	pop de
	ld bc, MON_NAME_LENGTH
	rst CopyBytes
	ret

CancelEvolution:
	ld hl, Text_StoppedEvolving
	call PrintText
	call ClearTileMap
	pop hl
	jmp EvolveAfterBattle_MasterLoop

IsMonHoldingEverstone:
	push hl
	ld a, [wCurPartyMon]
	ld hl, wPartyMon1Item
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld a, [hl]
	cp EVERSTONE
	pop hl
	ret

Text_CongratulationsYourPokemon:
	; Congratulations! Your @ @
	text_far _CongratulationsYourPokemonText
	text_end

Text_EvolvedIntoPKMN:
	; evolved into @ !
	text_far _EvolvedIntoText
	text_end

Text_StoppedEvolving:
	; Huh? @ stopped evolving!
	text_far _StoppedEvolvingText
	text_end

Text_WhatEvolving:
	; What? @ is evolving!
	text_far _EvolvingText
	text_end

LearnEvolutionMove:
	; c = species
	ld a, [wTempSpecies]
	ld [wCurPartySpecies], a
	ld c, a
	; b = form
	ld a, [wCurForm]
	ld b, a
	; bc = index
	call GetSpeciesAndFormIndex
	ld hl, EvolutionMoves
	add hl, bc
	ld a, [hl]
	and a
	ret z

	ld d, a
	ld hl, wPartyMon1Moves
	ld a, [wCurPartyMon]
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes

	ld b, NUM_MOVES
.check_move
	ld a, [hli]
	cp d
	ret z
	dec b
	jr nz, .check_move

	ld a, d
	ld [wPutativeTMHMMove], a
	ld [wNamedObjectIndex], a
	call GetMoveName
	call CopyName1
	ld a, [wCurPartySpecies]
	push af
	predef LearnMove
	pop af
	ld [wCurPartySpecies], a
	ld [wTempSpecies], a
	ret

LearnLevelMoves:
	ld a, [wTempSpecies]
	ld [wCurPartySpecies], a
	ld c, a
	; b = form
	ld a, [wCurForm]
	ld b, a
	call GetEvosAttacksPointer

.skip_evos
	ld a, [hli]
	inc a
	jr nz, .skip_evos

.find_move
	ld a, [hli]
	inc a
	ret z
	dec a
	ld b, a
	ld a, [wCurPartyLevel]
	cp b
	ld a, [hli]
	jr nz, .find_move

	push hl
	ld d, a
	ld hl, wPartyMon1Moves
	ld a, [wCurPartyMon]
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes

	ld b, NUM_MOVES
.check_move
	ld a, [hli]
	cp d
	jr z, .has_move
	dec b
	jr nz, .check_move

	ld a, d
	ld [wPutativeTMHMMove], a
	ld [wNamedObjectIndex], a
	call GetMoveName
	call CopyName1
	ld a, [wCurPartySpecies]
	push af
	predef LearnMove
	pop af
	ld [wCurPartySpecies], a
	ld [wTempSpecies], a
.has_move
	pop hl
	jr .find_move

FillMoves:
; Fill in moves at de for species c form b at wCurPartyLevel

	push hl
	push de
	push bc
	call GetEvosAttacksPointer
.GoToAttacks:
	ld a, [hli]
	inc a
	jr nz, .GoToAttacks
	jr .GetLevel

.NextMove:
	pop de
.GetMove:
	inc hl
.GetLevel:
	ld a, [hli]
	and a
	jr z, .done
	ld b, a
	ld a, [wCurPartyLevel]
	cp b
	jr c, .done
	ld a, [wEvolutionOldSpecies]
	and a
	jr z, .CheckMove
	ld a, [wPrevPartyLevel]
	cp b
	jr nc, .GetMove

.CheckMove:
	push de
	ld c, NUM_MOVES
.CheckRepeat:
	ld a, [de]
	inc de
	cp [hl]
	jr z, .NextMove
	dec c
	jr nz, .CheckRepeat
	pop de
	push de
	ld c, NUM_MOVES
.CheckSlot:
	ld a, [de]
	and a
	jr z, .LearnMove
	inc de
	dec c
	jr nz, .CheckSlot
	pop de
	push de
	push hl
	ld h, d
	ld l, e
	call ShiftMoves
	ld a, [wEvolutionOldSpecies]
	and a
	jr z, .ShiftedMove
	push de
	ld bc, wPartyMon1PP - (wPartyMon1Moves + NUM_MOVES - 1)
	add hl, bc
	ld d, h
	ld e, l
	call ShiftMoves
	pop de

.ShiftedMove:
	pop hl

.LearnMove:
	ld a, [hl]
	ld [de], a
	ld a, [wEvolutionOldSpecies]
	and a
	jr z, .NextMove
	push hl
	ld a, [hl]
	ld hl, MON_PP - MON_MOVES
	add hl, de
	push hl
	ld hl, Moves + MOVE_PP
	call GetMoveProperty
	pop hl
	ld [hl], a
	pop hl
	jr .NextMove

.done
	jmp PopBCDEHL

ShiftMoves:
	ld c, NUM_MOVES - 1
.loop
	inc de
	ld a, [de]
	ld [hli], a
	dec c
	jr nz, .loop
	ret

EvoFlagAction:
	push de
	ld d, $0
	predef FlagPredef
	pop de
	ret

GetBaseEvolution:
; Find the first mon in the evolution chain including wCurPartySpecies.

; Return carry and the new species in wCurPartySpecies
; if a base evolution is found.

	call GetPreEvolution
GetPreEvolution:
; Find the first mon to evolve into wCurPartySpecies+wCurForm.

; Return carry and the new species in wCurPartySpecies+wCurForm
; if a pre-evolution is found.

	ld bc, 0
.loop ; For each Pokemon...
	ld hl, EvosAttacksPointers
	add hl, bc
	add hl, bc
	ld a, [hli]
	ld h, [hl]
	ld l, a
.loop2 ; For each evolution...
	ld a, [hli]
	inc a
	jr z, .no_evolve ; If we jump, this Pokemon does not evolve into wCurPartySpecies.
	dec a
	cp EVOLVE_STAT ; This evolution type has the extra parameter of stat comparison.
	jr nz, .not_inc
	cp EVOLVE_HOLDING
	jr nz, .not_inc
	inc hl

.not_inc
	inc hl
	ld a, [wCurPartySpecies]
	cp [hl]
	inc hl
	jr nz, .not_preevo
	ld a, [wCurForm]
	cp [hl]
	jr z, .found_preevo
.not_preevo
	inc hl
	ld a, [hl]
	and a
	jr nz, .loop2

.no_evolve
	inc bc
	ld a, b
	cp HIGH(NUM_SPECIES)
	jr c, .loop
	ld a, c
	cp LOW(NUM_SPECIES)
	jr c, .loop
	and a
	ret

.found_preevo
	inc c
	ld a, c
	ld [wCurPartySpecies], a
	ld a, [hl] ; we're pointing to mon form
	ld [wCurForm], a
	scf
	ret

GetEvosAttacksPointer:
; input: b = form, c = species
; output: bc = index, hl = pointer
	call GetSpeciesAndFormIndex
	ld hl, EvosAttacksPointers
	add hl, bc
	add hl, bc
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ret
