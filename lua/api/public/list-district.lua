local mysql = require("core.driver.mysql")
local cjson = require "cjson"

local arg = ngx.req.get_uri_args()

local res = mysql:query("select ID as id , NAME as name from DISTRICT order by CREATE_TIME")
mysql:closeClient()



ngx.say(cjson.encode(res))