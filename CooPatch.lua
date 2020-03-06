-- MMBN coop lua script test
-- requires Bizhawk w/ VBA-Next core
-- hooks ingame functions to create and complete events
-- events would be sent between players to simulate a Co-op experience 
-- currently only works with NTSC 3 Blue currently
-- by NMarkro
memory.usememorydomain("System Bus")

pressed = false
queue = {}
valid_registers = emu.getregisters()

end_main_func_addr = 0x08000322
-- function calls are addr+1 to call in THUMB mode
give_chip_func_addr = 0x08011281
give_zenny_func_addr = 0x0801480B
give_bugfrag_func_addr = 0x0801485F

-- IDEA: watch the function that sets chip library flags
-- send give_chip events with "amount = 0" to update the other player's library without adding the chip
-- this is mainly for when players pick up extra folders and folder 2
-- we can't actually call this by itself as it sets off anti-cheat
give_library_func_addr = 0x080112AE

--[[
hooks the end of the main function
code normally looks like this:
	0800031C	ldr		r0,=3006825h						load some function addr into r0
	0800031E	mov 	r14,r15								move the PC into r14 for returning here
	08000320	bx r0					<- hooking here		call the function loaded in r0
	08000322	b 		80002B4h							goes back to start of main loop
the idea is to call whatever function we want with r0 then rerun this code normally
--]]
function main_hook()
	if next(queue) ~= nil then
		local index, event = next(queue)
		emu.setregister("R0", event.addr)
		emu.setregister("R14", 0x0800031C)
	end
end

-- r0 is used to call functions and as function args
-- we need to set the args manually at the beginning of functions
function set_args(registers)
	for reg, value in pairs(registers) do
		if valid_registers[reg] ~= nil then
			emu.setregister(reg, value)
		end
	end
end

-- hooks the give_chip function
-- has 2 purposes, to create new events for other players or complete current queued events
function give_chip_hook()
	-- check if we called this function
	if emu.getregister("R14") == 0x0800031C then
		local index, event = next(queue)
		set_args(event.registers)		
		table.remove(queue, 1)
	else
		-- the player was given this chip normally
		-- here you would create an event from the given args to be sent over the network
	end
end

-- hooks the give_zenny function
-- has 2 purposes, to create new events for other players or complete current queued events
function give_zenny_hook()
	-- check if we called this function
	if emu.getregister("R14") == 0x0800031C then
		local index, event = next(queue)
		set_args(event.registers)
		table.remove(queue, 1)
	else
		-- the player was given this zenny normally
		-- here you would create an event from the given args to be sent over the network
	end
end

-- hooks the give_bugfrag function
-- has 2 purposes, to create new events for other players or complete current queued events
function give_bugfrag_hook()
	-- check if we called this function
	if emu.getregister("R14") == 0x0800031C then
		local index, event = next(queue)
		set_args(event.registers)
		table.remove(queue, 1)
	else
		-- the player was given this bugfrag normally
		-- here you would create an event from the given args to be sent over the network
	end
end


event.onmemoryexecute(main_hook, end_main_func_addr)
-- bizhawk needs even addr for events
event.onmemoryexecute(give_chip_hook, give_chip_func_addr+1)
event.onmemoryexecute(give_zenny_hook, give_zenny_func_addr+1)
event.onmemoryexecute(give_bugfrag_hook, give_bugfrag_func_addr+1)

while true do
	local inputs = joypad.get()
	-- pressing L+R+A will give you 1x LavaStg T
	if inputs.L and inputs.R and inputs.A then
		if not pressed then
			-- for give_chip the args are
			-- R0 = chip_id
			-- R1 = chip_code
			-- R2 = amount
			local new_event = {
				addr=give_chip_func_addr, 
				registers={["R0"]=0x0B3,["R1"]=0x13,["R2"]=0x1}
			}
			table.insert(queue, new_event)
			pressed = true
		end
	-- pressing L+R+B will give you 1000z
	elseif inputs.L and inputs.R and inputs.B then
		if not pressed then
			-- for give_zenny the args are
			-- R0 = amount
			local new_event = {
				addr=give_zenny_func_addr, 
				registers={["R0"]=1000}
			}
			table.insert(queue, new_event)
			pressed = true
		end
	-- pressing L+R+Select will give you 10 bugfrags
	elseif inputs.L and inputs.R and inputs.Select then
		if not pressed then
			-- for give_bugfrag the args are
			-- R0 = amount
			local new_event = {
				addr=give_bugfrag_func_addr, 
				registers={["R0"]=10}
			}
			table.insert(queue, new_event)
			pressed = true
		end
	-- pressing L+R+Start will add AntiDmg to your library
	elseif inputs.L and inputs.R and inputs.Start then
		if not pressed then
			-- for give_chip the args are
			-- R0 = chip_id
			-- R1 = chip_code (shouldn't matter)
			-- R2 = amount (set to 0 to only update library)
			local new_event = {
				addr=give_chip_func_addr, 
				registers={["R0"]=0x0BF,["R1"]=0x01,["R2"]=0x0}
			}
			table.insert(queue, new_event)
			pressed = true
		end
	else
		pressed = false
	end

	emu.frameadvance()
end