local P=assert(dofile('lua/quickbridge_processor_v29.lua'))
local checks=0
local function eq(a,b) checks=checks+1;assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function run(prefix,base,shift,expected)
 local ctx={input='',opts={ascii_mode=false,prediction=false}}
 function ctx:get_option(k) return self.opts[k] end
 function ctx:has_menu() return false end
 function ctx:clear() self.input='' end
 function ctx:push_input(s) self.input=self.input..s;return true end
 local env={engine={context=ctx}}
 local out={}
 function env.engine:commit_text(s) out[#out+1]=s end
 local function key(k,s)
  local e={keycode=k:byte()}
  function e:shift()return not not s end
  function e:release()return false end
  function e:ctrl()return false end
  function e:alt()return false end
  function e:super()return false end
  return P.func(e,env)
 end
 for c in prefix:gmatch('.') do eq(key(c),1) end
 eq(key(base,shift),1)
 eq(table.concat(out),expected)
 eq(ctx.input,'')
end
local symbols={{"'",'"'},{',','<'},{'-','_'},{'.','>'},{'/','?'},{';',':'},{'=','+'},{'[','{'},{'\\','|'},{']','}'}}
for _,pair in ipairs(symbols) do
 for x=97,122 do
  local letter=string.char(x)
  run(letter,pair[1],false,letter..pair[1])
  run(letter,pair[1],true,letter..pair[2])
  run(letter,pair[2],true,letter..pair[2])
 end
 run('hello',pair[1],true,'hello'..pair[2])
end
print('US physical punctuation matrix:',checks,'assertions, mocked Rime')
