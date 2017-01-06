local build = require("api.buildimg")
local cjson = require "cjson"
local mysql = require("core.driver.mysql")

local arg = ngx.req.get_uri_args()


local build_id = arg.id

if not build_id then
	local sql = "select ID from BUILD where MAP_NUMBER = %s and BLOCK_NO = %s and BUILD_NO = %s"


	local res = mysql:query(sqlutil:format(ndk.set_var.set_quote_sql_str(arg.m),ndk.set_var.set_quote_sql_str(arg.bl),ndk.set_var.set_quote_sql_str(arg.b) ))
	mysql:closeClient()
	if table.getn(res) == 0 then
		ngx.exit(ngx.HTTP_NOT_FOUND)
		return
	elseif table.getn(res) == 1 then	
		build_id = res[1].ID
	else 
		ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		return
	end
end

ngx.say(cjson.encode(build:data(build_id,"SELECT hr.HOUSE_CODE,hr.HOUSE_STATUS,h.HOUSE_ORDER,h.IN_FLOOR_NAME,h.HOUSE_UNIT_NAME ,h.HOUSE_AREA,po.NAME FROM HOUSE_OWNER_RECORD.HOUSE_RECORD hr left join HOUSE_OWNER_RECORD.HOUSE h on h.ID = hr.HOUSE left join HOUSE_OWNER_RECORD.POWER_OWNER po on po.ID=h.MAIN_OWNER where h.BUILD_CODE = %s")))

ngx.exit(ngx.HTTP_OK)

