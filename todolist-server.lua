local component = require "component"
local event = require "event"
local term = require "term"
local modem

function run()
	local path = "/home/todolist.txt"
	while true do
		local id, addr, from, port, dist, msg = event.pullMultiple("interrupted", "modem_message")
		if id == "interrupted" then
			print("user quit todo-server")
			return
		else
			if msg and msg ~= "request-todo" then
				print("server received invalid request")
				modem.send(from, port, "response-invalid-request")
			else
				local fromShort = string.sub(from, 1,8)
				print(string.format("received request-todo from %s", fromShort))
				local f, err = io.open(path)
				if not f then
					print(string.format("failed to open %s for reading: %s", path, err))
					return
				else
					modem.send(from, port, f:read("*all"))
					f:close()
					print(string.format("sent todolist to %s:%d", fromShort, port))
				end
			end
		end
	end
end

function start()
	term.clear()
	local port = 4000
	if not component.isAvailable("modem") then
		print("failed to request todolist: this computer lacks a network card.")
		print("press any key to continue...")
		event.pull("key_down")
		return
	end
	modem = component.modem
	modem.open(port)
	print("started todolist-server; listening on port "..port)
	run()
end

