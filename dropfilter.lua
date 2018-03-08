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
			trcount = trcount+1
			
			if trAttr and trAttr:find("blank-row", 2, true) then
				-- remove the last element of writeKey
				writeKey = h3id
				trblankcount = trblankcount + 1
			else
				--print("not blank")
				-- padding cell in this tablerow?
				
				
				-- for each tabledelimiter / tableheading
				local itemName, itemChance = "", 0
				
				for ttype, tdhAttr, tdh in tr:gmatch("<t([dh])(.-)>(.-)</t[dh]>") do
					
					if tdhAttr:find("pad-cell", 2, true) then
						padcell = true
					end
					
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
							print(tdh, writeKey)
							--io.read()
							
						elseif ttype == "d" then
							tdcount = tdcount + 1
							
							if itemName == "" then
								itemName = tdh
								
							elseif itemChance == 0 then
								itemChance = tonumber(tdh:match("%((%d+%.?%d*)%%%)"))
								
								itemcount = itemcount + 1
								if not dropTable[writeKey] then
									dropTable[writeKey] = {}
								end
								
								if dropTable[writeKey][itemName] then
									print("Overwriting ".. itemName .." (".. itemChance ..") in ".. writeKey.."! This shouldnt happen")
								end
								--print("W|".. writeKey ..": ".. itemName, string.format("%.2f%%",itemChance or tdh))
								print("W|".. writeKey ..": ".. itemName, itemChance)
								
								dropTable[writeKey][itemName] = itemChance
							end
						else
							error("Unknown type: ".. ttype .."! <td> or <th> expected in table ".. writeKey)
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
end

extractChances(htmltext)