-- v2.7 focused regression. Executes real Lua processor with Rime context mock.
-- This is NOT an assertion of live Windows/Weasel keyboard event routing.
local mod=assert(dofile('lua/quickbridge_processor_v29.lua'))
local cases,asserts=0,0
local function eq(v,e,msg)
  asserts=asserts+1
  if v~=e then error((msg or 'value')..': expected '..tostring(e)..' got '..tostring(v),2) end
end
local function case(name,fn) fn();cases=cases+1;print('PASS '..name) end
local function start()
 local out={}
 local c={input='',predict=false,tag='prediction',clear_count=0,opts={prediction=true,ascii_mode=false}}
 local candidates={of={'伙','你'},vd={'好','她'},hi={'凡','么'},f={'火'}}
 function c:get_option(k)return self.opts[k]end
 function c:has_menu()return self.predict or candidates[self.input]~=nil end
 function c:push_input(s)self.input=self.input..s;self.predict=false;return true end
 function c:clear()self.clear_count=self.clear_count+1;self.input='';self.predict=false end
 function c:get_selected_candidate()local a=candidates[self.input];return a and {text=a[1]} or nil end
 function c:commit() local x=self:get_selected_candidate();if x then out[#out+1]=x.text;self:clear() end end
 local segment={}; function segment:has_tag(tag)return c.predict and c.tag==tag end
 local comp={};function comp:empty()return not c.predict end;function comp:back()return segment end
 c.composition=comp
 local env={engine={context=c}}
 function env.engine:commit_text(s)out[#out+1]=s end
 return env,c,out
end
local function hit(env,kc,opts)
 opts=opts or {}
 if type(kc)=='string' then kc=string.byte(kc) end
 local k={keycode=kc}
 for _,a in ipairs({'shift','release','alt','ctrl','super'}) do k[a]=function()return not not opts[a]end end
 if opts.repr then k.repr=function()return opts.repr end end
 return mod.func(k,env)
end
local function word(env,w)
 for i=1,#w do local ch=w:sub(i,i);eq(hit(env,ch,{shift=ch:match('%u')~=nil}),1,'typing '..w) end
end
local function got(out)return table.concat(out)end
local function pred(c,out,ch)out[#out+1]=ch;c.predict=true;c.tag='prediction';c.input='~'end
local numpad={['0']=0xffb0,['1']=0xffb1,['2']=0xffb2,['3']=0xffb3,['4']=0xffb4,['5']=0xffb5,['6']=0xffb6,['7']=0xffb7,['8']=0xffb8,['9']=0xffb9}
local kp_ops={['+']=0xffab,['-']=0xffad,['*']=0xffaa,['/']=0xffaf,['.']=0xffae,[',']=0xffac,['=']=0xffbd}

case('hi NumPad1 is literal hi1',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,numpad['1']),1);eq(got(o),'hi1');eq(c.input,'')
end)
case('hi main-row 1 remains Chinese candidate selection (passed to native)',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,'1'),2);eq(c.input,'hi');eq(got(o),'')
end)
case('of NumPad2 literal, of main-row 2 native',function()
 local e,c,o=start();word(e,'of');eq(hit(e,numpad['2']),1);eq(got(o),'of2')
 local e2,c2,o2=start();word(e2,'of');eq(hit(e2,'2'),2);eq(c2.input,'of')
end)
case('all NumPad 0 through 9 after two lower letters',function()
 for i=0,9 do
  local e,c,o=start();word(e,'hi');eq(hit(e,0xffb0+i),1,'KP '..i);eq(got(o),'hi'..i)
 end
end)
case('hello + NumPad 1 2 3 commits continuous hello123',function()
 local e,c,o=start();word(e,'hello')
 for i=1,3 do eq(hit(e,0xffb0+i),1) end
 eq(got(o),'hello123');eq(e.qb_v24_ascii_stream,true);eq(c.input,'')
end)
case('hello + mixed main row and NumPad digits',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,0xffb1),1);eq(hit(e,'2'),1);eq(hit(e,0xffb3),1)
 eq(got(o),'hello123')
end)
case('AI + NumPad 2 0 2 6',function()
 local e,c,o=start();word(e,'AI')
 for _,i in ipairs({2,0,2,6}) do eq(hit(e,0xffb0+i),1) end
 eq(got(o),'AI2026')
end)
case('hi + NumPad 1 2 3',function()
 local e,c,o=start();word(e,'hi')
 for i=1,3 do eq(hit(e,0xffb0+i),1)end
 eq(got(o),'hi123')
end)
case('all NumPad arithmetic symbols after two letters',function()
 for sym,kc in pairs(kp_ops) do
  local e,c,o=start();word(e,'hi');eq(hit(e,kc),1,'KP '..sym);eq(got(o),'hi'..sym,'KP '..sym)
 end
end)
case('hi + regular plus is explicit hi+ boundary',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,'+',{shift=true}),1);eq(got(o),'hi+')
end)
case('single letter f + NumPad1 is literal English f1',function()
 local e,c,o=start();word(e,'f');eq(hit(e,0xffb1),1);eq(c.input,'');eq(got(o),'f1')
end)
case('single letter f + NumPadPlus is literal English f+',function()
 local e,c,o=start();word(e,'f');eq(hit(e,0xffab),1);eq(c.input,'');eq(got(o),'f+')
end)
case('vd comma stays original Chinese punctuation path',function()
 local e,c,o=start();word(e,'vd');eq(hit(e,','),2);eq(c.input,'vd')
end)
case('vd + number row digit stays original Chinese path',function()
 local e,c,o=start();word(e,'vd');eq(hit(e,'1'),2);eq(c.input,'vd')
end)
case('NumPad digits after uppercase short Latin word',function()
 local e,c,o=start();word(e,'Hi');eq(hit(e,0xffb4),1);eq(hit(e,0xffb5),1);eq(got(o),'Hi45')
end)
case('numpad plus in active prediction closes old menu',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,0xffab),1);eq(got(o),'你+');eq(c.predict,false);eq(c.input,'')
end)
case('all NumPad operators after Chinese prediction dismiss menu',function()
 for sym,kc in pairs(kp_ops) do
  local e,c,o=start();pred(c,o,'好');eq(hit(e,kc),1,'prediction KP '..sym)
  eq(got(o),'好'..sym);eq(c.predict,false)
 end
end)
case('NumPad plain digit after Chinese prediction is literal',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,0xffb1),1);eq(got(o),'你1');eq(c.predict,false)
end)
case('NumPad 0 and 9 after prediction are literal',function()
 for _,i in ipairs({0,9}) do
  local e,c,o=start();pred(c,o,'好');eq(hit(e,0xffb0+i),1);eq(got(o),'好'..i)
 end
end)
case('shifted NumPad number cannot select Chinese prediction suffix',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,0xffb1,{shift=true}),1);eq(got(o),'你');eq(c.predict,true)
end)
case('main-row Shift+1 is still delegated to association guard',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,'!',{shift=true}),2);eq(c.predict,true)
end)
case('post-punctuation prediction rearm cleared before new NumPad digit',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,0xffab),1)
 c.predict=true;c.input='~'
 eq(hit(e,0xffb2),1);eq(c.predict,false)
 eq(got(o),'你+2') -- explicit NumPad entry after stale prediction cleared
end)
case('after NumPad digit stream punctuation stops stream',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,0xffb1),1);eq(hit(e,0xffab),1);eq(got(o),'hello1+');eq(e.qb_v24_ascii_stream,false)
end)
case('after NumPad digit stream decimal and next normal letter starts new composition',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,0xffb1),1);eq(hit(e,0xffae),1);eq(e.qb_v24_ascii_stream,false)
 eq(hit(e,'v'),1);eq(c.input,'v');eq(got(o),'hello1.')
end)
case('stream mode accepts NumPad digits after main digit started stream',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,'1'),1);eq(hit(e,0xffb2),1);eq(got(o),'hello12')
end)
case('stream mode allows NumPad +/-/*// and ends stream',function()
 for sym,kc in pairs(kp_ops) do
  local e,c,o=start();word(e,'hi');eq(hit(e,0xffb1),1);eq(hit(e,kc),1);eq(got(o),'hi1'..sym);eq(e.qb_v24_ascii_stream,false)
 end
end)
case('KP_Enter after two letters confirms English',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xff8d),1);eq(got(o),'hi')
end)
case('KP_Enter ends an active ASCII digit stream',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xffb1),1);eq(hit(e,0xff8d),2);eq(got(o),'hi1');eq(e.qb_v24_ascii_stream,false)
end)
case('KP_End NumLock-off stays navigation, not ASCII digit 1',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xff9c),2);eq(got(o),'');eq(c.input,'hi')
end)
case('KP_Insert NumLock-off is navigation, not digit 0',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,0xff9e),2);eq(got(o),'')
end)
case('KP_F3 or KP_Home not misread as digit',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xff93),2);eq(hit(e,0xff95),2);eq(got(o),'')
end)
case('Key repr normalized ASCII keycode still detects KP_1',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,49,{repr='KP_1'}),1);eq(got(o),'hi1')
end)
case('Key repr normalized ASCII keycode detects KP_Add',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,43,{repr='KP_Add'}),1);eq(got(o),'hi+')
end)
case('main-row 1..9 remain Chinese; 0 is unambiguous Latin',function()
 for i=1,9 do
  local e,c,o=start();word(e,'hi');eq(hit(e,48+i),2);eq(got(o),'');eq(c.input,'hi')
 end
 local e,c,o=start();word(e,'hi');eq(hit(e,'0'),1);eq(got(o),'hi0')
end)
case('control shortcut does not intercept NumPad keys',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xffb1,{ctrl=true}),2);eq(got(o),'');eq(c.input,'hi')
end)
case('alt shortcut does not intercept NumPad operators',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xffab,{alt=true}),2);eq(got(o),'')
end)
case('NumPad keyup cannot commit duplicate',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xffb1),1);eq(hit(e,0xffb1,{release=true}),2);eq(got(o),'hi1')
end)
case('Shift tap still works after NumPad input',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,0xffe1,{shift=true}),2);eq(hit(e,0xffe1,{release=true}),1);eq(got(o),'hi')
 word(e,'of');eq(hit(e,0xffb1),1);eq(got(o),'hiof1')
end)
case('English stream resets on Space and next Quick code uses native selection',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,0xffb1),1);eq(hit(e,32),1);word(e,'of');eq(hit(e,'2'),2);eq(got(o),'hello1 ')
end)
case('Long English then NumPad operator commits directly',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,0xffab),1);eq(got(o),'hello+')
end)
case('NumPad key without composition is literal, not delegated to Rime',function()
 local e,c,o=start();eq(hit(e,0xffb1),1);eq(hit(e,0xffab),1);eq(got(o),'1+')
end)
case('prediction menu after KP number cannot swallow next letter',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,0xffb1),1)
 c.predict=true;c.input='~'
 eq(hit(e,'h'),1);eq(c.predict,false);eq(c.input,'h');eq(got(o),'你1')
end)
print(('RESULT: %d groups / %d assertions (mock)'):format(cases,asserts))
