HOTKEY_MANAGER_USE = nil
HOTKEY_MANAGER_USEONSELF = 1
HOTKEY_MANAGER_USEONTARGET = 2
HOTKEY_MANAGER_USEWITH = 3

HotkeyColors = {
  text = '#888888',
  textAutoSend = '#FFFFFF',
  itemUse = '#8888FF',
  itemUseSelf = '#00FF00',
  itemUseTarget = '#FF0000',
  itemUseWith = '#F5B325',
}

overlay = nil
healthCircleFront = nil
manaCircleFront = nil
healthCircle = nil
manaCircle = nil
topHealthBar = nil
topManaBar = nil
topExperienceBar = 'Posiadasz %d%% do %d poziomu.'
healthTooltip = 'Posiadasz %d zycia z %d.'
manaTooltip = 'Posiadasz %d many z %d.'
experienceTooltip = 'Posiadasz %d%% do %d poziomu.'

hotkeysManagerLoaded = false
hotkeysWindow = nil
hotkeysButton = nil
currentHotkeyLabel = nil
currentItemPreview = false
itemWidget = false
addHotkeyButton = nil
removeHotkeyButton = nil
hotkeyText = nil
hotKeyTextLabel = nil
sendAutomatically = nil
selectObjectButton = nil
clearObjectButton = nil
useOnSelf = false
useOnTarget = false
useWith = false
defaultComboKeys = nil
perServer = true
perCharacter = true
mouseGrabberWidget = nil
useRadioGroup = nil
currentHotkeys = nil
boundCombosCallback = {}
hotkeysList = {}

-- public functions
function init()
  g_keyboard.bindKeyDown('Ctrl+K', toggle)
  hotkeysWindow = g_ui.displayUI('hotkeys_manager')
  hotkeysWindow:setVisible(false)

  currentHotkeys = hotkeysWindow:getChildById('currentHotkeys')
  currentItemPreview = hotkeysWindow:getChildById('itemPreview')
  addHotkeyButton = hotkeysWindow:getChildById('addHotkeyButton')
  removeHotkeyButton = hotkeysWindow:getChildById('removeHotkeyButton')
  hotkeyText = hotkeysWindow:getChildById('hotkeyText')
  hotKeyTextLabel = hotkeysWindow:getChildById('hotKeyTextLabel')
  sendAutomatically = hotkeysWindow:getChildById('sendAutomatically')
  selectObjectButton = hotkeysWindow:getChildById('selectObjectButton')
  clearObjectButton = hotkeysWindow:getChildById('clearObjectButton')
  useOnSelf = hotkeysWindow:getChildById('useOnSelf')
  useOnTarget = hotkeysWindow:getChildById('useOnTarget')
  useWith = hotkeysWindow:getChildById('useWith')

  useRadioGroup = UIRadioGroup.create()
  useRadioGroup:addWidget(useOnSelf)
  useRadioGroup:addWidget(useOnTarget)
  useRadioGroup:addWidget(useWith)
  useRadioGroup.onSelectionChange = function(self, selected) onChangeUseType(selected) end

  mouseGrabberWidget = g_ui.createWidget('UIWidget')
  mouseGrabberWidget:setVisible(false)
  mouseGrabberWidget:setFocusable(false)
  mouseGrabberWidget.onMouseRelease = onChooseItemMouseRelease
  
  healthCircleButton = modules.client_topmenu.addRightGameToggleButton('healtCircleButton', tr('Health and mana'), '/images/topbuttons/circle', togglehealth)
  healthCircleButton:setOn(true)


  topHealthBarButton = modules.client_topmenu.addRightGameToggleButton('topHealthBarButton', tr('Health and mana'), '/images/topbuttons/tophealth', togglehealthbar)
  topHealthBarButton:setOn(true)

  currentHotkeys.onChildFocusChange = function(self, hotkeyLabel) onSelectHotkeyLabel(hotkeyLabel) end
  g_keyboard.bindKeyPress('Down', function() currentHotkeys:focusNextChild(KeyboardFocusReason) end, hotkeysWindow)
  g_keyboard.bindKeyPress('Up', function() currentHotkeys:focusPreviousChild(KeyboardFocusReason) end, hotkeysWindow)
  
  overlay = g_ui.createWidget('HealthOverlay', modules.game_interface.getMapPanel())  
  healthCircleFront = overlay:getChildById('healthCircleFront')
  manaCircleFront = overlay:getChildById('manaCircleFront')
  healthCircle = overlay:getChildById('healthCircle')
  manaCircle = overlay:getChildById('manaCircle')
  topHealthBar = overlay:getChildById('topHealthBar')
  topManaBar = overlay:getChildById('topManaBar')
  topExperienceBar = overlay:getChildById('topExperienceBar')
  
  connect(overlay, { onGeometryChange = onOverlayGeometryChange })
  
  connect(LocalPlayer, { onHealthChange = onHealthChange,
                         onManaChange = onManaChange,
                         onLevelChange = onLevelChange})

  connect(g_game, {
    onGameStart = online,
    useOnSelf:hide(),
    useOnTarget:hide(),
    useWith:hide(),
    currentItemPreview:hide(),
    onGameEnd = offline
  })
  
  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
    onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
  end


  load()
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  
  disconnect(LocalPlayer, { onHealthChange = onHealthChange,
                            onManaChange = onManaChange,
                            onLevelChange = onLevelChange })

  disconnect(g_game, { onGameEnd = offline })
  disconnect(overlay, { onGeometryChange = onOverlayGeometryChange })

  g_keyboard.unbindKeyDown('Ctrl+K')

  unload()

  hotkeysWindow:destroy()
  mouseGrabberWidget:destroy()
  overlay:destroy()
end

function configure(savePerServer, savePerCharacter)
  perServer = savePerServer
  perCharacter = savePerCharacter
  reload()
end

function online()
  reload()
  hide()
end

function offline()
  unload()
  hide()
end

function show()
  if not g_game.isOnline() then
    return
  end
  hotkeysWindow:show()
  hotkeysWindow:raise()
  hotkeysWindow:focus()
end

function hide()
  hotkeysWindow:hide()
end

function toggle()
  if not hotkeysWindow:isVisible() then
    show()
  else
    hide()
  end
end

function ok()
  save()
  hide()
end

function cancel()
  reload()
  hide()
end

function load(forceDefaults)
  hotkeysManagerLoaded = false

  local hotkeySettings = g_settings.getNode('game_hotkeys')
  local hotkeys = {}

  if not table.empty(hotkeySettings) then hotkeys = hotkeySettings end
  if perServer and not table.empty(hotkeys) then hotkeys = hotkeys[G.host] end
  if perCharacter and not table.empty(hotkeys) then hotkeys = hotkeys[g_game.getCharacterName()] end

  hotkeyList = {}
  if not forceDefaults then
    if not table.empty(hotkeys) then
      for keyCombo, setting in pairs(hotkeys) do
        keyCombo = tostring(keyCombo)
        addKeyCombo(keyCombo, setting)
        hotkeyList[keyCombo] = setting
      end
    end
  end

  if currentHotkeys:getChildCount() == 0 then
    loadDefautComboKeys()
  end

  hotkeysManagerLoaded = true
end

function unload()
  for keyCombo,callback in pairs(boundCombosCallback) do
    g_keyboard.unbindKeyPress(keyCombo, callback)
  end
  boundCombosCallback = {}
  currentHotkeys:destroyChildren()
  currentHotkeyLabel = nil
  updateHotkeyForm(true)
  hotkeyList = {}
end

function reset()
  unload()
  load(true)
end

function reload()
  unload()
  load()
end

function save()
  local hotkeySettings = g_settings.getNode('game_hotkeys') or {}
  local hotkeys = hotkeySettings

  if perServer then
    if not hotkeys[G.host] then
      hotkeys[G.host] = {}
    end
    hotkeys = hotkeys[G.host]
  end

  if perCharacter then
    local char = g_game.getCharacterName()
    if not hotkeys[char] then
      hotkeys[char] = {}
    end
    hotkeys = hotkeys[char]
  end

  table.clear(hotkeys)

  for _,child in pairs(currentHotkeys:getChildren()) do
    hotkeys[child.keyCombo] = {
      autoSend = child.autoSend,
      itemId = child.itemId,
      subType = child.subType,
      useType = child.useType,
      value = child.value
    }
  end

  hotkeyList = hotkeys
  g_settings.setNode('game_hotkeys', hotkeySettings)
  g_settings.save()
end

function loadDefautComboKeys()
  if not defaultComboKeys then
    for i=1,12 do
      addKeyCombo('F' .. i)
    end
    for i=1,4 do
      addKeyCombo('Shift+F' .. i)
    end
  else
    for keyCombo, keySettings in pairs(defaultComboKeys) do
      addKeyCombo(keyCombo, keySettings)
    end
  end
end

function setDefaultComboKeys(combo)
  defaultComboKeys = combo
end

function onChooseItemMouseRelease(self, mousePosition, mouseButton)
  local item = nil
  if mouseButton == MouseLeftButton then
    local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if clickedWidget then
      if clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
          local thing = tile:getTopMoveThing()
          if thing and thing:isItem() then
            item = thing
          end
        end
      elseif clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
        item = clickedWidget:getItem()
      end
    end
  end

  if item and currentHotkeyLabel then
    currentHotkeyLabel.itemId = item:getId()
    if item:isFluidContainer() then
        currentHotkeyLabel.subType = item:getSubType()
    end
    if item:isMultiUse() then
      currentHotkeyLabel.useType = HOTKEY_MANAGER_USEWITH
    else
      currentHotkeyLabel.useType = HOTKEY_MANAGER_USE
    end
    currentHotkeyLabel.value = nil
    currentHotkeyLabel.autoSend = false
    updateHotkeyLabel(currentHotkeyLabel)
    updateHotkeyForm(true)
  end

  show()

  g_mouse.popCursor('target')
  self:ungrabMouse()
  return true
end

function togglehealth()
  if healthCircleButton:isOn() then
    healthCircleButton:setOn(false)
    healthCircle:hide()
    manaCircle:hide()
    healthCircleFront:hide()
    manaCircleFront:hide()
  else
    healthCircleButton:setOn(true)
    healthCircle:show()
    manaCircle:show()
    healthCircleFront:show()
    manaCircleFront:show()
  end
end

function togglehealthbar()
  if topHealthBarButton:isOn() then
    topHealthBarButton:setOn(false)
    topHealthBar:hide()
    topManaBar:hide()
    topExperienceBar:hide()
  else
    topHealthBarButton:setOn(true)
    topHealthBar:show()
    topManaBar:show()
    topExperienceBar:show()
  end
end

function onHealthChange(localPlayer, health, maxHealth) 
  topHealthBar:setText(health .. ' / ' .. maxHealth)
  topHealthBar:setTooltip(tr(healthTooltip, health, maxHealth))
  topHealthBar:setValue(health, 0, maxHealth)
  local healthPercent2 = math.floor(100*health/maxHealth)
  if (healthPercent2 >= 93) and (healthPercent2 < 101) then
    topHealthBar:setBackgroundColor("#00BC00FF")
  elseif (healthPercent2 >= 61) and (healthPercent2 < 93) then
    topHealthBar:setBackgroundColor("#50A150FF")
  elseif (healthPercent2 >= 31) and (healthPercent2 < 61) then
    topHealthBar:setBackgroundColor("#A1A100FF")
  elseif (healthPercent2 >= 9) and (healthPercent2 < 31) then
    topHealthBar:setBackgroundColor("#BF0A0AFF")
  elseif (healthPercent2 >= 4) and (healthPercent2 < 9) then
    topHealthBar:setBackgroundColor("#910F0FFF")
  elseif (healthPercent2 >= 2) and (healthPercent2 < 4) then
    topHealthBar:setBackgroundColor("#850C0CFF")
  elseif (healthPercent2 >= 1) and (healthPercent2 < 2) then
    topHealthBar:setBackgroundColor("#660B0BFF")
  end

  local healthPercent = math.floor(g_game.getLocalPlayer():getHealthPercent())
  local healthPercent2 = math.floor(100*health/maxHealth)
  local Yhppc = math.floor(208 * (1 - (math.floor((g_game.getLocalPlayer():getMaxHealth() - (g_game.getLocalPlayer():getMaxHealth() - g_game.getLocalPlayer():getHealth())) * 100 / g_game.getLocalPlayer():getMaxHealth()) / 100)))
  local rect = { x = 0, y = Yhppc, width = 63, height = 208 }

  if (healthPercent2 >= 93) and (healthPercent2 < 101) then
    healthCircleFront:setImageColor("#00BC00FF")
  elseif (healthPercent2 >= 61) and (healthPercent2 < 93) then
    healthCircleFront:setImageColor("#50A150FF")
  elseif (healthPercent2 >= 31) and (healthPercent2 < 61) then
    healthCircleFront:setImageColor("#A1A100FF")
  elseif (healthPercent2 >= 9) and (healthPercent2 < 31) then
    healthCircleFront:setImageColor("#BF0A0AFF")
  elseif (healthPercent2 >= 4) and (healthPercent2 < 9) then
    healthCircleFront:setImageColor("#910F0FFF")
  elseif (healthPercent2 >= 2) and (healthPercent2 < 4) then
    healthCircleFront:setImageColor("#850C0CFF")
  elseif (healthPercent2 >= 1) and (healthPercent2 < 2) then
    healthCircleFront:setImageColor("#660B0BFF")
  end
  
  healthCircleFront:setImageClip(rect)
  healthCircleFront:setMarginTop(Yhppc)
end

function onManaChange(localPlayer, mana, maxMana)
  topManaBar:setText(mana .. ' / ' .. maxMana)
  topManaBar:setTooltip(tr(manaTooltip, mana, maxMana))
  topManaBar:setValue(mana, 0, maxMana)

  local Ymppc = math.floor(208 * (1 - (math.floor((g_game.getLocalPlayer():getMaxMana() - (g_game.getLocalPlayer():getMaxMana() - g_game.getLocalPlayer():getMana())) * 100 / g_game.getLocalPlayer():getMaxMana()) / 100)))
  local rect = { x = 0, y = Ymppc, width = 63, height = 208 }
  manaCircleFront:setImageClip(rect)
  manaCircleFront:setMarginTop(Ymppc)
end

function onLevelChange(localPlayer, value, percent)
  topExperienceBar:setText(tr(experienceTooltip, percent, value+1))
  topExperienceBar:setTooltip(tr(experienceTooltip, percent, value+1))
  topExperienceBar:setPercent(percent) 
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

function setExperienceTooltip(tooltip)
  experienceTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    experienceBar:setTooltip(tr(experienceTooltip, localPlayer:getLevelPercent(), localPlayer:getLevel()+1))
  end
end

function onOverlayGeometryChange() 
  local classic = g_settings.getBoolean("classicView")
  local minMargin = 100
  if classic then
    topHealthBar:setMarginTop(15)
    topManaBar:setMarginTop(15)
    topExperienceBar:setMarginTop(15)
  else
    topHealthBar:setMarginTop(45)
    topManaBar:setMarginTop(45)
	topExperienceBar:setMarginTop(45)  
    minMargin = 200
  end

  local height = overlay:getHeight()
  local width = overlay:getWidth()
  
   
  topHealthBar:setMarginLeft(math.max(minMargin, (width - height) / 2 + 2))
  topManaBar:setMarginRight(math.max(minMargin, (width - height) / 2 + 2))
  topExperienceBar:setMarginRight(math.max(minMargin, (width - height) / 2 + 2))
  topExperienceBar:setMarginLeft(math.max(minMargin, (width - height) / 2 + 2))
end

function startChooseItem()
  if g_ui.isMouseGrabbed() then return end
  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
  hide()
end

function clearObject()
  currentHotkeyLabel.itemId = nil
  currentHotkeyLabel.subType = nil
  currentHotkeyLabel.useType = nil
  currentHotkeyLabel.autoSend = nil
  currentHotkeyLabel.value = nil
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm(true)
end

function addHotkey()
  local assignWindow = g_ui.createWidget('HotkeyAssignWindow', rootWidget)
  assignWindow:grabKeyboard()

  local comboLabel = assignWindow:getChildById('comboPreview')
  comboLabel.keyCombo = ''
  assignWindow.onKeyDown = hotkeyCapture
end

function addKeyCombo(keyCombo, keySettings, focus)
  if keyCombo == nil or #keyCombo == 0 then return end
  if not keyCombo then return end
  local hotkeyLabel = currentHotkeys:getChildById(keyCombo)
  if not hotkeyLabel then
    hotkeyLabel = g_ui.createWidget('HotkeyListLabel')
    hotkeyLabel:setId(keyCombo)

    local children = currentHotkeys:getChildren()
    children[#children+1] = hotkeyLabel
    table.sort(children, function(a,b)
      if a:getId():len() < b:getId():len() then
        return true
      elseif a:getId():len() == b:getId():len() then
        return a:getId() < b:getId()
      else
        return false
      end
    end)
    for i=1,#children do
      if children[i] == hotkeyLabel then
        currentHotkeys:insertChild(i, hotkeyLabel)
        break
      end
    end

    if keySettings then
      currentHotkeyLabel = hotkeyLabel
      hotkeyLabel.keyCombo = keyCombo
      hotkeyLabel.autoSend = toboolean(keySettings.autoSend)
      hotkeyLabel.itemId = tonumber(keySettings.itemId)
      hotkeyLabel.subType = tonumber(keySettings.subType)
      hotkeyLabel.useType = tonumber(keySettings.useType)
      if keySettings.value then hotkeyLabel.value = tostring(keySettings.value) end
    else
      hotkeyLabel.keyCombo = keyCombo
      hotkeyLabel.autoSend = false
      hotkeyLabel.itemId = nil
      hotkeyLabel.subType = nil
      hotkeyLabel.useType = nil
      hotkeyLabel.value = ''
    end

    updateHotkeyLabel(hotkeyLabel)

    boundCombosCallback[keyCombo] = function() doKeyCombo(keyCombo) end
    g_keyboard.bindKeyPress(keyCombo, boundCombosCallback[keyCombo])
  end

  if focus then
    currentHotkeys:focusChild(hotkeyLabel)
    currentHotkeys:ensureChildVisible(hotkeyLabel)
    updateHotkeyForm(true)
  end
end

function doKeyCombo(keyCombo)
  if not g_game.isOnline() then return end
  local hotKey = hotkeyList[keyCombo]
  if not hotKey then return end
  if hotKey.itemId == nil then
    if not hotKey.value or #hotKey.value == 0 then return end
    if hotKey.autoSend then
      modules.game_console.sendMessage(hotKey.value)
    else
      modules.game_console.setTextEditText(hotKey.value)
    end
  elseif hotKey.useType == HOTKEY_MANAGER_USE then
    if g_game.getProtocolVersion() > 760 or hotKey.subType then
      local item = g_game.findPlayerItem(hotKey.itemId, hotKey.subType or -1)
      if item then
        g_game.use(item)
      end
    else
      g_game.useInventoryItem(hotKey.itemId)
    end
  elseif hotKey.useType == HOTKEY_MANAGER_USEONSELF then
    if g_game.getProtocolVersion() > 760 or hotKey.subType then
      local item = g_game.findPlayerItem(hotKey.itemId, hotKey.subType or -1)
      if item then
        g_game.useWith(item, g_game.getLocalPlayer())
      end
    else
      g_game.useInventoryItemWith(hotKey.itemId, g_game.getLocalPlayer())
    end
  elseif hotKey.useType == HOTKEY_MANAGER_USEONTARGET then
    local attackingCreature = g_game.getAttackingCreature()
    if not attackingCreature then
      local item = Item.create(hotKey.itemId)
      if g_game.getProtocolVersion() > 760 or hotKey.subType then
        local tmpItem = g_game.findPlayerItem(hotKey.itemId, hotKey.subType or -1)
        if not tmpItem then return end
        item = tmpItem
      end

      modules.game_interface.startUseWith(item)
      return
    end

    if not attackingCreature:getTile() then return end
    if g_game.getProtocolVersion() > 760 or hotKey.subType then
      local item = g_game.findPlayerItem(hotKey.itemId, hotKey.subType or -1)
      if item then
        g_game.useWith(item, attackingCreature)
      end
    else
      g_game.useInventoryItemWith(hotKey.itemId, attackingCreature)
    end
  elseif hotKey.useType == HOTKEY_MANAGER_USEWITH then
    local item = Item.create(hotKey.itemId)
    if g_game.getProtocolVersion() > 760 or hotKey.subType then
      local tmpItem = g_game.findPlayerItem(hotKey.itemId, hotKey.subType or -1)
      if not tmpItem then return true end
      item = tmpItem
    end
    modules.game_interface.startUseWith(item)
  end
end

function updateHotkeyLabel(hotkeyLabel)
  if not hotkeyLabel then return end
  if hotkeyLabel.useType == HOTKEY_MANAGER_USEONSELF then
    hotkeyLabel:setText(tr('%s: (use object on yourself)', hotkeyLabel.keyCombo))
    hotkeyLabel:setColor(HotkeyColors.itemUseSelf)
  elseif hotkeyLabel.useType == HOTKEY_MANAGER_USEONTARGET then
    hotkeyLabel:setText(tr('%s: (use object on target)', hotkeyLabel.keyCombo))
    hotkeyLabel:setColor(HotkeyColors.itemUseTarget)
  elseif hotkeyLabel.useType == HOTKEY_MANAGER_USEWITH then
    hotkeyLabel:setText(tr('%s: (use object with crosshair)', hotkeyLabel.keyCombo))
    hotkeyLabel:setColor(HotkeyColors.itemUseWith)
  elseif hotkeyLabel.itemId ~= nil then
    hotkeyLabel:setText(tr('%s: (use object)', hotkeyLabel.keyCombo))
    hotkeyLabel:setColor(HotkeyColors.itemUse)
  else
    local text = hotkeyLabel.keyCombo .. ': '
    if hotkeyLabel.value then
      text = text .. hotkeyLabel.value
    end
    hotkeyLabel:setText(text)
    if hotkeyLabel.autoSend then
      hotkeyLabel:setColor(HotkeyColors.autoSend)
    else
      hotkeyLabel:setColor(HotkeyColors.text)
    end
  end
end

function updateHotkeyForm(reset)
  if currentHotkeyLabel then
    removeHotkeyButton:enable()
    if currentHotkeyLabel.itemId ~= nil then
      hotkeyText:clearText()
      hotkeyText:disable()
      hotKeyTextLabel:disable()
      sendAutomatically:setChecked(false)
      sendAutomatically:disable()
      selectObjectButton:disable()
      clearObjectButton:enable()
      currentItemPreview:setItemId(currentHotkeyLabel.itemId)
      if currentHotkeyLabel.subType then
        currentItemPreview:setItemSubType(currentHotkeyLabel.subType)
      end
      if currentItemPreview:getItem():isMultiUse() then
        useOnSelf:hide()
        useOnTarget:hide()
        useWith:hide()
        if currentHotkeyLabel.useType == HOTKEY_MANAGER_USEONSELF then
          useRadioGroup:selectWidget(useOnSelf)
        elseif currentHotkeyLabel.useType == HOTKEY_MANAGER_USEONTARGET then
          useRadioGroup:selectWidget(useOnTarget)
        elseif currentHotkeyLabel.useType == HOTKEY_MANAGER_USEWITH then
          useRadioGroup:selectWidget(useWith)
        end
      else
        useOnSelf:disable()
        useOnTarget:disable()
        useWith:disable()
        useRadioGroup:clearSelected()
      end
    else
      useOnSelf:disable()
      useOnTarget:disable()
      useWith:disable()
      useRadioGroup:clearSelected()
      hotkeyText:enable()
      hotkeyText:focus()
      hotKeyTextLabel:enable()
      if reset then
        hotkeyText:setCursorPos(-1)
      end
      hotkeyText:setText(currentHotkeyLabel.value)
      sendAutomatically:setChecked(currentHotkeyLabel.autoSend)
      sendAutomatically:setEnabled(currentHotkeyLabel.value and #currentHotkeyLabel.value > 0)
      selectObjectButton:enable()
      clearObjectButton:disable()
      currentItemPreview:clearItem()
    end
  else
    removeHotkeyButton:disable()
    hotkeyText:disable()
    sendAutomatically:disable()
    selectObjectButton:disable()
    clearObjectButton:disable()
    useOnSelf:disable()
    useOnTarget:disable()
    useWith:disable()
    hotkeyText:clearText()
    useRadioGroup:clearSelected()
    sendAutomatically:setChecked(false)
    currentItemPreview:clearItem()
  end
end

function removeHotkey()
  if currentHotkeyLabel == nil then return end
  g_keyboard.unbindKeyPress(currentHotkeyLabel.keyCombo, boundCombosCallback[currentHotkeyLabel.keyCombo])
  boundCombosCallback[currentHotkeyLabel.keyCombo] = nil
  currentHotkeyLabel:destroy()
  currentHotkeyLabel = nil
end

function onHotkeyTextChange(value)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  currentHotkeyLabel.value = value
  if value == '' then
    currentHotkeyLabel.autoSend = false
  end
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onSendAutomaticallyChange(autoSend)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  if not currentHotkeyLabel.value or #currentHotkeyLabel.value == 0 then return end
  currentHotkeyLabel.autoSend = autoSend
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onChangeUseType(useTypeWidget)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  if useTypeWidget == useOnSelf then
    currentHotkeyLabel.useType = HOTKEY_MANAGER_USEONSELF
  elseif useTypeWidget == useOnTarget then
    currentHotkeyLabel.useType = HOTKEY_MANAGER_USEONTARGET
  elseif useTypeWidget == useWith then
    currentHotkeyLabel.useType = HOTKEY_MANAGER_USEWITH
  else
    currentHotkeyLabel.useType = HOTKEY_MANAGER_USE
  end
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onSelectHotkeyLabel(hotkeyLabel)
  currentHotkeyLabel = hotkeyLabel
  updateHotkeyForm(true)
end

function hotkeyCapture(assignWindow, keyCode, keyboardModifiers)
  local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
  local comboPreview = assignWindow:getChildById('comboPreview')
  comboPreview:setText(tr('Current hotkey to add: %s', keyCombo))
  comboPreview.keyCombo = keyCombo
  comboPreview:resizeToText()
  assignWindow:getChildById('addButton'):enable()
  return true
end

function hotkeyCaptureOk(assignWindow, keyCombo)
  addKeyCombo(keyCombo, nil, true)
  assignWindow:destroy()
end
