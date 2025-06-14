# Base94

A pretty fast Luau Base94 encoder

## Usage

```lua
local Base94 = require(path.to.Base94)

local data = buffer.fromstring("Hello, world!")

local encodedData = Base94.encode(data) -- buffer: "0UB,/8uYl48{/1E B"
local decodedData = Base94.decode(encodedData) -- buffer: "Hello, world!"

print(buffer.tostring(decodedData)) -- "Hello, world!"
```
