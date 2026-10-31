-- Deterministic full two-letter matrix: 26^2 prefixes x 10 NumPad digits.
local proc=assert(dofile('lua/quickbridge_processor_v29.lua'))
local assertions=0
local function eq(a,b)
 assertions=assertions+1
 if a~=b then error('expected '..tostring(b)..', got '..tostring(a)) end
end
local function ctxnew()
 local output={}
 local c={input='',opts={prediction=true,ascii_mode=false},predict=false}
 function c:get_option(name) return self.opts[name] end
 function c:has_menu()return self.predict or #self.input<=2 end
 function c:push_input(s)self.input=self.input..s;return true end
 function c:clear()self.input='';self.predict=false end
 local comp={};function comp:empty()return true end;c.composition=comp
 local e={engine={context=c}};function e.engine:commit_text(s)output[#output+1]=s end
 return e,c,output
end
local function hit(e,kc)
 local k={keycode=kc}
 function k:release()return false end
 function k:ctrl()return false end
 function k:alt()return false end
 function k:super()return false end
 function k:shift()return false end
 return proc.func(k,e)
end
local checked=0
for a=97,122 do
 for b=97,122 do
  local pair=string.char(a,b)
  for n=0,9 do
   local e,c,o=ctxnew()
   eq(hit(e,a),1);eq(hit(e,b),1)
   eq(hit(e,0xffb0+n),1)
   eq(table.concat(o),pair..n)
   eq(c.input,'')
   local e2,c2,o2=ctxnew()
   eq(hit(e2,a),1);eq(hit(e2,b),1)
   if n==0 then
    eq(hit(e2,48+n),1)
    eq(c2.input,'');eq(table.concat(o2),pair..'0')
   else
    eq(hit(e2,48+n),2)
    eq(c2.input,pair);eq(table.concat(o2),'')
   end
   checked=checked+1
  end
 end
end
print(('RESULT: %d two-letter+digit cases / %d assertions (mock)'):format(checked,assertions))
