local mysql = require("core.driver.mysql")
local cjson = require "cjson"

local arg = ngx.req.get_uri_args()

local res = mysql:list("*","HOUSE",10,tonumber(arg.page),"","")



ngx.say(cjson.encode(res))




