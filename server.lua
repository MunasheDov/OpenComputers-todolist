local event = require "event"
local term = require "term"
local m = (require "component").modem

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
				m.send(from, port, "response-invalid-request")
			else
				local fromShort = string.sub(from, 1,8)
				print(string.format("received request-todo from %s", fromShort))
				local f, err = io.open(path)
				if not f then
					print(string.format("failed to open %s for reading: %s", path, err))
					return
				else
					m.send(from, port, f:read("*all"))
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
	if not m then
		print("failed to start todo-server: this computer lacks a network card.")
		return
	end
	m.open(port)
	print("started todolist-server; listening on port "..port)
	run()
end

