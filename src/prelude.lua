-- app = link {
--   name = "app",
--   objs = {
--     main(),
--     libfoo(),
--   },
-- }

-- local main = cc_object {
--   target = "main.c",
--   hdrscan = true,
-- }

-- local libfoo = download {
--   out = "libfoo.o",
--   url = "........",
--   md5 = "........",
-- }

-- Generated by ChatGPT3.5
local function removeKeysAndCollectValues(tbl, valuesList)
    for _, value in pairs(tbl) do
        if type(value) == "table" then
            removeKeysAndCollectValues(value, valuesList) -- Recursively remove keys for nested tables
        else
            table.insert(valuesList, value) -- Keep the value
        end
    end
end

function sumids(ents)
  buf = ""
  for i, e in ipairs(ents) do
    print("[IDENTIFY]", e.name, e:identify()) -- TODO remove this
    buf = buf .. e:identify()
  end
  return buf
end

function task(ops)
  return function()
    srcs = ops.fetch()
    flatsrcs = {}
    removeKeysAndCollectValues(srcs, flatsrcs)

    flatouts = {}
    removeKeysAndCollectValues(ops.yield, flatouts)
    initial_build = false
    for i, output in ipairs(flatouts) do
      print("[CHECK EXISTS]", output.name)
      if not output:exists() then
        initial_build = true
        break
      end
    end

    -- TODO: in future depend only on build(), not whole smeltfile
    insid = sumids(flatsrcs) .. file("SMELT.lua"):identify()
    print("[IDENTIFY]", file("SMELT.lua").name)  -- dbg
    currentid = insid .. sumids(flatouts)
    -- print(sumids(flatouts))

    if initial_build or not cache_search(currentid) then
      print("[BUILDING]")
      ops.build(srcs)
      print("[CACHING]")
      print(ops.yield.output:exists())
      cache_add(insid .. sumids(flatouts))
      return ops.yield
    end

    return ops.yield
  end
end

function gcc_executable(opts)
  opts.name = tofile(opts.name)
  opts.outf = tofile(opts.outf)
  return task {
    fetch = function ()
     return { main = opts.name }
    end,
    build = function (srcs)
      os.execute("gcc " .. srcs.main.name .. " -o " .. opts.outf.name )
    end,
    yield = { output = opts.outf } 
  } 
end

function tofile(f)
  if type(f) == "userdata" then 
    return f
  end
  return file(f)
end
