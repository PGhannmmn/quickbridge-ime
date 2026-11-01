-- Offline Rime mock. Checks processor return values and committed output only.
-- Does not prove the same key event ordering in real Weasel/Windows.
local mod=assert(dofile('lua/quickbridge_processor_v29.lua'))
local cases, asserts=0,0
local function eq(v,e,reason)
  asserts=asserts+1
  if v~=e then error((reason or 'value')..': expected '..tostring(e)..' got '..tostring(v),2) end
end
local function case(name,fn) fn();cases=cases+1;print('PASS '..name) end
local function start()
 local out={}
 local c={input='',predict=false,tag='prediction',clear_count=0,opts={prediction=true,ascii_mode=false}}
 local candcodes={of={'伙','你'},vd={'好','她'},ha={'香'},f={'火'},to={'芝','芙'}}
 function c:get_option(k)return self.opts[k]end
 function c:has_menu()return self.predict or candcodes[self.input]~=nil end
 function c:push_input(s)self.input=self.input..s;self.predict=false;return true end
 function c:clear()self.clear_count=self.clear_count+1;self.input='';self.predict=false end
 function c:get_selected_candidate()local arr=candcodes[self.input];if arr then return {text=arr[1]} end end
 function c:commit()local x=self:get_selected_candidate();if x then out[#out+1]=x.text;self:clear() end end
 local segment={};function segment:has_tag(tag)return c.predict and c.tag==tag end
 local comp={};function comp:empty()return not c.predict end;function comp:back()return segment end
 c.composition=comp
 local env={engine={context=c}};function env.engine:commit_text(s)out[#out+1]=s end
 return env,c,out
end
local function hit(e,ch,opts)
 opts=opts or {};local k={keycode=type(ch)=='number' and ch or string.byte(ch)}
 for _,t in ipairs({'release','ctrl','alt','super','shift'}) do k[t]=function()return not not opts[t] end end
 return mod.func(k,e)
end
local function word(e,s)
 for i=1,#s do
  local ch=s:sub(i,i)
  eq(hit(e,ch,{shift=(ch:match('[A-Z]')~=nil)}),1,'typing '..s)
 end
end
local function committed(out)return table.concat(out)end
local function pred(c,out,head)
 out[#out+1]=head;c.predict=true;c.tag='prediction';c.input='~'
end
case('Chinese comma is punctuation not first prediction',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,','),1);eq(committed(o),'你,');eq(c.predict,false)
end)
case('Chinese question mark and full stop without prediction select',function()
 local e,c,o=start();pred(c,o,'好');eq(hit(e,'.'),1);eq(hit(e,'?'),2);eq(committed(o),'好.')
end)
case('Chinese punctuation with Shift+slash is literal ?',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,'?',{shift=true}),1);eq(committed(o),'你?')
end)
case('Shift+1 on prediction is left to prediction guard',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,'!',{shift=true}),2);eq(committed(o),'你');eq(c.predict,true)
end)
case('Plain number while prediction is not swallowed',function()
 local e,c,o=start();pred(c,o,'你');eq(hit(e,'1'),2);eq(c.predict,true)
end)
case('Native Quick of2 unmodified',function()
 local e,c,o=start();word(e,'of');eq(hit(e,'2'),2);eq(c.input,'of')
end)
case('Native Quick of Space pages unchanged',function()
 local e,c,o=start();word(e,'of');eq(hit(e,32),2);eq(c.input,'of')
end)
case('Single letter f space still native Chinese candidate',function()
 local e,c,o=start();word(e,'f');eq(hit(e,32),1);eq(committed(o),'火')
end)
case('Two letter hi Shift+Space yields literal hi plus space',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,32,{shift=true}),1);eq(committed(o),'hi ')
end)
case('Two letter of Shift+Space is explicit English',function()
 local e,c,o=start();word(e,'of');eq(hit(e,32,{shift=true}),1);eq(committed(o),'of ')
end)
case('Two letter uppercase Hi comma commits without Enter',function()
 local e,c,o=start();word(e,'Hi');eq(hit(e,','),1);eq(committed(o),'Hi,')
end)
case('Two-letter lowercase Chinese Quick punctuation stays native',function()
 local e,c,o=start();word(e,'vd');eq(hit(e,','),2);eq(committed(o),'');eq(c.input,'vd')
end)
case('hello123 type continuously',function()
 local e,c,o=start();word(e,'hello')
 eq(hit(e,'1'),1);eq(e.qb_v24_ascii_stream,true);eq(hit(e,'2'),1);eq(hit(e,'3'),1)
 eq(committed(o),'hello123');eq(hit(e,32),1);eq(committed(o),'hello123 ');eq(e.qb_v24_ascii_stream,false)
end)
case('AI2026 acronym uppercase starts a continuous digit run',function()
 local e,c,o=start();word(e,'AI');eq(hit(e,'2'),1);eq(hit(e,'0'),1);eq(hit(e,'2'),1);eq(hit(e,'6'),1);eq(committed(o),'AI2026')
end)
case('hi123 keeps native 2 code selection',function()
 local e,c,o=start();word(e,'hi');eq(hit(e,'1'),2);eq(c.input,'hi')
end)
case('English run can include trailing letters and punctuation',function()
 local e,c,o=start();word(e,'abc');eq(hit(e,'1'),1);eq(hit(e,'A',{shift=true}),1);eq(hit(e,'2'),1);eq(hit(e,'!',{shift=true}),1);eq(committed(o),'abc1A2!')
end)
case('English run Enter reaches application after stream',function()
 local e,c,o=start();word(e,'hello');eq(hit(e,'1'),1);eq(hit(e,0xff0d),2);eq(e.qb_v24_ascii_stream,false);eq(committed(o),'hello1')
end)
case('English digit stream reset and Backspace passed through',function()
 local e,c,o=start();word(e,'abc');eq(hit(e,'5'),1);eq(hit(e,0xff08),2);eq(e.qb_v24_ascii_stream,false)
end)
case('English capital followed by Chinese composition with Enter',function()
 local e,c,o=start();word(e,'Hello');eq(hit(e,0xff0d),1);eq(committed(o),'Hello')
 pred(c,o,'你');eq(hit(e,'W',{shift=true}),1);word(e,'orld');eq(hit(e,0xff0d),1);eq(committed(o),'Hello你World')
end)
case('Modifier shortcuts do not interfere with native Rime',function()
 local e,c,o=start();pred(c,o,'你');for _,x in ipairs({'alt','ctrl','super','release'}) do eq(hit(e,',',{[x]=true}),2) end
 eq(c.predict,true);eq(committed(o),'你')
end)
case('Two-code Chinese Quick punctuation stays native',function()
 local e,c,o=start();word(e,'vd');eq(hit(e,','),2);eq(committed(o),'');eq(c.input,'vd')
end)

case('After punctuation prediction is dismissed even if engine reopens it synchronously',function()
 local e,c,o=start()
 pred(c,o,'你')
 local original=e.engine.commit_text
 function e.engine:commit_text(s)
   original(self,s)
   -- Simulate predictor resurrection on punctuation commit.
   if s==',' then c.predict=true;c.input='~' end
 end
 eq(hit(e,','),1)
 eq(committed(o),'你,')
 eq(c.predict,false,'menu hidden after punctuation')
 eq(c.input,'','input blank after punctuation')
 eq(e.qb_v25_post_punct_dismiss,true,'one-key guard armed')
end)
case('After punctuation delayed stale prediction does not consume next English key',function()
 local e,c,o=start()
 pred(c,o,'你')
 eq(hit(e,','),1)
 -- Simulate the framework restoring old menu after M.func returned.
 c.predict=true;c.input='~'
 eq(hit(e,'h'),1)
 eq(c.input,'h')
 eq(c.predict,false)
 eq(e.qb_v25_post_punct_dismiss,false)
 eq(hit(e,'i'),1)
 eq(hit(e,0xff0d),1)
 eq(committed(o),'你,hi')
end)
case('After punctuation delayed menu does not steal Space',function()
 local e,c,o=start()
 pred(c,o,'好')
 eq(hit(e,'.'),1)
 c.predict=true;c.input='~'
 -- On empty input the Lua processor passes Space to the OS/Rime normally.
 -- Crucial assertion: stale prediction menu is now gone (so cannot page it).
 eq(hit(e,32),2)
 eq(c.predict,false)
 eq(c.input,'')
 eq(committed(o),'好.')
end)
case('After punctuation subsequent punctuation has no stale selection',function()
 local e,c,o=start()
 pred(c,o,'你')
 eq(hit(e,','),1)
 c.predict=true;c.input='~'
 eq(hit(e,'.'),2) -- passed downstream for normal punctuation insertion
 eq(c.predict,false)
 eq(committed(o),'你,') -- mock does not simulate downstream punct_translator
end)
case('Non-shift punctuation cancels but Shift+number remains prediction selection',function()
 for _,k in ipairs({',','.','?',';',':','/','\\','-',"'",'"',')','['}) do
   local e,c,o=start()
   pred(c,o,'好')
   eq(hit(e,k),1,'punct should dismiss '..k)
   eq(c.predict,false,'punct menu should close '..k)
 end
 local e2,c2,o2=start()
 pred(c2,o2,'你')
 eq(hit(e2,'!',{shift=true}),2)
 eq(c2.predict,true)
end)


-- v2.6 Left Shift tap: keydown and keyup must both be delivered by host.
local function shift_down(e)
 return hit(e,0xffe1,{shift=true})
end
local function shift_up(e)
 return hit(e,0xffe1,{release=true})
end
case('Left Shift tap commits lowercase two-letter English without space',function()
 local e,c,o=start();word(e,'of');eq(shift_down(e),2);eq(committed(o),'')
 eq(shift_up(e),1);eq(committed(o),'of');eq(c.input,'')
end)
case('Left Shift tap commits two-letter hi and then fresh Chinese Quick',function()
 local e,c,o=start();word(e,'hi');eq(shift_down(e),2);eq(shift_up(e),1)
 word(e,'of');eq(hit(e,'2'),2);eq(committed(o),'hi');eq(c.input,'of')
end)
case('Left Shift tap commits uppercase acronym only on release',function()
 local e,c,o=start();word(e,'AI');eq(shift_down(e),2);eq(committed(o),'')
 eq(shift_up(e),1);eq(committed(o),'AI')
end)
case('Shift plus number is not a tap and preserves prediction',function()
 local e,c,o=start();pred(c,o,'你');eq(shift_down(e),2)
 eq(hit(e,'!',{shift=true}),2);eq(shift_up(e),2)
 eq(committed(o),'你');eq(c.predict,true)
end)
case('Shift plus space keeps existing explicit English-with-space shortcut',function()
 local e,c,o=start();word(e,'of');eq(shift_down(e),2)
 eq(hit(e,32,{shift=true}),1);eq(shift_up(e),2)
 eq(committed(o),'of ')
end)
case('Shift plus capital does not commit pending two-letter English',function()
 local e,c,o=start();word(e,'of');eq(shift_down(e),2)
 eq(hit(e,'A',{shift=true}),1);eq(shift_up(e),2)
 eq(committed(o),'');eq(c.input,'ofA')
end)
case('Shift tap when no composition is inert',function()
 local e,c,o=start();eq(shift_down(e),2);eq(shift_up(e),2)
 eq(committed(o),'');eq(c.input,'')
end)
case('Shift tap explicitly commits one-letter English',function()
 local e,c,o=start();word(e,'f');eq(shift_down(e),2);eq(shift_up(e),1)
 eq(committed(o),'f');eq(c.input,'')
end)
case('Shift tap when a prediction popup is visible does not cancel it',function()
 local e,c,o=start();pred(c,o,'好');eq(shift_down(e),2);eq(shift_up(e),2)
 eq(c.predict,true);eq(committed(o),'好')
end)
case('Right Shift tap cannot confirm a two-letter English code',function()
 local e,c,o=start();word(e,'of');eq(hit(e,0xffe2,{shift=true}),2)
 eq(hit(e,0xffe2,{release=true}),2);eq(committed(o),'')
 eq(c.input,'of')
end)
case('Ctrl plus Left Shift cannot commit a two-letter code',function()
 local e,c,o=start();word(e,'of');eq(shift_down(e),2)
 eq(hit(e,'c',{ctrl=true}),2);eq(shift_up(e),2)
 eq(committed(o),'');eq(c.input,'of')
end)
case('Second ordinary Shift tap after a successful one does nothing',function()
 local e,c,o=start();word(e,'hi');eq(shift_down(e),2);eq(shift_up(e),1)
 eq(shift_down(e),2);eq(shift_up(e),2);eq(committed(o),'hi')
end)
case('Shift held across key release does not incorrectly mark a tap',function()
 local e,c,o=start();word(e,'of');eq(shift_down(e),2)
 eq(hit(e,'1',{shift=true,release=true}),2);eq(shift_up(e),1)
 eq(committed(o),'of')
end)

print(('RESULT: %d groups / %d assertions (mock)'):format(cases,asserts))
