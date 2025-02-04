import "pkg:/source/utils/misc.brs"

sub init()
    m.top.itemComponentName = "HomeItem"
    ' how many rows are visible on the screen
    m.top.numRows = 2

    m.top.rowFocusAnimationStyle = "fixedFocusWrap"
    m.top.vertFocusAnimationStyle = "fixedFocus"

    m.top.showRowLabel = [true]
    m.top.rowLabelOffset = [0, 20]
    m.top.showRowCounter = [true]

    m.homeSectionIndexes = {
        count: 0
    }

    updateSize()

    m.top.setfocus(true)

    m.top.observeField("rowItemSelected", "itemSelected")

    ' Load the Libraries from API via task
    m.LoadLibrariesTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadLibrariesTask.observeField("content", "onLibrariesLoaded")

    ' set up tesk nodes for other rows
    m.LoadContinueWatchingTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadContinueWatchingTask.itemsToLoad = "continue"

    m.LoadNextUpTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadNextUpTask.itemsToLoad = "nextUp"

    m.LoadOnNowTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadOnNowTask.itemsToLoad = "onNow"

    m.LoadFavoritesTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadFavoritesTask.itemsToLoad = "favorites"
end sub

sub loadLibraries()
    m.LoadLibrariesTask.control = "RUN"
end sub

sub updateSize()
    m.top.translation = [111, 180]
    itemHeight = 330

    'Set width of Rows to cut off at edge of Safe Zone
    m.top.itemSize = [1703, itemHeight]

    ' spacing between rows
    m.top.itemSpacing = [0, 105]

    ' spacing between items in a row
    m.top.rowItemSpacing = [20, 0]

    m.top.visible = true
end sub

sub onLibrariesLoaded()
    ' save data for other functions
    m.libraryData = m.LoadLibrariesTask.content
    m.LoadLibrariesTask.unobserveField("content")
    m.LoadLibrariesTask.content = []

    content = CreateObject("roSGNode", "ContentNode")
    sizeArray = []
    loadedSections = 0

    ' Add sections in order based on user settings
    for i = 0 to 6
        sectionName = LCase(m.global.session.user.settings["homesection" + i.toStr()])
        sectionLoaded = addHomeSection(content, sizeArray, sectionName)

        ' Count how many sections with data are loaded
        if sectionLoaded then loadedSections++

        ' If 2 sections with data are loaded or we're at the end of the web client section data, consider the home view loaded
        if loadedSections = 2 or i = 6
            if not m.global.app_loaded
                m.top.signalBeacon("AppLaunchComplete") ' Roku Performance monitoring
                m.global.app_loaded = true
            end if
        end if
    end for

    ' Favorites isn't an option on Web settings, so we must manually add it for now
    addHomeSection(content, sizeArray, "favorites")

    m.top.rowItemSize = sizeArray
    m.top.content = content
end sub

' Removes a home section from the home rows
sub removeHomeSection(sectionType as string)
    sectionName = LCase(sectionType)

    removedSectionIndex = m.homeSectionIndexes[sectionName]

    if not isValid(removedSectionIndex) then return

    for each section in m.homeSectionIndexes
        if m.homeSectionIndexes[section] > removedSectionIndex
            m.homeSectionIndexes[section]--
        end if
    end for

    m.homeSectionIndexes.Delete(sectionName)
    m.homeSectionIndexes.AddReplace("count", m.homeSectionIndexes.count - 1)

    m.top.content.removeChildIndex(removedSectionIndex)
end sub

' Adds a new home section to the home rows.
' Returns a boolean indicating whether the section was handled.
function addHomeSection(content as dynamic, sizeArray as dynamic, sectionName as string) as boolean
    ' Poster size library items
    if sectionName = "livetv"
        createLiveTVRow(content, sizeArray)
        return true
    end if

    ' Poster size library items
    if sectionName = "smalllibrarytiles"
        createLibraryRow(content, sizeArray)
        return true
    end if

    ' Continue Watching items
    if sectionName = "resume"
        createContinueWatchingRow(content, sizeArray)
        return true
    end if

    ' Next Up items
    if sectionName = "nextup"
        createNextUpRow(content, sizeArray)
        return true
    end if

    ' Latest items in each library
    if sectionName = "latestmedia"
        createLatestInRows(content, sizeArray)
        return true
    end if

    ' Favorite Items
    if sectionName = "favorites"
        createFavoritesRow(content, sizeArray)
        return true
    end if

    return false
end function

' Create a row displaying the user's libraries
sub createLibraryRow(content as dynamic, sizeArray as dynamic)
    ' Ensure we have data
    if not isValidAndNotEmpty(m.libraryData) then return

    mediaRow = content.CreateChild("HomeRow")
    mediaRow.title = tr("My Media")

    m.homeSectionIndexes.AddReplace("library", m.homeSectionIndexes.count)
    m.homeSectionIndexes.count++

    sizeArray.push([464, 331])

    filteredMedia = filterNodeArray(m.libraryData, "id", m.global.session.user.configuration.MyMediaExcludes)
    for each item in filteredMedia
        mediaRow.appendChild(item)
    end for
end sub

' Create a row displaying latest items in each of the user's libraries
sub createLatestInRows(content as dynamic, sizeArray as dynamic)
    ' Ensure we have data
    if not isValidAndNotEmpty(m.libraryData) then return

    ' create a "Latest In" row for each library
    filteredLatest = filterNodeArray(m.libraryData, "id", m.global.session.user.configuration.LatestItemsExcludes)
    for each lib in filteredLatest
        if lib.collectionType <> "boxsets" and lib.collectionType <> "livetv" and lib.json.CollectionType <> "Program"
            latestInRow = content.CreateChild("HomeRow")
            latestInRow.title = tr("Latest in") + " " + lib.name + " >"

            m.homeSectionIndexes.AddReplace("latestin" + LCase(lib.name).Replace(" ", ""), m.homeSectionIndexes.count)
            m.homeSectionIndexes.count++
            sizeArray.Push([464, 331])

            loadLatest = createObject("roSGNode", "LoadItemsTask")
            loadLatest.itemsToLoad = "latest"
            loadLatest.itemId = lib.id

            metadata = { "title": lib.name }
            metadata.Append({ "contentType": lib.json.CollectionType })
            loadLatest.metadata = metadata

            loadLatest.observeField("content", "updateLatestItems")
            loadLatest.control = "RUN"
        end if
    end for
end sub

' Create a row displaying the live tv now on section
sub createLiveTVRow(content as dynamic, sizeArray as dynamic)
    contentRow = content.CreateChild("HomeRow")
    contentRow.title = tr("On Now")
    m.homeSectionIndexes.AddReplace("livetv", m.homeSectionIndexes.count)
    m.homeSectionIndexes.count++
    sizeArray.push([464, 331])

    m.LoadOnNowTask.observeField("content", "updateOnNowItems")
    m.LoadOnNowTask.control = "RUN"
end sub

' Create a row displaying items the user can continue watching
sub createContinueWatchingRow(content as dynamic, sizeArray as dynamic)
    continueWatchingRow = content.CreateChild("HomeRow")
    continueWatchingRow.title = tr("Continue Watching")
    m.homeSectionIndexes.AddReplace("resume", m.homeSectionIndexes.count)
    m.homeSectionIndexes.count++
    sizeArray.push([464, 331])

    ' Load the Continue Watching Data
    m.LoadContinueWatchingTask.observeField("content", "updateContinueWatchingItems")
    m.LoadContinueWatchingTask.control = "RUN"
end sub

' Create a row displaying next episodes up to watch
sub createNextUpRow(content as dynamic, sizeArray as dynamic)
    nextUpRow = content.CreateChild("HomeRow")
    nextUpRow.title = tr("Next Up >")
    m.homeSectionIndexes.AddReplace("nextup", m.homeSectionIndexes.count)
    m.homeSectionIndexes.count++
    sizeArray.push([464, 331])

    ' Load the Next Up Data
    m.LoadNextUpTask.observeField("content", "updateNextUpItems")
    m.LoadNextUpTask.control = "RUN"
end sub

' Create a row displaying items from the user's favorites list
sub createFavoritesRow(content as dynamic, sizeArray as dynamic)
    favoritesRow = content.CreateChild("HomeRow")
    favoritesRow.title = tr("Favorites")
    sizeArray.Push([464, 331])

    m.homeSectionIndexes.AddReplace("favorites", m.homeSectionIndexes.count)
    m.homeSectionIndexes.count++

    ' Load the Favorites Data
    m.LoadFavoritesTask.observeField("content", "updateFavoritesItems")
    m.LoadFavoritesTask.control = "RUN"
end sub

' Update home row data
sub updateHomeRows()
    if m.global.playstateTask.state = "run"
        m.global.playstateTask.observeField("state", "updateHomeRows")
        return
    end if

    m.global.playstateTask.unobserveField("state")

    ' If resume section exists, reload row's data
    if m.homeSectionIndexes.doesExist("resume")
        m.LoadContinueWatchingTask.observeField("content", "updateContinueWatchingItems")
        m.LoadContinueWatchingTask.control = "RUN"
    end if

    ' If next up section exists, reload row's data
    if m.homeSectionIndexes.doesExist("nextup")
        m.LoadNextUpTask.observeField("content", "updateNextUpItems")
        m.LoadNextUpTask.control = "RUN"
    end if

    ' If favorites section exists, reload row's data
    if m.homeSectionIndexes.doesExist("favorites")
        m.LoadFavoritesTask.observeField("content", "updateFavoritesItems")
        m.LoadFavoritesTask.control = "RUN"
    end if

    ' If live tv's on now section exists, reload row's data
    if m.homeSectionIndexes.doesExist("livetv")
        m.LoadOnNowTask.observeField("content", "updateOnNowItems")
        m.LoadOnNowTask.control = "RUN"
    end if

    ' If latest in library section exists, reload row's data
    hasLatestHomeSection = false

    for each section in m.homeSectionIndexes
        if LCase(Left(section, 6)) = "latest"
            hasLatestHomeSection = true
            exit for
        end if
    end for

    if hasLatestHomeSection
        updateLatestInRows()
    end if
end sub

sub updateFavoritesItems()
    itemData = m.LoadFavoritesTask.content
    m.LoadFavoritesTask.unobserveField("content")
    m.LoadFavoritesTask.content = []

    if itemData = invalid then return

    rowIndex = m.homeSectionIndexes.favorites

    if itemData.count() < 1
        removeHomeSection("favorites")
        return
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Favorites")

        for each item in itemData
            usePoster = true

            if lcase(item.type) = "episode" or lcase(item.type) = "audio" or lcase(item.type) = "musicartist"
                usePoster = false
            end if

            item.usePoster = usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        ' replace the old row
        m.top.content.replaceChild(row, rowIndex)

    end if
end sub

sub updateContinueWatchingItems()
    itemData = m.LoadContinueWatchingTask.content
    m.LoadContinueWatchingTask.unobserveField("content")
    m.LoadContinueWatchingTask.content = []

    if itemData = invalid then return

    if itemData.count() < 1
        removeHomeSection("resume")
        return
    end if

    ' remake row using the new data
    row = CreateObject("roSGNode", "HomeRow")
    row.title = tr("Continue Watching")

    for each item in itemData
        if isValid(item.json) and isValid(item.json.UserData) and isValid(item.json.UserData.PlayedPercentage)
            item.PlayedPercentage = item.json.UserData.PlayedPercentage
        end if

        item.usePoster = row.usePoster
        item.imageWidth = row.imageWidth
        row.appendChild(item)
    end for

    ' replace the old row
    m.top.content.replaceChild(row, m.homeSectionIndexes.resume)
end sub

sub updateNextUpItems()
    itemData = m.LoadNextUpTask.content
    m.LoadNextUpTask.unobserveField("content")
    m.LoadNextUpTask.content = []

    if itemData = invalid then return

    if itemData.count() < 1
        removeHomeSection("nextup")
        return
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Next Up") + " >"
        for each item in itemData
            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        ' replace the old row
        m.top.content.replaceChild(row, m.homeSectionIndexes.nextup)
    end if
end sub

' Iterate over user's libraries and update data for each Latest In section
sub updateLatestInRows()
    ' Ensure we have data
    if not isValidAndNotEmpty(m.libraryData) then return

    ' Load new data for each library
    filteredLatest = filterNodeArray(m.libraryData, "id", m.global.session.user.configuration.LatestItemsExcludes)
    for each lib in filteredLatest
        if lib.collectionType <> "boxsets" and lib.collectionType <> "livetv" and lib.json.CollectionType <> "Program"
            loadLatest = createObject("roSGNode", "LoadItemsTask")
            loadLatest.itemsToLoad = "latest"
            loadLatest.itemId = lib.id

            metadata = { "title": lib.name }
            metadata.Append({ "contentType": lib.json.CollectionType })
            loadLatest.metadata = metadata

            loadLatest.observeField("content", "updateLatestItems")
            loadLatest.control = "RUN"
        end if
    end for
end sub

sub updateLatestItems(msg)
    itemData = msg.GetData()

    node = msg.getRoSGNode()
    node.unobserveField("content")
    node.content = []

    if itemData = invalid then return

    sectionName = "latestin" + LCase(node.metadata.title).Replace(" ", "")

    rowIndex = m.homeSectionIndexes[sectionName]

    if itemData.count() < 1
        removeHomeSection(sectionName)
        return
    else
        ' remake row using new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Latest in") + " " + node.metadata.title + " >"
        row.usePoster = true
        ' Handle specific types with different item widths
        if node.metadata.contentType = "movies"
            row.imageWidth = 180
            itemSize = [188, 331]
        else if node.metadata.contentType = "music"
            row.imageWidth = 261
            itemSize = [261, 331]
        else
            row.imageWidth = 464
            itemSize = [464, 331]
        end if

        for each item in itemData
            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        ' replace the old row
        updateSizeArray(itemSize, rowIndex, "replace")
        m.top.content.replaceChild(row, rowIndex)
    end if
end sub

sub updateOnNowItems()
    itemData = m.LoadOnNowTask.content
    m.LoadOnNowTask.unobserveField("content")
    m.LoadOnNowTask.content = []

    if itemData = invalid then return

    if itemData.count() < 1
        removeHomeSection("livetv")
        return
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("On Now")
        for each item in itemData
            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        ' replace the old row
        m.top.content.replaceChild(row, m.homeSectionIndexes.livetv)

    end if
end sub

sub updateSizeArray(rowItemSize, rowIndex = invalid, action = "insert")
    sizeArray = m.top.rowItemSize
    ' append by default
    if rowIndex = invalid
        rowIndex = sizeArray.count()
    end if

    newSizeArray = []
    for i = 0 to sizeArray.count()
        if rowIndex = i
            if action = "replace"
                newSizeArray.Push(rowItemSize)
            else if action = "insert"
                newSizeArray.Push(rowItemSize)
                if isValid(sizeArray[i])
                    newSizeArray.Push(sizeArray[i])
                end if
            end if
        else if isValid(sizeArray[i])
            newSizeArray.Push(sizeArray[i])
        end if
    end for
    m.top.rowItemSize = newSizeArray
end sub

sub itemSelected()
    m.top.selectedItem = m.top.content.getChild(m.top.rowItemSelected[0]).getChild(m.top.rowItemSelected[1])

    'Prevent the selected item event from double firing
    m.top.selectedItem = invalid
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press
        if key = "play"
            print "play was pressed from homerow"
            itemToPlay = m.top.content.getChild(m.top.rowItemFocused[0]).getChild(m.top.rowItemFocused[1])
            if isValid(itemToPlay)
                m.top.quickPlayNode = itemToPlay
            end if
            return true
        else if key = "replay"
            m.top.jumpToRowItem = [m.top.rowItemFocused[0], 0]
            return true
        end if
    end if
    return false
end function

function filterNodeArray(nodeArray as object, nodeKey as string, excludeArray as object) as object
    if excludeArray.IsEmpty() then return nodeArray

    newNodeArray = []
    for each node in nodeArray
        excludeThisNode = false
        for each exclude in excludeArray
            if node[nodeKey] = exclude
                excludeThisNode = true
            end if
        end for
        if excludeThisNode = false
            newNodeArray.Push(node)
        end if
    end for
    return newNodeArray
end function
