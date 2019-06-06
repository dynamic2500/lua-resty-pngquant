local _M = {
	name = "pngquant ffi module"
}

local ffi = require('ffi')
local liblodepng = require ("resty.pngquant.liblodepng")
local libimagequant = require ("resty.pngquant.libimagequant")

local function set_compress_options(attr,options)
	local optionTable = {
		max_colors = function (v)
				return libimagequant.liq_set_max_colors(attr,v) -- int
			end,
		speed = function (v)
				return libimagequant.liq_set_speed(attr,v) -- int
			end,
		min_opacity = function (v)
				return libimagequant.liq_set_min_opacity(attr,v) -- int
			end,
		min_posterization = function (v)
				return libimagequant.liq_set_min_posterization(attr,v) -- int
			end,
		quality = function (v)
				return libimagequant.liq_set_quality(attr,v,v) -- <int>min, <int>max
			end,
		last_index_transparent = function (v)
				libimagequant.liq_set_last_index_transparent(attr,v) -- int
			end,
		outfile = function (v) return 0 end
	}

	for option,values in pairs (options)
	do
		if (option) then
			optionTable[option](values)
		end

	end
end

-- input param is output from load()
local function compress(img)
	local return_data = ""
	if (img.compressed_data == nil) then
		local attr = libimagequant.liq_attr_create()
		set_compress_options(attr,img["compress"])
		local width = img["width"]
		local height = img["height"]
		local input_image  = libimagequant.liq_image_create_rgba(attr, img["raw_rgba_pixels"], width, height, 0);
		local quantization_result = ffi.new("liq_result *[1]")
		local liq_img_quantize = libimagequant.liq_image_quantize(input_image, attr, quantization_result)

		if (liq_img_quantize ~= libimagequant.LIQ_OK) then
			return nil
		end

		local pixels_size = width * height
		local raw_8bit_pixels = ffi.new("unsigned char [?]",pixels_size)
		libimagequant.liq_set_dithering_level(quantization_result[0], 1.0);
		libimagequant.liq_write_remapped_image(quantization_result[0], input_image, raw_8bit_pixels, pixels_size);
		local palette = libimagequant.liq_get_palette(quantization_result[0]);
		local state = ffi.new("LodePNGState")
		liblodepng.lodepng_state_init(state);
		state.info_raw.colortype = liblodepng.LCT_PALETTE;
		state.info_raw.bitdepth = 8;
		state.info_png.color.colortype = liblodepng.LCT_PALETTE;
		state.info_png.color.bitdepth = 8;
		for i=0,palette.count-1,1
		do
			liblodepng.lodepng_palette_add(state.info_png.color, palette.entries[i].r, palette.entries[i].g, palette.entries[i].b, palette.entries[i].a);
			liblodepng.lodepng_palette_add(state.info_raw, palette.entries[i].r, palette.entries[i].g, palette.entries[i].b, palette.entries[i].a);
		end

		local output_file_data = ffi.new("unsigned char *[1]")
		local output_file_size = ffi.new("size_t [?]",4)
		local out_status = liblodepng.lodepng_encode(output_file_data, output_file_size, raw_8bit_pixels, width, height, state);
		if(out_status ~= 0)then
			return nil
		end
		return_data = ffi.string(output_file_data[0],tonumber(output_file_size[0]))
		--- free memory
		libimagequant.liq_result_destroy(quantization_result[0])
		libimagequant.liq_image_destroy(input_image);
		libimagequant.liq_attr_destroy(attr);
		local p = ffi.gc(raw_8bit_pixels,nil)
		p = nil
		ffi.C.free(p)
		liblodepng.lodepng_state_cleanup(state);
		img.compressed_data = return_data
	else
		return_data = img.compressed_data
	end

	if (img["compress"]["outfile"]) then
		local fout = io.open(img["compress"]["outfile"],"w")
		if (fout) then
			fout:write(return_data)
			fout:close()
			return 0
		else
			return nil
		end
	end
	return return_data
end

local function save(img)
	if (img["compress"]["outfile"]) then
		compress(img)
	else
		return nil
	end
end

local function get_blob(img)
	img["compress"]["outfile"] = nil
	return compress(img)
end

local function load(data,blobData)
	local width = ffi.new("unsigned int[1]")
	local height = ffi.new("unsigned int[1]")
	local raw_rgba_pixels = ffi.new("unsigned char *[1]")
	local status = 0
	if (blobData) then
		status = liblodepng.lodepng_decode32(raw_rgba_pixels, width, height, data, #data)
	else
		status = liblodepng.lodepng_decode32_file(raw_rgba_pixels, width, height, data)
	end
	if(status ~= 0) then
		return nil
	end
	local compress_options = {
		max_colors = nil,
		speed = nil,
		min_opacity = nil,
		min_posterization = nil,
		quality = nil,
		last_index_transparent = nil,
		outfile = nil
	}
	local img = {
		raw_rgba_pixels = raw_rgba_pixels[0],
		width = width[0],
		height = height[0],
		stride = width[0] * 4,
		compress = compress_options,
		compressed_data = nil,
	}
	img.save = function () return save(img) end
	img.get_blob = function() return get_blob(img) end
	return img
end

local function load_blob(blob)
	return load(blob,true)
end

local function load_from_disk(infile)
	return load(infile,false)
end

_M.load_blob = load_blob
_M.load_from_disk = load_from_disk
return _M
