
local cjson = require "cjson"
local mysql = require("core.driver.mysql")
local string_util = require("core.util.string")

local BuildImg = {}

local function getHouses(code , house_sql )

	local houses = mysql:query(house_sql:format(ndk.set_var.set_quote_sql_str(code)))

	local house = {}
	local delete_house = {}
	for i = 1, table.maxn(houses) do
		if (houses[i].HOUSE_STATUS and (houses[i].HOUSE_STATUS == 'DESTROY')) then
			table.insert(delete_house,houses[i])	
		else
			house[houses[i].HOUSE_CODE] = houses[i]	
		end
			
	end
	houses = nil

	local locked_sql = "SELECT HOUSE_CODE,TYPE,DESCRIPTION,EMP_NAME,EMP_CODE,LOCKED_TIME FROM HOUSE_OWNER_RECORD.LOCKED_HOUSE where BUILD_CODE = %s"

	local lock_houses = mysql:query(locked_sql:format(ndk.set_var.set_quote_sql_str(code)))

	for i = 1 , table.maxn(lock_houses) do
		if house[lock_houses[i].HOUSE_CODE] then
			if house[lock_houses[i].HOUSE_CODE].locked then
				table.insert(house[lock_houses[i].HOUSE_CODE].locked,lock_houses[i])
			else
				house[lock_houses[i].HOUSE_CODE].locked = {lock_houses[i]}
			end
		end
	end

	lock_houses = nil

	local biz_sql = "SELECT bh.HOUSE_CODE,ob.ID,ob.DEFINE_NAME,ob.APPLY_TIME FROM HOUSE_OWNER_RECORD.BUSINESS_HOUSE bh left join HOUSE_OWNER_RECORD.OWNER_BUSINESS ob on ob.ID = bh.BUSINESS_ID left join HOUSE_OWNER_RECORD.HOUSE h on h.ID = bh.AFTER_HOUSE where (ob.STATUS = 'RUNNING' or ob.STATUS = 'SUSPEND') and h.BUILD_CODE= %s"
	local biz_houses = mysql:query(biz_sql:format(ndk.set_var.set_quote_sql_str(code)))
	for i = 1, table.maxn(biz_houses) do
		if (house[biz_houses[i].HOUSE_CODE]) then
			house[biz_houses[i].HOUSE_CODE].biz = biz_houses[i]
		end
	end

	biz_houses = nil

	return house,delete_house
end

local function comparePri(x,y)
	return x.pri < y.pri
end

local function extractUnitOrder(name)
	return extractNumber(name)
end

local function extractFloorOrder(name)
	if string.find(name,"阁楼") then
		return -100000
	end

	local o = extractNumber(name)
	if string.find(name,"(负)|(地下)") then
		o = o * -1
	end

	return 99999 - o

end

local function extractHouseOrder(name)
	return extractNumber(name)
end

local function extractNumber(name)
	local regex  = [[(\d{4})(?!.*\d+.*)]]
	local m  = ngx.re.match(name,regex,"o")
	if m then
		return tonumber(m[1])
	end

	local regex = "((一|二|三|四|五|六|七|八|九|十)+)(?!.*(一|二|三|四|五|六|七|八|九|十)+.*)"
	m  = ngx.re.match(test,regex,"o")
	if m then
		local s,n = string.gsub(m[1],"^十","1")
		s,n = string.gsub(s,"十$","0")
		s,n = string.gsub(s,"十","")
		s,n = string.gsub(s,"一","1")
		s,n = string.gsub(s,"二","2")
		s,n = string.gsub(s,"三","3")
		s,n = string.gsub(s,"四","4")
		s,n = string.gsub(s,"五","5")
		s,n = string.gsub(s,"六","6")
		s,n = string.gsub(s,"七","7")
		s,n = string.gsub(s,"八","8")
		s,n = string.gsub(s,"九","9")
		return tonumber(s)
	end

	return 0;
	
end


local function getFrame(code)
	local build_sql = "SELECT ID,NAME,_ORDER as pri FROM BUILD_GRID_MAP WHERE BUILD_ID = %s"
	local pages = mysql:query(build_sql:format(ndk.set_var.set_quote_sql_str(code)))
	for i = 1, table.maxn(pages) do
		local row = mysql:query("SELECT ID,TITLE,_ORDER as pri FROM GRID_ROW WHERE GRID_ID='" .. pages[i].ID .. "'")
		local block = mysql:query("SELECT gb.ROW_ID,gb._ORDER as pri,gb.COLSPAN,gb.ROWSPAN,HOUSE_CODE FROM GRID_BLOCK gb left join GRID_ROW gr on gr.ID = gb.ROW_ID WHERE gr.GRID_ID='"  .. pages[i].ID .. "'")
		for j = 1 , table.maxn(row) do
			for k = 1, table.maxn(block) do
				if (block[k].ROW_ID == row[j].ID) then
					block[k].pri = row[j].pri * 100000 + block[k].pri
					if (row[j].blocks) then
						table.insert(row[j].blocks,block[k])
					else
						row[j].blocks = {block[k]}	
					end
				end
			end
			if row[j].blocks then
				table.sort(row[j].blocks,comparePri)
			end
		end
		pages[i].rows = row

		table.sort(pages[i].rows,comparePri)

		pages[i].titles = mysql:query("SELECT _ORDER as pri,TITLE,COLSPAN FROM HOUSE_GRID_TITLE where GRILD_ID ='" .. pages[i].ID .. "'" )
		table.sort(pages[i].titles, comparePri)
	end

	table.sort(pages,comparePri)

	return pages

end

local function createFrame(houses)

	local units = {}
	local layers = {}

	-- 生成单元和层
	for key, value in pairs(houses) do
		if not units[value.HOUSE_UNIT_NAME] then
			units[value.HOUSE_UNIT_NAME] = {pri = extractUnitOrder(value.HOUSE_UNIT_NAME) , TITLE = value.HOUSE_UNIT_NAME, COLSPAN = 1}
		end
		

		if value.IN_FLOOR_NAME then
			value.IN_FLOOR_NAME = string_util.trim(value.IN_FLOOR_NAME)
		else
			value.IN_FLOOR_NAME = ""
		end

		if not layers[value.IN_FLOOR_NAME] then
			layers[value.IN_FLOOR_NAME] = {pri = extractFloorOrder(value.IN_FLOOR_NAME),TITLE = value.IN_FLOOR_NAME,units = {}, blocks = {} }
		end
	end

	-- 分配有单元的房屋 / 计算单元宽度
	for lk, layer in pairs(layers) do
		for uk, unit in pairs(units) do
			for hk, h in pairs(houses) do
				if (h.HOUSE_UNIT_NAME) and (lk == h.IN_FLOOR_NAME) and (uk == h.HOUSE_UNIT_NAME) then
					local h_o = {pri = unit.pri * 100000 + extractHouseOrder(h.HOUSE_ORDER), house = h ,COLSPAN = 1,ROWSPAN = 1}
					if layer.units[h.HOUSE_UNIT_NAME] then
						table.insert(layer.units[h.HOUSE_UNIT_NAME],h_o)
					else
						layer.units[h.HOUSE_UNIT_NAME] = {h_o}	
					end

					if units[h.HOUSE_UNIT_NAME].COLSPAN < table.getn(layer.units[h.HOUSE_UNIT_NAME]) then
						units[h.HOUSE_UNIT_NAME].COLSPAN = table.getn(layer.units[h.HOUSE_UNIT_NAME])
					end

				end
			end
		end
	end



	-- 填空格 / 排序
	local rows = {}
	for lk, layer in pairs(layers) do
		for uk, unit in pairs(units) do
			if layer.units[uk] then
				if (table.getn(layer.units[uk]) < unit.COLSPAN) then
					table.insert(unit,{pri = unit.pri * 100000 + 99999 , COLSPAN = unit.COLSPAN - table.getn(layer.units[uk]),ROWSPAN = 1})
				end
			else
				layer.units[uk] = {pri =  unit.pri * 100000 , COLSPAN = unit.COLSPAN ,ROWSPAN = 1} 
			end	

		end

		for uk,unit in pairs(layer.units) do
			for i = 1, table.maxn(unit) do
				table.insert(layer.blocks,unit[i])
			end
		end


		table.sort(layer.blocks,comparePri)
		layer.units = nil
		table.insert(rows,layer)
	end

	table.sort(rows,comparePri)

	-- 单元排序
	local titles = {} 
	for k,value in pairs(units) do
		table.insert(titles,value)
	end
	table.sort(titles,comparePri)
	table.insert(titles,1,{pri = 0,TITLE="",COLSPAN=1})
	return {rows=rows,titles=titles}

end

function BuildImg:data(code, house_sql)
	local houses, destory_houses = getHouses(code,house_sql)
	local pages = getFrame(code)
	for p = 1, table.maxn(pages) do
		for r = 1,table.maxn(pages[p].rows) do
			for b = 1, table.maxn(pages[p].rows[r].blocks) do
				local block = pages[p].rows[r].blocks[b]
				if block.HOUSE_CODE and houses[block.HOUSE_CODE] then 
					pages[p].rows[r].blocks[b].house = houses[block.HOUSE_CODE]
					houses[block.HOUSE_CODE] = nil
				end
			end
		end
	end



	local result_house = {}
	local no_unit_house = {}
	for k,house in pairs(houses) do

		if house.HOUSE_UNIT_NAME then
			house.HOUSE_UNIT_NAME = string_util.trim(house.HOUSE_UNIT_NAME)
		else
			house.HOUSE_UNIT_NAME = ""
		end
		
		if house.HOUSE_UNIT_NAME == "" then
			table.insert(no_unit_house,house)
		else
			table.insert(result_house,house)
		end
	end
	if table.getn(result_house) > 0 then
		local auto_page = createFrame(result_house)
		auto_page.NAME = "合生页"
		table.insert(pages,auto_page)
	end
	if table.getn(no_unit_house) > 0 then
		local auto_page = createFrame(no_unit_house)
		auto_page.NAME = "无单元页"
		table.insert(pages,auto_page)
	end

	if table.getn(destory_houses) > 0 then
		local auto_page = createFrame(destory_houses)
		auto_page.NAME = "已删除房屋"
		table.insert(pages,auto_page)
	end


	mysql:closeClient()
	
	return pages
	
end

return BuildImg;