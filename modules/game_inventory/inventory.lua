Icons = {}
Icons[1] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[2] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[4] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[8] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[16] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[32] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[64] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[128] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[256] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[512] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[1024] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[2048] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[4096] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[8192] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[16384] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[32768] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[65536] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }

InventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot"
}

inventoryWindow = nil
inventoryPanel = nil
inventoryButton = nil
purseButton = nil
fightOffensiveBox = nil
fightBalancedBox = nil
fightDefensiveBox = nil
chaseModeButton = nil
safeFightButton = nil

healthBar = nil
manaBar = nil
healthTooltip = 'Posiadasz %d zycia z %d.'
manaTooltip = 'Posiadasz %d many z %d.'


function init()
  connect(LocalPlayer, { onInventoryChange = onInventoryChange,
  					     onHealthChange = onHealthChange,
                         onManaChange = onManaChange,
                         onStatesChange = onStatesChange,
                         onSoulChange = onSoulChange,
                         onFreeCapacityChange = onFreeCapacityChange,
                         onFightModeChange = update,
                         onChaseModeChange = update,
                         onSafeFightChange = update,
                         onWalk = check,
                         onAutoWalk = check})
  connect(g_game, { onGameStart = refresh })
  connect(g_game, { onGameEnd = offline })
  connect(g_game, { onGameStart = online })
  g_keyboard.bindKeyDown('Ctrl+I', toggle)

  inventoryButton = modules.client_topmenu.addRightGameToggleButton('inventoryButton', tr('Inventory') .. ' (Ctrl+I)', '/images/topbuttons/inventory', toggle)
  inventoryButton:setOn(true)

  inventoryWindow = g_ui.loadUI('inventory', modules.game_interface.getRightPanel())
  inventoryWindow:disableResize()
  inventoryPanel = inventoryWindow:getChildById('contentsPanel')
  healthBar = inventoryWindow:recursiveGetChildById('healthBar')
  manaBar = inventoryWindow:recursiveGetChildById('manaBar')

  purseButton = inventoryPanel:getChildById('purseButton')
  local function purseFunction()
    local purse = g_game.getLocalPlayer():getInventoryItem(InventorySlotPurse)
    if purse then
      g_game.use(purse)
    end
  end
  purseButton.onClick = purseFunction
  
  fightModeRadioGroup = UIRadioGroup.create()
  fightOffensiveBox = inventoryWindow:recursiveGetChildById('fightOffensiveBox')
  fightBalancedBox = inventoryWindow:recursiveGetChildById('fightBalancedBox')
  fightDefensiveBox = inventoryWindow:recursiveGetChildById('fightDefensiveBox')
  
  
  fightModeRadioGroup = UIRadioGroup.create()
  fightModeRadioGroup:addWidget(fightOffensiveBox)
  fightModeRadioGroup:addWidget(fightBalancedBox)
  fightModeRadioGroup:addWidget(fightDefensiveBox)

  
  chaseModeButton = inventoryWindow:recursiveGetChildById('chaseModeBox')
  safeFightButton = inventoryWindow:recursiveGetChildById('safeFightBox')

  connect(chaseModeButton, { onCheckChange = onSetChaseMode })
  connect(safeFightButton, { onCheckChange = onSetSafeFight })
  connect(fightModeRadioGroup, { onSelectionChange = onSetFightMode })


  for k,v in pairs(Icons) do
    g_textures.preload(v.path)
  end
  
  soulLabel = inventoryWindow:recursiveGetChildById('soulLabel')
  capLabel = inventoryWindow:recursiveGetChildById('capLabel')
  conditionPanel = inventoryWindow:recursiveGetChildById('conditionPanel')


  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
    onStatesChange(localPlayer, localPlayer:getStates(), 0)
    onSoulChange(localPlayer, localPlayer:getSoul())
    onFreeCapacityChange(localPlayer, localPlayer:getFreeCapacity())
  end



  refresh()
  inventoryWindow:setup()
end

function terminate()
  disconnect(LocalPlayer, {
    onHealthChange = onHealthChange,
    onManaChange = onManaChange,
    onInventoryChange = onInventoryChange,
	onStatesChange = onStatesChange,
	onSoulChange = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange
  })
  disconnect(g_game, {
	onGameStart = refresh,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onWalk = check,
    onAutoWalk = check,
	onGameEnd = offline
  })
  

  g_keyboard.unbindKeyDown('Ctrl+I')
  
  inventoryWindow:destroy()
  inventoryButton:destroy()
  fightModeRadioGroup:destroy()
end

function update()

  local fightMode = g_game.getFightMode()
  if fightMode == FightOffensive then
    fightModeRadioGroup:selectWidget(fightOffensiveBox)
  elseif fightMode == FightBalanced then
    fightModeRadioGroup:selectWidget(fightBalancedBox)
  else
    fightModeRadioGroup:selectWidget(fightDefensiveBox)
  end
  
  local chaseMode = g_game.getChaseMode()
  chaseModeButton:setChecked(chaseMode == ChaseOpponent)

  local safeFight = g_game.isSafeFight()
  safeFightButton:setChecked(not safeFight)
end

function onHealthChange(localPlayer, health, maxHealth)
  healthBar:setText(health .. ' / ' .. maxHealth)
  healthBar:setTooltip(tr(healthTooltip, health, maxHealth))
  healthBar:setValue(health, 0, maxHealth)
  local healthPercent2 = math.floor(100*health/maxHealth)
  if (healthPercent2 >= 93) and (healthPercent2 < 101) then
    healthBar:setBackgroundColor("#00BC00FF")
  elseif (healthPercent2 >= 61) and (healthPercent2 < 93) then
    healthBar:setBackgroundColor("#50A150FF")
  elseif (healthPercent2 >= 31) and (healthPercent2 < 61) then
    healthBar:setBackgroundColor("#A1A100FF")
  elseif (healthPercent2 >= 9) and (healthPercent2 < 31) then
    healthBar:setBackgroundColor("#BF0A0AFF")
  elseif (healthPercent2 >= 4) and (healthPercent2 < 9) then
    healthBar:setBackgroundColor("#910F0FFF")
  elseif (healthPercent2 >= 2) and (healthPercent2 < 4) then
    healthBar:setBackgroundColor("#850C0CFF")
  elseif (healthPercent2 >= 1) and (healthPercent2 < 2) then
    healthBar:setBackgroundColor("#660B0BFF")
  end
end

function onManaChange(localPlayer, mana, maxMana)
  manaBar:setText(mana .. ' / ' .. maxMana)
  manaBar:setTooltip(tr(manaTooltip, mana, maxMana))
  manaBar:setValue(mana, 0, maxMana)
end

function setHealthTooltip(tooltip)
  healthTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    healthBar:setTooltip(tr(healthTooltip, localPlayer:getHealth(), localPlayer:getMaxHealth()))
  end
end

function setManaTooltip(tooltip)
  manaTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    manaBar:setTooltip(tr(manaTooltip, localPlayer:getMana(), localPlayer:getMaxMana()))
  end
end

function check()
  if modules.client_options.getOption('autoChaseOverride') then
    if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
      g_game.setChaseMode(DontChase)
    end
  end
end

function online()
  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()

    local lastCombatControls = g_settings.getNode('LastCombatControls')
    if not table.empty(lastCombatControls) then
      if lastCombatControls[char] then
        g_game.setFightMode(lastCombatControls[char].fightMode)
        g_game.setChaseMode(lastCombatControls[char].chaseMode)
        g_game.setSafeFight(lastCombatControls[char].safeFight)
      end  
    end
  end

  update()
end

function refresh()
  local player = g_game.getLocalPlayer()
  for i = InventorySlotFirst, InventorySlotPurse do
    if g_game.isOnline() then
      onInventoryChange(player, i, player:getInventoryItem(i))
    else
      onInventoryChange(player, i, nil)
    end
  if player then
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
  end
  end

  purseButton:setVisible(g_game.getFeature(GamePurseSlot))
end


function toggle()
  if inventoryButton:isOn() then
    inventoryWindow:close()
    inventoryButton:setOn(false)
  else
    inventoryWindow:open()
    inventoryButton:setOn(true)
  end
end

function onMiniWindowClose()
  inventoryButton:setOn(false)
end

-- hooked events
function onInventoryChange(player, slot, item, oldItem)
  if slot > InventorySlotPurse then return end

  if slot == InventorySlotPurse then
    if g_game.getFeature(GamePurseSlot) then
      purseButton:setEnabled(item and true or false)
    end
    return
  end

  local itemWidget = inventoryPanel:getChildById('slot' .. slot)
  if item then
    itemWidget:setStyle('Item')
    itemWidget:setItem(item)
  else
    itemWidget:setStyle(InventorySlotStyles[slot])
    itemWidget:setItem(nil)
  end
end

-- status
function toggleIcon(bitChanged)
  local content = inventoryWindow:recursiveGetChildById('conditionPanel')
  
  local icon = content:getChildById(Icons[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = loadIcon(bitChanged)
    icon:setParent(content)
  end
end

function loadIcon(bitChanged)
  local icon = g_ui.createWidget('ConditionWidget', conditionPanel)
  icon:setId(Icons[bitChanged].id)
  icon:setImageSource(Icons[bitChanged].path)
  icon:setTooltip(Icons[bitChanged].tooltip)
  return icon
end

function onSoulChange(localPlayer, soul)
  if not soul then return end
  soulLabel:setText(tr('Soul') .. ':\n' .. soul)
end

function onFreeCapacityChange(player, freeCapacity)
  if not freeCapacity then return end
  if freeCapacity > 99 then
    freeCapacity = math.floor(freeCapacity * 10) / 10
  end
  if freeCapacity > 999 then
    freeCapacity = math.floor(freeCapacity)
  end
  if freeCapacity > 99999 then
    freeCapacity = 99999
  end
  capLabel:setText(tr('Cap') .. ':\n' .. (freeCapacity * 100))
end

function offline()
  local lastCombatControls = g_settings.getNode('LastCombatControls')
  if not lastCombatControls then
    lastCombatControls = {}
  end

  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    lastCombatControls[char] = {
      fightMode = g_game.getFightMode(),
      chaseMode = g_game.getChaseMode(),
      safeFight = g_game.isSafeFight()
    }
    
    -- save last combat control settings
    g_settings.setNode('LastCombatControls', lastCombatControls)
    
    inventoryWindow:recursiveGetChildById('conditionPanel'):destroyChildren()
  end
end

function onSetFightMode(self, selectedFightButton)
  if selectedFightButton == nil then return end
  local buttonId = selectedFightButton:getId()
  local fightMode
  if buttonId == 'fightOffensiveBox' then
    fightMode = FightOffensive
  elseif buttonId == 'fightBalancedBox' then
    fightMode = FightBalanced
  else
    fightMode = FightDefensive
  end
  g_game.setFightMode(fightMode)
end

function onSetChaseMode(self, checked)
  local chaseMode
  if checked then
    chaseMode = ChaseOpponent
  else
    chaseMode = DontChase
  end
  g_game.setChaseMode(chaseMode)
end

function onSetSafeFight(self, checked)
  g_game.setSafeFight(not checked)
end


function onStatesChange(localPlayer, now, old)
  if now == old then return end
  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

