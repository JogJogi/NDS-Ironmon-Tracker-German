local function MainScreen(initialSettings, initialTracker, initialProgram)
    local Frame = dofile("ironmon_tracker/ui/UIBaseClasses/Frame.lua")
    local Box = dofile("ironmon_tracker/ui/UIBaseClasses/Box.lua")
    local Component = dofile("ironmon_tracker/ui/UIBaseClasses/Component.lua")
    local TextLabel = dofile("ironmon_tracker/ui/UIBaseClasses/TextLabel.lua")
    local ImageLabel = dofile("ironmon_tracker/ui/UIBaseClasses/ImageLabel.lua")
    local ImageField = dofile("ironmon_tracker/ui/UIBaseClasses/ImageField.lua")
    local TextField = dofile("ironmon_tracker/ui/UIBaseClasses/TextField.lua")
    local TextStyle = dofile("ironmon_tracker/ui/UIBaseClasses/TextStyle.lua")
    local Layout = dofile("ironmon_tracker/ui/UIBaseClasses/Layout.lua")
    local Icon = dofile("ironmon_tracker/ui/UIBaseClasses/Icon.lua")
    local HoverEventListener = dofile("ironmon_tracker/ui/UIBaseClasses/HoverEventListener.lua")
    local MouseClickEventListener = dofile("ironmon_tracker/ui/UIBaseClasses/MouseClickEventListener.lua")
    local FrameCounter = dofile(Paths.FOLDERS.DATA_FOLDER.."/FrameCounter.lua")
    local settings = initialSettings
    local tracker = initialTracker
    local program = initialProgram
    local justChangedHiddenPower = false
    local currentPokemon = nil
    local opposingPokemon = nil
    local badgesEnabled = true
    local defeatedLance = false
    local constants = {
        STAT_PREDICTION_STATES = {"", "+", "_"},
        BADGE_HORIZONTAL_WIDTH = 140,
        BADGE_HORIZONTAL_HEIGHT = 19,
        BADGE_VERTICAL_WIDTH = 19,
        BADGE_VERTICAL_HEIGHT = 131,
        STAT_INFO_HEIGHT = 73,
        HEALS_ACC_EVA_HEIGHT = 52,
        MOVE_HEADER_HEIGHT = 14,
        MOVE_ENTRY_HEIGHT = 10,
        MOVE_Y_START = 97,
        MOVE_FRAME_Y = 94,
        MOVE_INFO_HEIGHT = 46,
        BOTTOM_BOX_HEIGHT = 19,
        POKEMON_INFO_STAT_OFFSET = 10,
        POKEMON_INFO_X_OFFSET = 31,
        POKEMON_INFO_Y_START = 0,
        POKEMON_INFO_WIDTH = 96,
        POKEMON_INFO_HEIGHT = 51,
        STAT_FRAME_HEIGHT = 10
    }
    local eventListeners = {
        abilityHoverListener = nil,
        heldItemHoverListener = nil,
        pokemonHoverListener = nil
    }
    local frameCounters = {}
    local moveEventListeners = {}
    local statPredictionEventListeners = {}
    local ui = {}
    local self = {}
    local activeHoverFrame = nil
    local extraThingsToDraw = {
        moveEffectiveness = {},
        nature = {},
        statStages = {}
    }
    local function onHoverInfoEnd()
        activeHoverFrame = nil
        program.drawCurrentScreens()
    end

    local function setStatPredictionToControl(control, newPrediction)
        if newPrediction == "_" then
            control.setTextOffset({x = 0, y = -5})
        else
            control.setTextOffset({x = 0, y = -1})
        end
        control.setText(newPrediction)
    end

    local function onStatPredictionClick(params)
        local pokemonID = params.pokemonID
        local stat = params.stat
        if pokemonID ~= nil then
            local pokemonStatPredictions = tracker.getStatPredictions(pokemonID)
            local states = constants.STAT_PREDICTION_STATES
            local currentState = pokemonStatPredictions[stat]
            local nextState = (currentState % 3) + 1
            pokemonStatPredictions[stat] = nextState
            tracker.setStatPredictions(pokemonID, pokemonStatPredictions)
            setStatPredictionToControl(ui.controls[stat .. "StatPrediction"], states[nextState])
            program.drawCurrentScreens()
        end
    end

    local function moveHoverFrameToMouse(hoverFrame, alignment)
        local position = Input.getMousePosition()
        MiscUtils.clampFramePosition(alignment, position, ui.frames.mainFrame, hoverFrame.getSize())
        hoverFrame.move(position)
    end

    local function readStatPredictions(pokemonID)
        local pokemonStatPredictions = tracker.getStatPredictions(pokemonID)
        local states = constants.STAT_PREDICTION_STATES
        for stat, predictionState in pairs(pokemonStatPredictions) do
            setStatPredictionToControl(ui.controls[stat .. "StatPrediction"], states[predictionState])
        end
    end

    local function createNote(pokemonID)
        local width, height = 270, 70
        local clientCenter = FormsUtils.getCenter(width, height)
        local charMax = 40
        if pokemonID ~= nil then
            forms.destroyall()
            local noteForm =
                forms.newform(
                width,
                height,
                "Note (" .. charMax .. " char. max)",
                function()
                end
            )
            local textBox = forms.textbox(noteForm, tracker.getNote(pokemonID), 190, 0, nil, 5, 5)
            forms.button(
                textBox,
                "Set",
                function()
                    tracker.setNote(pokemonID, forms.gettext(textBox))
                    program.drawCurrentScreens()
                    forms.destroy(noteForm)
                end,
                200,
                4,
                48,
                22
            )
            forms.setlocation(noteForm, clientCenter.xPos, clientCenter.yPos)
            forms.setproperty(textBox,"TabStop", true)
        end
    end

    local function onPokemonImageHover(params)
        local pokemonHoverFrame = HoverFrameFactory.createTypeDefensesFrame(params)
        activeHoverFrame = pokemonHoverFrame
        program.drawCurrentScreens()
        pokemonHoverFrame.show()
    end

    local function onItemBagInfoHover(params)
        local items = params.items
        local itemType = params.itemType
        if items == nil or next(items) == nil then
            local hoverFrame =
                HoverFrameFactory.createHoverTextFrame(
                "Top box background color",
                "Top box border color",
                "You currently do not have any " .. itemType:lower() .. " items.",
                "Top box text color",
                114
            )
            moveHoverFrameToMouse(hoverFrame, Graphics.HOVER_ALIGNMENT_TYPE.ALIGN_ABOVE)
            activeHoverFrame = hoverFrame
            program.drawCurrentScreens()
            hoverFrame.show()
        else
            if ui.frames.healFrame.isVisible() then
                local itemsHoverFrame = HoverFrameFactory.createItemBagHoverFrame(items, ui.frames.mainFrame, itemType)
                activeHoverFrame = itemsHoverFrame
                program.drawCurrentScreens()
                itemsHoverFrame.show()
            end
        end
    end

    local function onMoveHeaderHover(params)
        if params.pokemon ~= nil then
            local movelvls = params.pokemon.movelvls
            local moveHeaderHoverFrame
            if #movelvls == 0 then
                moveHeaderHoverFrame =
                    HoverFrameFactory.createHoverTextFrame(
                    "Bottom box background color",
                    "Bottom box border color",
                    "This Pok\233mon does not learn any moves.",
                    "Bottom box text color",
                    126
                )
                moveHoverFrameToMouse(
                    moveHeaderHoverFrame,
                    Graphics.HOVER_ALIGNMENT_TYPE.ALIGN_ABOVE,
                    moveHeaderHoverFrame.getSize()
                )
            else
                moveHeaderHoverFrame = HoverFrameFactory.createMoveLevelsHoverFrame(params.pokemon, params.mainFrame)
            end
            activeHoverFrame = moveHeaderHoverFrame
            program.drawCurrentScreens()
            activeHoverFrame.show()
        end
    end

    local function onHoverInfo(hoverParams)
        local BGColorKey = hoverParams.BGColorKey
        local BGColorFillKey = hoverParams.BGColorFillKey
        local textColorKey = hoverParams.textColorKey
        local text = hoverParams.text
        if text ~= "" then
            local width = hoverParams.width
            local alignment = hoverParams.alignment
            local hoverFrame =
                HoverFrameFactory.createHoverTextFrame(BGColorKey, BGColorFillKey, text, textColorKey, width)
            moveHoverFrameToMouse(hoverFrame, alignment)
            program.drawCurrentScreens()
            hoverFrame.show()
            activeHoverFrame = hoverFrame
        end
    end

    local function onHiddenPowerFrameCounter()
        frameCounters["hiddenPowerCounter"] = nil
        justChangedHiddenPower = false
        program.drawCurrentScreens()
    end

    local function onChangeHiddenPower(direction)
        if direction == "forward" then
            tracker.increaseHiddenPowerType()
        else
            tracker.decreaseHiddenPowerType()
        end
        local baseWait = 90
        local clientFrameRate = client.get_approx_framerate()
        if clientFrameRate ~= nil and clientFrameRate > 60 then
            baseWait = math.floor(baseWait * (clientFrameRate/90))
        end
        frameCounters["hiddenPowerCounter"] = FrameCounter(baseWait, onHiddenPowerFrameCounter)
        justChangedHiddenPower = true
        program.drawCurrentScreens()
    end

    local function initHiddenPowerArrows()
        local leftArrow = TextLabel(
            Component(ui.frames.hiddenPowerArrowsFrame, Box({x = 0, y = 0}, {width = 7, height = 7}, nil, nil, nil)),
            TextField(
                "<",
                {x = 0, y = 0},
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        local rightArrow = TextLabel(
            Component(ui.frames.hiddenPowerArrowsFrame, Box({x = 0, y = 0}, {width = 7, height = 7}, nil, nil, nil)),
            TextField(
                ">",
                {x = 0, y = 0},
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        table.insert(eventListeners,MouseClickEventListener(leftArrow,onChangeHiddenPower,"backward"))
        table.insert(eventListeners,MouseClickEventListener(rightArrow,onChangeHiddenPower, "forward"))
    end

    local function initMainFrames()
        ui.frames.hiddenPowerArrowsFrame =
            Frame(
            Box(
                {x = 0, y = 0},
                {width = 0, height = 0},
                nil,
                nil
            ),
            Layout(
                Graphics.ALIGNMENT_TYPE.HORIZONTAL,
                0,
                {x = 0, y = 1}
            ),
            nil
        )
        ui.frames.mainFrame =
            Frame(
            Box(
                {x = Graphics.SIZES.SCREEN_WIDTH, y = 0},
                {width = Graphics.SIZES.MAIN_SCREEN_WIDTH, height = Graphics.SIZES.MAIN_SCREEN_HEIGHT},
                "Main background color",
                nil
            ),
            Layout(
                Graphics.ALIGNMENT_TYPE.HORIZONTAL,
                5,
                {x = Graphics.SIZES.BORDER_MARGIN, y = Graphics.SIZES.BORDER_MARGIN}
            ),
            nil
        )

        ui.frames.mainInnerFrame =
            Frame(
            Box(
                {x = Graphics.SIZES.BORDER_MARGIN, y = Graphics.SIZES.BORDER_MARGIN},
                {
                    width = Graphics.SIZES.MAIN_SCREEN_WIDTH - 2 * Graphics.SIZES.BORDER_MARGIN,
                    height = Graphics.SIZES.MAIN_SCREEN_HEIGHT - 2 * Graphics.SIZES.BORDER_MARGIN
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL),
            ui.frames.mainFrame
        )

        ui.frames.topHalfFrame =
            Frame(
            Box(
                {x = 0, y = 0},
                {
                    width = Graphics.SIZES.MAIN_SCREEN_WIDTH - 2 * Graphics.SIZES.BORDER_MARGIN,
                    height = constants.STAT_INFO_HEIGHT - 1
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL),
            ui.frames.mainInnerFrame
        )

        ui.frames.topLeftFrame =
            Frame(
            Box(
                {x = 0, y = 0},
                {width = constants.POKEMON_INFO_WIDTH, height = constants.STAT_INFO_HEIGHT},
                "Top box background color",
                "Top box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL),
            ui.frames.topHalfFrame
        )
        ui.frames.mainPokemonInfoFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_WIDTH,
                    height = constants.POKEMON_INFO_HEIGHT
                },
                "Top box background color",
                "Top box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL),
            ui.frames.topLeftFrame
        )
        ui.frames.pokemonImageTypeFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_X_OFFSET,
                    height = constants.POKEMON_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL),
            ui.frames.mainPokemonInfoFrame
        )
        ui.frames.pokemonInfoFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_X_OFFSET,
                    height = constants.POKEMON_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL),
            ui.frames.mainPokemonInfoFrame
        )
        ui.frames.pokemonNameGearFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_X_OFFSET,
                    height = 10
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL),
            ui.frames.pokemonInfoFrame
        )
        ui.frames.miscInfoFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_WIDTH,
                    height = constants.STAT_INFO_HEIGHT - constants.POKEMON_INFO_HEIGHT
                },
                "Top box background color",
                "Top box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0),
            ui.frames.topLeftFrame
        )
        ui.frames.healFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_WIDTH - 26,
                    height = constants.STAT_INFO_HEIGHT - constants.POKEMON_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 0, {x = 0, y = 1}),
            ui.frames.miscInfoFrame
        )
        ui.frames.enemyNoteFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_WIDTH - 26,
                    height = constants.STAT_INFO_HEIGHT - constants.POKEMON_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0, {x = 4, y = 3}),
            ui.frames.miscInfoFrame,
            false
        )
        ui.frames.accEvaFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = 30,
                    height = constants.STAT_INFO_HEIGHT - constants.POKEMON_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL),
            ui.frames.miscInfoFrame,
            false
        )
        ui.frames.statFrame =
            Frame(
            Box(
                {
                    x = constants.POKEMON_INFO_WIDTH,
                    y = 0
                },
                {
                    width = Graphics.SIZES.MAIN_SCREEN_WIDTH - constants.POKEMON_INFO_WIDTH -
                        2 * Graphics.SIZES.BORDER_MARGIN,
                    height = constants.STAT_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 0, {x = 0, y = 0}),
            ui.frames.topHalfFrame
        )
        ui.frames.mainStatsFrame =
            Frame(
            Box(
                {
                    x = constants.POKEMON_INFO_WIDTH,
                    y = 0
                },
                {
                    width = Graphics.SIZES.MAIN_SCREEN_WIDTH - constants.POKEMON_INFO_WIDTH -
                        2 * Graphics.SIZES.BORDER_MARGIN,
                    height = constants.STAT_INFO_HEIGHT - 11
                },
                "Top box background color",
                "Top box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 0, {x = 0, y = 2}),
            ui.frames.statFrame
        )
        ui.frames.moveHeaderFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = 80,
                    height = constants.MOVE_HEADER_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0, {x = 3, y = 3}),
            ui.frames.mainInnerFrame
        )
        ui.frames.moveInfoFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = Graphics.SIZES.MAIN_SCREEN_WIDTH - 2 * Graphics.SIZES.BORDER_MARGIN,
                    height = constants.MOVE_INFO_HEIGHT - 0.5
                },
                "Bottom box background color",
                "Bottom box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL),
            ui.frames.mainInnerFrame
        )
        ui.frames.badgeFrame1 =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.BADGE_HORIZONTAL_WIDTH,
                    height = constants.BOTTOM_BOX_HEIGHT
                },
                "Bottom box background color",
                "Bottom box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 1, {x = 3, y = 2}),
            ui.frames.mainFrame
        )
        ui.frames.badgeFrame2 =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.BADGE_HORIZONTAL_WIDTH,
                    height = constants.BOTTOM_BOX_HEIGHT
                },
                "Bottom box background color",
                "Bottom box border color"
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 1, {x = 3, y = 2}),
            ui.frames.mainFrame
        )
    end

    local function initStatControls()
        local stats = {"HP", "ATK", "DEF", "SPA", "SPD", "SPE"}
        for _, stat in pairs(stats) do
            local frameName = stat .. "Frame"
            ui.frames[frameName] =
                Frame(
                Box(
                    {x = 0, y = 0},
                    {
                        width = 45,
                        height = 10
                    },
                    nil,
                    nil,
                    nil
                ),
                Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0, {x = 1, y = 0}),
                ui.frames.mainStatsFrame
            )
            local labelName = stat .. "StatName"
            ui.controls[labelName] =
                TextLabel(
                Component(ui.frames[frameName], Box({x = 0, y = 0}, {width = 25, height = 10}, nil, nil, nil)),
                TextField(
                    stat,
                    {x = 0, y = -2},
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Top box text color",
                        "Top box background color"
                    )
                )
            )
            local numberLabelName = stat .. "StatNumber"
            ui.controls[numberLabelName] =
                TextLabel(
                Component(ui.frames[frameName], Box({x = 0, y = 0}, {width = 0, height = 0}, nil, nil, nil)),
                TextField(
                    "-1",
                    {x = 0, y = -2},
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Top box text color",
                        "Top box background color"
                    ),
                    true
                ),
                nil
            )
            local predictionLabel = stat .. "StatPrediction"
            ui.controls[predictionLabel] =
                TextLabel(
                Component(
                    ui.frames[frameName],
                    Box(
                        {x = 0, y = 0},
                        {width = 8, height = 8},
                        "Top box background color",
                        "Top box border color",
                        true,
                        "Top box background color"
                    )
                ),
                TextField(
                    "",
                    {x = 0, y = -1},
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Top box text color",
                        "Top box background color"
                    )
                ),
                nil,
                false
            )
            statPredictionEventListeners[stat] =
                MouseClickEventListener(
                ui.controls[predictionLabel],
                onStatPredictionClick,
                {stat = stat, pokemonID = nil}
            )
        end
        ui.frames.BSTFrame =
            Frame(
            Box(
                {x = 0, y = 0},
                {
                    width = 44,
                    height = 11
                },
                "Top box background color",
                "Top box border color",
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0, {x = 1, y = 0}),
            ui.frames.statFrame
        )
        ui.controls.BST =
            TextLabel(
            Component(ui.frames.BSTFrame, Box({x = 0, y = 0}, {width = 25, height = 10}, nil, nil)),
            TextField(
                "BST",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.BSTNumber =
            TextLabel(
            Component(ui.frames.BSTFrame, Box({x = 0, y = 0}, {width = 25, height = 10}, nil, nil)),
            TextField(
                "720",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                ),
                true
            )
        )
    end

    local function initPokemonInfoControls()
        ui.controls.pokemonImageLabel =
            ImageLabel(
            Component(ui.frames.pokemonImageTypeFrame, Box({x = 0, y = 0}, {width = 30, height = 28}, nil, nil)),
            ImageField("ironmon_tracker/images/pokemonIcons/1.png", {x = 0, y = -5}, nil)
        )
        ui.controls.pokemonType1 =
            ImageLabel(
            Component(ui.frames.pokemonImageTypeFrame, Box({x = 0, y = 0}, {width = 0, height = 12}, nil, nil)),
            ImageField("", {x = 1, y = 0}, {width = 30, height = 12})
        )
        ui.controls.pokemonType2 =
            ImageLabel(
            Component(ui.frames.pokemonImageTypeFrame, Box({x = 0, y = 0}, {width = 0, height = 14}, nil, nil)),
            ImageField("", {x = 1, y = 0}, {width = 30, height = 12})
        )
        ui.controls.pokemonNameLabel =
            TextLabel(
            Component(ui.frames.pokemonNameGearFrame, Box({x = 0, y = 0}, {width = 56, height = 10}, nil, nil)),
            TextField(
                "Gorebyss",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.gearIcon =
            Icon(
            Component(ui.frames.pokemonNameGearFrame, Box({x = 0, y = 0}, {width = 8, height = 8}, nil, nil)),
            "GEAR",
            {x = 0, y = 2}
        )
        ui.controls.pokemonLevelAndEvo =
            TextLabel(
            Component(
                ui.frames.pokemonInfoFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 10, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "Lv. 7 (--)",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.pokemonHP =
            TextLabel(
            Component(
                ui.frames.pokemonInfoFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 10, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "HP: 29/29",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.heldItem =
            TextLabel(
            Component(
                ui.frames.pokemonInfoFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 64, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "---",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Intermediate text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.abilityDetails =
            TextLabel(
            Component(
                ui.frames.pokemonInfoFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 64, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "Honey Gather",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Intermediate text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.moveHeaderLearnedText =
            TextLabel(
            Component(
                ui.frames.moveHeaderFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 79, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "Moves: 0/0 (0)",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Move header text color",
                    "Main background color"
                )
            )
        )
        ui.controls.moveHeaderPP =
            TextLabel(
            Component(
                ui.frames.moveHeaderFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 17, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "PP",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Move header text color",
                    "Main background color"
                )
            )
        )
        ui.controls.moveHeaderPow =
            TextLabel(
            Component(
                ui.frames.moveHeaderFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 24, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "Pow",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Move header text color",
                    "Main background color"
                )
            )
        )
        ui.controls.moveHeaderAcc =
            TextLabel(
            Component(
                ui.frames.moveHeaderFrame,
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {width = 25, height = 10},
                    nil,
                    nil
                )
            ),
            TextField(
                "Acc",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Move header text color",
                    "Main background color"
                )
            )
        )
        --]]
    end

    local function initMoveInfo()
        ui.moveInfoFrames = {}
        for i = 1, 4, 1 do
            local moveInfoFrame = {}
            local frameName = "move" .. i .. "Frame"
            local nameIconFrameName = "move" .. i .. "NameIconFrame"
            local PPPowAccFrameName = "move" .. i .. "PPPowAccFrame"
            ui.frames[frameName] =
                Frame(
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {
                        width = Graphics.SIZES.MAIN_SCREEN_WIDTH - 2 * Graphics.SIZES.BORDER_MARGIN,
                        height = constants.MOVE_ENTRY_HEIGHT
                    },
                    nil,
                    nil
                ),
                Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0, {x = 1, y = 2}),
                ui.frames.moveInfoFrame
            )
            ui.frames[nameIconFrameName] =
                Frame(
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {
                        width = 80,
                        height = constants.MOVE_ENTRY_HEIGHT
                    },
                    nil,
                    nil
                ),
                Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL),
                ui.frames[frameName]
            )
            ui.frames[PPPowAccFrameName] =
                Frame(
                Box(
                    {
                        x = 0,
                        y = 0
                    },
                    {
                        width = 50,
                        height = constants.MOVE_ENTRY_HEIGHT
                    },
                    nil,
                    nil
                ),
                Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL),
                ui.frames[frameName]
            )
            moveInfoFrame.categoryIcon =
                Icon(
                Component(
                    ui.frames[nameIconFrameName],
                    Box(
                        {
                            x = 0,
                            y = 0
                        },
                        {width = 8, height = 10},
                        nil,
                        nil
                    )
                ),
                "PHYSICAL",
                {x = 1, y = 2}
            )
            moveInfoFrame.moveTypeIcon =
                Icon(
                Component(
                    ui.frames[nameIconFrameName],
                    Box(
                        {
                            x = 0,
                            y = 0
                        },
                        {width = 9, height = 10},
                        nil,
                        nil
                    )
                ),
                "DRAGON",
                {x = 1, y = 2}
            )
            moveInfoFrame.moveNameLabel =
                TextLabel(
                Component(
                    ui.frames[nameIconFrameName],
                    Box(
                        {
                            x = 0,
                            y = 0
                        },
                        {width = 70, height = 8},
                        nil,
                        nil
                    )
                ),
                TextField(
                    "Tail Whip",
                    Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Bottom box text color",
                        "Bottom box background color"
                    )
                ),
                "Bottom"
            )
            moveInfoFrame.PPLabel =
                TextLabel(
                Component(
                    ui.frames[PPPowAccFrameName],
                    Box(
                        {
                            x = 0,
                            y = 0
                        },
                        {width = 18, height = 10},
                        nil,
                        nil
                    )
                ),
                TextField(
                    "-1",
                    Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Bottom box text color",
                        "Bottom box background color"
                    ),
                    true,
                    2
                )
            )
            moveInfoFrame.powLabel =
                TextLabel(
                Component(
                    ui.frames[PPPowAccFrameName],
                    Box(
                        {
                            x = 0,
                            y = 0
                        },
                        {width = 22, height = 10},
                        nil,
                        nil
                    )
                ),
                TextField(
                    "-1",
                    Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Bottom box text color",
                        "Bottom box background color"
                    ),
                    true
                )
            )
            moveInfoFrame.accLabel =
                TextLabel(
                Component(
                    ui.frames[PPPowAccFrameName],
                    Box(
                        {
                            x = 0,
                            y = 0
                        },
                        {width = 10, height = 10},
                        nil,
                        nil
                    ),
                    true
                ),
                TextField(
                    "-1",
                    Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Bottom box text color",
                        "Bottom box background color"
                    ),
                    true
                )
            )
            table.insert(ui.moveInfoFrames, moveInfoFrame)
        end
    end

    local function initBadgeControls()
        ui.badgeControlsSet1 = {}
        ui.badgeControlsSet2 = {}
        local prefix = program.getGameInfo().BADGE_PREFIX
        for i = 1, 8, 1 do
            local badgeControl =
                ImageLabel(
                Component(ui.frames.badgeFrame1, Box({x = 0, y = 0}, {width = 16.3, height = 16}, nil, nil)),
                ImageField("ironmon_tracker/images/icons/" .. prefix .. "_badge" .. i .. "_OFF.png", {x = -1, y = 0})
            )
            table.insert(ui.badgeControlsSet1, badgeControl)
        end
        if program.getGameInfo().GEN == 4 then
            for i = 1, 8, 1 do
                local badgeControl =
                    ImageLabel(
                    Component(ui.frames.badgeFrame2, Box({x = 0, y = 0}, {width = 16.3, height = 16}, nil, nil)),
                    ImageField("ironmon_tracker/images/icons/HGSS_K_badge" .. i .. "_OFF.png", {x = -1, y = 0})
                )
                table.insert(ui.badgeControlsSet2, badgeControl)
            end
        end
    end

    local function initMiscControls()
        ui.controls.healsLabel =
            TextLabel(
            Component(ui.frames.healFrame, Box({x = 0, y = 0}, {width = 80, height = 9}, nil, nil)),
            TextField(
                "Heals in bag:",
                {x = 1, y = 0},
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        --[[
        ui.frames.healsBottom = Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = 0,
                    height = 0
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL),
            ui.frames.healFrame
     
        ui.controls.potionIcon = Icon(
            Component(ui.frames.healsBottom, Box({x = 0, y = 0}, {width = 10, height = 16}, nil, nil)),
            "HP_HEALS_ICON",
            {x = 2, y = 0}
        )
        ui.controls.statusIcon = Icon(
            Component(ui.frames.healsBottom, Box({x = 0, y = 0}, {width = 11, height = 16}, nil, nil)),
            "STATUS_HEALS_ICON",
            {x = 2, y = 0}
        )--]]
        ui.controls.statusItemsLabel =
            TextLabel(
            Component(ui.frames.healFrame, Box({x = 0, y = 0}, {width = 68, height = 10}, nil, nil)),
            TextField(
                "this is a test",
                {x = 1, y = 0},
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        --]]
        ui.controls.accLabel =
            TextLabel(
            Component(ui.frames.accEvaFrame, Box({x = 0, y = 0}, {width = 10, height = 10}, nil, nil)),
            TextField(
                "ACC",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.evaLabel =
            TextLabel(
            Component(ui.frames.accEvaFrame, Box({x = 0, y = 0}, {width = 10, height = 10}, nil, nil)),
            TextField(
                "EVA",
                Graphics.SIZES.DEFAULT_TEXT_OFFSET,
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.controls.noteIcon =
            Icon(
            Component(ui.frames.enemyNoteFrame, Box({x = 0, y = 0}, {width = 12, height = 16}, nil, nil)),
            "NOTE_TOP",
            {x = 0, y = 2}
        )
        ui.controls.mainNoteLabel =
            TextLabel(
            Component(ui.frames.enemyNoteFrame, Box({x = 0, y = 0}, {width = 0, height = 8}, nil, nil)),
            TextField(
                "",
                {x = 1, y = 2},
                TextStyle(
                    Graphics.FONT.DEFAULT_FONT_SIZE,
                    Graphics.FONT.DEFAULT_FONT_FAMILY,
                    "Top box text color",
                    "Top box background color"
                )
            )
        )
        ui.frames.noteLabelsFrame =
            Frame(
            Box(
                {
                    x = 0,
                    y = 0
                },
                {
                    width = constants.POKEMON_INFO_WIDTH - 26,
                    height = constants.STAT_INFO_HEIGHT - constants.POKEMON_INFO_HEIGHT
                },
                nil,
                nil
            ),
            Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 1, {x = 0, y = -2}),
            ui.frames.enemyNoteFrame
        )
        ui.controls.noteLabels = {}
        for i = 1, 2, 1 do
            ui.controls.noteLabels[i] =
                TextLabel(
                Component(ui.frames.noteLabelsFrame, Box({x = 0, y = 0}, {width = 0, height = 8}, nil, nil)),
                TextField(
                    "",
                    {x = 1, y = 0},
                    TextStyle(
                        Graphics.FONT.DEFAULT_FONT_SIZE,
                        Graphics.FONT.DEFAULT_FONT_FAMILY,
                        "Top box text color",
                        "Top box background color"
                    )
                )
            )
        end
    end

    local function initUI()
        ui.controls = {}
        ui.frames = {}
        ui.mainFrame = nil
        initMainFrames()
        initMoveInfo()
        initPokemonInfoControls()
        initStatControls()
        initBadgeControls()
        initMiscControls()
        initHiddenPowerArrows()
    end

    local function setUpStatStages(pokemon)
        if pokemon.statStages ~= nil then
            extraThingsToDraw.statStages = {}
            for statName, statStage in pairs(pokemon.statStages) do
                if statName ~= "ACC" and statName ~= "EVA" then
                    local namePosition = ui.controls[statName .. "StatName"].getPosition()
                    local chevronPosition = {x = namePosition.x + 20, y = namePosition.y + 5}
                    extraThingsToDraw.statStages[statName] = {stage = statStage, position = chevronPosition}
                end
            end
        end
    end

    local function setUpMoveEffectiveness(moveIDs, defendingPokemon)
        extraThingsToDraw.moveEffectiveness = {}
        if settings.battle.SHOW_MOVE_EFFECTIVENESS then
            for i, moveID in pairs(moveIDs) do
                local moveFrame = ui.moveInfoFrames[i]
                local PPLabelPosition = moveFrame.PPLabel.getPosition()
                local chevronPosition = {x = PPLabelPosition.x + 14, y = PPLabelPosition.y + 3}
                local moveData = MoveData.MOVES[moveID + 1]
                local moveEffectiveness = MoveUtils.netEffectiveness(moveData, defendingPokemon)
                table.insert(
                    extraThingsToDraw.moveEffectiveness,
                    {position = chevronPosition, effectiveness = moveEffectiveness}
                )
            end
        end
    end

    local function drawExtraStuff()
        if extraThingsToDraw.statStages ~= nil then
            for _, statStageInfo in pairs(extraThingsToDraw.statStages) do
                DrawingUtils.drawStatStageChevrons(statStageInfo.position, statStageInfo.stage)
            end
        end
        if extraThingsToDraw.moveEffectiveness ~= nil then
            for _, entry in pairs(extraThingsToDraw.moveEffectiveness) do
                DrawingUtils.drawMoveEffectiveness(entry.position, entry.effectiveness)
            end
        end
        if extraThingsToDraw.nature ~= nil then
            for _, entry in pairs(extraThingsToDraw.nature) do
                DrawingUtils.drawNaturePlusMinus(entry.position, entry.affect)
            end
        end
    end

    local function checkForVariableMoves(pokemon, isEnemy, opposingPokemon, moveIDs, movePPs)
        local lowHPCalcEntry = {
            requirement = not isEnemy,
            calcFunction = function()
                return MoveUtils.calculateLowHPBasedDamage(pokemon.curHP, pokemon.stats.HP)
            end
        }
        local highHPCalcEntry = {
            requirement = not isEnemy,
            calcFunction = function()
                return MoveUtils.calculateHighHPBasedDamage(pokemon.curHP, pokemon.stats.HP)
            end
        }
        local weightBasedEntry = {
            requirement = program.isInBattle() and opposingPokemon ~= nil,
            calcFunction = function()
                return MoveUtils.calculateWeightBasedDamage(opposingPokemon.weight)
            end
        }
        local weightDifferenceEntry = {
            requirement = program.isInBattle() and opposingPokemon ~= nil,
            calcFunction = function()
                return MoveUtils.calculateWeightDifferenceDamage(pokemon, opposingPokemon)
            end
        }
        local moveNamesToCalcFunctions = {
            ["Flail"] = lowHPCalcEntry,
            ["Reversal"] = lowHPCalcEntry,
            ["Water Spout"] = highHPCalcEntry,
            ["Eruption"] = highHPCalcEntry,
            ["Trump Card"] = {
                requirement = true,
                calcFunction = function(movePP)
                    return MoveUtils.calculateTrumpCardPower(movePP)
                end
            },
            ["Heat Crash"] = weightDifferenceEntry,
            ["Heavy Slam"] = weightDifferenceEntry,
            ["Punishment"] = {
                requirement = (not isEnemy) and program.isInBattle() and opposingPokemon ~= nil,
                calcFunction = function()
                    return MoveUtils.calculatePunishmentPower(opposingPokemon)
                end
            },
            ["Grass Knot"] = weightBasedEntry,
            ["Low Kick"] = weightBasedEntry
        }
        if settings.battle.CALCULATE_VARIABLE_DAMAGE then
            for i, moveID in pairs(moveIDs) do
                local name = MoveData.MOVES[moveID + 1].name
                local moveFrame = ui.moveInfoFrames[i]
                local entry = moveNamesToCalcFunctions[name]
                if entry then
                    if name ~= "Trump Card" then
                        if entry.requirement then
                            moveFrame.powLabel.setText(entry.calcFunction())
                        end
                    else
                        moveFrame.powLabel.setText(entry.calcFunction(movePPs[i]))
                    end
                end
            end
        end
    end

    local function setUpMoves(pokemon, isEnemy, opposingPokemon)
        local movesHeader = MoveUtils.getMoveHeader(pokemon)
        ui.controls.moveHeaderLearnedText.setText(movesHeader)
        ui.frames.hiddenPowerArrowsFrame.setVisibility(false)
        local moveIDs = pokemon.moveIDs
        local movePPs = {}
        if isEnemy then
            moveIDs = {}
            local moves = tracker.getMoves(pokemon.pokemonID)
            for i, move in pairs(moves) do
                moveIDs[i] = move.move
                movePPs[i] = MoveData.MOVES[move.move + 1].pp
            end
            if settings.battle.SHOW_ACTUAL_ENEMY_PP then
                for i, move in pairs(moveIDs) do
                    for j, compare in pairs(pokemon.moveIDs) do
                        if move == compare then
                            movePPs[i] = pokemon.movePPs[j]
                            if move == 0 then
                                movePPs[i] = Graphics.TEXT.NO_PP
                            end
                        end
                    end
                end
            end
        else
            for i, moveID in pairs(moveIDs) do
                if moveID == 0 then
                    movePPs[i] = Graphics.TEXT.NO_PP
                else
                    movePPs[i] = pokemon.movePPs[i]
                end
            end
        end
        if opposingPokemon ~= nil then
            setUpMoveEffectiveness(moveIDs, opposingPokemon)
        end
        for i, moveID in pairs(moveIDs) do
            local moveData = MoveData.MOVES[moveID + 1]
            local moveFrame = ui.moveInfoFrames[i]
            local movePP = movePPs[i]
            moveFrame.categoryIcon.setIconName(moveData.category)
            if settings.colorSettings["Color move names by type"] then
                moveFrame.moveNameLabel.setTextColorKey(moveData.type)
                if moveData.name == "Hidden Power" then
                    moveFrame.moveNameLabel.setTextColorKey(tracker.getCurrentHiddenPowerType())
                end
            else
                moveFrame.moveNameLabel.setTextColorKey("Bottom box text color")
            end
            moveFrame.moveTypeIcon.setIconName(moveData.type)
            moveFrame.moveTypeIcon.setVisibility(settings.colorSettings["Draw move type icons"])
            moveFrame.categoryIcon.setVisibility(settings.colorSettings["Show phys/spec move icons"])
            local moveNameText = moveData.name
            if justChangedHiddenPower and moveData.name == "Hidden Power" then
                print("yes")
                local hiddenPowerType = tracker:getCurrentHiddenPowerType()
                moveNameText = hiddenPowerType:sub(1,1)..hiddenPowerType:sub(2):lower()
            end
            if isEnemy then
                local stars = MoveUtils.getStars(pokemon)
                moveNameText = moveNameText .. stars[i]
            end
            moveFrame.moveNameLabel.setText(moveNameText)
            moveFrame.moveNameLabel.resize({width = 70,height = 8})
            if moveData.name == "Hidden Power" then
                moveFrame.moveNameLabel.resize({width = 55,height = 8})
                local frame = ui.frames["move" .. i .. "NameIconFrame"]
                ui.frames.hiddenPowerArrowsFrame.changeParentFrame(frame,4)
                ui.frames.hiddenPowerArrowsFrame.setVisibility(true)
            end
            moveFrame.PPLabel.setText(movePP)
            moveFrame.powLabel.setTextColorKey("Bottom box text color")
            if MoveUtils.isSTAB(moveData, pokemon) and program.isInBattle() then
                moveFrame.powLabel.setTextColorKey("Positive text color")
            end
            moveFrame.powLabel.setText(moveData.power)
            moveFrame.accLabel.setText(moveData.accuracy)
            local listener = moveEventListeners[i]
            local params = listener.getOnHoverParams()
            params.text = moveData.description
        end
        checkForVariableMoves(pokemon, isEnemy, opposingPokemon, moveIDs, movePPs)
    end

    local function setEnemySpecificControls(pokemon)
        local abilityHoverParams = eventListeners.abilityHoverListener.getOnHoverParams()
        local itemHoverParams = eventListeners.heldItemHoverListener.getOnHoverParams()
        readStatPredictions(pokemon.pokemonID)
        ui.controls.pokemonHP.setText("HP: ?/?")
        abilityHoverParams.text = ""
        itemHoverParams.text = ""
        eventListeners.noteIconListener.setOnClickParams(pokemon.pokemonID)
        local note = tracker.getNote(pokemon.pokemonID)
        local lines = DrawingUtils.textToWrappedArray(note, 74)
        ui.controls.mainNoteLabel.setText(lines[1])
        ui.controls.mainNoteLabel.setVisibility(#lines == 1)
        for i = 1, 2, 1 do
            ui.controls.noteLabels[i].setVisibility(#lines > 1)
            if #lines > 1 and DrawingUtils.calculateWordPixelLength(lines[i]) <= 80 then
                ui.controls.noteLabels[i].setText(lines[i])
            end
        end
        ui.controls.heldItem.setText("Total seen: " .. tracker.getAmountSeen(pokemon.pokemonID))
        ui.controls.abilityDetails.setText("Last level: " .. tracker.getLastLevelSeen(pokemon.pokemonID))
        ui.controls.healsLabel.setText("")
        ui.controls.statusItemsLabel.setText("")
    end

    local function setUpStats(pokemon, isEnemy)
        ui.controls.BSTNumber.setText(pokemon.bst)
        extraThingsToDraw.nature = {}
        for statName, stat in pairs(pokemon.stats) do
            ui.controls[statName .. "StatName"].setTextColorKey("Top box text color")
            ui.controls[statName .. "StatNumber"].setVisibility(not isEnemy)
            ui.controls[statName .. "StatPrediction"].setVisibility(isEnemy)
            if isEnemy then
                ui.controls[statName .. "StatName"].resize({width = 30, height = 10})
                statPredictionEventListeners[statName].setOnClickParams(
                    {["stat"] = statName, pokemonID = pokemon.pokemonID}
                )
            else
                ui.controls[statName .. "StatName"].resize({width = 25, height = 10})
                ui.controls[statName .. "StatNumber"].setText(stat)
                local color = DrawingUtils.getNatureColor(statName, pokemon.nature)
                local namePosition = ui.controls[statName .. "StatName"].getPosition()
                local naturePosition = {
                    x = namePosition.x + 16,
                    y = namePosition.y - 4
                }
                if color == "Positive text color" then
                    table.insert(
                        extraThingsToDraw.nature,
                        {
                            position = naturePosition,
                            affect = "plus"
                        }
                    )
                elseif color == "Negative text color" then
                    table.insert(
                        extraThingsToDraw.nature,
                        {
                            position = naturePosition,
                            affect = "minus"
                        }
                    )
                end
                ui.controls[statName .. "StatName"].setTextColorKey(
                    DrawingUtils.getNatureColor(statName, pokemon.nature)
                )
            end
        end
    end

    local function setUpPokemonImage(pokemon)
        if pokemon.alternateForm == 0x00 then
            ui.controls.pokemonImageLabel.setPath("ironmon_tracker/images/pokemonIcons/" .. pokemon.pokemonID .. ".png")
        else
            if PokemonData.ALTERNATE_FORMS[pokemon.baseForm.name] then
                local index = pokemon.alternateForm / 8
                local baseName = pokemon.baseForm.name
                local path = "ironmon_tracker/images/pokemonIcons/alternateForms/" .. baseName .. "/" .. index .. ".png"
                ui.controls.pokemonImageLabel.setPath(path)
            end
        end
    end

    local function clearExtraThingsToDraw()
        extraThingsToDraw = {
            moveEffectiveness = {},
            nature = {},
            statStages = {}
        }
    end

    local function readPokemonIntoUI()
        ui.frames.mainFrame.recalculateChildPositions()
        local pokemon = currentPokemon
        local isEnemy = pokemon.owner == program.SELECTED_PLAYERS.ENEMY
        local heldItemInfo = ItemData.GEN_5_ITEMS[pokemon.heldItem]

        ui.controls.pokemonNameLabel.setText(pokemon.name)
        setUpPokemonImage(pokemon)
        local pokemonHoverParams = eventListeners.pokemonHoverListener.getOnHoverParams()
        pokemonHoverParams.pokemon = pokemon
        local evo = pokemon.evolution
        if evo == PokemonData.EVOLUTION_TYPES.FRIEND and pokemon.friendship >= 220 then
            evo = "SOON"
        end
        ui.controls.pokemonLevelAndEvo.setText("Lv. " .. pokemon.level .. " (" .. pokemon.evolution .. ")")
        ui.controls.pokemonHP.setText("HP: " .. pokemon.curHP .. "/" .. pokemon.HP)
        local abilityName = AbilityData.ABILITIES[pokemon.ability + 1].name
        ui.controls.abilityDetails.setText(abilityName)
        ui.controls.heldItem.setText(heldItemInfo.name)
        for i, type in pairs(pokemon.type) do
            ui.controls["pokemonType" .. i].setPath(Paths.FOLDERS.TYPE_IMAGES_FOLDER .. "/" .. type .. ".png")
        end

        local healingTotals = program.getHealingTotals()
        local statusTotals = program.getStatusTotals()
        if healingTotals == nil then
            healingTotals = {healing = 0, numHeals = 0}
        end
        eventListeners.statusItemsHoverListener.setOnHoverParams(
            {items = program.getStatusItems(), itemType = "Status"}
        )
        eventListeners.healingItemsHoverListener.setOnHoverParams(
            {items = program.getHealingItems(), itemType = "Healing"}
        )
        ui.controls.healsLabel.setText("Heals: " .. healingTotals.healing .. "% HP (" .. healingTotals.numHeals .. ")")
        ui.controls.statusItemsLabel.setText("Status items: " .. statusTotals)
        eventListeners.moveHeaderHoverListener.setOnHoverParams(
            {["pokemon"] = pokemon, mainFrame = ui.frames.mainFrame}
        )
        local abilityHoverParams = eventListeners.abilityHoverListener.getOnHoverParams()
        abilityHoverParams.text = AbilityData.ABILITIES[pokemon.ability + 1].description
        local itemHoverParams = eventListeners.heldItemHoverListener.getOnHoverParams()
        itemHoverParams.text = heldItemInfo.description
        ui.frames.enemyNoteFrame.setVisibility(isEnemy)
        ui.frames.healFrame.setVisibility(not isEnemy)
        setUpStats(pokemon, isEnemy)
        if isEnemy then
            setEnemySpecificControls(pokemon)
        end
        setUpMoves(pokemon, isEnemy, opposingPokemon)
        setUpStatStages(pokemon)
    end

    local function openOptionsScreen()
        ui.frames.mainFrame.setVisibility(false)
        client.SetGameExtraPadding(0, 0, Graphics.SIZES.MAIN_SCREEN_PADDING, 0)
        program.undoTrackedPokemonView()
        program.setCurrentScreens({program.UI_SCREENS.MAIN_OPTIONS_SCREEN})
        program.drawCurrentScreens()
        ui.frames.mainFrame.setVisibility(true)
    end

    function self.setPokemonToDraw(pokemon, newOpposingPokemon)
        currentPokemon = pokemon
        opposingPokemon = newOpposingPokemon
    end

    function self.addEventListener(eventListener)
        table.insert(eventListeners, eventListener)
    end

    function self.runEventListeners()
        local listenerGroups = {eventListeners, moveEventListeners, statPredictionEventListeners}
        for _, listenerGroup in pairs(listenerGroups) do
            for _, eventListener in pairs(listenerGroup) do
                eventListener.listen()
            end
        end
        self.runFrameCounters()
    end

    function self.runFrameCounters()
        for _, counter in pairs(frameCounters) do
            counter.decrement()
        end
    end

    function self.resetEventListeners()
        local listenerGroups = {eventListeners, moveEventListeners, statPredictionEventListeners}
        for _, listenerGroup in pairs(listenerGroups) do
            for _, eventListener in pairs(listenerGroup) do
                if eventListener.reset then
                    eventListener.reset()
                end
            end
        end
    end

    function self.resetHoverFrame()
        activeHoverFrame = nil
        self.resetEventListeners()
    end

    function self.show()
        self.updateBadgeLayout()
        readPokemonIntoUI()
        ui.frames.mainFrame.show()
        if not program.isInBattle() then
            extraThingsToDraw.moveEffectiveness = {}
            extraThingsToDraw.statStages = {}
        end
        drawExtraStuff()
        if activeHoverFrame ~= nil then
            activeHoverFrame.show()
        end
    end

    local function initEventListeners()
        for i = 1, 4, 1 do
            local moveFrame = ui.moveInfoFrames[i]
            table.insert(
                moveEventListeners,
                HoverEventListener(
                    moveFrame.moveNameLabel,
                    onHoverInfo,
                    {
                        BGColorKey = "Bottom box background color",
                        BGColorFillKey = "Bottom box border color",
                        text = "",
                        textColorKey = "Bottom box text color",
                        width = 120,
                        alignment = Graphics.HOVER_ALIGNMENT_TYPE.ALIGN_ABOVE
                    },
                    onHoverInfoEnd
                )
            )
        end
        eventListeners.abilityHoverListener =
            HoverEventListener(
            ui.controls.abilityDetails,
            onHoverInfo,
            {
                BGColorKey = "Top box background color",
                BGColorFillKey = "Top box border color",
                text = "",
                textColorKey = "Top box text color",
                width = 120,
                alignment = Graphics.HOVER_ALIGNMENT_TYPE.ALIGN_BELOW
            },
            onHoverInfoEnd
        )
        eventListeners.heldItemHoverListener =
            HoverEventListener(
            ui.controls.heldItem,
            onHoverInfo,
            {
                BGColorKey = "Top box background color",
                BGColorFillKey = "Top box border color",
                text = "",
                textColorKey = "Top box text color",
                width = 120,
                alignment = Graphics.HOVER_ALIGNMENT_TYPE.ALIGN_BELOW
            },
            onHoverInfoEnd
        )
        eventListeners.pokemonHoverListener =
            HoverEventListener(
            ui.controls.pokemonImageLabel,
            onPokemonImageHover,
            {pokemon = nil, mainFrame = ui.frames.mainFrame},
            onHoverInfoEnd
        )
        eventListeners.moveHeaderHoverListener =
            HoverEventListener(ui.controls.moveHeaderLearnedText, onMoveHeaderHover, {pokemon = nil}, onHoverInfoEnd)
        eventListeners.optionsIconListener = MouseClickEventListener(ui.controls.gearIcon, openOptionsScreen, nil)
        eventListeners.noteIconListener = MouseClickEventListener(ui.controls.noteIcon, createNote, nil)
        eventListeners.healingItemsHoverListener =
            HoverEventListener(ui.controls.healsLabel, onItemBagInfoHover, nil, onHoverInfoEnd)
        eventListeners.statusItemsHoverListener =
            HoverEventListener(ui.controls.statusItemsLabel, onItemBagInfoHover, nil, onHoverInfoEnd)
    end

    local function recalculateMainFrameSize(orientation)
        local baseSize = {
            width = Graphics.SIZES.MAIN_SCREEN_WIDTH,
            height = Graphics.SIZES.MAIN_SCREEN_HEIGHT
        }
        local spacing = 0
        if settings.badgesAppearance.SPACER then
            spacing = 5
        end
        ui.frames.mainFrame.setLayoutSpacing(spacing)
        local add = {width = 0, height = 0}
        local gameInfo = program.getGameInfo()
        local numBadges = 1
        if settings.badgesAppearance.SHOW_BOTH_BADGES and (gameInfo.NAME == "Pokemon HeartGold" or gameInfo.NAME == "Pokemon SoulSilver") then
            numBadges = 2
            if not ui.frames.badgeFrame2.isVisible() then
                numBadges = numBadges - 1
            end
        end
        if not ui.frames.badgeFrame1.isVisible() then
            numBadges = numBadges - 1
        end
        if orientation == "VERTICAL" then
            add.width = numBadges * constants.BADGE_VERTICAL_WIDTH + spacing * numBadges
        else
            add.height = numBadges * constants.BOTTOM_BOX_HEIGHT + spacing * numBadges
        end
        ui.frames.mainFrame.resize({width = baseSize.width + add.width, height = baseSize.height + add.height})
    end

    function self.HGSS_setBadgesToKanto()
        local badgeControls = ui.badgeControlsSet1
        for _, control in pairs(badgeControls) do
            control.setPath(control.getPath():gsub("HGSS", "HGSS_K"))
        end
    end

    function self.updateBadges(newBadges)
        local badgeSets = {
            {badges = newBadges.firstSet, controls = ui.badgeControlsSet1},
            {badges = newBadges.secondSet, controls = ui.badgeControlsSet2}
        }
        for i, badgeSet in pairs(badgeSets) do
            for badgeIndex, control in pairs(badgeSet.controls) do
                local prefix = program.getGameInfo().BADGE_PREFIX
                local badgeValue = badgeSet.badges[badgeIndex]
                local off = ""
                if badgeValue == 0 then
                    off = "_OFF"
                end
                if badgeSet.badges == newBadges.secondSet then
                    prefix = prefix .. "_K"
                end
                control.setPath("ironmon_tracker/images/icons/" .. prefix .. "_badge" .. badgeIndex .. off .. ".png")
            end
        end
    end

    function self.setLanceDefeated(newValue)
        defeatedLance = newValue
    end

    function self.setUpForTrackedPokemonView()
        badgesEnabled = false
    end

    function self.undoTrackedPokemonView()
        ui.frames.mainFrame.move({x = Graphics.SIZES.SCREEN_WIDTH, y = 0})
        badgesEnabled = true
    end

    function self.moveMainScreen(newPosition)
        ui.frames.mainFrame.move(newPosition)
    end

    function self.updateBadgeLayout()
        if not badgesEnabled then
            ui.frames.badgeFrame1.setVisibility(false)
            ui.frames.badgeFrame2.setVisibility(false)
            recalculateMainFrameSize("VERTICAL")
        else
            local gameInfo = program.getGameInfo()
            local showBoth =
                settings.badgesAppearance.SHOW_BOTH_BADGES and
                (gameInfo.NAME == "Pokemon HeartGold" or gameInfo.NAME == "Pokemon SoulSilver")
            local MAIN_FRAME_INDICES = {
                [Graphics.BADGE_ALIGNMENT_TYPE.ABOVE] = 1,
                [Graphics.BADGE_ALIGNMENT_TYPE.BELOW] = 3,
                [Graphics.BADGE_ALIGNMENT_TYPE.LEFT] = 1,
                [Graphics.BADGE_ALIGNMENT_TYPE.RIGHT] = 3,
                [Graphics.BADGE_ALIGNMENT_TYPE.ABOVE_AND_BELOW] = {1, 3},
                [Graphics.BADGE_ALIGNMENT_TYPE.LEFT_AND_RIGHT] = {1, 3},
                [Graphics.BADGE_ALIGNMENT_TYPE.BOTH_ABOVE] = {1, 2},
                [Graphics.BADGE_ALIGNMENT_TYPE.BOTH_BELOW] = {3, 3},
                [Graphics.BADGE_ALIGNMENT_TYPE.BOTH_LEFT] = {1, 2},
                [Graphics.BADGE_ALIGNMENT_TYPE.BOTH_RIGHT] = {3, 3}
            }
            local primaryBadgeFrame = ui.frames.badgeFrame1
            local secondaryBadgeFrame = ui.frames.badgeFrame2
            if showBoth then
                if settings.badgesAppearance.PRIMARY_BADGE_SET == "KANTO" then
                    local temp = primaryBadgeFrame
                    primaryBadgeFrame = secondaryBadgeFrame
                    secondaryBadgeFrame = temp
                end
            elseif defeatedLance then
                primaryBadgeFrame = ui.frames.badgeFrame2
            end
            
            primaryBadgeFrame.setVisibility(true)
            local alignment
            if showBoth then
                alignment = Graphics.BADGE_ALIGNMENT_TYPE[settings.badgesAppearance.DOUBLE_BADGE_ALIGNMENT]
            else
                alignment = Graphics.BADGE_ALIGNMENT_TYPE[settings.badgesAppearance.SINGLE_BADGE_ALIGNMENT]
            end
            local newOrientation = Graphics.BADGE_ORIENTATION[alignment]

            local badgeFrames = {primaryBadgeFrame, secondaryBadgeFrame}
            local newSize = {
                width = 0,
                height = 0
            }
            if newOrientation == "VERTICAL" then
                ui.frames.mainFrame.setLayoutAlignment(Graphics.ALIGNMENT_TYPE.HORIZONTAL)
                newSize.width = constants.BADGE_VERTICAL_WIDTH
                newSize.height = constants.BADGE_VERTICAL_HEIGHT
            else
                ui.frames.mainFrame.setLayoutAlignment(Graphics.ALIGNMENT_TYPE.VERTICAL)
                newSize.width = constants.BADGE_HORIZONTAL_WIDTH
                newSize.height = constants.BOTTOM_BOX_HEIGHT
            end
            for _, badgeFrame in pairs(badgeFrames) do
                if showBoth then
                    badgeFrame.setVisibility(true)
                end
                if newOrientation == "VERTICAL" then
                    badgeFrame.setLayoutAlignment(Graphics.ALIGNMENT_TYPE.VERTICAL)
                    badgeFrame.setLayoutSpacing(0)
                else
                    badgeFrame.setLayoutAlignment(Graphics.ALIGNMENT_TYPE.HORIZONTAL)
                    badgeFrame.setLayoutSpacing(1)
                end
            end
            if showBoth then
                local indices = MAIN_FRAME_INDICES[alignment]
                primaryBadgeFrame.changeParentFrame(ui.frames.mainFrame, indices[1])
                secondaryBadgeFrame.changeParentFrame(ui.frames.mainFrame, indices[2])
            else
                ui.frames.badgeFrame2.setVisibility(false)
                local index = MAIN_FRAME_INDICES[alignment]
                ui.frames.badgeFrame1.changeParentFrame(ui.frames.mainFrame, index)
            end
            ui.frames.badgeFrame1.resize(newSize)
            ui.frames.badgeFrame2.resize(newSize)
            recalculateMainFrameSize(newOrientation)
        end
    end

    initUI()
    initEventListeners()

    return self
end

return MainScreen
