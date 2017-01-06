local cjson = require "cjson.safe"
local weedfs = require "weedfs"


function get_img(card_number)
	local res = ngx.location.capture("/ttserver/" .. card_number)

	
	if res.status == 200 then
		local fid
		local person_info = cjson.decode(res.body)
		if (person_info == nil) then
			fid = res.body
		else
			fid = person_info.img_fid
		end
		ngx.log(ngx.DEBUG,"redirect:" .. fid)
		ngx.redirect('/img/orig/' .. fid)
	else
		ngx.exit(res.status)
		return
	end
end

function put_person_files(card_number,img_md5)
	ngx.log(ngx.DEBUG,"put person img")
	local person_info
	local res = ngx.location.capture("/ttserver/" .. card_number)

	if res.status == 200 then
		person_info = cjson.decode(res.body)
		if (person_info == nil) then
			ngx.exit(404)
		end
	else
		ngx.exit(res.status)
		return
	end

	local code , body = weedfs:upload()
	if (code ~= 201) then
		ngx.exit(code)
		return
	end

	if person_info.img_fid ~= nil then
		weedfs:delete(person_info.img_fid)
	end 

	person_info.img_fid = body.fid
	person_info.img_md5 = img_md5
	local person_str = cjson.encode(person_info)

    local res = ngx.location.capture(
        "/ttserver/" .. card_number,{method = ngx.HTTP_PUT,body=person_str} 
        )

    if res.status == 201 then
    	ngx.say(person_str)	
    end
	ngx.exit(res.status)
end

function put_person(card_number)
	ngx.log(ngx.DEBUG,"begin put_person")
	ngx.req.read_body()
	local post_args = ngx.req.get_post_args();
	local person = cjson.decode(post_args.person)
	if (person == nil) then
	    ngx.exit(505)
		return	
	end

	local orig_person
	local res = ngx.location.capture("/ttserver/" .. card_number)

	if res.status == 200 then
		orig_person = cjson.decode(res.body)
		
		if orig_person == nil then
			orig_person = {
				img_md5 = 'na',
				img_fid = res.body
			}
		end
	end

	local exit_code = 201

	if (orig_person == nil) then
		person.img_md5 = nil
		exit_code = 202
	else
		person.img_fid = orig_person.img_fid
		if person.img_md5 ~= orig_person.img_md5 then
			person.img_md5 = orig_person.img_md5
			exit_code = 202
		end
	end

	local person_str = cjson.encode(person)

	local put_res = ngx.location.capture(
        	"/ttserver/" .. card_number,{method = ngx.HTTP_PUT,body=person_str} 
            )
	if put_res.status == 201 then
		if (exit_code == 201) then
			ngx.log(ngx.DEBUG,"use cache")
			ngx.say(person_str)
		end
		ngx.exit(exit_code)
	else
		ngx.exit(put_res.status)
	end
	--
end




if (ngx.var.arg_number == nil) or (ngx.var.arg_type == nil) then
	ngx.log(ngx.DEBUG,"number or type is nil")
	ngx.exit(400)
	return 
end

local process_type = ngx.var.arg_type;
local process_number = ngx.var.arg_number;

if process_type == "info" then
	put_person(process_number)
elseif process_type == "file" then
	if (ngx.var.arg_md5 == nil) then
		ngx.log(ngx.DEBUG,"md5 is nil")
		ngx.exit(400)
	else
		put_person_files(process_number,ngx.var.arg_md5)
	end

elseif process_type == "img" then
	get_img(process_number)
end


--put_person(ngx.var.arg_number)