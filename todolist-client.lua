local event = require "event"
local term = require "term"
local fs = require "filesystem"
local component = require "component"
local serialization = require "serialization"

function loadServerList()
    if fs.exists("/home/serverlist.txt") then
        local file = io.open("/home/serverlist.txt", "r")
        local serverList = serialization.unserialize(file:read("*all"))
        file:close()
        return serverList
    else
        return {}
    end
end

function saveServerList(serverList)
    local file = io.open("/home/serverlist.txt", "w")
    file:write(serialization.serialize(serverList))
    file:close()
end

function start()
    term.clear()
    local serverList = loadServerList()

    print("Select a server address:")
    for i, server in ipairs(serverList) do
        print(i .. ". " .. server)
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
        if not serverList[serverAddress] then
            table.insert(serverList, serverAddress)
            saveServerList(serverList)
        end
    end

    local port = 4000
    print("Attempting request of updated todolist from todo-server at " .. string.sub(serverAddress, 1, 8))

    if not component.isAvailable("modem") then
        print("Failed to request todolist: this computer lacks a network card.")
        return
    end
    local modem = component.modem

    if not modem then
        print("Failed to request todolist: this computer lacks a network card.")
        return
    end

    if not modem.open(port) then
        print("Failed to open port " .. port)
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
    -- TODO: verification of the responder to our request
    f:write(msg)
    f:close()
    modem.close(port)

    local horz = "─"
    local gpu = term.gpu()
    local width, height = gpu.getResolution()
    local horzLine = string.rep(horz, width)

    print("\n")
    print(horzLine)
    print(msg)
    print(horzLine)
    print("\n")

    print("Press any key to continue...")
    event.pull("key_down")
    term.clear()
end