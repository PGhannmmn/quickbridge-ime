-- QuickBridge IME v2.9 -- human-input audit; single-letter English, NumPad, modifiers.
-- EXPERIMENTAL; isolated scheme. Never changes v2.5/v2.4/v2.3/v2.2/v2.1 or global Rime config.
-- Preserves v2.3; fixes punctuation after prediction, provides Shift+Space for 2-letter English,
-- and streams English alphanumerics once a 3+ letter word or 2-letter uppercase-leading
-- acronym is followed by a digit. Normal 2-letter Quick + digit remains native.
-- Do not try to infer a boundary between two unseparated Latin letter runs.
-- NO file, registry, network, clipboard, or OS access.
-- Rime processor return: 1=Accepted, 2=Noop.
--   Letters: displayed as INLINE preedit (not committed until delimiter/selection).
--   Native numbered Chinese selections 1..9 stay in original rank/order.
--   One-letter + Space: native first Chinese candidate (f + Space = 火).
--   Two letters + Space with native menu: Rime key_binder pages the ORIGINAL menu.
--   Tab: literal English + one space; Enter: literal English, no space.
--   3+ letters + Space: literal English plus one space.
--   3+ letters + punctuation: commit exact Latin text plus ASCII punctuation.
-- The same two-letter input + Space cannot both page and add an English space.
local M = {}
local ACCEPTED, NOOP = 1, 2
local X_TAB, X_RETURN, X_KP_ENTER = 0xff09, 0xff0d, 0xff8d
local SPACE = 32
local X_BACKSPACE, X_ESCAPE = 0xff08, 0xff1b
local X_SHIFT_L, X_SHIFT_R = 0xffe1, 0xffe2
local MAX_ASCII = 64
-- Keysyms (US/English layout) for punctuation commonly used at an English
-- word boundary. Shifted symbols arrive already translated as keysyms.
-- The map is deliberately static and ASCII-only: don't guess punctuation
-- from international/IME keys. 1..9 selection and Chinese codes stay native.
local ASCII_PUNCT = {
  [33]='!', [34]='"', [35]='#', [36]='$', [37]='%', [38]='&', [39]="'",
  [40]='(', [41]=')', [42]='*', [43]='+', [44]=',', [45]='-', [46]='.',
  [47]='/', [58]=':', [59]=';', [60]='<', [61]='=', [62]='>',
  [63]='?', [64]='@', [91]='[', [92]='\\', [93]=']', [94]='^',
  [95]='_', [96]='`', [123]='{', [124]='|', [125]='}', [126]='~'
}

-- NumPad has its own X11/Rime keysyms, not ASCII 0..9 or + - * / .
-- NumLock OFF produces navigation keysyms; never convert those into numbers.
-- Prefer the specific keypad codes so main-row 1..9 remain Quick selections.
local KP_SYMBOL = {
  [0xffaa]='*', [0xffab]='+', [0xffac]=',', [0xffad]='-',
  [0xffae]='.', [0xffaf]='/', [0xffbd]='='
}
local KP_REPR_SYMBOL = {
  KP_Multiply='*', KP_Add='+', KP_Separator=',', KP_Subtract='-',
  KP_Decimal='.', KP_Divide='/', KP_Equal='='
}
local function keypad_key(key)
  local kc = key.keycode
  if kc >= 0xffb0 and kc <= 0xffb9 then
    return tostring(kc - 0xffb0), true
  end
  if KP_SYMBOL[kc] then return KP_SYMBOL[kc], false end
  -- Some frontends report the keypad key as a normalized ASCII keycode while
  -- retaining the physical keypad name in key:repr(). Ignore Shift+... prefixes.
  if type(key.repr) == 'function' then
    local repr = key:repr()
    if type(repr) == 'string' then
      local d = repr:match('^KP_([0-9])$')
      if d then return d, true end
      if KP_REPR_SYMBOL[repr] then return KP_REPR_SYMBOL[repr], false end
    end
  end
  return nil, false
end

local function letters(s)
  return type(s) == 'string' and #s > 0 and #s <= MAX_ASCII
      and s:match('^[A-Za-z]+$') ~= nil
end

local function ctx_from(env)
  if env and env.engine then return env.engine.context end
end

-- A Chinese commit may leave a zero-length predictor menu active. If the
-- next key is a letter (English OR a new Quick code), discard ONLY that menu.
-- Never clear a normal Chinese composition or change selector 1..9 behavior.
local function prediction_active(ctx)
  if not ctx or not ctx:get_option('prediction') or not ctx:has_menu() then
    return false
  end
  local comp = ctx.composition
  if not comp or comp:empty() then return false end
  local seg = comp:back()
  return seg ~= nil and seg:has_tag('prediction')
end

local function commit_raw(env, ctx, text)
  ctx:clear() -- avoid committing a pending Chinese menu a second time
  env.engine:commit_text(text)
  return ACCEPTED
end

-- In the Rime environment table this state survives consecutive keystrokes,
-- but is isolated per engine. Characters are committed immediately once an
-- English number run begins; app Backspace can erase them normally.
local SHIFT_DIGIT_SYMBOLS = {
  [33]=true, [64]=true, [35]=true, [36]=true, [37]=true,
  [94]=true, [38]=true, [42]=true, [40]=true
}
local function ascii_letter(kc)
  return (kc >= 97 and kc <= 122) or (kc >= 65 and kc <= 90)
end
local function ascii_digit(kc)
  return kc >= 48 and kc <= 57
end
-- Some frontends supply a shifted keysym (!), while others supply the base
-- keysym (1) with a Shift modifier. Both must produce punctuation, not "1".
-- Only used once ASCII mode has been explicitly established.
local SHIFTED_MAIN_DIGIT = {
  [48]=')', [49]='!', [50]='@', [51]='#', [52]='$', [53]='%',
  [54]='^', [55]='&', [56]='*', [57]='('
}
local function raw_stream_char(key, kc)
  if ascii_letter(kc) then
    -- Caps Lock uppercase keysyms need no physical Shift. Conversely some
    -- frontend events keep a lowercase keysym with a Shift mask.
    if kc >= 97 and kc <= 122 and key:shift() then
      return string.char(kc - 32)
    end
    return string.char(kc)
  end
  if ascii_digit(kc) then
    if key:shift() then return SHIFTED_MAIN_DIGIT[kc] end
    return string.char(kc)
  end
  return nil
end

-- A TAP is one Shift_L press followed by its release, with no intervening
-- key-down. This deliberately does not use the shifted keysym (! @ ...)
-- because Shift+digit MUST remain the original Chinese prediction picker.
-- Single-code Quick (e.g. h) MAY be explicitly confirmed as Latin by a tap.
-- Any pending all-Latin preedit (1..63 characters) is eligible for the tap. Shift+Space and Enter remain available.
-- A Shift tap while only the prediction menu is open does not commit anything.
local function left_shift_tap(key, env)
  local kc = key.keycode
  if kc == X_SHIFT_L then
    if key:release() then
      local tap = env.qb_v26_lshift_down and not env.qb_v26_lshift_used
      env.qb_v26_lshift_down = false
      env.qb_v26_lshift_used = false
      if not tap or key:ctrl() or key:alt() or key:super() then return NOOP end
      local ctx = ctx_from(env)
      if not ctx or ctx:get_option('ascii_mode') or prediction_active(ctx) then return NOOP end
      local pending = ctx.input or ''
      if letters(pending) then
        return commit_raw(env, ctx, pending) -- NO trailing whitespace
      end
      -- A bare Shift tap also explicitly ends a previously committed ASCII
      -- number stream, permitting a fresh Quick code without whitespace.
      if env.qb_v24_ascii_stream and pending == '' then
        env.qb_v24_ascii_stream = false
        return ACCEPTED
      end
      return NOOP
    end
    -- Repeated modifier key-down is not a fresh tap.
    if not env.qb_v26_lshift_down then
      env.qb_v26_lshift_down = true
      env.qb_v26_lshift_used = false
    end
    return NOOP
  end
  if env.qb_v26_lshift_down and not key:release() then
    env.qb_v26_lshift_used = true
  end
  return nil -- not a left-Shift event: continue ordinary v2.5 processing
end

function M.func(key, env)
  if not key then return NOOP end
  local shift_result = left_shift_tap(key, env)
  if shift_result ~= nil then return shift_result end
  if key:release() then return NOOP end
  if key:ctrl() or key:alt() or key:super() then
    env.qb_v24_ascii_stream = false
    return NOOP
  end
  local ctx = ctx_from(env)
  if not ctx or ctx:get_option('ascii_mode') then
    env.qb_v24_ascii_stream = false
    return NOOP
  end
  local code, input = key.keycode, ctx.input or ''
  local is_alpha = letters(input)
  local native_menu = is_alpha and #input <= 2 and ctx:has_menu()
  local boundary = ASCII_PUNCT[code]
  local kp_char, kp_is_digit = keypad_key(key)
  local kp_is_symbol = kp_char ~= nil and not kp_is_digit
  -- KEYBOARD POLICY: main-row digits normally select Quick characters;
  -- keypad digits after ANY pending Latin letter explicitly signal English.
  -- h + KP1 => h1, hi + KP1 => hi1, but hi + top-row1 selects 凡.
  -- One-letter English is explicitly confirmed by a bare left Shift tap.

  -- Rime/Weasel may reopen a stale predictor menu after an ASCII punctuation
  -- commit. Before the very next real key-down, discard that stale menu once,
  -- then process THIS key normally (never swallow it). No global option change.
  if env.qb_v25_post_punct_dismiss then
    env.qb_v25_post_punct_dismiss = false
    if prediction_active(ctx) then
      ctx:clear()
      input = ctx.input or ''
      is_alpha = letters(input)
      native_menu = is_alpha and #input <= 2 and ctx:has_menu()
    end
  end

  -- Following a Latin word with a digit (hello1 / AI2), keep all subsequent
  -- digits/letters in an unambiguous ASCII stream. No delimiter required.
  -- This has started only after an explicit, safe English cue (3+ letters, or
  -- a 2-letter uppercase-leading acronym); never on plain two-letter Quick.
  if env.qb_v24_ascii_stream then
    -- An externally started composition / reconstructed prediction takes
    -- precedence over the old English run (e.g. focus change, new Quick code).
    if input ~= '' or prediction_active(ctx) then
      env.qb_v24_ascii_stream = false
    -- Shift+KP digit may represent NumLock-inverted navigation. Do not force
    -- it into a digit or commit the pending English composition.
    elseif kp_is_digit and key:shift() then
      env.qb_v24_ascii_stream = false
      return NOOP
    else
      local c = kp_is_digit and kp_char or raw_stream_char(key, code)
      if c then return commit_raw(env, ctx, c) end
      if boundary or kp_is_symbol then
        env.qb_v24_ascii_stream = false
        return commit_raw(env, ctx, kp_char or boundary)
      end
      if code == SPACE then
        env.qb_v24_ascii_stream = false
        return commit_raw(env, ctx, ' ')
      end
      -- There is NO pending preedit during the ASCII stream: Tab, Enter,
      -- NumPad Enter and Esc must reach the application (focus/newline/cancel).
      if code == X_TAB or code == X_RETURN or code == X_KP_ENTER
         or code == X_ESCAPE then
        env.qb_v24_ascii_stream = false
        return NOOP
      end
      -- Backspace deletes the last already committed character in the app.
      env.qb_v24_ascii_stream = false
      if code == X_BACKSPACE then return NOOP end
    end
  end

  -- Chinese has already been committed, but Rime's prediction menu is still
  -- active. Direct punctuation must NOT select an unintended predicted word.
  -- Except shifted number-row keys: Shift+1..9 belongs to the v2.1 guard.
  -- Prediction is a zero-length Chinese menu. A NumPad number must be
  -- inserted literally (not select a suffix or an old Chinese candidate).
  -- Shift+KP digit is deliberately swallowed: it is NOT the documented
  -- Shift+main-number-row association picker, and may be a NumLock-off key.
  if prediction_active(ctx) and kp_is_digit then
    if key:shift() then return ACCEPTED end
    ctx:clear()
    env.engine:commit_text(kp_char)
    ctx:clear()
    env.qb_v25_post_punct_dismiss = true
    return ACCEPTED
  end

  -- NumPad arithmetic punctuation should dismiss the prediction menu too.
  if prediction_active(ctx) and kp_is_symbol then
    ctx:clear()
    env.engine:commit_text(kp_char)
    ctx:clear()
    env.qb_v25_post_punct_dismiss = true
    return ACCEPTED
  end

  if prediction_active(ctx) and boundary then
    if key:shift() and SHIFT_DIGIT_SYMBOLS[code] then return NOOP end
    -- Clear both before AND after committing punctuation: some Rime
    -- configurations may reconstruct the prediction segment on commit.
    -- Keep a one-key fallback above for delayed reconstruction.
    ctx:clear()
    env.engine:commit_text(boundary)
    ctx:clear()
    env.qb_v25_post_punct_dismiss = true
    return ACCEPTED
  end

  -- With no active composition, NumPad itself should still produce literal
  -- numbers/operators. Do not depend on the downstream selector to forward
  -- them as text; this branch also supports numeric input like 123+45.
  -- This does NOT start a Latin stream: typing a new Quick code immediately
  -- after standalone 1 should still start Chinese composition.
  local empty_comp = not ctx.composition or ctx.composition:empty()
  if input == '' and empty_comp and kp_char
     and not (kp_is_digit and key:shift()) then
    env.qb_v24_ascii_stream = false
    return commit_raw(env, ctx, kp_char)
  end

  -- NumPad digit is an explicit ASCII cue even after ONE Latin letter.
  -- NumPad deliberately DOES NOT select Chinese Quick candidates: the main
  -- digit row (1..9) remains the native Chinese selector.
  if kp_is_digit and is_alpha and not key:shift() then
    local result = commit_raw(env, ctx, input .. kp_char)
    env.qb_v24_ascii_stream = true
    return result
  end

  -- NumPad operators (and an explicit main-keyboard +) are Latin boundaries
  -- even after ONE letter. Main keyboard comma/period remain native for
  -- one/two-letter Quick: vd, must retain Chinese punctuation behavior.
  if is_alpha and (kp_is_symbol or code == 43) then
    return commit_raw(env, ctx, input .. (kp_char or '+'))
  end

  -- Main-row digits 1..9 after short lowercase Quick retain native Chinese
  -- selection. Zero is NOT a selection (9 slots/page), and is a safe ASCII
  -- cue even after one Latin letter (h0 / of0).
  -- Uppercase-leading English (AI2026 / H1) and 3+ Latin letters stream.
  -- Shift+1 must never turn into literal digit "1".
  if ascii_digit(code) and not key:shift() and is_alpha
     and (code == 48 or #input > 2 or input:match('^[A-Z]')) then
    local result = commit_raw(env, ctx, input .. string.char(code))
    env.qb_v24_ascii_stream = true
    return result
  end

  -- On some frontends Shift+1 reports keycode 49 with a Shift mask instead
  -- of an exclam keysym. Only unambiguously English compositions capture it;
  -- a pending Quick code or association keeps the original Shift+digit path.
  local latin_punct = boundary or (key:shift() and SHIFTED_MAIN_DIGIT[code])
  -- English punctuation after 3+ letters; or explicit uppercase-leading
  -- short English (Hi,). Lowercase two-letter Quick codes (vd, / of,) stay
  -- native, consistent with the v2.2 regression/selection semantics.
  if is_alpha and (#input > 2 or input:match('^[A-Z]')) and latin_punct then
    return commit_raw(env, ctx, input .. latin_punct)
  end

  if (code == X_RETURN or code == X_KP_ENTER) and is_alpha then
    return commit_raw(env, ctx, input)
  end
  if code == X_TAB and is_alpha then
    return commit_raw(env, ctx, input .. ' ')
  end

  if code == SPACE and is_alpha then
    -- Shift+Space: explicit short English with trailing space (h / hi).
    -- Ordinary Space on a single Quick code commits Chinese, on two pages.
    if key:shift() then
      return commit_raw(env, ctx, input .. ' ')
    end
    if #input == 1 and native_menu then
      local chosen = ctx:get_selected_candidate()
      if chosen and chosen.text then
        ctx:commit()
        return ACCEPTED
      end
      return NOOP
    end
    if #input == 2 and native_menu then return NOOP end
    return commit_raw(env, ctx, input .. ' ')
  end

  local lower = code >= 97 and code <= 122
  local upper = code >= 65 and code <= 90
  if lower or upper then
    local latin = raw_stream_char(key, code)
    if prediction_active(ctx) then
      ctx:clear()
      local accepted = ctx:push_input(latin)
      if accepted == false then return NOOP end
      return ACCEPTED
    end
    if input == '' or is_alpha then
      if #input >= MAX_ASCII - 1 then
        -- Commit on the 64th character, BEFORE Rime's max_code_length can
        -- reject or auto-finalize it; continue in raw ASCII stream mode.
        local result = commit_raw(env, ctx, input .. latin)
        env.qb_v24_ascii_stream = true
        return result
      end
      local accepted = ctx:push_input(latin)
      if accepted == false then return NOOP end
      return ACCEPTED
    end
  end
  return NOOP
end

return M
