
TOOL.Category   = "GUI Panels"
TOOL.Name       = "Self Changer 2"
TOOL.Command    = nil
TOOL.ConfigName = ""

local SELFCHANGER = {}
SELFCHANGER.DefaultValue = "hllo_wrld"
SELFCHANGER.path    = { }
SELFCHANGER.maxnest = 1

local BannedClasses = {
	-- ["gmod_wire_expression2"] = false,
	["starfall_processor"] = true,
}

TOOL.ClientConVar = {
	variable_path     = "",
	realm             = "CLIENT",
	max_nested_prints = "1"
}


local function strJustify(str,len)
	return str .. string.rep(' ', math.max( 0, len - #str ) )
end

local function throwDisabled()
	if SERVER then return false end
	SELFCHANGER.SoundHint("Function disabled (for now)", NOTIFY_ERROR, 3, "buttons/button10.wav")
	if true then return false end
end

local function checkBannedClasses( ent, sender )
	if TypeID(ent) ~= TYPE_ENTITY then return false end
	local class = ent:GetClass() 
	if( BannedClasses[ class ] ) then 
		if sender then
			SELFCHANGER.SoundHint( sender, "Entity class backlisted: "..class, NOTIFY_ERROR, 3, "buttons/button10.wav" )
		elseif CLIENT then
			SELFCHANGER.SoundHint( "Entity class backlisted: "..class, NOTIFY_ERROR, 3, "buttons/button10.wav" )
		end
		return true
	end
end

local function PrintTableFancy(tbl,name,indent,printQueue)
	local indentStr = string.rep('\t',indent)
	if indent >= SELFCHANGER.maxnest then 
		printQueue[#printQueue+1] = (indentStr .. name ..' = {...}') 
		return printQueue
	end
	
	local indentStr2 = string.rep('\t',indent+1)
	local stringData = {}
	local tableData = {}
	local didSomething = false
	local longest = 0
	for key, v in pairs(tbl) do
		didSomething = true
		local typ = type(v)
		key = tostring(key)
		longest = math.max(longest, #key)
		if typ == 'table' or typ == 'userdata' then
			tableData[#tableData+1] = { key, v }
		else
			stringData[#stringData+1] = { key, tostring(v), typ }
		end
	end
	if not didSomething then 
		printQueue[#printQueue+1] = (indentStr .. name ..' = { }') 
	else 
		printQueue[#printQueue+1] = (indentStr .. name ..' = {')
	end

	table.sort(stringData, function(a,b) return a[3] < b[3] end)
	for k, v in ipairs(stringData) do
		printQueue[#printQueue+1] = ( indentStr2 .. strJustify(v[1],longest) .. " = " .. v[2] )
	end
	for k, v in ipairs(tableData) do
		PrintTableFancy(v[2],v[1],indent+1,printQueue)
	end
	if didSomething then
		printQueue[#printQueue+1] = (indentStr .. '}' )
	end
	return printQueue
end

local function navigateTable(tbl, paths, root, sender)
	local reads = root or "SELF"
	local path = paths[1]

	for n=1, #paths do

		path = paths[n]

		local number = tonumber(path) -- if not 1, try "1"
		if tbl[number]~=nil then
			path = number
		end

		if tbl[path]==nil then return tbl, reads, path, true end
		if checkBannedClasses(tbl[path], sender) then return tbl, reads, path, true end

		if n == #paths then 
			break 
		end
		
		tbl = tbl[path]
		reads = reads .. '.' .. path

	end
	
	return tbl, reads, path
end

if CLIENT then

	local typeChecks = {
		NUMBER = 		function( val ) local n = tonumber(val) return n end,
		VECTOR = 		function( val ) local x,y,z = string.match( val, "^ *([^%s,]+) *, *([^%s,]+) *, *([^%s,]+) *$" ) x = tonumber(x) y = tonumber(y) z = tonumber(z) if ( x ~= nil and y ~= nil and z ~= nil ) then return Vector(x,y,z) end end,
		ANGLE = 		function( val ) local x,y,z = string.match( val, "^ *([^%s,]+) *, *([^%s,]+) *, *([^%s,]+) *$" ) x = tonumber(x) y = tonumber(y) z = tonumber(z) if ( x ~= nil and y ~= nil and z ~= nil ) then return Angle(x,y,z) end end,
		STRING = 		function( val ) return tostring(val) end,
		BOOLEAN =       function( val ) if val == "false" then return false elseif val == "true" then return true end return nil end,
		UNKNOWN = 		function() return end
	}

	local typeCheckIndexes = {		
		ANGLE = 		1,
		BOOLEAN =		2,
		NUMBER = 		3,
		STRING = 		4,
		UNKNOWN =		5,
		VECTOR = 		6,
	}

	local typeCheckOrder = {
		"NUMBER",
		"VECTOR",
		"BOOLEAN",
		"STRING"
	}

	language.Add( "tool.selfchanger.name"  , "Self Changer 2" )
	language.Add( "tool.selfchanger.desc"  , "Print or modify properties of entities" )

	language.Add( "tool.selfchanger.left"  , "Write/Paste to specified location" )
	language.Add( "tool.selfchanger.right" , "Read/Copy from specified location" )
	language.Add( "tool.selfchanger.reload", "Print entire entity table to console" )
	language.Add( "tool.selfchanger.reload_use", "Print value at location to console" )

	TOOL.Information = { 
		{ name = "reload" },
		{ name = "right" },
		{ name = "left" },
		{ name = "reload_use", icon2 = "gui/e.png" },
	}

	------

	local function getPath(str)
		str = string.Replace(str, "\\\\", "\128") -- "escape" backslashes
		str = string.Replace(str, "\\.", "\129")  -- "escape" dots
		
		if( string.match(str,"\\") ) then return end -- invalid escape sequence
		
		local access = string.Explode(".",str,false)
		
		for k, v in ipairs(access) do
			access[k] = string.Replace(access[k],"\129",".") -- unescape the dots
			access[k] = string.Replace(access[k],"\128","\\") -- unescape backslashes
			access[k] = access[k] or tonumber(access[k])
			if access[k] == "" then access[k] = nil end
		end

		return access
	end

	local function pathValidate(panel)
		SELFCHANGER.path = getPath( panel:GetValue() )
		if( SELFCHANGER.path ) then
			panel:SetTooltip( "This path is valid." )
			panel.parseIcon:SetImage( "icon16/accept.png" )
		else
			panel:SetTooltip( "Invalid escape sequence." )
			panel.parseIcon:SetImage( "icon16/cancel.png" )
		end
	end

	------

	local function guessValue(val)
		local value
		for k, v in ipairs(typeCheckOrder) do
			value = typeChecks[v](val)
			if( value~=nil ) then SELFCHANGER.value = value return end
		end
		SELFCHANGER.value = SELFCHANGER.DefaultValue
	end 

	local function typeUpper(val)
		return type(val):upper()
	end

	function TOOL.BuildCPanel(panel)

		panel:SetName( "Self Changer 2" )
		panel:Help("#tool.selfchanger.desc")

		local realmSelect = panel:ComboBox("Lua Realm:", "selfchanger_realm")
		realmSelect:AddChoice( "CLIENT", "CLIENT", true )
		realmSelect:AddChoice( "SERVER", "SERVER", false )
		realmSelect:Dock( FILL )
		realmSelect.oldselect = "CLIENT"

		local pathEntry = panel:TextEntry("Variable Path:", "selfchanger_variable_path")
			local parseIcon = vgui.Create( "DImage", pathEntry )
				parseIcon:Dock( RIGHT )
				parseIcon:DockMargin( 2,2,2,2 )
				parseIcon:SetImage( "icon16/accept.png" )
				parseIcon:SizeToContents()
				pathEntry.OnChange = pathValidate
			pathEntry.parseIcon = parseIcon
		panel:Help("Separate table indicies with periods (.) and escape them with backslashes (\\) if needed.  Backslashes can also be escaped if needed.\n"):SetColor(Color(47,149,241))
		
		SELFCHANGER.UpdatePath = function() pathValidate(pathEntry) end

		----[[
		local label2 = vgui.Create("DLabel", top)
			label2:SetText("Variable Type:")
			label2:SetColor(Color(0,0,0))

		SELFCHANGER.TypeSelectBox = vgui.Create("DComboBox") 
			for k, v in ipairs(typeCheckOrder) do
				SELFCHANGER.TypeSelectBox:AddChoice(v:upper())
			end
		SELFCHANGER.TypeSelectBox:AddChoice("ANGLE")
		SELFCHANGER.TypeSelectBox:AddChoice("UNKNOWN")
		SELFCHANGER.TypeSelectBox:ChooseOption("STRING",typeCheckIndexes["STRING"])
		SELFCHANGER.TypeSelectBox:Dock( FILL )

		panel:AddItem( label2, SELFCHANGER.TypeSelectBox )			

		SELFCHANGER.VarEntryBox = panel:TextEntry("Variable Value:")
			SELFCHANGER.ParseIconValue = vgui.Create( "DImage", SELFCHANGER.VarEntryBox )
				SELFCHANGER.ParseIconValue:Dock( RIGHT )
				SELFCHANGER.ParseIconValue:DockMargin( 2,2,2,2 )
				SELFCHANGER.ParseIconValue:SetImage( "icon16/accept.png" )
				SELFCHANGER.ParseIconValue:SizeToContents()
		panel:Help("Enter a comma-separated triplet of numbers to use vectors or angles.\nWARNING: Typing in this field will overwrite saved values copied via right-click!"):SetColor(Color(47,149,241))

		local function typeValidate()
			SELFCHANGER.value = typeChecks[SELFCHANGER.TypeSelectBox:GetValue()](SELFCHANGER.VarEntryBox:GetValue())
			if typeUpper(SELFCHANGER.value) == SELFCHANGER.TypeSelectBox:GetValue() then
				SELFCHANGER.VarEntryBox:SetTooltip( "This is a valid instance of "..SELFCHANGER.TypeSelectBox:GetValue().."." )
				SELFCHANGER.ParseIconValue:SetImage( "icon16/accept.png" )
			else
				SELFCHANGER.VarEntryBox:SetTooltip( "This is not a valid instance of "..SELFCHANGER.TypeSelectBox:GetValue().."." )
				SELFCHANGER.ParseIconValue:SetImage( "icon16/cancel.png" )
			end
		end

		SELFCHANGER.VarEntryBox.OnChange = function( self )
			guessValue( self:GetValue() )
			if SELFCHANGER.value ~= nil then
				local typ = typeUpper(SELFCHANGER.value)
				SELFCHANGER.TypeSelectBox:ChooseOption(typ,typeCheckIndexes[typ])
				SELFCHANGER.VarEntryBox:SetTooltip( "This is a valid instance of "..typ.."." )
				SELFCHANGER.ParseIconValue:SetImage( "icon16/accept.png" )
			else
				SELFCHANGER.VarEntryBox:SetTooltip( "This is not a valid instance of any known data type." )
				SELFCHANGER.ParseIconValue:SetImage( "icon16/cancel.png" )
			end
		end

		--]]--
		local recursionSlider = panel:NumSlider("Nested Table Limit:", "selfchanger_max_nested_prints", 1, 5, 0)
		recursionSlider:Dock(FILL)
		recursionSlider.OnValueChanged = function(pan,n) -- snappy slider; snap to nearest integer to give the UI a "crisp" feel
			local new = math.Round(n or 0)
			if new ~= n then
				pan:SetValue(new)
			end
		end
		panel:Help("The maximum depth to explore nested tables to.  Should save you from self-referential tables if you accidentally print one."):SetColor(Color(47,149,241))
		----[[
		local function SendClientValue(value)
			net.Start("selfchanger", true)
				net.WriteString("StoreClientValue")
				net.WriteType(value)
			net.SendToServer()
		end

		local function RequestServerValue(value)
			net.Start("selfchanger", true)
				net.WriteString("RequestServerValue")
			net.SendToServer()
		end

		SELFCHANGER.TypeSelectBox.OnSelect = function(self)
			if self:GetValue() ~= "UNKNOWN" then
				guessValue( SELFCHANGER.VarEntryBox:GetValue() )
				typeValidate()
				SendClientValue(SELFCHANGER.value)
			end
		end

		SELFCHANGER.VarEntryBox.OnLoseFocus = function( self )
			SendClientValue(SELFCHANGER.value)
		end

		SELFCHANGER.VarEntryBox:SetValue(SELFCHANGER.DefaultValue)

		realmSelect.OnSelect = function( self, index, value, data )

			if self.oldselect == value then return end
			self.oldselect = value

			RunConsoleCommand("selfchanger_realm",value)

			if value == "SERVER" then
				local success, err = pcall(SendClientValue, SELFCHANGER.value)
				if success then
					notification.AddLegacy( "Stored client value sent to server.", NOTIFY_GENERIC, 3 )
					surface.PlaySound( "ambient/water/drip3.wav" )
				else
					notification.AddLegacy( "Failed to send stored client value to server: "..err, NOTIFY_ERROR, 8 )
					surface.PlaySound( "buttons/button10.wav" )
				end
				return
			end

			if value == "CLIENT" then
				RequestServerValue()
				return
			end

		end
		--]]--
		
	end

	SELFCHANGER.SetUnknown = function( )
		if not SELFCHANGER.TypeSelectBox then -- idiot hasn't opened spawnmenu yet
			return
		end
		local typ = "UNKNOWN"
		SELFCHANGER.TypeSelectBox:ChooseOption(typ,typeCheckIndexes[typ])
		SELFCHANGER.VarEntryBox:SetTooltip( "This is a valid instance of "..typ.."." )
		SELFCHANGER.ParseIconValue:SetImage( "icon16/accept.png" )
		SELFCHANGER.VarEntryBox:SetText( tostring(SELFCHANGER.value) )
	end

end

if SERVER then

	util.AddNetworkString("selfchanger")
	SELFCHANGER.ServerCommands = { }

	for k, ply in ipairs( player.GetHumans() ) do
		ply.SelfChangerValue = SELFCHANGER.DefaultValue
	end

	net.Receive("selfchanger", function(len, sender)
		local command = net.ReadString()
		SELFCHANGER.ServerCommands[command](sender)
	end)

	function SELFCHANGER.SoundHint(ply, msg, icon, time, snd)
		net.Start("selfchanger")
			net.WriteString("SoundHint")
			net.WriteString(msg)
			net.WriteUInt(icon, 4)
			net.WriteUInt(time, 8)
			net.WriteString(snd)
		net.Send(ply)
	end

end

if CLIENT then

	SELFCHANGER.value = SELFCHANGER.DefaultValue
	SELFCHANGER.ClientCommands = { }

	function SELFCHANGER.SoundHint(msg, icon, time, snd, color)
		color = color or Color( 255, 222, 102 )
		notification.AddLegacy( msg, icon, time )
		surface.PlaySound( snd )
		MsgC(color, msg .. "\n")
	end

	function SELFCHANGER.ClientCommands.SoundHint()
		SELFCHANGER.SoundHint( net.ReadString(), net.ReadUInt(4), net.ReadUInt(8), net.ReadString(), Color( 137, 222, 255 ) )
	end

	net.Receive("selfchanger", function()
		local command = net.ReadString()
		SELFCHANGER.ClientCommands[command]()
	end)

end

---------------------------------- Left Click ----------------------------------

----[[
if SERVER then
	function SELFCHANGER.ServerCommands.LeftClick( sender )

		if true then return throwDisabled() end

		local entity = net.ReadEntity()
		local sv_path = net.ReadTable()
		local tbl = entity:GetTable()

		if( #sv_path == 0 ) then -- oh god
			SELFCHANGER.SoundHint( sender, "Can't change root entity table.", NOTIFY_ERROR, 3, "buttons/button10.wav" )
			return
		end

		local final, reads, path, failed = navigateTable(tbl,sv_path,root,sender)		

		if not failed then
			final[path] = sender.SelfChangerValue
			SELFCHANGER.SoundHint( sender, "Server value pasted: " .. reads .. '.' .. path .. " = " .. tostring(sender.SelfChangerValue) .. " (a " .. type(sender.SelfChangerValue) .. " value)" , NOTIFY_CLEANUP, 3, "buttons/button14.wav" )
			return true
		else
			SELFCHANGER.SoundHint( sender, "Can't write to this location." , NOTIFY_ERROR, 3, "buttons/button14.wav" )
			return true
		end
	end
end

function TOOL:LeftClick( trace )

	if not IsFirstTimePredicted() then return true end
	if true then return throwDisabled() end

	if CLIENT then
		SELFCHANGER.UpdatePath()
	end

	local entity = trace.Entity
	if checkBannedClasses(entity) then
		return true
	end

	if SERVER then return true end

	local MODE = self:GetClientInfo("realm")
	local root = 'Entity('..entity:EntIndex()..')'

	if MODE == 'CLIENT' then

		local tbl = entity:GetTable()

		if( #SELFCHANGER.path == 0 ) then -- oh god
			SELFCHANGER.SoundHint( "Can't change root entity table.", NOTIFY_ERROR, 3, "buttons/button10.wav" )
			return
		end

		local final, reads, path, failed = navigateTable(tbl,SELFCHANGER.path,root)

		if not failed then
			final[path] = SELFCHANGER.value
			SELFCHANGER.SoundHint( "Client value pasted: " .. reads .. '.' .. path .. " = " .. tostring(SELFCHANGER.value) .. " (a " .. type(SELFCHANGER.value) .. " value)" , NOTIFY_CLEANUP, 3, "buttons/button14.wav" )
			return true
		else
			SELFCHANGER.SoundHint( "Can't write to this location.", NOTIFY_ERROR, 3, "buttons/button10.wav" )
			return true
		end

	end

	if MODE == 'SERVER' then

		net.Start("selfchanger")
			net.WriteString("LeftClick") -- command name
			net.WriteEntity(entity) -- entity to inspect
			net.WriteTable(SELFCHANGER.path) -- path to take
		net.SendToServer()

		return true

	end

end

---------------------------------- Right Click ----------------------------------

if CLIENT then

	function SELFCHANGER.ClientCommands.ReceiveServerValue()
		SELFCHANGER.value = net.ReadType()
		SELFCHANGER.SetUnknown( )
	end

	function StoreValueCL(val,location)
		SELFCHANGER.value = val
		local msg = "Client value '" .. tostring(val) .. "' stored! (a "..type(val).." value)"
		SELFCHANGER.SoundHint( msg, NOTIFY_GENERIC, 5, "ambient/water/drip3.wav" )
		SELFCHANGER.SetUnknown( )
	end

end

if SERVER then

	local function StoreServerValue(ply,val,location)
		ply.SelfChangerValue = val
		local msg = "Server value '" .. tostring(val) .. "' stored! (a "..type(val).." value)"
		SELFCHANGER.SoundHint( ply, msg, NOTIFY_GENERIC, 5, "ambient/water/drip3.wav" )
	end

	local function SendServerValue(value,ply)
		net.Start("selfchanger", true)
			net.WriteString("ReceiveServerValue")
			net.WriteType(value)
		net.Send(ply)
	end

	function SELFCHANGER.ServerCommands.StoreClientValue(sender)
		local value = net.ReadType()
		if value ~= nil then
			sender.SelfChangerValue = value
		end
	end

	function SELFCHANGER.ServerCommands.RequestServerValue(sender)
		local success, err = pcall(SendServerValue, sender.SelfChangerValue, sender)
		if success then
			SELFCHANGER.SoundHint( sender, "Stored server value downloaded.", NOTIFY_GENERIC, 3, "ambient/water/drip3.wav" )
		else
			SELFCHANGER.SoundHint( sender, "Failed to download stored server value: "..err, NOTIFY_ERROR, 8, "buttons/button10.wav" )
			SendServerValue(SELFCHANGER.DefaultValue, sender)
		end
	end

	function SELFCHANGER.ServerCommands.RightClick(sender)

		if true then return throwDisabled() end

		local entity = net.ReadEntity()

		if checkBannedClasses(entity) then
			return -- security, please escort this hacker out
		end

		local sv_path = net.ReadTable()
		local tbl = entity:GetTable()
		local root = 'Entity('..entity:EntIndex()..')'

		if( #sv_path == 0 ) then
			StoreServerValue(sender,tbl,root)
			return
		end

		local final, reads, path, failed = navigateTable(tbl,sv_path,root,sender)		

		if failed then
			SELFCHANGER.SoundHint(sender, "Can't store server value at " .. reads .. '.' .. path .. " (nil or blacklisted)", NOTIFY_ERROR, 3, "buttons/button10.wav")
			return
		end

		final = final[path]
		StoreServerValue(sender,final,reads .. '.' .. path)
		return

	end

end

function TOOL:RightClick( trace )

	if not IsFirstTimePredicted() then return true end
	if true then return throwDisabled() end

	local entity = trace.Entity
	if checkBannedClasses(entity) then
		return true
	end

	if SERVER then return true end

	local MODE = self:GetClientInfo("realm")
	local root = 'Entity('..entity:EntIndex()..')'

	if MODE == 'CLIENT' then

		local tbl = entity:GetTable()

		if( #SELFCHANGER.path == 0 ) then
			StoreValueCL(tbl,root)
			return true
		end

		local final, reads, path, failed = navigateTable(tbl,SELFCHANGER.path,root)		
		final = final[path]

		if failed then
			SELFCHANGER.SoundHint("Can't store client value at " .. reads .. '.' .. path .. " (nil or blacklisted)", NOTIFY_ERROR, 3, "buttons/button10.wav")
			return true
		end

		StoreValueCL(final,reads .. '.' .. path)
		return true


	end

	if MODE == 'SERVER' then

		net.Start("selfchanger")
			net.WriteString("RightClick") -- command name
			net.WriteEntity(entity) -- entity to inspect
			net.WriteTable(SELFCHANGER.path) -- path to take
		net.SendToServer()

		return true

	end

end
--]]--

---------------------------------- Reload ----------------------------------

if CLIENT then 
	function SELFCHANGER.ClientCommands.printTable()

		local msg = net.ReadString()
		local prints = net.ReadString()
		prints = string.Explode("\n", prints, false)
		notification.AddLegacy( msg .. " | See console for details ("..#prints..")", NOTIFY_HINT, 5 )
		for k, v in ipairs(prints) do
			MsgC(Color( 137, 222, 255 ), v .. "\n") -- server color
		end

	end

	function SELFCHANGER.ClientCommands.printString()
		
		local msg = net.ReadString()
		MsgC(Color( 137, 222, 255 ), msg .. "\n")
		notification.AddLegacy( msg, NOTIFY_HINT, 5 )

	end
end

if SERVER then

	local function printTable(ply,root,prints)
		net.Start("selfchanger")
			net.WriteString("printTable")
			net.WriteString(root)
			net.WriteString(prints)
		net.Send(ply)
	end

	local function printString(ply,str)
		net.Start("selfchanger")
			net.WriteString("printString")
			net.WriteString(str)
		net.Send(ply)
	end

	function SELFCHANGER.ServerCommands.Reload(sender)

		local entity = net.ReadEntity()

		if checkBannedClasses(entity) then
			return -- security, please escort this hacker out
		end
		local sv_path = net.ReadTable()
		local tbl = entity:GetTable()
		local root = 'Entity('..entity:EntIndex()..')'

		if( #sv_path == 0 or not sender:KeyDown(IN_USE) ) then
			local prints = PrintTableFancy(tbl,root,0,{})
			prints = table.concat(prints,"\n")
			printTable(sender,root .. " = <table>",prints)
			return
		end

		local final, reads, path = navigateTable(tbl,sv_path,root,sender)
		local value = final[path]
		local typ = type(value)

		if( typ ~= "table" ) then
			printString(sender, reads .. '.' .. path .." = "..tostring(value).." (a "..typ.." value)" ) -- notification
			return
		else
			local prints = PrintTableFancy(tbl[path],reads .. '.' .. path,0,{})
			prints = table.concat(prints,"\n")
			printTable(sender,reads .. '.' .. path  .. " = " .. tostring(value),prints)
			return
		end

	end

end

function TOOL:Reload( trace )

	if not IsFirstTimePredicted() then return true end

	SELFCHANGER.maxnest = self:GetClientNumber("max_nested_prints", 1)

	if SERVER then return true end
	
	local entity = trace.Entity
	if checkBannedClasses(entity) then
		return true
	end

	local MODE = self:GetClientInfo("realm")
	local root = 'Entity('..entity:EntIndex()..')'

	if MODE == 'CLIENT' then -- easy

		local tbl = entity:GetTable()

		if( not SELFCHANGER.path or #SELFCHANGER.path == 0 or not LocalPlayer():KeyDown(IN_USE) ) then
			local prints = PrintTableFancy(tbl,root,0,{})
			notification.AddLegacy( root.." = " .. tostring(tbl) .. " | See console for details ("..#prints..")", NOTIFY_HINT, 5 )
			for k, v in ipairs(prints) do
				MsgC(Color( 255, 222, 102 ), v .. "\n") -- cilent color
			end
			return true
		end

		local final, reads, path = navigateTable(tbl,SELFCHANGER.path,root)

		local value = final[path]
		local typ = type(value)
		if( typ ~= "table" ) then
			local msg = reads .. '.' .. path .." = "..tostring(value).." (a "..typ.." value)"
			MsgC(Color( 255, 222, 102 ), msg .. "\n")
			notification.AddLegacy( msg, NOTIFY_HINT, 5 )
			return true
		else
			local prints = PrintTableFancy(value,reads .. '.' .. path,0,{})
			notification.AddLegacy( reads .. '.' .. path .. " = " .. tostring(tbl) .. " | See console for details ("..#prints..")", NOTIFY_HINT, 5 )
			for k, v in ipairs(prints) do
				MsgC(Color( 255, 222, 102 ), v .. "\n") -- cilent color
			end
			return true
		end

	end

	if MODE == 'SERVER' then
		net.Start("selfchanger")
			net.WriteString("Reload") -- command name
			net.WriteEntity(entity) -- entity to inspect
			net.WriteTable(SELFCHANGER.path) -- path to take
		net.SendToServer()
		return true
	end

end


