--!native
--!optimize 2

local lookupValueToCharacter = buffer.create(94)
local lookupCharacterToValue = buffer.create(256)
local powersOf94 = {94^4, 94^3, 94^2, 94^1, 1}
local alphabetStart = 33 -- '!'

for i = 0,93 do
	buffer.writeu8(lookupValueToCharacter, i, alphabetStart + i)
	buffer.writeu8(lookupCharacterToValue, alphabetStart + i, i)
end

local function encode(input: buffer): buffer
	local inLen = buffer.len(input)
	local full = math.floor(inLen/4)
	local rem  = inLen % 4
	local outLen = full*5 + (rem>0 and rem+1 or 0)
	local out = buffer.create(outLen)

	-- full 4-byte chunks
	for ci=0,full-1 do
		local baseIn = ci*4
		local v1 = buffer.readu8(input, baseIn)
		local v2 = buffer.readu8(input, baseIn+1)
		local v3 = buffer.readu8(input, baseIn+2)
		local v4 = buffer.readu8(input, baseIn+3)
		local chunk = bit32.bor(
			bit32.lshift(v1,24),
			bit32.lshift(v2,16),
			bit32.lshift(v3,8),
			v4
		)
		-- decompose into five 0–93 digits
		local digits = {}
		for i=5,1,-1 do
			digits[i] = chunk % 94
			chunk = math.floor(chunk/94)
		end
		-- write out as chars
		local baseOut = ci*5
		for i=1,5 do
			buffer.writeu8(out, baseOut + i - 1, buffer.readu8(lookupValueToCharacter, digits[i]))
		end
	end

	-- final partial chunk
	if rem>0 then
		local baseIn = full*4
		local b1 = buffer.readu8(input, baseIn)
		local b2 = (rem>1 and buffer.readu8(input,baseIn+1) or 0)
		local b3 = (rem>2 and buffer.readu8(input,baseIn+2) or 0)
		local b4 = 0
		local chunk = bit32.bor(
			bit32.lshift(b1,24),
			bit32.lshift(b2,16),
			bit32.lshift(b3,8),
			b4
		)
		local digits = {}
		for i=5,1,-1 do
			digits[i] = chunk % 94
			chunk = math.floor(chunk/94)
		end
		local baseOut = full*5
		-- we only need rem+1 output chars
		for i=1,rem+1 do
			buffer.writeu8(out, baseOut + i - 1, buffer.readu8(lookupValueToCharacter, digits[i]))
		end
	end

	return out
end

local function decode(input: buffer): buffer
	local inLen = buffer.len(input)
	local full = math.floor(inLen/5)
	local rem  = inLen % 5
	if rem == 1 then rem = 0 end  -- 1-char tail is invalid
	local outLen = full*4 + (rem>0 and rem-1 or 0)
	local out = buffer.create(outLen)

	-- full 5-char chunks
	for ci=0,full-1 do
		local baseIn = ci*5
		local value = 0
		for i=1,5 do
			local c = buffer.readu8(input, baseIn + i - 1)
			local d = buffer.readu8(lookupCharacterToValue, c)
			value = value + d * powersOf94[i]
		end
		-- extract b1..b4
		local baseOut = ci*4
		for i=0,3 do
			local shift = 24 - (i*8)
			local byte = bit32.band(bit32.rshift(value, shift), 0xFF)
			buffer.writeu8(out, baseOut + i, byte)
		end
	end

	-- partial tail
	if rem>0 then
		local baseIn = full*5
		local value = 0
		for i=1,rem do
			local c = buffer.readu8(input, baseIn + i - 1)
			local d = buffer.readu8(lookupCharacterToValue, c)
			value = value + d * powersOf94[i]
		end
		-- pad the rest with highest digit (93)
		for i=rem+1,5 do
			value = value + 93 * powersOf94[i]
		end
		-- extract real bytes (rem-1 of them)
		local chunk = value
		for i=0,rem-2 do
			local shift = 24 - (i*8)
			local byte = bit32.band(bit32.rshift(chunk, shift), 0xFF)
			buffer.writeu8(out, full*4 + i, byte)
		end
	end

	return out
end

return {
	encode = encode,
	decode = decode,
}
