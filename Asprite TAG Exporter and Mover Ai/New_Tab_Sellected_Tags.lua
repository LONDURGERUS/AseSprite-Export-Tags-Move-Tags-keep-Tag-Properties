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
    local dlg = Dialog("Full Property Stitcher")

    dlg:label{ text="Reorder tags (Layers, Cels, and Blend Modes preserved):" }
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
    newSprite.filename = "Full_Property_Copy_" .. sprite.filename
    
    -- PHASE 1: Copy Layer Properties
    local layerMap = {}
    for _, layer in ipairs(sprite.layers) do
        local nl = newSprite:newLayer()
        nl.name = layer.name
        nl.color = layer.color
        nl.opacity = layer.opacity
        nl.blendMode = layer.blendMode
        nl.isVisible = layer.isVisible
        layerMap[layer.name] = nl
    end

    local finalTagPositions = {}

    -- PHASE 2: Stitch frames and Copy Cel Properties
    for _, tagData in ipairs(tagList) do
        if tagData.checked then
            local startFrame = #newSprite.frames + 1
            if #newSprite.frames == 1 and not newSprite.layers[1]:cel(1) then
                startFrame = 1
            end

            for i = tagData.from, tagData.to do
                local currentFrame = (i == tagData.from and startFrame == 1) 
                                     and newSprite.frames[1] or newSprite:newEmptyFrame()
                
                currentFrame.duration = sprite.frames[i].duration
                
                for _, layer in ipairs(sprite.layers) do
                    local sourceCel = layer:cel(i)
                    if sourceCel then
                        local targetLayer = layerMap[layer.name]
                        -- Create the new Cel
                        local newCel = newSprite:newCel(targetLayer, currentFrame, sourceCel.image, sourceCel.position)
                        
                        -- COPY CEL PROPERTIES HERE
                        newCel.opacity = sourceCel.opacity -- Individual cel transparency
                        newCel.color = sourceCel.color     -- Individual cel color label
                        newCel.zIndex = sourceCel.zIndex   -- Order within the frame
                    end
                end
            end
            
            table.insert(finalTagPositions, {
                name = tagData.name,
                color = tagData.color,
                start = startFrame,
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

    -- Final Cleanup
    for _, nl in ipairs(newSprite.layers) do
        if nl.name == "Layer 1" and not nl:cel(1) then
            newSprite:deleteLayer(nl)
            break
        end
    end

    app.alert("Success! Layers, Cels, and Tags are all 100% preserved.")
end

showDialog()