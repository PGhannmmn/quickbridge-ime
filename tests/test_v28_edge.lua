-- v2.8 focused edge tests: captures real bugs in v2.7, real Lua processor.
local module_path = 'lua/quickbridge_processor_v29.lua'
local M = assert(dofile(module_path))
local cases,checks=0,0
local function eq(x,y,label)
  checks=checks+1
  if x~=y then error((label or 'assert')..' expected '..tostring(y)..' got '..tostring(x),2) end
end
local function run(name,cb)cb();cases=cases+1;print('PASS '..name)end
local function start()
  local out={};local c={input='',predict=false,opts={prediction=true,ascii_mode=false}}
  function c:get_option(k)return self.opts[k]end
  function c:has_menu()return self.predict or self.input=='of' or self.input=='vd' or self.input=='hi' end
  function c:push_input(v)self.input=self.input..v;return true end
  function c:clear()self.input='';self.predict=false end
  function c:commit()self:clear()end
  function c:get_selected_candidate()return {text='好'}end
  local seg={selected_index=0};function seg:has_tag(tag)return c.predict and tag=='prediction' end
  function seg:get_candidate_at(n) return {text='們'}end
  local cmp={}; function cmp:empty()return not c.predict end;function cmp:back()return seg end
  c.composition=cmp
  local env={engine={context=c}}
  function env.engine:commit_text(t)out[#out+1]=t end
  return env,c,out
end
local function hit(e,kc,opt)
  opt=opt or {};if type(kc)=='string' then kc=string.byte(kc)end
  local k={keycode=kc}
  for _,n in ipairs({'shift','alt','ctrl','super','release'})do k[n]=function()return not not opt[n]end end
  if opt.repr then k.repr=function()return opt.repr end end
  return M.func(k,e)
end
local function typeword(e,w)
  for i=1,#w do local ch=w:sub(i,i);eq(hit(e,ch,{shift=ch:match('%u')~=nil}),1,w)end
end
local function output(o)return table.concat(o)end
local function startstream(w)
  local e,c,o=start();typeword(e,w);eq(hit(e,0xffb1),1,'KP1');eq(e.qb_v24_ascii_stream,true)
  return e,c,o
end
run('Enter after raw digit stream reaches app and ends stream',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff0d),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('NumPad Enter after raw digit stream reaches app',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff8d),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('Escape after raw digit stream reaches app',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff1b),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('Tab after raw digit stream remains real Tab (not space)',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff09),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('Shift+Tab after raw digit stream remains app shortcut',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff09,{shift=true}),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('BackSpace after committed English+digits passes through to app',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff08),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('Space after stream commits exactly one literal space',function()
 local e,c,o=startstream('hello');eq(hit(e,32),1);eq(output(o),'hello1 ');eq(e.qb_v24_ascii_stream,false)
end)
run('External new Quick composition cancels stale ASCII stream',function()
 local e,c,o=startstream('hello');c.input='of';eq(hit(e,'2'),2);eq(c.input,'of');eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('External predictor popup cancels stream and Shift+1 is delegated',function()
 local e,c,o=startstream('hello');c.input='~';c.predict=true;eq(hit(e,'!',{shift=true}),2);eq(c.predict,true);eq(e.qb_v24_ascii_stream,false)
end)
run('Do not treat Shift+NumPad1 as typing hi1',function()
 local e,c,o=start();typeword(e,'hi');eq(hit(e,0xffb1,{shift=true}),2);eq(c.input,'hi');eq(output(o),'')
end)
run('Shift+NumPad1 in stream does not create digit',function()
 local e,c,o=startstream('hello');eq(hit(e,0xffb1,{shift=true}),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
run('64+ characters stay Latin, no new Quick composition',function()
 local e,c,o=start();local a=string.rep('a',63)
 typeword(e,a);eq(c.input,a)
 eq(hit(e,'b'),1);eq(output(o),a..'b');eq(c.input,'');eq(e.qb_v24_ascii_stream,true)
 eq(hit(e,'c'),1);eq(output(o),a..'bc');eq(c.input,'')
 eq(hit(e,0xffb1),1);eq(output(o),a..'bc1')
 eq(hit(e,32),1);eq(output(o),a..'bc1 ')
end)
run('64 letters then punctuation ends stream normally',function()
 local e,c,o=start();typeword(e,string.rep('a',63));eq(hit(e,'b'),1);eq(hit(e,'!'),1)
 eq(output(o),string.rep('a',63)..'b!');eq(e.qb_v24_ascii_stream,false)
end)
run('Bare Left Shift tap explicitly ends raw digit stream',function()
 local e,c,o=startstream('hello')
 eq(hit(e,0xffe1,{shift=true}),2)
 eq(hit(e,0xffe1,{release=true}),1)
 eq(e.qb_v24_ascii_stream,false)
 eq(output(o),'hello1')
 eq(hit(e,'v'),1);eq(hit(e,'d'),1);eq(c.input,'vd')
 eq(hit(e,'1'),2)
end)
run('Main-row Chinese 1 unaffected after two letters',function()
 local e,c,o=start();typeword(e,'hi');eq(hit(e,'1'),2);eq(c.input,'hi');eq(output(o),'')
end)
run('Keypad 1 after two letters still commits hi1',function()
 local e,c,o=start();typeword(e,'hi');eq(hit(e,0xffb1),1);eq(output(o),'hi1')
end)
run('Unshifted shift tap still commits two-letter English',function()
 local e,c,o=start();typeword(e,'hi');eq(hit(e,0xffe1,{shift=true}),2);eq(hit(e,0xffe1,{release=true}),1);eq(output(o),'hi')
end)
run('KP plus after two letters still commits hi+',function()
 local e,c,o=start();typeword(e,'hi');eq(hit(e,0xffab),1);eq(output(o),'hi+')
end)
run('NumLock off navigation after two letters not forced to digit',function()
 local e,c,o=start();typeword(e,'hi');eq(hit(e,0xff9c,{repr='KP_End'}),2);eq(output(o),'');eq(c.input,'hi')
end)
run('Do not swallow ctrl+enter shortcut in active stream',function()
 local e,c,o=startstream('hello');eq(hit(e,0xff0d,{ctrl=true}),2);eq(output(o),'hello1');eq(e.qb_v24_ascii_stream,false)
end)
print(('EDGE RESULT: %d groups / %d assertions (real Lua + mocked Rime)'):format(cases,checks))
