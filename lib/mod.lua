-- nb_supertonic v0.1 @sonoCircuit - based on supertonic @infinitedigits

local fs = require 'fileselect'
local tx = require 'textentry'
local md = require 'core/mods'

local NUM_VOICES = 6

local kit_path = "/home/we/dust/data/nb_supertonic/supertonic_kits"
local vox_path = "/home/we/dust/data/nb_supertonic/supertonic_voxs"
local default_kit = "/home/we/dust/data/nb_supertonic/supertonic_kits/default.stkit"

local selected_voice = 1
local current_kit = ""

local voice_params = {
  "level", "dist", "send_a", "send_b", "eq_freq", "eq_gain", "mix",
  "osc_wav", "osc_freq", "mod_mode", "mod_amt", "mod_rate", "osc_attack", "osc_decay",
  "noise_mode", "noise_freq", "noise_q", "noise_env", "noise_attack", "noise_decay", "noise_stereo",
  "osc_vel", "mod_vel", "noise_vel"
}


---------------- osc msgs ----------------

local function trig_supertonic(note, vel)
  local vox = note % NUM_VOICES
  osc.send({'localhost', 57120}, '/nb_supertonic/trig', {vox, vel})
end

local function set_param(i, key, val)
  local vox = i - 1
  osc.send({'localhost', 57120}, '/nb_supertonic/set_param', {vox, key, val})
end

local function set_main_amp(val)
  osc.send({'localhost', 57120}, '/nb_supertonic/set_main_amp', {val})
end

local function set_cutoff(val)
  osc.send({'localhost', 57120}, '/nb_supertonic/set_cutoff', {val})
end

local function set_resonance(val)
  osc.send({'localhost', 57120}, '/nb_supertonic/set_resonance', {val})
end


---------------- functions ----------------

local function linsig(k, x)
	return (1 / (1 + math.exp(-k * (x - 0.5))))
end

local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

local function build_menu()
  for i = 1, NUM_VOICES do
    for _,v in ipairs(voice_params) do
      local name = "nb_supertonic_"..v.."_"..i
      if i == selected_voice then
        params:show(name)
        if not md.is_loaded("fx") then
          params:hide("nb_supertonic_send_a_"..i)
          params:hide("nb_supertonic_send_b_"..i)
        end
      else
        params:hide(name)
      end
    end
  end
  _menu.rebuild_params()
end

local function save_kit(txt)
  if txt then
    local kit = {}
    for _, v in ipairs(voice_params) do
      kit[v] = {}
      for n = 1, NUM_VOICES do
        table.insert(kit[v], params:get("nb_supertonic_"..v.."_"..n))
      end
    end
    tab.save(kit, kit_path.."/"..txt..".stkit")
    current_kit = txt
    print("saved supertonic kit: "..txt)
  end
end

local function load_kit(path)
  if path ~= "cancel" and path ~= "" then
    if path:match("^.+(%..+)$") == ".stkit" then
      local kit = tab.load(path)
      if kit ~= nil then
        for i, v in ipairs(voice_params) do
          if kit[v] ~= nil then
            for n = 1, NUM_VOICES do
              params:set("nb_supertonic_"..v.."_"..n, kit[v][n])
            end
          end
        end
        local name = path:match("[^/]*$")
        current_kit = name:gsub(".stkit", "")
        print("loaded supertonic kit: "..current_kit)
      else
        print("error: could not find kit", path)
      end
    else
      print("error: not a kit file")
    end
  end
end

local function save_voice(txt)
  if txt then
    local t = {}
    for _, v in ipairs(voice_params) do
      t[v] = params:get("nb_supertonic_"..v.."_"..selected_voice)
    end
    tab.save(t, vox_path.."/"..txt..".stvox")
    print("saved drmfm voice: "..txt)
  end
end

local function load_voice(path)
  if path ~= "cancel" and path ~= "" then
    if path:match("^.+(%..+)$") == ".stvox" then
      local t = tab.load(path)
      if t ~= nil then
        for _, v in ipairs(voice_params) do
          if t[v] ~= nil then
            params:set("nb_supertonic_"..v.."_"..selected_voice, t[v])
          end
        end
        local name = path:match("[^/]*$"):gsub(".kvox", "")
        print("loaded supertonic vox: "..name)
      else
        print("error: could not find vox", path)
      end
    else
      print("error: not a vox file")
    end
  end
end

local function add_params()
  params:add_group("nb_supertonic_group", "supertonic", ((NUM_VOICES * 24) + 16))
  
  params:add_separator("nb_supertonic_kits", "supertonic kit")

  params:add_trigger("nb_supertonic_load_kit", ">> load")
  params:set_action("nb_supertonic_load_kit", function(path) fs.enter(kit_path, function(path) load_kit(path) end) end)

  params:add_trigger("nb_supertonic_save_kit", "<< save")
  params:set_action("nb_supertonic_save_kit", function() tx.enter(save_kit, current_kit)  end)
   
  params:add_separator("nb_supertonic_globals", "globals")

  params:add_control("nb_supertonic_global_level", "main level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("nb_supertonic_global_level", function(val) set_main_amp(val) end)

  params:add_control("nb_supertonic_global_cutoff", "lpf cutoff", controlspec.new(20, 20000, "exp", 0, 20000), function(param) return round_form(param:get(), 1, "hz") end)
  params:set_action("nb_supertonic_global_cutoff", function(val) set_cutoff(val) end)
  
  params:add_control("nb_supertonic_global_resonance", "lpf rez", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("nb_supertonic_global_resonance", function(val) set_resonance(val) end)

  params:add_separator("nb_supertonic_voice", "voice")

  params:add_number("nb_supertonic_selected_voice", "selected voice", 1, NUM_VOICES, 1)
  params:set_action("nb_supertonic_selected_voice", function(n) selected_voice = n build_menu() end)
  
  params:add_binary("nb_supertonic_trig", "trig voice >>")
  params:set_action("nb_supertonic_trig", function() trig_supertonic(selected_voice - 1, 1) end)

  params:add_trigger("nb_supertonic_save_voice", "> load voice")
  params:set_action("nb_supertonic_save_voice", function() fs.enter(vox_path, function(path) load_voice(path) end) end)

  params:add_trigger("nb_supertonic_load_voice", "< save voice")
  params:set_action("nb_supertonic_load_voice", function() tx.enter(save_voice, "") end)
  
  params:add_separator("nb_supertonic_level_params", "levels")
  for i = 1, NUM_VOICES do
    params:add_control("nb_supertonic_level_"..i, "level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_level_"..i, function(val) set_param(i, 'level', val)  end)

    params:add_control("nb_supertonic_dist_"..i, "distortion", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_dist_"..i, function(val) set_param(i, 'distAmt', linsig(12.5, val)) end)

    params:add_control("nb_supertonic_send_a_"..i, "send a", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_send_a_"..i, function(val) set_param(i, 'sendA', val) end)

    params:add_control("nb_supertonic_send_b_"..i, "send b", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_send_b_"..i, function(val) set_param(i, 'sendB', val) end)
    
    params:add_control("nb_supertonic_eq_freq_"..i, "eq freq", controlspec.new(20, 20000, "exp", 0, 1000), function(param) return round_form(param:get(), 1, "hz") end)
    params:set_action("nb_supertonic_eq_freq_"..i, function(val) set_param(i, 'eQFreq', val) end)

    params:add_control("nb_supertonic_eq_gain_"..i, "eq gain", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 20, 0.1, "dB") end)
    params:set_action("nb_supertonic_eq_gain_"..i, function(val) set_param(i, 'eQFreq', val * 20) end)

    params:add_control("nb_supertonic_mix_"..i, "mix [tone/noise]", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(100 - (param:get() * 100), 1, "/")..round_form(param:get() * 100, 1, "") end)
    params:set_action("nb_supertonic_mix_"..i, function(val) set_param(i, 'mix', linsig(12.5, val)) end)
  end

  params:add_separator("nb_supertonic_tone_params", "tone")
  for i = 1, NUM_VOICES do
    params:add_option("nb_supertonic_osc_wav_"..i, "tone waveform", {"sine", "tri", "saw"}, 1)
    params:set_action("nb_supertonic_osc_wav_"..i, function(val) set_param(i, 'oscWave', val - 1)  end)

    params:add_control("nb_supertonic_osc_freq_"..i, "tone freq", controlspec.new(20, 20000, "exp", 0, 1000), function(param) return round_form(param:get(), 1, "hz") end)
    params:set_action("nb_supertonic_osc_freq_"..i, function(val) set_param(i, 'oscFreq', val + 5) end)

    params:add_option("nb_supertonic_mod_mode_"..i, "tone mod mode", {"decay", "sine", "random"}, 1)
    params:set_action("nb_supertonic_mod_mode_"..i, function(val) set_param(i, 'modMode', val - 1)  end)

    params:add_number("nb_supertonic_mod_amt_"..i, "tone mod amt", -96, 96, 0, function(param) return  (param:get() < 0 and "" or "+")..param:get().."st" end)
    params:set_action("nb_supertonic_mod_amt_"..i, function(val) set_param(i, 'modAmt', val)  end)

    params:add_control("nb_supertonic_mod_rate_"..i, "tone mod rate", controlspec.new(0.1, 20000, "exp", 0, 17), function(param) return round_form(param:get(), 0.1, "hz") end)
    params:set_action("nb_supertonic_mod_rate_"..i, function(val) set_param(i, 'eQFreq', val) end)

    params:add_control("nb_supertonic_osc_attack_"..i, "tone attack", controlspec.new(0, 10, "lin", 0, 0, "", 1/1000), function(param) return round_form(param:get() * 1000, 1, "ms") end)
    params:set_action("nb_supertonic_osc_attack_"..i, function(val) set_param(i, 'oscAtk', val) end)

    params:add_control("nb_supertonic_osc_decay_"..i, "tone decay", controlspec.new(0, 10, "lin", 0, 0.32, "", 1/1000), function(param) return round_form(param:get() * 1000, 1, "ms") end)
    params:set_action("nb_supertonic_osc_decay_"..i, function(val) set_param(i, 'oscDcy', val) end)
  end
  
  params:add_separator("nb_supertonic_noise_params", "noise")
  for i = 1, NUM_VOICES do
    params:add_control("nb_supertonic_noise_freq_"..i, "noise freq", controlspec.new(20, 20000, "exp", 0, 1000), function(param) return round_form(param:get(), 1, "hz") end)
    params:set_action("nb_supertonic_noise_freq_"..i, function(val) set_param(i, 'nFilFrq', val) end)

    params:add_control("nb_supertonic_noise_q_"..i, "noise filter q", controlspec.new(0.1, 10000, "exp", 0, 0.7), function(param) return round_form(param:get(), 0.1, "") end)
    params:set_action("nb_supertonic_noise_q_"..i, function(val) set_param(i, 'nFilQ', val) end)

    params:add_option("nb_supertonic_noise_mode_"..i, "noise filter mode", {"lp", "bp", "hp"}, 1)
    params:set_action("nb_supertonic_noise_mode_"..i, function(val) set_param(i, 'nFilMod', val - 1)  end)

    params:add_option("nb_supertonic_noise_env_"..i, "noise env mode", {"exp", "lin", "mod"}, 1)
    params:set_action("nb_supertonic_noise_env_"..i, function(val) set_param(i, 'nEnvMod', val - 1)  end)
    
    params:add_control("nb_supertonic_noise_attack_"..i, "noise attack", controlspec.new(0, 10, "lin", 0, 0, "", 1/1000), function(param) return round_form(param:get() * 1000, 1, "ms") end)
    params:set_action("nb_supertonic_noise_attack_"..i, function(val) set_param(i, 'nEnvAtk', val) end)

    params:add_control("nb_supertonic_noise_decay_"..i, "noise decay", controlspec.new(0, 10, "lin", 0, 0.32, "", 1/1000), function(param) return round_form(param:get() * 1000, 1, "ms") end)
    params:set_action("nb_supertonic_noise_decay_"..i, function(val) set_param(i, 'nEnvDcy', val * 1.4) end)
    
    params:add_option("nb_supertonic_noise_stereo_"..i, "noise stereo", {"off", "on"}, 2)
    params:set_action("nb_supertonic_noise_stereo_"..i, function(val) set_param(i, 'nStereo', val - 1)  end)
  end
  
  params:add_separator("nb_supertonic_velocity_params", "velocity")
  for i = 1, NUM_VOICES do
    params:add_control("nb_supertonic_osc_vel_"..i, "osc velocity", controlspec.new(0, 2, "lin", 0, 1, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_osc_vel_"..i, function(val) set_param(i, 'oscVel', val)  end)

    params:add_control("nb_supertonic_mod_vel_"..i, "mod velocity", controlspec.new(0, 2, "lin", 0, 1, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_mod_vel_"..i, function(val) set_param(i, 'modVel', val)  end)

    params:add_control("nb_supertonic_noise_vel_"..i, "noise velocity", controlspec.new(0, 2, "lin", 0, 1, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("nb_supertonic_noise_vel_"..i, function(val) set_param(i, 'nVel', val)  end)
  end
end

---------------- nb player ----------------

function add_nb_supertonic_player()
  local player = {}

  function player:describe()
    return {
      name = "supertonic",
      supports_bend = false,
      supports_slew = false
    }
  end
  
  function player:active()
    if self.name ~= nil then
      params:show("nb_supertonic_group")
      _menu.rebuild_params()
    end
  end

  function player:inactive()
    if self.name ~= nil then
      params:hide("nb_supertonic_group")
      _menu.rebuild_params()
    end
  end

  function player:stop_all()
  end

  function player:modulate(val)
  end

  function player:set_slew(s)
  end

  function player:pitch_bend(note, val)
  end

  function player:modulate_note(note, key, value)
  end

  function player:note_on(note, vel)
    trig_supertonic(note, vel)
  end

  function player:note_off(note)
  end

  function player:add_params()
    add_params()
  end

  if note_players == nil then
    note_players = {}
  end

  note_players["supertonic"] = player
end


---------------- mod zone ----------------

local function post_system()
  if util.file_exists(kit_path) == false then
    util.make_dir(kit_path)
    util.make_dir(vox_path)
    --os.execute('cp '.. '/home/we/dust/code/nb_supertonic/data/supertonic_kits/*.stkit '.. kit_path)
    --os.execute('cp '.. '/home/we/dust/code/nb_supertonic/data/supertonic_voxs/*.stvox '.. vox_path)
  end
end

local function pre_init()
  add_nb_supertonic_player()
end

md.hook.register("system_post_startup", "nb supertonic post startup", post_system)
md.hook.register("script_pre_init", "nb supertonic pre init", pre_init)

