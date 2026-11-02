-- v1.0.2 targeted: two lowercase Latin letters + punctuation,
-- multi-period tail and Chinese candidate controls (mocked Rime).
local P=assert(dofile('lua/quickbridge_processor_v29.lua'))
local G=assert(dofile('tests/quickbridge_prediction_guard_v21_fixture.lua'))
local checks=0
local function eq(actual,expected,label)
 checks=checks+1
 if actual~=expected then
   error((label or '?')..': expected '..tostring(expected)..' got '..tostring(actual),2)
 end
end
local function make()
 local out={};local c={input='',prediction=false,opts={prediction=true,ascii_mode=false}}
 function c:get_option(k) return self.opts[k] end
 function c:has_menu() return self.prediction or self.input=='of' or self.input=='f' end
 function c:push_input(x) self.input=self.input..x;return true end
 function c:clear() self.input='';self.prediction=false end
 function c:get_selected_candidate()return {text='火'}end
 function c:commit()out[#out+1]='火';self:clear()end
 local comp={}
 function comp:empty() return not c.prediction end
 function comp:back()
  local s={}
  function s:has_tag(k)return k=='prediction' end
  return s
 end
 c.composition=comp
 local e={engine={context=c}}
 function e.engine:commit_text(s) out[#out+1]=s end
 local function key(k,shift)
   local code=type(k)=='number' and k or string.byte(k)
   local x={keycode=code}
   function x:release()return false end
   function x:shift()return not not shift end
   function x:ctrl()return false end
   function x:alt()return false end
   function x:super()return false end
   local result=P.func(x,e)
   if result==2 then result=G.func(x,e) end
   return result
 end
 local function typed(s)
   for x in s:gmatch('.') do eq(key(x),1,'type letter') end
 end
 local function value()return table.concat(out)end
 return c,e,key,typed,value
end

local symbols={{',','<'},{'.','>'},{'/','?'},{';',':'},{"'",'"'},{'-','_'},{'=','+'},{'[','{'},{']','}'},{'\\','|'}}
for a=97,122 do for b=97,122 do
 local code=string.char(a,b)
 for _,symbol in ipairs(symbols) do
  for _,variant in ipairs({{symbol[1],false,symbol[1]},
                           {symbol[1],true,symbol[2]},
                           {symbol[2],true,symbol[2]}}) do
    local c,e,key,typed,value=make()
    typed(code)
    eq(key(variant[1],variant[2]),1,'punct key')
    eq(value(),code..variant[3],'two-letter punctuation')
    eq(c.input,'','clear composition')
  end
 end
end end

for _,entry in ipairs({
 {'wo...','wo','...'}, {'a...','a','...'},
 {'hello...','hello','...'}, {'wo+...','wo','+...'},
 {'vd,,','vd',',,'}, {'of?!','of','?!'}, {'wo.;','wo','.;'}
}) do
 local c,e,key,typed,value=make()
 typed(entry[2])
 for x in entry[3]:gmatch('.') do eq(key(x),1,'tail punctuation') end
 eq(value(),entry[1],'full sequence')
 eq(c.input,'','tail clears preedit')
end
-- A fresh Chinese Quick sequence must work after Latin punctuation.
do
 local c,e,key,typed,value=make()
 typed('wo')
 eq(key('.'),1);typed('of')
 eq(key('2'),2,'of2 still delegated to native Chinese')
 eq(c.input,'of','new Quick candidate preserved')
 eq(value(),'wo.','English part preserved')
end
-- Number row and modified number row after two-letter Quick remain native.
for _,word in ipairs({'wo','of','vd','hi'}) do
 for _,keycode in ipairs({49,50,57}) do
  local c,e,key,typed,value=make();typed(word)
  eq(key(keycode),2,'top-row candidate delegated')
  eq(c.input,word,'top-row preserves Quick')
  local d,f,k,t,v=make();t(word)
  eq(k(keycode,true),2,'Shift+number delegated')
  eq(d.input,word,'Shift+number preserves Quick')
 end
end
-- Single letter + Space must keep Chinese first-character selection.
do
 local c,e,key,typed,value=make();typed('f')
 eq(key(32),1);eq(value(),'火')
end
-- Two-letter + Space stays delegated to the native Rime menu.
do
 local c,e,key,typed,value=make();typed('of')
 eq(key(32),2);eq(value(),'');eq(c.input,'of')
end
print(('TWO LETTER PUNCT: %d assertions (processor+guard with mocked Rime)'):format(checks))
