local sprite = app.activeSprite
if not sprite then return app.alert("No active sprite found.") end

-- 1. Initialize the tag list
local tagList = {}
for _, tag in ipairs(sprite.tags) do
    table.insert(tagList, { 
        name = tag.name, 
        color = tag.color,
        checked = true,
        from = tag.fromFrame.frameNumber,
        to = tag.toFrame.frameNumber,
        frameCount = (tag.toFrame.frameNumber - tag.fromFrame.frameNumber) + 1
    })
end

local selectedIndex = 1

function showDialog()
    local dlg = Dialog("Clean Assembly")

    dlg:label{ text="Reorder tags (Empty frames/layers fixed):" }
    dlg:separator()

    for i, tagData in ipairs(tagList) do
        local labelText = string.format("%s (%d f)", tagData.name, tagData.frameCount)
        if i == selectedIndex then labelText = ">> " .. labelText .. " <<" end

        dlg:check{ id="check_" .. i, label=labelText, selected=tagData.checked, 
                   onclick=function() tagData.checked = dlg.data["check_" .. i] end }

        dlg:button{ text="Sel", onclick=function()
            selectedIndex = i
            dlg:close()
            showDialog()
        end }

        if i == selectedIndex then
            dlg:button{ text="▲", onclick=function()
                if i > 1 then
                    table.remove(tagList, i)
                    table.insert(tagList, i-1, tagData)
                    selectedIndex = i - 1
                    dlg:close()
                    showDialog()
                end
            end }
            dlg:button{ text="▼", onclick=function()
                if i < #tagList then
                    table.remove(tagList, i)
                    table.insert(tagList, i+1, tagData)
                    selectedIndex = i + 1
                    dlg:close()
                    showDialog()
                end
            end }
        end
        dlg:newrow()
    end

    dlg:separator()
    dlg:button{ id="ok", text="Create New Tab" }
    dlg:button{ id="cancel", text="Cancel" }

    local data = dlg:show().data
    if data and data.ok then
        assembleSprite()
    end
end

function assembleSprite()
    local newSprite = Sprite(sprite.width, sprite.height, sprite.colorMode)
    newSprite.filename = "Clean_Stitched_" .. sprite.filename
    
    local layerMap = {}

    -- PHASE 1: Recursive Layer Copy
    local function copyLayers(sourceLayers, targetContainer)
        for i = 1, #sourceLayers do
            local layer = sourceLayers[i]
            local nl
            if layer.isGroup then
                nl = newSprite:newGroup()
                nl.parent = targetContainer
                copyLayers(layer.layers, nl) 
            else
                nl = newSprite:newLayer()
                nl.parent = targetContainer
            end
            
            nl.name = layer.name
            nl.color = layer.color
            nl.opacity = layer.opacity
            nl.blendMode = layer.blendMode
            nl.isVisible = layer.isVisible
            nl.isEditable = layer.isEditable
            
            layerMap[layer] = nl
        end
    end

    copyLayers(sprite.layers, newSprite)

    -- CLEANUP DEFAULT LAYER 1: 
    -- We do this BEFORE stitching frames to avoid confusion
    local defaultLayer = newSprite.layers[1]
    if defaultLayer.name == "Layer 1" then
        newSprite:deleteLayer(defaultLayer)
    end

    -- PHASE 2: Assembly
    local finalTagPositions = {}
    local isFirstFrameAdded = false

    for _, tagData in ipairs(tagList) do
        if tagData.checked then
            local startFrameCount = #newSprite.frames
            local tagStartFrame

            for i = tagData.from, tagData.to do
                local currentFrame
                
                -- Handle the very first frame of the sprite
                if not isFirstFrameAdded then
                    currentFrame = newSprite.frames[1]
                    isFirstFrameAdded = true
                else
                    currentFrame = newSprite:newEmptyFrame()
                end
                
                if not tagStartFrame then tagStartFrame = currentFrame.frameNumber end
                currentFrame.duration = sprite.frames[i].duration
                
                for oldLayer, newLayer in pairs(layerMap) do
                    if not oldLayer.isGroup then
                        local sourceCel = oldLayer:cel(i)
                        if sourceCel then
                            local newCel = newSprite:newCel(newLayer, currentFrame, sourceCel.image, sourceCel.position)
                            newCel.opacity = sourceCel.opacity
                            newCel.color = sourceCel.color
                            newCel.zIndex = sourceCel.zIndex
                        end
                    end
                end
            end
            
            table.insert(finalTagPositions, {
                name = tagData.name,
                color = tagData.color,
                start = tagStartFrame,
                stop = #newSprite.frames
            })
        end
    end

    -- PHASE 3: Apply Tags
    for _, pos in ipairs(finalTagPositions) do
        local nTag = newSprite:newTag(pos.start, pos.stop)
        nTag.name = pos.name
        nTag.color = pos.color
    end

    app.alert("New Export Tab Created With Group,Tags,colors!")
end

showDialog()
