local current_challenge = nil
local has_matrix = minetest.get_modpath("matrix_bridge")
local challenge_types = { "descramble", "missing_letter", "typing", "reaction", "math" }

-- Load settings from minetest.conf
local reaction_min_delay = tonumber(minetest.settings:get("chat_challenges_reaction_min_delay")) or 3
local reaction_max_delay = tonumber(minetest.settings:get("chat_challenges_reaction_max_delay")) or 8
local challenge_interval = tonumber(minetest.settings:get("chat_challenges_interval")) or 300
local challenge_timeout = tonumber(minetest.settings:get("chat_challenges_timeout")) or 16
local max_item_name_length = tonumber(minetest.settings:get("chat_challenges_max_item_length")) or 7
local disallow_symbols = minetest.settings:get_bool("chat_challenges_disallow_symbols") or true
local disallow_numbers = minetest.settings:get_bool("chat_challenges_disallow_numbers") or true

local reward_items_raw = minetest.settings:get("chat_challenges_rewards") or
    "default:apple,default:pick_steel,default:mese_crystal"
local reward_items = {}
for item in reward_items_raw:gmatch("[^,]+") do
  table.insert(reward_items, item)
end

local enabled_challenges_raw = minetest.settings:get("chat_challenges_enabled") or
    "descramble,missing_letter,typing,reaction,math"
local enabled_challenges = {}
for challenge in enabled_challenges_raw:gmatch("[^,]+") do
  enabled_challenges[challenge] = true
end

-- Utility: Get item display name (first word only)
local function get_item_display_name(item_key)
  local def = minetest.registered_items[item_key]
  if def and def.description and def.description ~= "" then
    return def.description:match("^(%w+)") or def.description
  end
  -- Fallback: use short name from item key
  local short_name = item_key:match(":(%w+)$")
  return short_name or item_key
end


-- Utility: Scramble a word (Fisher-Yates)
local function scramble(word)
  local chars = {}
  for i = 1, #word do
    chars[i] = word:sub(i, i)
  end
  for i = #chars, 2, -1 do
    local j = math.random(i)
    chars[i], chars[j] = chars[j], chars[i]
  end
  return table.concat(chars)
end

-- Utility: Remove one random letter
local function remove_random_letter(word)
  if #word <= 1 then return word end
  local index = math.random(1, #word)
  return word:sub(1, index - 1) .. word:sub(index + 1)
end

-- Utility: Get one-word item keys
local function get_one_word_items()
  local items = {}
  for name, def in pairs(minetest.registered_items) do
    if not name:find(":") then goto continue end
    if not def or type(def.description) ~= "string" or def.description == "" then goto continue end
    local short_name = name:match(":(%w+)$")
    if not short_name then goto continue end
    if #short_name > max_item_name_length then goto continue end
    if disallow_symbols and short_name:find("[^%w]") then goto continue end
    if disallow_numbers and short_name:find("%d") then goto continue end
    table.insert(items, name)
    ::continue::
  end
  return items
end


-- Reward system
local function give_reward(player)
  local item = reward_items[math.random(#reward_items)]
  local inv = player:get_inventory()
  if inv then
    inv:add_item("main", item)
    minetest.chat_send_all(player:get_player_name() .. " received: " .. item)
  end
end

-- Challenge: Descramble
local function start_descramble()
  local items = get_one_word_items()
  if #items == 0 then
    minetest.chat_send_all("❌ No valid items found for descramble.")
    return
  end
  local item_key = items[math.random(#items)]
  local short_name = item_key:match(":(%w+)$")
  local scrambled = scramble(short_name)
  local display_name = get_item_display_name(item_key)

  current_challenge = {
    type = "descramble",
    answer = short_name,
    start_time = minetest.get_us_time()
  }

  minetest.chat_send_all("🔀 Unscramble this item name: " .. scrambled)
end

-- Challenge: Missing Letter
local function start_missing_letter()
  local items = get_one_word_items()
  if #items == 0 then
    minetest.chat_send_all("❌ No valid items found for missing-letter challenge.")
    return
  end
  local item_key = items[math.random(#items)]
  local short_name = item_key:match(":(%w+)$")
  local display_name = get_item_display_name(item_key)
  local puzzle = remove_random_letter(short_name)

  current_challenge = {
    type = "missing_letter",
    answer = short_name,
    start_time = minetest.get_us_time()
  }

  minetest.chat_send_all("🧩 Fill in the missing letter: " .. puzzle)
end

-- Challenge: Typing
local function start_typing()
  local items = get_one_word_items()
  if #items == 0 then
    minetest.chat_send_all("❌ No valid items found for typing.")
    return
  end
  local item_key = items[math.random(#items)]
  local short_name = item_key:match(":(%w+)$")
  local display_name = get_item_display_name(item_key)

  current_challenge = {
    type = "typing",
    answer = short_name,
    start_time = minetest.get_us_time()
  }

  minetest.chat_send_all("⌨️ Type this item name: " .. display_name)
end

-- Challenge: Reaction
local function start_reaction()
  local delay = math.random(reaction_min_delay, reaction_max_delay)
  minetest.chat_send_all("🚨 Get ready... wait for the signal!")
  minetest.after(delay, function()
    current_challenge = {
      type = "reaction",
      answer = "go",
      start_time = minetest.get_us_time()
    }
    minetest.chat_send_all("🚨 Type 'go' NOW!")
  end)
end

-- Challenge: Math
local function start_math()
  local a = math.random(1, 20)
  local b = math.random(1, 20)
  local op = math.random(1, 2) == 1 and "+" or "-"
  local answer = op == "+" and (a + b) or (a - b)

  current_challenge = {
    type = "math",
    answer = tostring(answer),
    start_time = minetest.get_us_time()
  }

  minetest.chat_send_all("🧮 Solve: " .. a .. " " .. op .. " " .. b)
end

-- Manual challenge command
minetest.register_chatcommand("challenge", {
  description = "Start a random chat challenge",
  privs = { server = true },
  func = function(name)
    if current_challenge then
      return false, "A challenge is already active."
    end

    local available = {}
    for _, ctype in ipairs(challenge_types) do
      if enabled_challenges[ctype] then
        table.insert(available, ctype)
      end
    end
    if #available == 0 then
      return false, "No challenges are enabled in settings."
    end

    local choice = available[math.random(#available)]
    if has_matrix and matrix_bridge and matrix_bridge.send_to_room then
      matrix_bridge.send_to_room("A " .. choice .. " challenge has been started.")
    end

    if choice == "descramble" then
      start_descramble()
    elseif choice == "missing_letter" then
      start_missing_letter()
    elseif choice == "typing" then
      start_typing()
    elseif choice == "reaction" then
      start_reaction()
    elseif choice == "math" then
      start_math()
    end
  end
})

-- Handle player responses
minetest.register_on_chat_message(function(name, message)
  if not current_challenge then return end

  if message == current_challenge.answer then
    local elapsed = (minetest.get_us_time() - current_challenge.start_time) / 1000000
    minetest.chat_send_all("✅ " ..
      name ..
      " solved the " .. current_challenge.type .. " challenge in " .. string.format("%.2f", elapsed) .. " seconds!")

    local player = minetest.get_player_by_name(name)
    if player then give_reward(player) end

    current_challenge = nil
    return true
  end
end)

-- Automatic challenge loop
local function auto_challenge_loop()
  minetest.after(challenge_interval, function()
    local players = minetest.get_connected_players()
    if #players == 0 then
      minetest.log("action", "[chat_challenges] No players online — skipping challenge.")
      auto_challenge_loop()
      return
    end

    if not current_challenge then
      local available = {}
      for _, ctype in ipairs(challenge_types) do
        if enabled_challenges[ctype] then
          table.insert(available, ctype)
        end
      end
      if #available > 0 then
        local choice = available[math.random(#available)]
        if has_matrix and matrix_bridge and matrix_bridge.send_to_room then
          matrix_bridge.send_to_room("A " .. choice .. " challenge has been started.")
        end
        if choice == "descramble" then
          start_descramble()
        elseif choice == "missing_letter" then
          start_missing_letter()
        elseif choice == "typing" then
          start_typing()
        elseif choice == "reaction" then
          start_reaction()
        elseif choice == "math" then
          start_math()
        end
      end
    end

    auto_challenge_loop()
  end)
end


local function challenge_timeout_loop()
  minetest.after(1, function()
    if current_challenge then
      local now = minetest.get_us_time()
      local elapsed = (now - current_challenge.start_time) / 1000000
      if elapsed > challenge_timeout then
        minetest.chat_send_all("⏰ Challenge timed out. No one solved the " .. current_challenge.type .. " challenge.")
        current_challenge = nil
      end
    end
    challenge_timeout_loop()
  end)
end

minetest.register_on_mods_loaded(function()
  auto_challenge_loop()
  challenge_timeout_loop()
end)
