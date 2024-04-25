local event = require "event"
local term = require "term"
local fs = require "filesystem"
local component = require "component"
local serialization = require "serialization"

function loadServerList()
    if fs.exists("/home/serverlist.txt") then
        local file = io.open("/home/serverlist.txt", "r")
        local success, serverList = pcall(function()
            return serialization.unserialize(file:read("*all"))
        end)
        file:close()
        if success then
            return serverList
        else
            print("Error loading server list: " .. serverList)
            return {}
        end
    else
        return {}
    end
end

function saveServerList(serverList)
    local file = io.open("/home/serverlist.txt", "w")
    local success, err = pcall(function()
        file:write(serialization.serialize(serverList))
    end)
    file:close()
    if not success then
        print("Error saving server list: " .. err)
    end
end

function requestTodoList(serverAddress, port)
    if not component.isAvailable("modem") then
        print("Failed to request todolist: this computer lacks a network card.")
        return
    end
    local modem = component.modem

    local success, err = pcall(function()
        modem.open(port)
    end)
    if not success then
        print("Failed to open port " .. port .. ": " .. err)
        return
    end

    local path = "/home/todolist.txt"
    local f, err = io.open(path, "w")
    if not f then
        print(string.format("Failed to open %s for writing: %s", path, err))
        modem.close(port)
        return
    end

    modem.send(serverAddress, port, "request-todo")
    local timeout = 5
    local _, _, fromAddress, _, _, msg = event.pull(timeout, "modem_message")
    if not msg then
        print("Response timed out after " .. timeout .. " seconds")
        modem.close(port)
        return
    end
    f:write(msg)
    f:close()
    modem.close(port)

    return msg
end

function displayTodoList(msg)
    term.clear()
    local horz = "─"
    local gpu = term.gpu()
    local width, height = gpu.getResolution()
    local horzLine = string.rep(horz, width)

    print("\n")
    print(horzLine)
    print(msg)
    print(horzLine)
    print("\n")
    print("Press 'R' to refresh or 'Ctrl+C' to exit.")
end

function start()
    term.clear()
    local serverList = loadServerList()

    print("Select a server address:")
    for i, server in ipairs(serverList) do
        print(i .. ". " .. tostring(server))
    end
    print("Enter a new server address or select a number from the list:")

    local input = io.read()
    local serverAddress

    if tonumber(input) then
        local index = tonumber(input)
        if index >= 1 and index <= #serverList then
            serverAddress = serverList[index]
        else
            print("Invalid selection. Please try again.")
            return
        end
    else
        serverAddress = input
        local found = false
        for _, server in ipairs(serverList) do
            if server == serverAddress then
                found = true
                break
            end
        end
        if not found then
            table.insert(serverList, serverAddress)
            saveServerList(serverList)
        end
    end

    if type(serverAddress) ~= "string" then
        print("Error: Server address must be a string.")
        return
    end

    local port = 4000
    print("Attempting request of updated todolist from todo-server at " .. string.sub(serverAddress, 1, 8))

    local refreshInterval = 60  -- Refresh interval in seconds (1 minute)
    local timer = event.timer(refreshInterval, function()
        local msg = requestTodoList(serverAddress, port)
        if msg then
            displayTodoList(msg)
        end
    end, math.huge)

    while true do
        local msg = requestTodoList(serverAddress, port)
        if msg then
            displayTodoList(msg)
        end

        local eventData = {event.pull()}
        if eventData[1] == "key_down" then
            if eventData[4] == 46 then  -- 'R' key
                local msg = requestTodoList(serverAddress, port)
                if msg then
                    displayTodoList(msg)
                end
            elseif eventData[4] == 29 then  -- 'Ctrl+C'
                event.cancel(timer)
                term.clear()
                break
            end
        end
    end
end

-- Call the start function within a pcall to catch any errors
local success, err = pcall(start)
if not success then
    print("An error occurred: " .. err)
    print("Press any key to continue...")
    event.pull("key_down")
    term.clear()
end
