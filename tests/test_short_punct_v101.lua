-- v1.0.1: one-letter English + keyboard punctuation, mocked Rime engine.
-- Real Windows/Weasel keyboard delivery still needs human validation.
local P=assert(dofile('lua/quickbridge_processor_v29.lua'))
local n=0
local function eq(a,b,label)
 n=n+1
 if a~=b then error((label or 'check')..' expected '..tostring(b)..' got '..tostring(a),2) end
end
local function fresh()
 local out={};local c={input='',predict=false,opts={ascii_mode=false,prediction=true}}
 local comp={};function comp:empty()return true end
 c.composition=comp
 function c:get_option(k)return self.opts[k] end
 function c:has_menu()return self.input=='f' or self.input=='vd' or self.input=='of' end
 function c:push_input(x)self.input=self.input..x;return true end
 function c:clear()self.input='';self.predict=false end
 function c:get_selected_candidate()return {text='火'}end
 function c:commit()out[#out+1]='火';self:clear()end
 local env={engine={context=c}}
 function env.engine:commit_text(s)out[#out+1]=s end
 local function key(code,shift)
  local k={keycode=type(code)=='string' and string.byte(code) or code}
  function k:shift()return not not shift end
  function k:release()return false end
  function k:ctrl()return false end
  function k:alt()return false end
  function k:super()return false end
  return P.func(k,env)
 end
 return c,env,out,key
end
for k=97,122 do
 local letter=string.char(k)
 for _,item in ipairs({{',',','},{'.','.'},{'/','/'},{',','<',true},{'.','>',true},{'/','?',true},{'<','<',true},{'>','>',true},{'?','?',true}}) do
  local c,e,out,hit=fresh()
  eq(hit(letter),1,'letter')
  eq(hit(item[1],item[3]),1,'punctuation')
  eq(table.concat(out),letter..item[2],'punct output')
  eq(c.input,'','preedit cleared')
 end
end
-- A one-code Chinese character remains accessible using native Space first.
do
 local c,e,out,hit=fresh();eq(hit('f'),1);eq(hit(32),1)
 eq(table.concat(out),'火')
end
-- Two-code punctuation commits raw English; shifted Chinese numeric
-- candidate selection remains delegated to native Rime/guard.
do
 local c,e,out,hit=fresh();eq(hit('v'),1);eq(hit('d'),1)
 eq(hit(','),1);eq(c.input,'');eq(table.concat(out),'vd,')
end
do
 local c,e,out,hit=fresh();eq(hit('v'),1);eq(hit('d'),1)
 eq(hit(49),2);eq(c.input,'vd');eq(table.concat(out),'')
end
do
 local c,e,out,hit=fresh();eq(hit('a'),1)
 eq(hit(49,true),2);eq(hit(33,true),2);eq(c.input,'a');eq(table.concat(out),'')
end
-- 3+ English letters use the same shifted-punctuation mapping.
do
 local c,e,out,hit=fresh();for _,v in ipairs({'h','e','l','l','o'}) do eq(hit(v),1) end
 eq(hit('.',true),1);eq(table.concat(out),'hello>')
end
print(('SHORT PUNCT RESULT: %d assertions (real processor + mocked Rime)'):format(n))
