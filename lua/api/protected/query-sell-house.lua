-- 取房屋信息

local mysql = require("core.driver.mysql")
local cjson = require "cjson"

local arg = ngx.req.get_uri_args()

local res

local query = [[select h.ID as HOUSE_CODE,h.HOUSE_ORDER,h.HOUSE_UNIT_NAME,h.IN_FLOOR_NAME,h.HOUSE_AREA,h.USE_AREA,
  h.COMM_AREA,h.SHINE_AREA,h.LOFT_AREA,
  (select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.HOUSE_TYPE) as HOUSE_TYPE,
   (select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.USE_TYPE) as USE_TYPE ,
   (select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.STRUCTURE) as STRUCTURE,h.UNIT_NUMBER,
(select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.KNOT_SIZE) as KNOT_SIZE,h.ADDRESS,
(select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.EAST_WALL) as EAST_WALL,
(select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.SOUTH_WALL) as SOUTH_WALL,
(select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.NORTH_WALL) as NORTH_WALL,
(select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.WEST_WALL) as WEST_WALL,
(select _VALUE from DB_PLAT_SYSTEM.WORD where ID= h.DIRECTION) as DIRECTION,
b.BUILD_NO,b.DEVELOPER_NUMBER,b.DOOR_NO,s.NAME as SECTION_NAME, d.ID as DISTRICT_ID
from HOUSE h left join BUILD b on b.ID = h.BUILDID LEFT JOIN PROJECT p on p.ID = b.PROJECT_ID
LEFT JOIN SECTION s on s.ID = p.SECTIONID LEFT JOIN DISTRICT d on d.ID = s.DISTRICT where h.DELETED = false]]

if arg.type == "MAP_NUMBER" then
	query = query .. [[ and b.MAP_NUMBER = %s and b.BLOCK_NO = %s and b.BUILD_NO = %s and h.HOUSE_ORDER = %s]]
	res = mysql:query(query:format(ndk.set_var.set_quote_sql_str(arg.map),ndk.set_var.set_quote_sql_str(arg.block),ndk.set_var.set_quote_sql_str(arg.build),ndk.set_var.set_quote_sql_str(arg.house)))
elseif arg.type == "HOUSE_CODE" then
	query = query .. [[ and h.ID = %s ]]
	res = mysql:query(query:format(ndk.set_var.set_quote_sql_str(arg.id)))
elseif arg.type == "UNIT_NUMBER" then
	query = query .. [[ and h.UNIT_NUMBER = %s ]]
	res = mysql:query(query:format(ndk.set_var.set_quote_sql_str(arg.unit)))
else
	ngx.exit(ngx.HTTP_BAD_REQUEST)
	return 
end

if table.getn(res) == 1 then
	local sell_data = mysql:query([[SELECT * from OLD_HOUSE_SELL ohs LEFT JOIN HOUSE_SELL_INFO hsi on hsi.ID = ohs.HOUSE_SELL_INFO WHERE  hsi.HOUSE = ']] .. res[1].HOUSE_CODE .. "'")
	mysql:closeClient()
	if (table.getn(sell_data) == 0) then
		ngx.say(cjson.encode({house=res[1] , status="OK"}))
		ngx.exit(ngx.HTTP_OK)
	elseif (table.getn(sell_data) == 1) then
		ngx.say(cjson.encode({house=res[1], sell=sell_data[1], status="EXISTS"}))
		ngx.exit(ngx.HTTP_OK)
	else
		ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	end
elseif table.getn(res) == 0 then
	-- TODO 应该查一下档案
	mysql:closeClient()
	ngx.exit(ngx.HTTP_NOT_FOUND)

else 
	mysql:closeClient()
	ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

