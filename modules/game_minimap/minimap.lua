local topMenu

minimapWidget = nil
minimapButton = nil
minimapWindow = nil
positionLabel = nil
otmm = true
preloaded = false
fullmapView = false
oldZoom = nil
oldPos = nil
minimapApoWindow = nil
minimapApoCategoryBox = nil
minimapApoSubCategoryBox = nil
minimapApoMapList = nil
mapApoScrollDownButton = nil
mapApoScrollUpButton = nil
local currentStartIndex = 1
local maxVisibleOptions = 30
local allOptions = {}
local loadedFlags = {}
local currentOption = nil


function init()
  minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton', tr('Minimap') .. ' (Ctrl+M)', '/images/topbuttons/minimap', toggle)
  minimapButton:setOn(true)

  topMenu = modules.client_topmenu.getTopMenu()

  positionLabel = topMenu:recursiveGetChildById('positionMapLabel')

  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(64)

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggle)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap)

  minimapWindow:setup()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  removeAllLoadedFlags()
  if g_game.isOnline() then
    saveMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Shift+M')



  minimapApoWindow:destroy()
  minimapApoCategoryBox:destroy()
  minimapApoSubCategoryBox:destroy()
  minimapWindow:destroy()
  minimapButton:destroy()
end

function toggle()
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  minimapButton:setOn(false)
end

function preload()
  loadMap(false)
  preloaded = true
end

function online()
  loadMap(not preloaded)
  updateCameraPosition()
end

function offline()
  removeAllLoadedFlags()
  saveMap()
end

function loadMap(clean)
  local protocolVersion = g_game.getProtocolVersion()

  if clean then
    g_minimap.clean()
  end

  if otmm then
    local minimapFile = '/minimap.otmm'
    if g_resources.fileExists(minimapFile) then
      g_minimap.loadOtmm(minimapFile)
    end
  else
    local minimapFile = '/minimap_' .. protocolVersion .. '.otcm'
    if g_resources.fileExists(minimapFile) then
      g_map.loadOtcm(minimapFile)
    end
  end
  minimapWidget:load()
end

function createApoWindow()
  if minimapApoWindow then minimapApoWindow:show() return end
  minimapApoWindow = g_ui.createWidget('ApoMapFilterWindow', rootWidget)

  minimapApoCategoryBox = minimapApoWindow:recursiveGetChildById('apoCategoryBox')

  minimapApoSubCategoryBox = minimapApoWindow:recursiveGetChildById('apoSubCategoryBox')

  mapApoScrollUpButton = minimapApoWindow:recursiveGetChildById('mapApoScrollUpButton')
  mapApoScrollDownButton = minimapApoWindow:recursiveGetChildById('mapApoScrollDownButton')
  mapApoScrollUpButton.onMouseRelease = scrollUp
  mapApoScrollDownButton.onMouseRelease = scrollDown


  minimapApoCategoryBox:addOption('Nothing', 'nothing')
  minimapApoCategoryBox:addOption('Cities', 'cities')
  minimapApoCategoryBox:addOption('NPC', 'npc')
  minimapApoCategoryBox:addOption('Quests', 'quests')
  minimapApoCategoryBox:addOption('Rook Quests', 'rookquests')
  minimapApoCategoryBox:addOption('Monsters', 'monsters')
  minimapApoCategoryBox:addOption('Houses', 'houses')
  minimapApoCategoryBox:setCurrentOptionByData('nothing')
  minimapApoCategoryBox.onOptionChange = onCategoryChangeMap


  minimapApoSubCategoryBox:addOption('Nothing', 'nothing')
  minimapApoSubCategoryBox:setCurrentOptionByData('nothing')
  minimapApoSubCategoryBox.onOptionChange = onSubCategoryChangeMap

  minimapApoMapList = minimapApoWindow:recursiveGetChildById('apoMapList')
  connect(minimapApoMapList, { onChildFocusChange = function(self, focusedChild)
    if focusedChild == nil then return end
    goToCoordinates(focusedChild:getText())
  end })

  g_keyboard.bindKeyPress('Up', function() minimapApoMapList:focusPreviousChild(KeyboardFocusReason) end, minimapApoWindow)
  g_keyboard.bindKeyPress('Down', function() minimapApoMapList:focusNextChild(KeyboardFocusReason) end, minimapApoWindow)


end

function loadFlagsFromFile(option,data)
  removeAllLoadedFlags()
  local filePath = "data/apoMap/" .. string.lower(tostring(currentOption):gsub(" ", "")) .. "/" .. data .. ".txt"
  local file = io.open(filePath, "r")
  if not file then
    print("Error: Could not open file " .. filePath)
    return
  end

  for line in file:lines() do
    local data = basic_json_decode(line)
    if data and data.x and data.y and data.z and data.title and data.id then
      local pos = {x = data.x, y = data.y, z = data.z}
      local description = data.title
      if description == "" then
        description = tostring(data.id)
      end
      minimapWidget:addFlag(pos, "14", description)
      table.insert(loadedFlags, {pos = pos, icon = "flag14", description = description})
    end
  end
  file:close()
end

function removeAllLoadedFlags()
  for _, flagData in ipairs(loadedFlags) do
    minimapWidget:removeFlag(flagData.pos, flagData.icon, flagData.description)
  end
  loadedFlags = {}
end

function basic_json_decode(line)
  local data = {}
  line = line:gsub('["{}]', '')
  for pair in line:gmatch("[^,]+") do
    local key, value = pair:match("([^:]+):(.+)")
    if key and value then
      key = key:match("^%s*(.-)%s*$")  -- Usuń białe znaki
      value = value:match("^%s*(.-)%s*$")
      if tonumber(value) then value = tonumber(value) end
      data[key] = value
    end
  end
  return data
end

function loadOptionsFromFile(option)
  allOptions = {} -- Wyczyść istniejącą listę opcji

  local filePath = "data/apoMap/" .. option:gsub(" ", ""):lower() .. ".txt"
  local file = io.open(filePath, "r")
  if not file then
    print("Error: Could not open file " .. filePath)
    return
  end

  for line in file:lines() do
    local id, name = line:match("^(%d+),(.+)$")
    if id and name then
      table.insert(allOptions, { name = name, id = id })
    end
  end
  file:close()

  currentStartIndex = 1
  updateVisibleOptions()
end


function updateVisibleOptions()
  minimapApoSubCategoryBox:clearOptions()

  for i = currentStartIndex, math.min(currentStartIndex + maxVisibleOptions - 1, #allOptions) do
    local option = allOptions[i]
    minimapApoSubCategoryBox:addOption(option.name, option.id)
  end
end

-- Funkcje do obsługi przycisków przewijania
function scrollUp()
  if currentStartIndex > 1 then
    currentStartIndex = currentStartIndex - maxVisibleOptions
    updateVisibleOptions()
  end
end

function scrollDown()
  if currentStartIndex + maxVisibleOptions <= #allOptions then
    currentStartIndex = currentStartIndex + maxVisibleOptions
    updateVisibleOptions()
  end
end

function onCategoryChangeMap(comboBox, option,text,data)
  currentOption = option
  loadOptionsFromFile(option)
end

function onSubCategoryChangeMap(comboBox, option,text,data)
  loadFlagsFromFile(option,text)
  createFlagListScrollArea()
end

function saveMap()
  local protocolVersion = g_game.getProtocolVersion()
  if otmm then
    local minimapFile = '/minimap.otmm'
    g_minimap.saveOtmm(minimapFile)
  else
    local minimapFile = '/minimap_' .. protocolVersion .. '.otcm'
    g_map.saveOtcm(minimapFile)
  end
  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  text = 'X: ' .. pos.x .. ' Y: ' .. pos.y .. ' Z: ' .. pos.z
  positionLabel:setText(text)
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
end

function createFlagListScrollArea()
  minimapApoMapList:destroyChildren()
  for _, flagData in ipairs(loadedFlags) do
    local labelWidget = g_ui.createWidget('ApoMapListLabel', minimapApoMapList)
    labelWidget:setText(flagData.description)
  end
  minimapApoMapList:updateScrollBars()
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(true)
    createApoWindow()
  else
    fullmapView = false
    minimapApoWindow:hide()
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWindow:show()
    minimapWidget:setAlternativeWidgetsVisible(false)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function goToCoordinates(description)
  if not minimapApoWindow then return end
  for _, flagData in ipairs(loadedFlags) do
    if flagData.description == description then
      minimapWidget:setCameraPosition(flagData.pos)
      return
    end
  end

  print("Flaga z opisem '" .. description .. "' nie została znaleziona.")
end
