-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.


------------- CORE

-- Generated by ChatGPT3.5
local function flattentable(tbl, valuesList)
    for _, value in pairs(tbl) do
        if type(value) == "table" then
            flattentable(value, valuesList) -- Recursively remove keys for nested tables
        else
            table.insert(valuesList, value) -- Keep the value
        end
    end
end

function sumids(ents)
  buf = ""
  for i, e in ipairs(ents) do
    print("id: ", e.name, e:identify()) -- TODO remove this
    buf = buf .. e:identify()
  end
  return buf
end

function task(ops)
  return function()
    srcs = ops.fetch()
    flatsrcs = {}
    flattentable(srcs, flatsrcs)

    flatouts = {}
    flattentable(ops.yield, flatouts)
    initial_build = false
    for i, output in ipairs(flatouts) do
      print("exists? ", output.name)
      if not output:exists() then
        initial_build = true
        break
      end
    end

    -- TODO: in future depend only on build(), not whole smeltfile
    -- herm = hash_function(ops.build)
    -- print("build:", herm)    
    -- insid = herm .. sumids(flatsrcs) 

    insid = sumids(flatsrcs) .. file("SMELT.lua"):identify()  

    if not initial_build then
      currentid = insid .. sumids(flatouts)
    end
    -- print(sumids(flatouts))
    
    if initial_build or not cache_search(currentid) then
      print("BUILDING...")
      ops.build(srcs)
      print("CACHING...")
      cache_add(insid .. sumids(flatouts))
      return ops.yield
    end
    print("SKIPPING!")

    return ops.yield
  end
end

------------- UTILS

-- https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end


-- Applies function f to every value in array t
-- https://stackoverflow.com/questions/11669926/is-there-a-lua-equivalent-of-scalas-map-or-cs-select-function
function map(f, t)
    local t1 = {}
    local t_len = #t
    for i = 1, t_len do
        t1[i] = f(t[i])
    end
    return t1
end

-- Applies function f to every value in table t, walks recursively 
-- Generated by ChatGPT 3.5
function mapr(f, t)
    local t1 = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            t1[k] = mapr(f, v) -- Recursively apply map function for nested tables
        else
            t1[k] = f(v)
        end
    end
    return t1
end

function mapchain(t, fns)
  for i, f in ipairs(fns) do
    t = mapr(f, t)
  end
  return t
end

function tofile(f)
  if type(f) == "userdata" then 
    return f
  end
  return file(f)
end

function runsubtask(t)
  if type(t) == "function" then
    return t()
  end
  return t  
end
  
------------- CONSTRUCTS

-- Make-style simple construct for deriving files using commands
-- srcs = table of input names/files
-- outs = table of output names/files
-- cmds = list of system commands to run
function make(opts)
  return task {
    fetch = function()
      return mapchain(opts.srcs, { runsubtask, tofile })
    end,

    build = function(srcs)
      for _, c in ipairs(opts.cmds) do
        os.execute(c)
      end
    end,

    yield = map(tofile, opts.outs),
  }
end

-- Compile a single C file using gcc
-- ins = C/object filenames 
-- out = filename to write to
function gcc_executable(opts)
  return make {
    srcs = opts.ins,
    outs = { opts.out },
    cmds = { "gcc " .. table.concat(opts.ins, " ") .. " -o " .. opts.out },
  }
end
