local f = io.open("/tmp/ce-portcheck.log","w")
local function say(s) f:write(tostring(s) .. "\n") f:flush() end

local p = io.open("/tmp/diana.pid"); local pid = tonumber(p:read("*l")); p:close()
local a = io.open("/tmp/diana.addr"); local addr = tonumber(a:read("*l"), 16); a:close()
say("target pid " .. pid .. " addr " .. string.format("%X", addr))

local ok, err = pcall(function()
  local opened = openProcess(pid)
  say("openProcess -> " .. tostring(opened))
  say("opened id -> " .. tostring(getOpenedProcessID()))

  local v = readInteger(addr)
  say("readInteger -> " .. tostring(v))

  local b = readBytes(addr, 4, true)
  if b then
    say(string.format("readBytes -> %02X %02X %02X %02X", b[1], b[2], b[3], b[4]))
  else
    say("readBytes -> nil")
  end

  local w = writeInteger(addr, 7654321)
  say("writeInteger -> " .. tostring(w))
  say("readInteger after -> " .. tostring(readInteger(addr)))

  local r = enumMemoryRegions()
  say("enumMemoryRegions -> " .. tostring(r and #r))
end)
if not ok then say("ERROR: " .. tostring(err)) end
say("== done ==")
f:close()
