-- QuickBridge v2.1 independent prediction guard: preserve v1.8 behavior; fix later-page positions.
-- Composition numbers unchanged: Quick code + 1-9 are handled by native Rime.
-- Prediction: plain 1-9 must NOT choose a candidate; Shift+1-9 can choose.
-- A short-lived pending symbol guard MAY catch a second synthetic punctuation
-- event following a Shift+digit selection. It CANNOT prevent an OS-level
-- character bypassing Rime; Windows live verification is essential.
local M = {}
local ACCEPTED, NOOP = 1, 2
local SHIFT_L, SHIFT_R = 0xffe1, 0xffe2
local symbols = {[33]=1,[64]=2,[35]=3,[36]=4,[37]=5,[94]=6,[38]=7,[42]=8,[40]=9}
local shifted = {'!','@','#','$','%','^','&','*','('}
local pending_symbol = nil

local function digit_of(kc)
  if kc >= 49 and kc <= 57 then return kc-48 end
  return symbols[kc]
end
local function prediction(ctx)
  if not ctx or not ctx:get_option('prediction') or not ctx:has_menu() then return false end
  local comp=ctx.composition
  return comp and not comp:empty() and comp:back():has_tag('prediction')
end
function M.func(key, env)
  if not key then return NOOP end
  local kc=key.keycode
  -- Bound the duplicate suppression to ONE physical Shift+digit keypress.
  if key:release() then
    if pending_symbol and (kc==pending_symbol or kc==SHIFT_L or kc==SHIFT_R
       or (kc>=49 and kc<=57)) then pending_symbol=nil end
    return NOOP
  end
  if key:ctrl() or key:alt() or key:super() then
    pending_symbol=nil
    return NOOP
  end
  local ctx=env and env.engine and env.engine.context
  local d=digit_of(kc)
  if pending_symbol then
    if key:shift() and kc==pending_symbol and not prediction(ctx) then
      pending_symbol=nil
      -- A second key event for the SAME Shift+digit before key release.
      -- Consumed as a duplicate, not inserted as punctuation.
      return ACCEPTED
    end
    pending_symbol=nil
  end
  if not prediction(ctx) then return NOOP end
  if not d then return NOOP end
  if not key:shift() then
    -- Rime's native selector would otherwise accept plain digits even in the
    -- zero-length prediction segment. Submit the digit literally and exit menu.
    if kc>=49 and kc<=57 then
      ctx:clear()
      env.engine:commit_text(tostring(d))
      return ACCEPTED
    end
    return NOOP
  end
  local comp=ctx.composition
  local seg=comp:back()
  -- selected_index is absolute; Shift+number addresses CURRENT PAGE, not page one.
  local selected=seg.selected_index or 0
  local page_start=math.floor(selected/9)*9
  local absolute=page_start+d-1
  local cand=seg:get_candidate_at(absolute)
  if not cand then return ACCEPTED end
  -- Preserve native predictor commit history and select notifier.
  -- In particular, do NOT replace ctx:select with engine:commit_text here.
  pending_symbol=string.byte(shifted[d])
  ctx:select(absolute)
  return ACCEPTED
end
return M
