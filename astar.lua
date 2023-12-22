// Script was written in early 2020, it was modified later in like 2022 by someone else but that version has been lost to time
// This version is an earlier version, and has many mistakes and issues
// Feel free to copy paste, if you dare.
// Original Pastebin - https://pastebin.com/cn11ca7c


-- When running as a server, convert source's built in navmesh to a table, and save as a JSON file so that the client can read it. 
-- Eventually i'd like to either be able to use the .nav file, or 
if SERVER then
	local map = game.GetMap()
	local navArea = {}
	local total = 0
	if !file.Exists("maps/"..map..".nav", "GAME") then
		print("navmesh file for this map doesnt exist.")
	return end

	local function navInfo()
        -- Loop over all navAreas
		for k,v in pairs(navmesh.GetAllNavAreas()) do
			total = total + 1 -- Count total for /fun/ data for user!
			local currentAdjAreas = {}
            -- Loop over Adjacent areas
            -- TODO fix so only outgoing connections.
			// 2024 me here, I did this ^ I just lost the file, sorry bout it bubz. 
			for i=1,#v:GetAdjacentAreas(),1 do
				table.insert(currentAdjAreas, tostring(v:GetAdjacentAreas()[i]))
			end
            -- Convert the navArea to a table so that we may save it

			// 2024 me here again. Why did I use strings instead of numerical indexes? I have no idea. 
			navArea[tostring(v)] = {
				["Corners"] = { v:GetCorner(0), v:GetCorner(1), v:GetCorner(2), v:GetCorner(3)},
				["Center"] = v:GetCenter(),
				["adjAreas"] = currentAdjAreas,
				["isUnderwater"] = v:IsUnderwater()
			}
		end
	end
	-- Save all that sweet data
	local function saveToFile()
		file.CreateDir("navmeshes")
		file.Write("navmeshes/"..map..".json", util.TableToJSON( navArea ) ) -- Apparently JsonToTable has a 44k character limit, but I've not ran into that issue so im sure it doesnt exist
		local size = file.Size("navmeshes/"..map..".json", "DATA")           
		sizeInMega = math.Round(size/1000000, 2)
		print("Wrote "..total.." CNavAreas to file for "..size.." bytes (~"..sizeInMega.." MB)") // #
	end

navInfo()
saveToFile()
return end


if not CLIENT then return end

if !file.Exists("navmeshes/"..game.GetMap()..".json", "DATA") then print("First run this script as server using lua_openscript to generate the Client's Navmesh") return end

local astar = {}
astar.navMesh = util.JSONToTable( file.Read("navmeshes/"..game.GetMap()..".json", DATA) )


local startTime
local startNode
local endNode
local neighborList
local totalmoves


-- I attempted to use DistToSqr to make sure you always get an area, however i find that that is an expensive process

local function getNode( pos )
	for k,v in pairs(navMesh) do
		if pos.x >= v["Corners"][1].x and pos.x <= v["Corners"][3].x and pos.y >= v["Corners"][1].y and pos.y <= v["Corners"][3].y then
			if (pos.z >= v["Corners"][1].z - 100 and pos.z <= v["Corners"][3].z + 100) or (pos.z <= v["Corners"][1].z + 100 and pos.z >= v["Corners"][3].z - 100) then
				return k
			end
		end
	end
end

-- Heurestic cost estimate
-- Returns the cost for the given navmesh
-- Takes in the start Vector, end Vector, and the Name of the node you wish to find cost
-- Used to determine which node to "visit" next
local function nodeCost( start, goal, index)
	local gcost = navMesh[index]["Center"]:DistToSqr(start)
	local hcost = navMesh[index]["Center"]:DistToSqr(goal)

	local returnTable = {
		["gcost"] = gcost,
		["hcost"] = hcost,
		["fcost"] = gcost + hcost
	}

	return returnTable
end

-- Used when retracing the path so that you have an order to follow.
-- Takes in a node and returns the node used to get to that node
local function getParent( node )
	for k,v in pairs(neighborList) do
		if v["name"] == node then
			return v["parent"]
		end
	end
end


-- Compete the pathing. The path is reversed so it is flipped and returned back to retracePath()
local function completePath( path )
	local reversedPath = table.Reverse( path )
	print("Considered "..totalmoves.." moves in "..SysTime()-startTime.." seconds")
	PrintTable(path)
	return reversedPath
end


-- Retrace the path. Called by astar()
-- Goes through all of the nodes and gets their parents, adding them to the final path.
-- returns the finalized path
local function retracePath( start, goal )
	local path = {}
    -- Set the node to check to goal
	local checkNode = goalNode

    -- loops until we are back to the start, checking all of the parents of nodes
	while not (checkNode == startNode ) do
		table.insert(path, checkNode)
		checkNode = getParent(checkNode)
	end

	return completePath( path )
end


-- Astar function
-- Returns a path
-- Takes two vectors, the position that you are starting from, and the position where you want to go
-- Doesnt always return the best path, and sometimes the path is silly, mainly because of the outgoing connections issues at the top
function astar.astar( start, goal )

	neighborList = {}
	totalmoves = 0
    
	-- Start and Goal must be vectors. 
    -- find the Nodes of the start and goal
	startNode = getNode( start )
	goalNode = getNode( goal )

	startTime = SysTime()
	local openSet = {}
	local closedSet = {}

	if goalNode == nil or startNode == nil then return false end -- Couldnt find the nodes
	if startNode == goalNode then return false end               -- You're already at the goal

    -- insert the startNode into the open Set
	table.insert(openSet, startNode)
	while not table.IsEmpty(openSet) do

		currentNode = openSet[1]
        -- Check all of the values of the open set and looks for the node with the lowest fcost
		for i=1,#openSet do
			local nextNodeCost = nodeCost(start, goal, openSet[i])
			local currentNodeCost = nodeCost( start, goal, currentNode)


			if (nextNodeCost["fcost"] < currentNodeCost["fcost"]) or (nextNodeCost["fcost"] == currentNodeCost["fcost"] and nextNodeCost["hcost"] < currentNodeCost["hcost"]) then
				currentNode = openSet[i]
			end
		end

        -- Remove the value from the open set, and add it to the closed set, indicating that we have checked this node.
		table.RemoveByValue(openSet, currentNode)
		table.insert(closedSet, currentNode)


		totalmoves = totalmoves + 1
		if SysTime() - startTime > 20 then print("timed out -- ".. startTime - SysTime().." Seconds") return false end
        -- Prevent an infinite loop, also the game freezes because we do this in one frame
        
        -- We have made it to the goal and we can return the path we have
		if currentNode == goalNode then
			return retracePath(startNode, goalNode)
		end

        -- Find all of the adjacent areas, and loop through them
		adjAreas = navMesh[currentNode]["adjAreas"]
		for _,v in pairs(adjAreas) do
			local neighbors = {}
			neighbors.name = v
            
            -- Skip nodes we have already checked or nodes that we dont want to path through, like underwater. Any other conditions can be added here as well.
			if table.HasValue(closedSet, neighbors.name) or navMesh[currentNode]["isUnderwater"] then
				continue
				-- goto next
			end

            -- Find the parent information and add the nodes to the open set
            -- Used later on and to add them to nodes to be checked.
			local currentCenter = navMesh[currentNode]["Center"]
			local endCenter = navMesh[neighbors.name]["Center"]

			local newCost = nodeCost(start, goal, currentNode)["gcost"] + currentCenter:DistToSqr( endCenter )
			local neighborCost = nodeCost(start, goal, neighbors.name)["gcost"]

			local isOpenSet = table.HasValue(openSet, neighbors.name)

			if newCost < neighborCost or not isOpenSet then
				table.insert(neighborList, neighbors)

				neighbors.parent = currentNode
				table.insert(neighborList, neighbors)

				if not isOpenSet then
					table.insert(openSet, neighbors.name)
				end
			end

			-- ::next::
		end
	end
	return false
end

return astar
