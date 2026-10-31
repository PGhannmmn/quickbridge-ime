-- Deterministic crash-safety stress, not a replacement for semantic acceptance.
local p=assert(dofile('lua/quickbridge_processor_v29.lua'))
math.randomseed(28031)
local keys={32,9,0xff0d,0xff8d,0xff08,0xff1b,0xffe1,0xffe2,33,35,36,40,42,43,44,45,46,47,63,64,0xffaa,0xffab,0xffac,0xffad,0xffae,0xffaf,0xffbd,0xff9c,0xff9e}
for i=0,9 do keys[#keys+1]=0xffb0+i;keys[#keys+1]=48+i end
for i=97,122 do keys[#keys+1]=i end
for i=65,90 do keys[#keys+1]=i end
local events=25000
local c={input='',predict=false,opts={prediction=true,ascii_mode=false},count=0}
function c:get_option(k)return self.opts[k]end
function c:has_menu()return self.predict or #self.input==2 end
function c:clear()self.input='';self.predict=false end
function c:push_input(s)self.input=self.input..s;return true end
function c:commit()self:clear()end
function c:get_selected_candidate()return {text='好'}end
local seg={};function seg:has_tag(k)return c.predict and k=='prediction'end
local comp={};function comp:empty()return not c.predict end;function comp:back()return seg end;c.composition=comp
local e={engine={context=c}};function e.engine:commit_text(s)assert(type(s)=='string');c.count=c.count+1;assert(#s<=1000)end
for j=1,events do
 if j%389==0 then c.predict=true;c.input='~' end
 if j%971==0 then c.input='vd';c.predict=false end
 local kc=keys[math.random(#keys)]
 local shift=kc>=65 and kc<=90 or math.random(1,20)==1
 local release=math.random(1,14)==1
 local ctrl=math.random(1,120)==1
 local k={keycode=kc}
 function k:shift()return shift end
 function k:release()return release end
 function k:alt()return false end
 function k:ctrl()return ctrl end
 function k:super()return false end
 local v=p.func(k,e)
 assert(v==1 or v==2,'invalid processor return')
 assert(type(c.input)=='string' and #c.input<1024,'broken context')
end
print(('FUZZ RESULT: %d deterministic mixed-key events, %d nonempty commits, no error'):format(events,c.count))
