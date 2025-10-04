local current_challenge = nil
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
    chat_channels.send("Challenges", "challenges", player:get_player_name() .. " received: " .. item)
  end
end

function challenge_respond(name, message)
  if not current_challenge then return end

  if message == current_challenge.answer then
    local elapsed = (minetest.get_us_time() - current_challenge.start_time) / 1000000
    chat_channels.send("Challenges", "challenges", name ..
      " solved the " .. current_challenge.type .. " challenge in " .. string.format("%.2f", elapsed) .. " seconds!", 4)
    local player = minetest.get_player_by_name(name)
    if player then give_reward(player) end

    current_challenge = nil
    return true
  end
end

-- Challenge: Descramble
local function start_descramble()
  local items = get_one_word_items()
  if #items == 0 then
    chat_channels.send("Challenges", "challenges", "No valid items found for descramble.")
    return
  end
  local item_key = items[math.random(#items)]
  local short_name = item_key:match(":(%w+)$")
  local scrambled = scramble(short_name)

  current_challenge = {
    type = "descramble",
    answer = short_name,
    start_time = minetest.get_us_time()
  }

  chat_channels.send("Challenges", "challenges", "Unscramble this item name: " .. scrambled)
  print("[chat_challenges] Answer: " .. short_name)
end

-- Challenge: Missing Letter
local function start_missing_letter()
  local items = get_one_word_items()
  if #items == 0 then
    chat_channels.send("Challenges", "challenges", "No valid items found for missing-letter challenge.")
    return
  end
  local item_key = items[math.random(#items)]
  local short_name = item_key:match(":(%w+)$")
  local puzzle = remove_random_letter(short_name)

  current_challenge = {
    type = "missing_letter",
    answer = short_name,
    start_time = minetest.get_us_time()
  }

  chat_channels.send("Challenges", "challenges", "Fill in the missing letter: " .. puzzle)
end

-- Challenge: Typing
local function start_typing()
  local items = get_one_word_items()
  if #items == 0 then
    chat_channels.send("Challenges", "challenges", "No valid items found for typing.")
    return
  end
  local item_key = items[math.random(#items)]
  local short_name = item_key:match(":(%w+)$")

  current_challenge = {
    type = "typing",
    answer = short_name,
    start_time = minetest.get_us_time()
  }

  chat_channels.send("Challenges", "challenges", "⌨️ Type this item name: " .. short_name)
end

-- Challenge: Reaction
local function start_reaction()
  local delay = math.random(reaction_min_delay, reaction_max_delay)
  chat_channels.send("Challenges", "challenges", "🚨 Get ready... wait for the signal!")
  minetest.after(delay, function()
    current_challenge = {
      type = "reaction",
      answer = "go",
      start_time = minetest.get_us_time()
    }
    chat_channels.send("Challenges", "challenges", "🚨 Type 'go' NOW!")
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

  chat_channels.send("Challenges", "challenges", "🧮 Solve: " .. a .. " " .. op .. " " .. b)
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
    -- if has_matrix and matrix_bridge and matrix_bridge.send_to_room then
    --   matrix_bridge.send_to_room("A " .. choice .. " challenge has been started.")
    -- end

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
        -- if has_matrix and matrix_bridge and matrix_bridge.send_to_room then
        --   matrix_bridge.send_to_room("A " .. choice .. " challenge has been started.")
        -- end
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
        chat_channels.send("Challenges", "challenges",
          "⏰ Challenge timed out. No one solved the " .. current_challenge.type .. " challenge.")
        current_challenge = nil
      end
    end
    challenge_timeout_loop()
  end)
end

-- Handle player responses
minetest.register_on_chat_message(function(name, message)
  challenge_respond(name, message)
end)

minetest.register_on_mods_loaded(function()
  chat_channels.create('challenges')
  chat_channels.send("Challenges", "global", 'test')
  auto_challenge_loop()
  challenge_timeout_loop()
end)
