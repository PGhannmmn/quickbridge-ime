-- Integration audit: actual v2.8 processor + actual v2.1 prediction guard.
-- Mock candidate page/commit wiring; no real Weasel/TSF available.
local proc=assert(dofile('lua/quickbridge_processor_v29.lua'))
local guard=assert(dofile('tests/quickbridge_prediction_guard_v21_fixture.lua'))
local cases,asserts=0,0
local function eq(a,b,msg)
 asserts=asserts+1
 if a~=b then error((msg or 'assert')..' expected '..tostring(b)..' got '..tostring(a),2) end
end
local function run(name,fn)fn();cases=cases+1;print('PASS '..name)end
local function state()
 local outputs={};local c={input='',predict=false,selected_index=0,opts={prediction=true,ascii_mode=false}}
 function c:get_option(n)return self.opts[n]end
 function c:has_menu()return self.predict or self.input=='of' end
 function c:push_input(s)self.input=self.input..s;return true end
 function c:clear()self.input='';self.predict=false end
 local seg={}
 function seg:has_tag(t)return t=='prediction' and c.predict end
 function seg:get_candidate_at(i)
  local t=({[0]='們',[1]='我',[9]='意思',[10]='人'})[i]
  if t then return {text=t} end
 end
 setmetatable(seg,{__index=function(_,k)if k=='selected_index' then return c.selected_index end end})
 local cmp={};function cmp:empty()return not c.predict end;function cmp:back()return seg end
 c.composition=cmp
 function c:select(i)
  local v=seg:get_candidate_at(i);if v then outputs[#outputs+1]=v.text;self:clear() end
 end
 local env={engine={context=c}}
 function env.engine:commit_text(t)outputs[#outputs+1]=t end
 return c,env,outputs
end
local function send(e,kc,opts)
 opts=opts or {};if type(kc)=='string' then kc=string.byte(kc)end
 local k={keycode=kc}
 for _,name in ipairs({'release','shift','ctrl','alt','super'}) do k[name]=function()return not not opts[name]end end
 local a=proc.func(k,e)
 if a==2 then a=guard.func(k,e) end
 return a
end
run('main Shift+1 after Chinese uses prediction guard, not punctuation',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,'!',{shift=true}),1);eq(table.concat(o),'你們');eq(c.predict,false)
end)
run('plain main row 1 after prediction types literal 1 and closes',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,'1'),1);eq(table.concat(o),'你1');eq(c.predict,false)
end)
run('second association page Shift+1 chooses absolute index nine',function()
 local c,e,o=state();o[#o+1]='好';c.predict=true;c.selected_index=9;eq(send(e,'!',{shift=true}),1);eq(table.concat(o),'好意思')
end)
run('NumPad plain 1 never selects association suffix',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,0xffb1),1);eq(table.concat(o),'你1');eq(c.predict,false)
end)
run('NumPad plus dismisses prediction and inserts literal plus',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,0xffab),1);eq(table.concat(o),'你+');eq(c.predict,false)
end)
run('punctuation after Chinese dismisses predictor without selecting word',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,','),1);eq(table.concat(o),'你,');eq(c.predict,false)
end)
run('prediction next Latin letter starts fresh composition',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,'h'),1);eq(c.predict,false);eq(c.input,'h')
end)
run('Shift+KP1 does not choose association candidate',function()
 local c,e,o=state();o[#o+1]='你';c.predict=true;eq(send(e,0xffb1,{shift=true}),1);eq(table.concat(o),'你');eq(c.predict,true)
end)
run('normal Quick of + main number 2 remains delegated downstream',function()
 local c,e,o=state();eq(send(e,'o'),1);eq(send(e,'f'),1);eq(send(e,'2'),2);eq(c.input,'of')
end)
run('Shift-tap of commits English and prevents native Chinese selection',function()
 local c,e,o=state();eq(send(e,'o'),1);eq(send(e,'f'),1);eq(send(e,0xffe1,{shift=true}),2);eq(send(e,0xffe1,{release=true}),1)
 eq(table.concat(o),'of');eq(c.input,'')
end)
print(('INTEGRATION RESULT: %d groups / %d assertions (real processor+guard, mocked Rime)'):format(cases,asserts))
