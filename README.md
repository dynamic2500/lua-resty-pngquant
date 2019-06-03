---
tagline: PNG encoding & decoding
---

# Required Library
[libimagequant](https://github.com/ImageOptim/libimagequant)

[lodepng](https://github.com/lvandeve/lodepng) (C Build)

## `local pngquant = require('resty.pngquant.png')`

A ffi binding for the [libimagequant](https://github.com/ImageOptim/libimagequant) with processing PNG image

## API

------------------------------------ -----------------------------------------
  * `pngquant.load_blob(blob) -> img:`               open a PNG image from blob binary data for decoding
  * `pngquant.load_from_disk(<string>infile) -> img:`open a PNG image from file on disk for decoding
  * `img.compress.[opt]:`                           set/read option for compress process (must set before run get_blob() for save() function)
  * `img:get_blob():`                               get JPEG image to binary string after compress
  * `img:save():`                                   save JPEG image to disk (must set img.compress.outfile)
------------------------------------ -----------------------------------------

### `pngquant.load_blob(blob) -> img`

Open a PNG image and read its header. `blob` is whole image binary string

The return value is an image object which gives information about the file
and can be used to load and decode the actual pixels. It has the fields:

  * `w`, `h`: width and height of the image.

### `img.compress.[opt]`

Set settings for compress process. `opt` are some options as follow:

  * `outfile<string>`: path to file on disk to save.
  * `speed<int>`: `1..10` range. Speed to compress, higher is faster but low compressed sized
  * `quality<int>`: `0..100` range. you know what that is.
  * `max_colors<int>`: `2..256` range. maximum color using for compress. (default 256)
  * `min_posterization<int>`: `0..4` range. Ignores given number of least significant bits in all channels, posterizing image to 2^bits levels. 0 gives full quality. Use 2 for VGA or 16-bit RGB565 displays, 4 if image is going to be output on a RGB444/RGBA4444 display (e.g. low-quality textures on Android).

### `img:get_blob() -> return <string> binary data`

Get image data in binary string after compress process

### `img:save()`

Save image to disk base on img.compress.outfile setting. Must use before get_blob()

## Sample Code

**Nginx Configuration**
~~~~Nginx
server {
    listen 80;
    location = /favicon.ico {
        empty_gif;
    }
    location ~ /proxy(.*) {
        ## can use root or proxy_pass to get data from local or remote site
        # proxy_pass https://<origin>$1;
        root /dev/shm;
    }
    location / {
        content_by_lua_file resty-pngquant-sample.lua;
    }
}
~~~~

----
**resty-pngquant-sample.lua**
~~~~lua

local pngquant = require("resty.pngquant.png") -- load library
-- get data direct from nginx
local res = ngx.location.capture('/proxy'..ngx.var.request_uri) -- get data from nginx location /proxy by subrequest 
local img = pngquant.load_blob(res.body) -- create object img
-- get data from disk
-- local img = pngquant.load_from_disk('/dev/shm/proxy/inputhd.jpg') -- create object img
local outfile = '/dev/shm/proxy/inputhd_new.jpg' -- declare outfile path
img.compress.outfile = outfile -- set outfile setting
img.compress.quality = 50 -- set quality
img.compress.speed = 9 -- set quality
img:save() -- save file to disk
ngx.print(img:get_blob()) -- return image after compress to end user
~~~~
