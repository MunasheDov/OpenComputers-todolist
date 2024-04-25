local event = require "event"
local term = require "term"
local fs = require "filesystem"
local component = require "component"


function start()
	-- change serverAddress to the address of network card
	-- of the computer running the server
	local serverAddress = "c4de7dc5-c340-4bb8-9ccf-1939f9eaf27a"
	local port = 4000
	term.clear()
	print("attempting request of updated todolist from todo-server at "..string.sub(serverAddress, 1,8))

	if not component.isAvailable("modem") then
		print("failed to request todolist: this computer lacks a network card.")
		return
	end
	local modem = component.modem

	local path = "/home/todolist.txt"
	local f, err = io.open(path, "w")
	if not f then
		print(string.format("failed to open %s for writing: %s", path, err))
		return
	end

	modem.open(port)
	modem.send(serverAddress, port, "request-todo")
	local _,_,fromAddress,_,_,msg = event.pull(1, "modem_message")
	if not msg then
		print("response timed out")
		return
	end
	-- TODO: verification of the responder to our request
	f:write(msg)
	f:close()

	local horz = "─"
	local gpu = term.gpu()
	local width, height = gpu.getResolution()
	local horzLine = string.rep(horz, width)

	print("\n")
	print(horzLine)
	print(msg)
	print(horzLine)
	print("\n")

	print("press any key to continue...")
	event.pull("key_down")
	term.clear()
end
