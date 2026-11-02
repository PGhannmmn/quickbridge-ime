-- Human input acceptance matrix. Executes REAL v2.9 Lua and the v2.1 guard.
-- Rime context is a mock; application delivery and Weasel/TSF require Windows verification.
local P=assert(dofile('lua/quickbridge_processor_v29.lua'))
local G=assert(dofile('tests/quickbridge_prediction_guard_v21_fixture.lua'))
local cases,checks=0,0
local function eq(a,b,n) checks=checks+1; if a~=b then error((n or 'eq')..' expected '..tostring(b)..' got '..tostring(a),2) end end
local function case(n,f) f(); cases=cases+1;print('PASS '..n) end
local top={'伙','你'}
local function make()
  local out={}
  local c={input='',predict=false,opts={prediction=true,ascii_mode=false},idx=0,clears=0}
  local words={h={'竹'},f={'火'},hi={'凡','么'},of={'伙','你'},vd={'好','她'},to={'芝','芙'}}
  function c:get_option(k) return self.opts[k]end
  function c:has_menu() return self.predict or words[self.input]~=nil end
  function c:push_input(s) self.input=self.input..s;self.predict=false;return true end
  function c:clear() self.input='';self.predict=false;self.clears=self.clears+1 end
  function c:get_selected_candidate() local a=words[self.input];return a and {text=a[1]} or nil end
  function c:commit() local a=words[self.input];if a then out[#out+1]=a[1] end;self:clear()end
  function c:select(i) out[#out+1]=i==0 and '們' or i==9 and '意思' or '我';self:clear() end
  local seg={};function seg:has_tag(k) return k=='prediction' and c.predict end
  function seg:get_candidate_at(i) return {text=i==0 and '們' or i==9 and '意思' or '我'}end
  setmetatable(seg,{__index=function(_,k) if k=='selected_index' then return c.idx end end})
  local comp={};function comp:empty() return not c.predict end;function comp:back()return seg end
  c.composition=comp
  local env={engine={context=c}}
  function env.engine:commit_text(t) out[#out+1]=t end
  local function send(k,opt)
    opt=opt or {}; local code=type(k)=='number' and k or string.byte(k)
    local key={keycode=code}
    for _,prop in ipairs({'shift','release','ctrl','alt','super'})do key[prop]=function()return not not opt[prop] end end
    if opt.repr then key.repr=function()return opt.repr end end
    local a=P.func(key,env); if a==2 then a=G.func(key,env) end
    -- Mock Rime native main-row Chinese selection (only for unchanged 1-9).
    if a==2 and not opt.shift and code>=49 and code<=57 then
      local list=words[c.input]
      if list then
        local x=list[code-48]
        if x then out[#out+1]=x;c:clear();a=1 end
      end
    end
    return a
  end
  local function typeword(s)
    for i=1,#s do
      local ch=s:sub(i,i);eq(send(ch,{shift=ch:match('%u')~=nil}),1,'type '..ch)
    end
  end
  return {out=out,ctx=c,env=env,send=send,typeword=typeword,
    value=function()return table.concat(out) end}
end
local K={}
for i=0,9 do K[i]=0xffb0+i end
local SYM={['+']=0xffab,['-']=0xffad,['*']=0xffaa,['/']=0xffaf,['.']=0xffae,[',']=0xffac,['=']=0xffbd}
local function shifttap(q)
 eq(q.send(0xffe1,{shift=true}),2,'ShiftDown noop')
 eq(q.send(0xffe1,{release=true}),1,'ShiftUp accepted')
end
case('ALL 26 single letters × 10 NumPad digits = literal, not Chinese', function()
 for k=97,122 do for n=0,9 do
  local q=make();local ch=string.char(k);q.typeword(ch)
  eq(q.send(K[n]),1,ch..' KP'..n)
  eq(q.value(),ch..n,ch..n..' result')
  eq(q.ctx.input,'','no pending Rime code')
 end end
end)
case('ALL 26 single letters × seven NumPad arithmetic keys',function()
 for k=97,122 do for sym,kp in pairs(SYM) do
  local q=make(); local ch=string.char(k);q.typeword(ch)
  eq(q.send(kp),1,ch..sym)
  eq(q.value(),ch..sym)
  eq(q.ctx.input,'')
 end end
end)
case('ALL 26 single letters × bare Left Shift commits exactly once',function()
 for k=97,122 do
  local q=make(); local ch=string.char(k); q.typeword(ch)
  shifttap(q);eq(q.value(),ch);eq(q.ctx.input,'')
  eq(q.send(0xffe1,{release=true}),2,'duplicate ShiftUp NOOP');eq(q.value(),ch)
 end
end)
case('one letter + Shift Space is English but plain Space keeps Chinese',function()
 local q=make();q.typeword('h');eq(q.send(32,{shift=true}),1);eq(q.value(),'h ')
 local r=make();r.typeword('h');eq(r.send(32),1);eq(r.value(),'竹')
end)
case('h + NumPad1, and h + top-row1, are different by design',function()
 local q=make();q.typeword('h');eq(q.send(K[1]),1);eq(q.value(),'h1')
 local r=make();r.typeword('h');eq(r.send('1'),1);eq(r.value(),'竹')
end)
case('ALL 26 single Latin codes × top 1..9 remain native Chinese selection',function()
 for k=97,122 do for n=1,9 do
  local q=make();local ch=string.char(k);q.typeword(ch)
  -- Only h/f have native sample candidates; these prove the raw processor
  -- never hijacks the selection. For other codes, native selector is external.
  if (ch=='h' or ch=='f') and n==1 then
   eq(q.send(string.char(48+n)),1);eq(q.value(),ch=='h' and '竹' or '火')
  else
   eq(q.send(string.char(48+n)),2)
   eq(q.value(),'');eq(q.ctx.input,ch)
  end
 end end
end)
case('All one-letter Latin + keyboard comma/period/slash commit literal English',function()
 for k=97,122 do
  local ch=string.char(k)
  for _,sym in ipairs({',','.','/'}) do
   local q=make();q.typeword(ch)
   eq(q.send(sym),1);eq(q.value(),ch..sym);eq(q.ctx.input,'')
  end
 end
end)
case('Shifted comma/period/slash after one letter produce < > ? with either keysym',function()
 for _,pair in ipairs({{',','<'},{'.','>'},{'/','?'}}) do
  for _,ch in ipairs({'a','f','h','z'}) do
   for _,keycode in ipairs({pair[1],pair[2]}) do
    local q=make();q.typeword(ch)
    eq(q.send(keycode,{shift=true}),1);eq(q.value(),ch..pair[2]);eq(q.ctx.input,'')
   end
  end
 end
end)
case('One-letter Latin + Shift+main-number-row selector stays native',function()
 for _,ch in ipairs({'a','f','h'}) do
  for _,sym in ipairs({33,49,64,50,35,51,36,52}) do
   local q=make();q.typeword(ch)
   eq(q.send(sym,{shift=true}),2);eq(q.value(),'');eq(q.ctx.input,ch)
  end
 end
end)
case('of + top 2 => 你, of + NumPad2 => of2',function()
 local q=make();q.typeword('of');eq(q.send('2'),1);eq(q.value(),'你')
 local r=make();r.typeword('of');eq(r.send(K[2]),1);eq(r.value(),'of2')
end)
case('NumPad literal stream after ONE letter mixes number rows',function()
 local q=make();q.typeword('h');eq(q.send(K[1]),1);eq(q.send('2'),1);eq(q.send(K[3]),1);eq(q.value(),'h123')
end)
case('Main-row 0 is not a 1–9 candidate: h0, of0',function()
 for _,prefix in ipairs({'h','of','hi'}) do
  local q=make();q.typeword(prefix);eq(q.send('0'),1);eq(q.value(),prefix..'0')
  eq(q.send('1'),1);eq(q.value(),prefix..'01')
 end
end)
case('h+Shift commits h, next NumPad 1 passes through without phantom candidate',function()
 local q=make();q.typeword('h');shifttap(q);eq(q.value(),'h');eq(q.send(K[1]),1,'no pending keypad literal');eq(q.value(),'h1')
end)
case('Standalone NumPad numbers and operators are literal then Chinese Quick can start',function()
 local q=make();eq(q.send(K[1]),1);eq(q.send(K[2]),1);eq(q.send(0xffab),1);eq(q.send(K[3]),1)
 eq(q.value(),'12+3');q.typeword('of');eq(q.send('2'),1);eq(q.value(),'12+3你')
end)
case('h+NumPad1 then Space and new Chinese Quick of2',function()
 local q=make();q.typeword('h');q.send(K[1]);eq(q.send(32),1);q.typeword('of');eq(q.send('2'),1);eq(q.value(),'h1 你')
end)
case('single uppercase H with CapsLock-style unshifted key and main 1 => H1',function()
 local q=make();eq(q.send('H',{shift=false}),1);eq(q.send('1'),1);eq(q.value(),'H1')
end)
case('shifted lowercase keysym in a Latin input is capitalized',function()
 local q=make();eq(q.send('h',{shift=true}),1);eq(q.send(K[1]),1);eq(q.value(),'H1')
end)
case('shifted main-row 1 in 3+ Latin preedit gives ! not digit 1',function()
 for _,key in ipairs({33,49}) do
  local q=make();q.typeword('hello');eq(q.send(key,{shift=true}),1);eq(q.value(),'hello!')
 end
end)
case('shifted main-row 1 in active ASCII number stream gives ! not digit 1',function()
 for _,key in ipairs({33,49}) do
  local q=make();q.typeword('hello');q.send(K[1]);eq(q.send(key,{shift=true}),1);eq(q.value(),'hello1!')
 end
end)
case('single h main-row Shift+1 must NOT become h1',function()
 local q=make();q.typeword('h');eq(q.send('1',{shift=true}),2);eq(q.ctx.input,'h');eq(q.value(),'')
end)
case('Shift held + any typed key does not count as solo Shift tap',function()
 local q=make();q.typeword('h');eq(q.send(0xffe1,{shift=true}),2)
 eq(q.send('a',{shift=true}),1);eq(q.send(0xffe1,{release=true}),2)
 eq(q.value(),'');eq(q.ctx.input,'hA')
end)
case('right Shift tap never commits Latin',function()
 local q=make();q.typeword('h');eq(q.send(0xffe2,{shift=true}),2);eq(q.send(0xffe2,{release=true}),2)
 eq(q.value(),'');eq(q.ctx.input,'h')
end)
case('ctrl/alt/super + NumPad cannot intercept shortcuts',function()
 for _,k in ipairs({'ctrl','alt','super'}) do
  local q=make();q.typeword('h');local x={[k]=true}
  eq(q.send(K[1],x),2);eq(q.ctx.input,'h');eq(q.value(),'')
 end
end)
case('Shift NumPad digit with NumLock inversion cannot be forced to ASCII',function()
 local q=make();q.typeword('h');eq(q.send(K[1],{shift=true}),2);eq(q.ctx.input,'h');eq(q.value(),'')
end)
case('NumLock off navigation never converted to digit, even after h',function()
 for _,kc in ipairs({0xff9c,0xff9e,0xff95,0xff97,0xff9a,0xff96}) do
  local q=make();q.typeword('h');eq(q.send(kc),2);eq(q.value(),'');eq(q.ctx.input,'h')
 end
end)
case('physical keypad repr KP_1 with ASCII keycode is recognized',function()
 local q=make();q.typeword('h');eq(q.send('1',{repr='KP_1'}),1);eq(q.value(),'h1')
end)
case('prediction Shift+1 selects candidate but NumPad 1 types literal',function()
 local q=make();q.out[#q.out+1]='你';q.ctx.predict=true;q.ctx.input='~'
 eq(q.send('!',{shift=true}),1);eq(q.value(),'你們')
 local r=make();r.out[#r.out+1]='你';r.ctx.predict=true;r.ctx.input='~'
 eq(r.send(K[1]),1);eq(r.value(),'你1');eq(r.ctx.predict,false)
end)
case('predictive comma closes window and does NOT select suffix',function()
 local q=make();q.out[#q.out+1]='你';q.ctx.predict=true;q.ctx.input='~'
 eq(q.send(','),1);eq(q.value(),'你,');eq(q.ctx.predict,false)
end)
case('post-punctuation stale prediction cannot swallow next h+NumPad1',function()
 local q=make();q.out[#q.out+1]='你';q.ctx.predict=true;q.ctx.input='~'
 eq(q.send(','),1);q.ctx.predict=true;q.ctx.input='~'
 eq(q.send('h'),1);eq(q.ctx.input,'h');eq(q.send(K[1]),1);eq(q.value(),'你,h1')
end)
case('Enter/Tab/Esc/Backspace after ASCII stream are not swallowed',function()
 for _,kc in ipairs({0xff0d,0xff8d,0xff09,0xff1b,0xff08}) do
  local q=make();q.typeword('h');q.send(K[1]);eq(q.send(kc),2,'host key');eq(q.value(),'h1')
  eq(q.env.qb_v24_ascii_stream,false,'stream resets')
 end
end)
case('bare Left Shift stops English stream and next Chinese is native',function()
 local q=make();q.typeword('h');q.send(K[1]);shifttap(q);eq(q.env.qb_v24_ascii_stream,false)
 q.typeword('of');eq(q.send('2'),1);eq(q.value(),'h1你')
end)
case('Backspace on preedit still belongs to Rime, not ASCII stream',function()
 local q=make();q.typeword('h');eq(q.send(0xff08),2);eq(q.ctx.input,'h')
end)
case('CapsLock/plain Shift+letter must not insert extra punctuation',function()
 local q=make();q.typeword('hello');eq(q.send(K[1]),1)
 eq(q.send('a',{shift=true}),1);eq(q.send('B',{shift=false}),1)
 eq(q.value(),'hello1AB')
end)
case('press-release NumPad digit commits once',function()
 local q=make();q.typeword('h');eq(q.send(K[1]),1);eq(q.send(K[1],{release=true}),2);eq(q.value(),'h1')
end)
case('long word + KP1 commits without losing data',function()
 local q=make();q.typeword(string.rep('a',63));eq(q.send('a'),1);eq(q.send(K[1]),1)
 eq(q.value(),string.rep('a',64)..'1')
end)
case('two-code Quick + punctuation commits English; candidate selection still native',function()
 local q=make();q.typeword('vd');eq(q.send(','),1);eq(q.value(),'vd,');eq(q.ctx.input,'')
 local r=make();r.typeword('of');eq(r.send('2'),1);eq(r.value(),'你')
end)
case('same physical Shift tap with prediction menu never commits stray Latin',function()
 local q=make();q.out[#q.out+1]='好';q.ctx.predict=true;q.ctx.input='~'
 eq(q.send(0xffe1,{shift=true}),2);eq(q.send(0xffe1,{release=true}),2)
 eq(q.value(),'好');eq(q.ctx.predict,true)
end)
print(('HUMAN TEST RESULT: %d named cases / %d assertions; real Lua+guard, mock Rime'):format(cases,checks))
