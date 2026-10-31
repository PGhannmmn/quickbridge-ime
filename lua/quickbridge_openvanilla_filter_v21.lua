-- QuickBridge v2.1: source-pinned OpenVanilla associated-phrases.cin full-order overlay.
-- This is historical third-party data, NOT an official Microsoft Windows 11 export.
-- Candidate pages are NOT truncated at 9; Rime handles 9-item paging.
-- Non-prediction/Quick candidates are passed through unchanged.
local ok, data = pcall(require, 'quickbridge_openvanilla_assoc_v21')
if not ok or type(data) ~= 'table' then data = {} end
local M = {}
local function last_head(ctx)
  if not ctx or not ctx:get_option('prediction') then return nil end
  local hist = ctx.commit_history
  if not hist or hist:empty() then return nil end
  local item = hist:back()
  if not item or type(item.text) ~= 'string' then return nil end
  if item.type == 'punct' or item.type == 'raw' or item.type == 'thru' then return nil end
  local t = item.text
  if #t == 0 then return nil end
  -- For multi-character phrase commits, use last Unicode character as head.
  if utf8 and utf8.offset then
    local success, i = pcall(utf8.offset, t, -1)
    if success and i then return t:sub(i) end
  end
  return t
end
function M.func(input, env)
  local ctx = env and env.engine and env.engine.context
  local head = last_head(ctx)
  local words = head and data[head] or nil
  if not words or #words == 0 then
    for cand in input:iter() do yield(cand) end
    return
  end
  local replaced = false
  for cand in input:iter() do
    if cand.type ~= 'prediction' then
      yield(cand)
    elseif not replaced then
      replaced = true
      local s = cand.start or 0
      local e = cand._end or s
      for _, suffix in ipairs(words) do
        yield(Candidate('prediction', s, e, suffix, ''))
      end
    end
  end
end
return M
