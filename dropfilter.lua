dropfile = io.open("drops.html", "rb")

htmltext = dropfile:read("*a")

dropfile:close()

-- every table is preceded with h3, id and fancy name: <h3 id="missionRewards">Missions:</h3>

-- every table begins with <table>, <tbody>
-- every table ends with <tr class="blank-row"><td class="blank-row" colspan="3"></td></tr>, </tbody>




function rarities(text)
	-- minimum and max chance for given "name"
	local min = {}
	local max = {}
	for rarity, percentage in text:gmatch("<td>([%w ]+) %((%d+%.?%d*)%%%)</td>") do
		--print(rarity, percentage)
		percentage = tonumber(percentage)
		
		if not min[rarity] or min[rarity] > percentage then
			min[rarity] = percentage
		end
		
		if not max[rarity] or max[rarity] < percentage then
			max[rarity] = percentage
		end
	end
	
	for k,v in pairs(min) do
		print(k, min[k] .. "% - ".. max[k] .."%")
	end
end

rarities(htmltext)

function writeKeyRemoveLast(str)
	return str:match("(.+) >") or ""
end

function extractChances(text)
	local dropTable = {}
	local writeKey = ""	-- e.g. "Level 40 - 60 Bounty > Rotation A > Stage 1"
	
	local trcount = 0
	local trblankcount = 0
	local tdcount = 0
	local thcount = 0
	local itemcount = 0
	
	-- match each different table
	for h3id, h3name, h3table in text:gmatch("<h%d.-id=\"(.-)\">(.-)</h%d>(<table>.-</table>)") do
		print(h3id, h3name, #h3table)
		
		writeKey = h3id
		-- match each new table row
		-- tr can include:
		-- 1) th (sometimes followed by second th); colspan'ned or not
		-- 2) td: Item name, td: rarity; e.g. 
		-- 3) td class="pad-cell", td: Item name, td: rarity; e.g. Bounties
		-- 4) 
		
		
		for trAttr, tr in h3table:gmatch("<tr(.-)>(.-)</tr>") do
			local padcell = false
			local column = 0	-- used inside td/th loop to determine the column
			trcount = trcount+1
			
			if trAttr and trAttr:find("blank-row", 2, true) then
				-- remove the last element of writeKey
				writeKey = h3id
				trblankcount = trblankcount + 1
			else
				--print("not blank")
				-- padding cell in this tablerow?
				
				
				-- for each tabledelimiter / tableheading
				local itemName, itemChance, modDropChance = "", -1, -1
				
				for ttype, tdhAttr, tdh in tr:gmatch("<t([dh])(.-)>(.-)</t[dh]>") do
					column = column + 1
					
					if tdhAttr:find("pad-cell", 2, true) then
						padcell = true
					end
					
					
					if h3id == "modLocations" or h3id == "blueprintLocations" then
						if #tdh > 0 then
							if ttype == "h" then
								if tdhAttr:find("colspan") then
									writeKey = writeKey .. " > ".. h3id:match("^[^A-Z]+") ..": ".. tdh
									
									if not dropTable[writeKey] then
										dropTable[writeKey] = {}
									end
								end
							elseif ttype == "d" then
								if column == 1 then
									itemName = tdh							
								elseif column == 2 then
									modDropChance = tonumber(tdh:match("(%d+%.?%d*)%%")) / 100
								elseif column == 3 then
									local chance = tonumber(tdh:match("%((%d+%.?%d*)%%%)")) / 100
									itemChance = modDropChance * chance
									
									if dropTable[writeKey][itemName] then
										print("Overwriting ".. itemName .." (".. itemChance ..") in ".. writeKey.."! This shouldnt happen")
									end
									
									dropTable[writeKey][itemName] = itemChance
									
									--print("W|".. writeKey ..": ".. itemName, itemChance)
								end
							else
								error("Unknown type: ".. ttype .."! <td> or <th> expected in table ".. writeKey)
							end
							
						end
						
					elseif h3id == "enemyModTables" or h3id == "enemyBlueprintTables" or h3id == "miscItems" then
						if #tdh > 0 then
							if ttype == "h" then
								if column == 1 then
									writeKey = writeKey .. " > ".. h3id:match("^[^A-Z]+") ..": ".. tdh
								elseif column == 2 then
									modDropChance = tonumber(tdh:match("(%d+%.?%d*)%%")) / 100
									writeKey = writeKey .. " (".. modDropChance*100 .."%)"
									
									if not dropTable[writeKey] then
										dropTable[writeKey] = {}
									end
								else
									error("This Number of columns was not expected: ".. tostring(column) ..", in ".. h3id ..", ".. writeKey)
								end
							elseif ttype == "d" then
								if column == 1 then
									-- it's empty					
								elseif column == 2 then
									itemName = tdh
								elseif column == 3 then
									local chance = tonumber(tdh:match("%((%d+%.?%d*)%%%)")) / 100
									-- if extract modDropChance from Key if not found (saved in header, thats why)
									local modDropChance = modDropChance > 0 and modDropChance or writeKey:match("%((%d+%.?%d*)%%%)")
									
									itemChance = modDropChance * chance
									--print(itemChance .. " = ".. modDropChance .."*".. chance)
									
									if dropTable[writeKey][itemName] then
										print("Overwriting ".. itemName .." (".. itemChance ..") in ".. writeKey.."! This shouldnt happen")
									end
									
									dropTable[writeKey][itemName] = itemChance
									
									print("W|".. writeKey ..": ".. itemName, itemChance)
								end
							else
								error("Unknown type: ".. ttype .."! <td> or <th> expected in table ".. writeKey)
							end
							
						end
					else
						if #tdh > 0 then	-- non-empty
							if ttype == "h" then
								thcount = thcount + 1
								
								if tdh:find("Rotation") and (writeKey:find("> Rotation %w$") or writeKey:find("> [Final ]*Stage")) then
									writeKey = writeKey:match("(.-Rotation )%w") .. tdh:sub(-1)
								
								elseif tdh:find("Stage") and writeKey:find("> [Final ]*Stage") then
									writeKey = writeKeyRemoveLast(writeKey)
									writeKey = writeKey .." > ".. tdh
								else
									writeKey = writeKey .." > ".. tdh
								end
								--print(tdh, writeKey)
								--io.read()
								
							elseif ttype == "d" then
								tdcount = tdcount + 1
								
								if itemName == "" then
									itemName = tdh
									
								elseif itemChance <= 0 then
									itemChance = tonumber(tdh:match("%((%d+%.?%d*)%%%)"))
									
									itemcount = itemcount + 1
									if not dropTable[writeKey] then
										dropTable[writeKey] = {}
									end
									
									if dropTable[writeKey][itemName] then
										print("Overwriting ".. itemName .." (".. itemChance ..") in ".. writeKey.."! This shouldnt happen")
									end
									--print("W|".. writeKey ..": ".. itemName, string.format("%.2f%%",itemChance or tdh))
									--print("W|".. writeKey ..": ".. itemName, itemChance)
									
									dropTable[writeKey][itemName] = itemChance
								end
							else
								error("Unknown type: ".. ttype .."! <td> or <th> expected in table ".. writeKey)
							end
						end
					end
				end
			end
		end
		
		writeKey = ""
	end
	
	print("tr", trcount)
	print("trblank", trblankcount)
	print("th", thcount)
	print("td", tdcount)
	print("items", itemcount)
	
	return dropTable
end

dropTable = extractChances(htmltext)

function filter(dropTbl, name, minChance)
	local minChance = minChance or 0
	local combinedChances = {}
	local sortedCombinedChances = {}
	
	for dropSource, drops in pairs(dropTbl) do
		for item, chance in pairs(drops) do
			if string.find(item, name, 1, true) and chance > minChance then
				print(dropSource, item, chance)
				
				-- str = "missionRewards > Event: Eris/Phalan (Interception) > Rotation C"
				-- missionRewards 
				-- missionRewards > Event: Eris/Phalan (Interception) 
				-- missionRewards > Event: Eris/Phalan (Interception) > Rotation C
				local rotationChance = 1
				local rotationChar = dropSource:match("Rotation (%w)")
				if rotationChar and not dropSource:find("cetusRewards") and not dropSource:find(" (Spy)", 1, true) then
					if rotationChar == "A" then
						rotationChance = 2
					elseif rotationChar == "B" then
						rotationChance = 1/3
					elseif rotationChar == "C" then
						rotationChance = 0.25
					else
						error("Unknown rotationChar: ".. tostring(rotationChar))
					end
				end
				
				local parent = dropSource
				repeat
					--print(parent)
					if not combinedChances[parent] then
						combinedChances[parent] = {}
					end
					
					combinedChances[parent][name] = rotationChance * chance + (combinedChances[parent][name] or 0)
					
					parent = writeKeyRemoveLast(parent)
				until #parent == 0
			end
		end
	end
	print("== Combined Chances ==")
	for k,v in pairs(combinedChances) do
		print(k, string.format("%.2f%%", v[name]))
		table.insert(sortedCombinedChances, k)
	end
	
	table.sort(sortedCombinedChances, function (a, b)
		if combinedChances[a][name] > combinedChances[b][name] then
			return true
		end
	end)
	
	print("== Sorted Combined Chances ==")
	for n, key in pairs(sortedCombinedChances) do
		print(key, string.format("%.2f%%", combinedChances[key][name]))
	end
end

print("Entering interpreter mode")
while true do
	local ok, err = pcall(loadstring(io.read()))
	if not ok then print(err) end
end