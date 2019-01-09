--[ FileConcat-S src/license_blurb.lua HASH:9dcbc85dd77b54786ebc0ef0b7145b6183e4fffc2d527c2832ee9bc51f0f61eb ]--
--[[
    Copyright (C) 2018

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--
--[ FileConcat-E src/license_blurb.lua HASH:9dcbc85dd77b54786ebc0ef0b7145b6183e4fffc2d527c2832ee9bc51f0f61eb ]--
--[ FileConcat-S lib/helpers.lua HASH:66f7cd869de2dda2fcc45a6af21529b84297f9001b7a26c8654ad096298a54a7 ]--
--[[
  Assorted helper functions, from checking falsey values to path utils
  to escaping and wrapping strings.

  Does not depend on other libs.
]]--

local assdraw = require 'mp.assdraw'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

-- Determine platform --
ON_WINDOWS = (package.config:sub(1,1) ~= '/')

-- Some helper functions needed to parse the options --
function isempty(v) return (v == false) or (v == nil) or (v == "") or (v == 0) or (type(v) == "table" and next(v) == nil) end

function divmod (a, b)
  return math.floor(a / b), a % b
end

-- Better modulo
function bmod( i, N )
  return (i % N + N) % N
end


-- Path utils
local path_utils = {
  abspath    = true,
  split      = true,
  dirname    = true,
  basename   = true,

  isabs      = true,
  normcase   = true,
  splitdrive = true,
  join       = true,
  normpath   = true,
  relpath    = true,
}

-- Helpers
path_utils._split_parts = function(path, sep)
  local path_parts = {}
  for c in path:gmatch('[^' .. sep .. ']+') do table.insert(path_parts, c) end
  return path_parts
end

-- Common functions
path_utils.abspath = function(path)
  if not path_utils.isabs(path) then
    local cwd = os.getenv("PWD") or utils.getcwd()
    path = path_utils.join(cwd, path)
  end
  return path_utils.normpath(path)
end

path_utils.split = function(path)
  local drive, path = path_utils.splitdrive(path)
  -- Technically unix path could contain a \, but meh
  local first_index, last_index = path:find('^.*[/\\]')

  if last_index == nil then
    return drive .. '', path
  else
    local head = path:sub(0, last_index-1)
    local tail = path:sub(last_index+1)
    if head == '' then head = sep end
    return drive .. head, tail
  end
end

path_utils.dirname = function(path)
  local head, tail = path_utils.split(path)
  return head
end

path_utils.basename = function(path)
  local head, tail = path_utils.split(path)
  return tail
end

path_utils.expanduser = function(path)
  -- Expands the following from the start of the path:
  -- ~ to HOME
  -- ~~ to mpv config directory (first result of mp.find_config_file('.'))
  -- ~~desktop to Windows desktop, otherwise HOME
  -- ~~temp to Windows temp or /tmp/

  local first_index, last_index = path:find('^.-[/\\]')
  local head = path
  local tail = ''

  local sep = ''

  if last_index then
    head = path:sub(0, last_index-1)
    tail = path:sub(last_index+1)
    sep  = path:sub(last_index, last_index)
  end

  if head == "~~desktop" then
    head = ON_WINDOWS and path_utils.join(os.getenv('USERPROFILE'), 'Desktop') or os.getenv('HOME')
  elseif head == "~~temp" then
    head = ON_WINDOWS and os.getenv('TEMP') or (os.getenv('TMP') or '/tmp/')
  elseif head == "~~" then
    local mpv_config_dir = mp.find_config_file('.')
    if mpv_config_dir then
      head = path_utils.dirname(mpv_config_dir)
    else
      msg.warn('Could not find mpv config directory (using mp.find_config_file), using temp instead')
      head = ON_WINDOWS and os.getenv('TEMP') or (os.getenv('TMP') or '/tmp/')
    end
  elseif head == "~" then
    head = ON_WINDOWS and os.getenv('USERPROFILE') or os.getenv('HOME')
  end

  return path_utils.normpath(path_utils.join(head .. sep, tail))
end


if ON_WINDOWS then
  local sep = '\\'
  local altsep = '/'
  local curdir = '.'
  local pardir = '..'
  local colon = ':'

  local either_sep = function(c) return c == sep or c == altsep end

  path_utils.isabs = function(path)
    local prefix, path = path_utils.splitdrive(path)
    return either_sep(path:sub(1,1))
  end

  path_utils.normcase = function(path)
    return path:gsub(altsep, sep):lower()
  end

  path_utils.splitdrive = function(path)
    if #path >= 2 then
      local norm = path:gsub(altsep, sep)
      if (norm:sub(1, 2) == (sep..sep)) and (norm:sub(3,3) ~= sep) then
        -- UNC path
        local index = norm:find(sep, 3)
        if not index then
          return '', path
        end

        local index2 = norm:find(sep, index + 1)
        if index2 == index + 1 then
          return '', path
        elseif not index2 then
          index2 = path:len()
        end

        return path:sub(1, index2-1), path:sub(index2)
      elseif norm:sub(2,2) == colon then
        return path:sub(1, 2), path:sub(3)
      end
    end
    return '', path
  end

  path_utils.join = function(path, ...)
    local paths = {...}

    local result_drive, result_path = path_utils.splitdrive(path)

    function inner(p)
      local p_drive, p_path = path_utils.splitdrive(p)
      if either_sep(p_path:sub(1,1)) then
        -- Path is absolute
        if p_drive ~= '' or result_drive == '' then
          result_drive = p_drive
        end
        result_path = p_path
        return
      elseif p_drive ~= '' and p_drive ~= result_drive then
        if p_drive:lower() ~= result_drive:lower() then
          -- Different paths, ignore first
          result_drive = p_drive
          result_path = p_path
          return
        end
      end

      if result_path ~= '' and not either_sep(result_path:sub(-1)) then
        result_path = result_path .. sep
      end
      result_path = result_path .. p_path
    end

    for i, p in ipairs(paths) do inner(p) end

    -- add separator between UNC and non-absolute path
    if result_path ~= '' and not either_sep(result_path:sub(1,1)) and
      result_drive ~= '' and result_drive:sub(-1) ~= colon then
      return result_drive .. sep .. result_path
    end
    return result_drive .. result_path
  end

  path_utils.normpath = function(path)
    if path:find('\\\\.\\', nil, true) == 1 or path:find('\\\\?\\', nil, true) == 1 then
      -- Device names and literal paths - return as-is
      return path
    end

    path = path:gsub(altsep, sep)
    local prefix, path = path_utils.splitdrive(path)

    if path:find(sep) == 1 then
      prefix = prefix .. sep
      path = path:gsub('^[\\]+', '')
    end

    local comps = path_utils._split_parts(path, sep)

    local i = 1
    while i <= #comps do
      if comps[i] == curdir then
        table.remove(comps, i)
      elseif comps[i] == pardir then
        if i > 1 and comps[i-1] ~= pardir then
          table.remove(comps, i)
          table.remove(comps, i-1)
          i = i - 1
        elseif i == 1 and prefix:match('\\$') then
          table.remove(comps, i)
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    end

    if prefix == '' and #comps == 0 then
      comps[1] = curdir
    end

    return prefix .. table.concat(comps, sep)
  end

  path_utils.relpath = function(path, start)
    start = start or curdir

    local start_abs = path_utils.abspath(path_utils.normpath(start))
    local path_abs = path_utils.abspath(path_utils.normpath(path))

    local start_drive, start_rest = path_utils.splitdrive(start_abs)
    local path_drive, path_rest = path_utils.splitdrive(path_abs)

    if path_utils.normcase(start_drive) ~= path_utils.normcase(path_drive) then
      -- Different drives
      return nil
    end

    local start_list = path_utils._split_parts(start_rest, sep)
    local path_list = path_utils._split_parts(path_rest, sep)

    local i = 1
    for j = 1, math.min(#start_list, #path_list) do
      if path_utils.normcase(start_list[j]) ~= path_utils.normcase(path_list[j]) then
        break
      end
      i = j + 1
    end

    local rel_list = {}
    for j = 1, (#start_list - i + 1) do rel_list[j] = pardir end
    for j = i, #path_list do table.insert(rel_list, path_list[j]) end

    if #rel_list == 0 then
      return curdir
    end

    return path_utils.join(unpack(rel_list))
  end

else
  -- LINUX
  local sep = '/'
  local curdir = '.'
  local pardir = '..'

  path_utils.isabs = function(path) return path:sub(1,1) == '/' end
  path_utils.normcase = function(path) return path end
  path_utils.splitdrive = function(path) return '', path end

  path_utils.join = function(path, ...)
    local paths = {...}

    for i, p in ipairs(paths) do
      if p:sub(1,1) == sep then
        path = p
      elseif path == '' or path:sub(-1) == sep then
        path = path .. p
      else
        path = path .. sep .. p
      end
    end

    return path
  end

  path_utils.normpath = function(path)
    if path == '' then return curdir end

    local initial_slashes = (path:sub(1,1) == sep) and 1
    if initial_slashes and path:sub(2,2) == sep and path:sub(3,3) ~= sep then
      initial_slashes = 2
    end

    local comps = path_utils._split_parts(path, sep)
    local new_comps = {}

    for i, comp in ipairs(comps) do
      if comp == '' or comp == curdir then
        -- pass
      elseif (comp ~= pardir or (not initial_slashes and #new_comps == 0) or
        (#new_comps > 0 and new_comps[#new_comps] == pardir)) then
        table.insert(new_comps, comp)
      elseif #new_comps > 0 then
        table.remove(new_comps)
      end
    end

    comps = new_comps
    path = table.concat(comps, sep)
    if initial_slashes then
      path = sep:rep(initial_slashes) .. path
    end

    return (path ~= '') and path or curdir
  end

  path_utils.relpath = function(path, start)
    start = start or curdir

    local start_abs = path_utils.abspath(path_utils.normpath(start))
    local path_abs = path_utils.abspath(path_utils.normpath(path))

    local start_list = path_utils._split_parts(start_abs, sep)
    local path_list = path_utils._split_parts(path_abs, sep)

    local i = 1
    for j = 1, math.min(#start_list, #path_list) do
      if start_list[j] ~= path_list[j] then break
      end
      i = j + 1
    end

    local rel_list = {}
    for j = 1, (#start_list - i + 1) do rel_list[j] = pardir end
    for j = i, #path_list do table.insert(rel_list, path_list[j]) end

    if #rel_list == 0 then
      return curdir
    end

    return path_utils.join(unpack(rel_list))
  end

end
-- Path utils end

-- Check if path is local (by looking if it's prefixed by a proto://)
local path_is_local = function(path)
  local proto = path:match('(..-)://')
  return proto == nil
end


function Set(source)
  local set = {}
  for _, l in ipairs(source) do set[l] = true end
  return set
end

---------------------------
-- More helper functions --
---------------------------

function busy_wait(seconds)
  local target = mp.get_time() + seconds
  local cycles = 0
  while target > mp.get_time() do
    cycles = cycles + 1
  end
  return cycles
end

-- Removes all keys from a table, without destroying the reference to it
function clear_table(target)
  for key, value in pairs(target) do
    target[key] = nil
  end
end
function shallow_copy(target)
  if type(target) == "table" then
    local copy = {}
    for k, v in pairs(target) do
      copy[k] = v
    end
    return copy
  else
    return target
  end
end

function deep_copy(target)
  local copy = {}
  for k, v in pairs(target) do
    if type(v) == "table" then
      copy[k] = deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Rounds to given decimals. eg. round_dec(3.145, 0) => 3
function round_dec(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function file_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    local ok, err, code = f:read(1)
    io.close(f)
    return code == nil
  else
    return false
  end
end

function path_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function create_directories(path)
  local cmd
  if ON_WINDOWS then
    cmd = { args = {'cmd', '/c', 'mkdir', path} }
  else
    cmd = { args = {'mkdir', '-p', path} }
  end
  utils.subprocess(cmd)
end

function move_file(source_path, target_path)
  local cmd
  if ON_WINDOWS then
    cmd = { cancellable=false, args = {'cmd', '/c', 'move', '/Y', source_path, target_path } }
    utils.subprocess(cmd)
  else
    -- cmd = { cancellable=false, args = {'mv', source_path, target_path } }
    os.rename(source_path, target_path)
  end
end

function check_pid(pid)
  -- Checks if a PID exists and returns true if so
  local cmd, r
  if ON_WINDOWS then
    cmd = { cancellable=false, args = {
      'tasklist', '/FI', ('PID eq %d'):format(pid)
    }}
    r = utils.subprocess(cmd)
    return r.stdout:sub(1,1) == '\13'
  else
    cmd = { cancellable=false, args = {
      'sh', '-c', ('kill -0 %d 2>/dev/null'):format(pid)
    }}
    r = utils.subprocess(cmd)
    return r.status == 0
  end
end

function kill_pid(pid)
  local cmd, r
  if ON_WINDOWS then
    cmd = { cancellable=false, args = {'taskkill', '/F', '/PID', tostring(pid) } }
  else
    cmd = { cancellable=false, args = {'kill', tostring(pid) } }
  end
  r = utils.subprocess(cmd)
  return r.status == 0, r
end


-- Find an executable in PATH or CWD with the given name
function find_executable(name)
  local delim = ON_WINDOWS and ";" or ":"

  local pwd = os.getenv("PWD") or utils.getcwd()
  local path = os.getenv("PATH")

  local env_path = pwd .. delim .. path -- Check CWD first

  local result, filename
  for path_dir in env_path:gmatch("[^"..delim.."]+") do
    filename = path_utils.join(path_dir, name)
    if file_exists(filename) then
      result = filename
      break
    end
  end

  return result
end

local ExecutableFinder = { path_cache = {} }
-- Searches for an executable and caches the result if any
function ExecutableFinder:get_executable_path( name, raw_name )
  name = ON_WINDOWS and not raw_name and (name .. ".exe") or name

  if self.path_cache[name] == nil then
    self.path_cache[name] = find_executable(name) or false
  end
  return self.path_cache[name]
end

-- Format seconds to HH.MM.SS.sss
function format_time(seconds, sep, decimals)
  decimals = decimals == nil and 3 or decimals
  sep = sep and sep or ":"
  local s = seconds
  local h, s = divmod(s, 60*60)
  local m, s = divmod(s, 60)

  local second_format = string.format("%%0%d.%df", 2+(decimals > 0 and decimals+1 or 0), decimals)

  return string.format("%02d"..sep.."%02d"..sep..second_format, h, m, s)
end

-- Format seconds to 1h 2m 3.4s
function format_time_hms(seconds, sep, decimals, force_full)
  decimals = decimals == nil and 1 or decimals
  sep = sep ~= nil and sep or " "

  local s = seconds
  local h, s = divmod(s, 60*60)
  local m, s = divmod(s, 60)

  if force_full or h > 0 then
    return string.format("%dh"..sep.."%dm"..sep.."%." .. tostring(decimals) .. "fs", h, m, s)
  elseif m > 0 then
    return string.format("%dm"..sep.."%." .. tostring(decimals) .. "fs", m, s)
  else
    return string.format("%." .. tostring(decimals) .. "fs", s)
  end
end

-- Writes text on OSD and console
function log_info(txt, timeout)
  timeout = timeout or 1.5
  msg.info(txt)
  mp.osd_message(txt, timeout)
end

-- Join table items, ala ({"a", "b", "c"}, "=", "-", ", ") => "=a-, =b-, =c-"
function join_table(source, before, after, sep)
  before = before or ""
  after = after or ""
  sep = sep or ", "
  local result = ""
  for i, v in pairs(source) do
    if not isempty(v) then
      local part = before .. v .. after
      if i == 1 then
        result = part
      else
        result = result .. sep .. part
      end
    end
  end
  return result
end

function wrap(s, char)
  char = char or "'"
  return char .. s .. char
end
-- Wraps given string into 'string' and escapes any 's in it
function escape_and_wrap(s, char, replacement)
  char = char or "'"
  replacement = replacement or "\\" .. char
  return wrap(string.gsub(s, char, replacement), char)
end
-- Escapes single quotes in a string and wraps the input in single quotes
function escape_single_bash(s)
  return escape_and_wrap(s, "'", "'\\''")
end

-- Returns (a .. b) if b is not empty or nil
function joined_or_nil(a, b)
  return not isempty(b) and (a .. b) or nil
end

-- Put items from one table into another
function extend_table(target, source)
  for i, v in pairs(source) do
    table.insert(target, v)
  end
end

-- Creates a handle and filename for a temporary random file (in current directory)
function create_temporary_file(base, mode, suffix)
  local handle, filename
  suffix = suffix or ""
  while true do
    filename = base .. tostring(math.random(1, 5000)) .. suffix
    handle = io.open(filename, "r")
    if not handle then
      handle = io.open(filename, mode)
      break
    end
    io.close(handle)
  end
  return handle, filename
end


function get_processor_count()
  local proc_count

  if ON_WINDOWS then
    proc_count = tonumber(os.getenv("NUMBER_OF_PROCESSORS"))
  else
    local cpuinfo_handle = io.open("/proc/cpuinfo")
    if cpuinfo_handle ~= nil then
      local cpuinfo_contents = cpuinfo_handle:read("*a")
      local _, replace_count = cpuinfo_contents:gsub('processor', '')
      proc_count = replace_count
    end
  end

  if proc_count and proc_count > 0 then
      return proc_count
  else
    return nil
  end
end

function substitute_values(string, values)
  local substitutor = function(match)
    if match == "%" then
       return "%"
    else
      -- nil is discarded by gsub
      return values[match]
    end
  end

  local substituted = string:gsub('%%(.)', substitutor)
  return substituted
end

-- ASS HELPERS --
function round_rect_top( ass, x0, y0, x1, y1, r )
  local c = 0.551915024494 * r -- circle approximation
  ass:move_to(x0 + r, y0)
  ass:line_to(x1 - r, y0) -- top line
  if r > 0 then
      ass:bezier_curve(x1 - r + c, y0, x1, y0 + r - c, x1, y0 + r) -- top right corner
  end
  ass:line_to(x1, y1) -- right line
  ass:line_to(x0, y1) -- bottom line
  ass:line_to(x0, y0 + r) -- left line
  if r > 0 then
      ass:bezier_curve(x0, y0 + r - c, x0 + r - c, y0, x0 + r, y0) -- top left corner
  end
end

function round_rect(ass, x0, y0, x1, y1, rtl, rtr, rbr, rbl)
    local c = 0.551915024494
    ass:move_to(x0 + rtl, y0)
    ass:line_to(x1 - rtr, y0) -- top line
    if rtr > 0 then
        ass:bezier_curve(x1 - rtr + rtr*c, y0, x1, y0 + rtr - rtr*c, x1, y0 + rtr) -- top right corner
    end
    ass:line_to(x1, y1 - rbr) -- right line
    if rbr > 0 then
        ass:bezier_curve(x1, y1 - rbr + rbr*c, x1 - rbr + rbr*c, y1, x1 - rbr, y1) -- bottom right corner
    end
    ass:line_to(x0 + rbl, y1) -- bottom line
    if rbl > 0 then
        ass:bezier_curve(x0 + rbl - rbl*c, y1, x0, y1 - rbl + rbl*c, x0, y1 - rbl) -- bottom left corner
    end
    ass:line_to(x0, y0 + rtl) -- left line
    if rtl > 0 then
        ass:bezier_curve(x0, y0 + rtl - rtl*c, x0 + rtl - rtl*c, y0, x0 + rtl, y0) -- top left corner
    end
end
--[ FileConcat-E lib/helpers.lua HASH:66f7cd869de2dda2fcc45a6af21529b84297f9001b7a26c8654ad096298a54a7 ]--
--[ FileConcat-S lib/text_measurer.lua HASH:972853e2bee899f877edb68959d39072af9afad10ebb3c0ff9eaa6b3863dcdba ]--
--[[
	TextMeasurer can calculate character and text width with medium accuracy,
	and wrap/truncate strings by the information.
	It works by creating an ASS subtitle, rendering it with a subprocessed mpv
	and then counting pixels to find the bounding boxes for individual characters.
]]--

local TextMeasurer = {
	FONT_HEIGHT = 16 * 5,
	FONT_MARGIN = 5,
	BASE_X = 10,

	IMAGE_WIDTH = 256,

	FONT_NAME = 'sans-serif',

	CHARACTERS = {
		'', 'M ', -- For measuring, removed later
		'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'!', '"', '#', '$', '%', '&', "'", '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~',
		'\195\161', '\195\129', '\195\160', '\195\128', '\195\162', '\195\130', '\195\164', '\195\132', '\195\163', '\195\131', '\195\165', '\195\133', '\195\166',
		'\195\134', '\195\167', '\195\135', '\195\169', '\195\137', '\195\168', '\195\136', '\195\170', '\195\138', '\195\171', '\195\139', '\195\173', '\195\141',
		'\195\172', '\195\140', '\195\174', '\195\142', '\195\175', '\195\143', '\195\177', '\195\145', '\195\179', '\195\147', '\195\178', '\195\146', '\195\180',
		'\195\148', '\195\182', '\195\150', '\195\181', '\195\149', '\195\184', '\195\152', '\197\147', '\197\146', '\195\159', '\195\186', '\195\154', '\195\185',
		'\195\153', '\195\187', '\195\155', '\195\188', '\195\156'
	},

	WIDTH_MAP = nil,

	ASS_HEADER = [[[Script Info]
Title: Temporary file
ScriptType: v4.00+
PlayResX: %d
PlayResY: %d

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,%s,80,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
]]
}

TextMeasurer.LINE_HEIGHT = (TextMeasurer.FONT_HEIGHT + TextMeasurer.FONT_MARGIN)
TextMeasurer.TOTAL_HEIGHT = TextMeasurer.LINE_HEIGHT * #TextMeasurer.CHARACTERS


function TextMeasurer:create_ass_track()
	local ass_lines = { self.ASS_HEADER:format(self.IMAGE_WIDTH, self.TOTAL_HEIGHT, self.FONT_NAME) }

	for i, character in ipairs(self.CHARACTERS) do
		local ass_line = 'Dialogue: 0,0:00:00.00,0:00:05.00,Default,,0,0,0,,' .. ('{\\pos(%d, %d)}%sM'):format(self.BASE_X, (i-1) * self.LINE_HEIGHT, character)
		table.insert(ass_lines, ass_line)
	end

	return table.concat(ass_lines, '\n')
end


function TextMeasurer:render_ass_track(ass_sub_data)
	-- Round up to divisible by 2
	local target_height = self.TOTAL_HEIGHT + (self.TOTAL_HEIGHT + 2) % 2

	local mpv_args = {
		'mpv',
		'--msg-level=all=no',

		'--sub-file=memory://' .. ass_sub_data,
		('av://lavfi:color=color=black:size=%dx%d:duration=1'):format(self.IMAGE_WIDTH, target_height),
		'--frames=1',

		-- Byte for each pixel
		'--vf-add=format=gray',
		'--of=rawvideo',
		'--ovc=rawvideo',

		-- Write to stdout
		'-o=-'
	}

	local ret = utils.subprocess({args=mpv_args, cancellable=false})
	return ret.stdout
end


function TextMeasurer:get_bounds(image_data, offset)
	local w = self.IMAGE_WIDTH
	local h = self.LINE_HEIGHT

	local left_edge = nil
	local right_edge = nil

	-- Approach from left
	for x = 0, w-1 do
		for y = 0, h-1 do
			local p = image_data:byte(x + y*w + 1 + offset)
			if p > 0 then
				left_edge = x
				break
			end
		end
		if left_edge then break end
	end

	-- Approach from right
	for x = w-1, 0, -1 do
		for y = 0, h-1 do
			local p = image_data:byte(x + y*w + 1 + offset)
			if p > 0 then
				right_edge = x
				break
			end
		end
		if right_edge then break end
	end

	if left_edge and right_edge then
		return left_edge, right_edge
	end
end


function TextMeasurer:parse_characters(image_data)
	local sub_image_size = self.IMAGE_WIDTH * self.LINE_HEIGHT

	if #image_data < self.IMAGE_WIDTH * self.TOTAL_HEIGHT then
		-- Not enough bytes for all rows
		return nil
	end

	local edge_map = {}

	for i, character in ipairs(self.CHARACTERS) do
		local left, right = self:get_bounds(image_data, (i-1) * sub_image_size)
		edge_map[character] = {left, right}
	end

	local em_bound = edge_map['']
	local em_space_em_bound = edge_map['M ']

	local em_w = (em_bound[2] - em_bound[1]) + (em_bound[1] - self.BASE_X)

	-- Remove measurement characters from map
	edge_map[''] = nil
	edge_map['M '] = nil

	for character, edges in pairs(edge_map) do
		edge_map[character] = (edges[2] - self.BASE_X - em_w)
	end

	-- Space
	edge_map[' '] = (em_space_em_bound[2] - em_space_em_bound[1]) - (em_w * 2)

	return edge_map
end


function TextMeasurer:create_character_map()
	if not self.WIDTH_MAP then
		local ass_sub_data = TextMeasurer:create_ass_track()
		local image_data = TextMeasurer:render_ass_track(ass_sub_data)
		self.WIDTH_MAP = TextMeasurer:parse_characters(image_data)
		if not self.WIDTH_MAP then
			msg.error("Failed to parse character widths!")
		end
	end
	return self.WIDTH_MAP
end

-- String functions

function TextMeasurer:_utf8_iter(text)
	iter = text:gmatch('([%z\1-\127\194-\244][\128-\191]*)')
	return function() return iter() end
end

function TextMeasurer:calculate_width(text, font_size)
	local total_width = 0
	local width_map = self:create_character_map()
	local default_width = width_map['M']

	for char in self:_utf8_iter(text) do
		local char_width = width_map[char] or default_width
		total_width = total_width + char_width
	end

	return total_width * (font_size / self.FONT_HEIGHT)
end

function TextMeasurer:trim_to_width(text, font_size, max_width, suffix)
	suffix = suffix or "..."
	max_width = max_width * (self.FONT_HEIGHT / font_size) - self:calculate_width(suffix, font_size)

	local width_map = self:create_character_map()
	local default_width = width_map['M']

	local total_width = 0
	local characters = {}
	for char in self:_utf8_iter(text) do
		local char_width = width_map[char] or default_width
		total_width = total_width + char_width

		if total_width > max_width then break end
		table.insert(characters, char)
	end

	if total_width > max_width then
		return table.concat(characters, '') .. suffix
	else
		return text
	end
end

function TextMeasurer:wrap_to_width(text, font_size, max_width)
	local lines = {}
	local line_widths = {}

	local current_line = ''
	local current_width = 0

	for word in text:gmatch("( *[%S]*\n?)") do
		if word ~= '' then
			local is_newline = word:sub(-1) == '\n'
			word = word:gsub('%s*$', '')

			if word ~= '' then
				local part_width = TextMeasurer:calculate_width(word, font_size)

				if (current_width + part_width) > max_width then
					table.insert(lines, current_line)
					table.insert(line_widths, current_width)
					current_line = word:gsub('^%s*', '')
					current_width = part_width
				else
					current_line = current_line .. word
					current_width = current_width + part_width
				end
			end

			if is_newline then
				table.insert(lines, current_line)
				table.insert(line_widths, current_width)
				current_line = ''
				current_width = 0
			end
		end
	end
	table.insert(lines, current_line)
	table.insert(line_widths, current_width)

	return lines, line_widths
end


function TextMeasurer:load_or_create(file_path)
	local cache_file = io.open(file_path, 'r')
	if cache_file then
		local map_json = cache_file:read('*a')
		local width_map = utils.parse_json(map_json)
		self.WIDTH_MAP = width_map
		cache_file:close()
	else
		cache_file = io.open(file_path, 'w')
		msg.warn("Generating OSD font character measurements, this may take a second...")
		local width_map = self:create_character_map()
		local map_json = utils.format_json(width_map)
		cache_file:write(map_json)
		cache_file:close()
		msg.info("Text measurements created and saved to", file_path)
	end
end
--[ FileConcat-E lib/text_measurer.lua HASH:972853e2bee899f877edb68959d39072af9afad10ebb3c0ff9eaa6b3863dcdba ]--
--[ FileConcat-S lib/input_tools.lua HASH:7c5b9b73f8d67119a3db9898eea7c260857f4af803a52e8dcc0f0df575683b3b ]--
--[[
  Collection of tools to gather user input.
  NumberInputter can do more than the name says.
  It's a dialog for integer, float, text and even timestamp input.

  ChoicePicker allows one to choose an item from a list.

  Depends on TextMeasurer and helpers.lua (round_rect)
]]--

local NumberInputter = {}
NumberInputter.__index = NumberInputter

setmetatable(NumberInputter, {
  __call = function (cls, ...) return cls.new(...) end
})

NumberInputter.validators = {
  integer = {
    live = function(new_value, old_value)
      if new_value:match("^%d*$") then return new_value
      else return old_value end
    end,
    submit = function(value)
      if value:match("^%d+$") then return tonumber(value)
      elseif value ~= "" then return nil, value end
    end
  },

  signed_integer = {
    live = function(new_value, old_value)
      if new_value:match("^[-]?%d*$") then return new_value
      else return old_value end
    end,
    submit = function(value)
      if value:match("^[-]?%d+$") then return tonumber(value)
      elseif value ~= "" then return nil, value end
    end
  },

  float = {
    live = function(new_value, old_value)
      if new_value:match("^%d*$") or new_value:match("^%d+%.%d*$") then return new_value
      else return old_value end
    end,
    submit = function(value)
      if value:match("^%d+$") or value:match("^%d+%.%d+$") then
        return tonumber(value)
      elseif value:match("^%d%.$") then
        return nil, value:sub(1, -2)
      elseif value ~= "" then
        return nil, value
      end
    end
  },

  signed_float = {
    live = function(new_value, old_value)
      if new_value:match("^[-]?%d*$") or new_value:match("^[-]?%d+%.%d*$") then return new_value
      else return old_value end
    end,
    submit = function(value)
      if value:match("^[-]?%d+$") or value:match("^[-]?%d+%.%d+$") then
        return tonumber(value)
      elseif value:match("^[-]?%d%.$") then
        return nil, value:sub(1, -2)
      elseif value ~= "" then
        return nil, value
      end
    end
  },

  text = {
    live = function(new_value, old_value)
      return new_value:match("^%s*(.*)")
    end,
    submit = function(value)
      if value:match("%s+$") then
        return nil, value:match("^(.-)%s+$")
      elseif value ~= "" then
        return value
      end
    end
  },

  filename = {
    live = function(new_value, old_value)
      return new_value:match("^%s*(.*)"):gsub('[^a-zA-Z0-9 !#$%&\'()+%-,.;=@[%]_ {}]', '')
    end,
    submit = function(value)
      if value:match("%s+$") then
        return nil, value:match("^(.-)%s+$")
      elseif value ~= "" then
        return value
      end
    end
  },

  timestamp = {
    initial_parser = function(v)
      v = math.min(99*3600 + 59*60 + 59.999, math.max(0, v))

      local ms = round_dec((v - math.floor(v)) * 1000)
      if (ms >= 1000) then
        v = v + 1
        ms = ms - 1000
      end

      return ("%02d%02d%02d%03d"):format(
        math.floor(v / 3600),
        math.floor((v % 3600) / 60),
        math.floor(v % 60),
        ms
      )
    end,
    live = function(new_value, old_value)
      if new_value:match("^%d*$") then return new_value, true
      else return old_value, false end
    end,
    submit = function(value)
      local v = tonumber(value:sub(1,2)) * 3600 + tonumber(value:sub(3,4)) * 60 + tonumber(value:sub(5,9)) / 1000
      v = math.min(99*3600 + 59*60 + 59.999, math.max(0, v))

      local ms = round_dec((v - math.floor(v)) * 1000)
      if (ms >= 1000) then
        v = v + 1
        ms = ms - 1000
      end

      local fv = ("%02d%02d%02d%03d"):format(
        math.floor(v / 3600),
        math.floor((v % 3600) / 60),
        math.floor(v % 60),
        ms
      )

      -- Check if formatting matches, if not, return fixed value for resubmit
      if fv == value then return v
      else return nil, fv end
    end
  }
}

function NumberInputter.new()
  local self = setmetatable({}, NumberInputter)

  self.active = false

  self.option_index = 1
  self.options = {} -- {name, hint, value, type_string}

  self.scale = 1

  self.cursor = 1
  self.last_move = 0
  self.replace_mode = false

  self._input_characters = {}

  local input_char_string = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" ..
                            "!\"#$%&'()*+,-./:;<=>?@[\\]^_{|}~#"
  local keys = {
    "ENTER", "ESC", "TAB",
    "BS", "DEL",
    "LEFT", "RIGHT", "HOME", "END",

    -- Extra input characters
    "SPACE", "SHARP",
  }
  local repeatable_keys = Set{"BS", "DEL", "LEFT", "RIGHT"}

  for c in input_char_string:gmatch('.') do
    self._input_characters[c] = c
    table.insert(keys, c)
  end
  self._input_characters["SPACE"] = " "
  self._input_characters["SHARP"] = "#"

  self._keys_bound = false
  self._key_binds = {}

  for i,k in pairs(keys) do
    local listener = function() self:_on_key(k) end
    local do_repeat = (repeatable_keys[k] or self._input_characters[k])
    local flags = do_repeat and {repeatable=true} or nil

    table.insert(self._key_binds, {k, "_input_" .. i, listener, flags})
  end

  return self
end

function NumberInputter:escape_ass(text)
  return text:gsub('\\', '\\\226\129\160'):gsub('{', '\\{')
end

function NumberInputter:cycle_options()
  self.option_index = (self.option_index) % #self.options + 1

  local initial_value = self.options[self.option_index][3]
  local parser = self.validators[self.options[self.option_index][4]].initial_parser or tostring

  if type(initial_value) == "function" then initial_value = initial_value() end
  self.current_value = initial_value and parser(initial_value) or ""
  self.cursor = 1

  self.replace_mode = (self.options[self.option_index][4] == "timestamp")
end

function NumberInputter:enable_key_bindings()
  if not self._keys_bound then
    for k, v in pairs(self._key_binds)  do
      mp.add_forced_key_binding(unpack(v))
    end
    self._keys_bound = true
  end
end

function NumberInputter:disable_key_bindings()
  for k, v in pairs(self._key_binds)  do
    mp.remove_key_binding(v[2]) -- remove by name
  end
  self._keys_bound = false
end

function NumberInputter:start(options, on_enter, on_cancel)
  self.active = true
  self.was_paused = mp.get_property_native('pause')
  if not self.was_paused then
    mp.set_property_native('pause', true)
    mp.osd_message("Paused playback for input")
  end

  self.options = options

  self.option_index = 0
  self:cycle_options() -- Will move index to 1

  self.enter_callback = on_enter
  self.cancel_callback = on_cancel

  self:enable_key_bindings()
end
function NumberInputter:stop()
  self.active = false
  self.current_value = ""
  if not self.was_paused then
    mp.set_property_native('pause', false)
    mp.osd_message("Resumed playback")
  end

  self:disable_key_bindings()
end

function NumberInputter:_append( part )
  local l = self.current_value:len()
  local validator_data = self.validators[self.options[self.option_index][4]]

  if self.replace_mode then
    if self.cursor > 1 then

      local new_value = self.current_value:sub(1, l - self.cursor + 1) .. part .. self.current_value:sub(l - self.cursor + 3)
      self.current_value, changed = validator_data.live(new_value, self.current_value, self)
      if changed then
        self.cursor = math.max(1, self.cursor - 1)
      end
    end

  else
    local new_value = self.current_value:sub(1, l - self.cursor + 1) .. part .. self.current_value:sub(l - self.cursor + 2)

    self.current_value = validator_data.live(new_value, self.current_value, self)
  end
end

function NumberInputter:_on_key( key )

  if key == "ESC" then
    self:stop()
    if self.cancel_callback then
      self.cancel_callback()
    end

  elseif key == "ENTER" then
    local opt = self.options[self.option_index]
    local extra_validation = opt[5]

    local value, repl = self.validators[opt[4]].submit(self.current_value)
    if value and extra_validation then
      local number_formats = Set{"integer", "float", "signed_float", "signed_integer", "timestamp"}
      if number_formats[opt[4]] then
        if extra_validation.min and value < extra_validation.min then repl = tostring(extra_validation.min) end
        if extra_validation.max and value > extra_validation.max then repl = tostring(extra_validation.max) end
      end
    end

    if repl then
      self.current_value = repl
    else

      self:stop()
      if self.enter_callback then
        self.enter_callback(opt[1], value)
      end
    end

  elseif key == "TAB" then
    self:cycle_options()

  elseif key == "BS" then
    -- Remove character to the left
    local l = self.current_value:len()
    local c = self.cursor

    if not self.replace_mode and c <= l then
      self.current_value = self.current_value:sub(1, l - c) .. self.current_value:sub(l - c + 2)
      self.cursor = math.min(c, self.current_value:len() + 1)

    elseif self.replace_mode then
      if c <= l then
        self.current_value = self.current_value:sub(1, l - c) .. '0' .. self.current_value:sub(l - c + 2)
        self.cursor = math.min(l + 1, c + 1)
      end
    end

  elseif key == "DEL" then
    -- Remove character to the right
    local l = self.current_value:len()
    local c = self.cursor

    if not self.replace_mode and c > 1 then
      self.current_value = self.current_value:sub(1, l - c + 1) .. self.current_value:sub(l - c + 3)
      self.cursor = math.min(math.max(1, c - 1), self.current_value:len() + 1)

    elseif self.replace_mode then
      if c > 1 then
        self.current_value = self.current_value:sub(1, l - c + 1) .. '0' .. self.current_value:sub(l - c + 3)
        self.cursor = math.max(1, c - 1)
      end
    end

  elseif key == "LEFT" then
    self.cursor = math.min(self.cursor + 1, self.current_value:len() + 1)
  elseif key == "RIGHT" then
    self.cursor = math.max(self.cursor - 1, 1)
  elseif key == "HOME" then
    self.cursor = self.current_value:len() + 1
  elseif key == "END" then
    self.cursor = 1

  elseif self._input_characters[key] then
    self:_append(self._input_characters[key])

  end

  self.last_move = mp.get_time()
end

function NumberInputter:get_ass( w, h )
  local ass = assdraw.ass_new()

  -- Center
  local cx = w / 2
  local cy = h / 2
  local multiple_options = #self.options > 1

  local scaled = function(v) return v * self.scale end


  -- Dialog size
  local b_w = scaled(190)
  local b_h = scaled(multiple_options and 80 or 64)
  local m = scaled(4) -- Margin

  local txt_fmt = "{\\fs%d\\an%d\\bord2}"
  local bgc = 16
  local background_style = string.format("{\\bord0\\1a&H%02X&\\1c&H%02X%02X%02X&}", 96, bgc, bgc, bgc)

  local small_font_size = scaled(14)
  local main_font_size = scaled(18)

  local value_width = TextMeasurer:calculate_width(self.current_value, main_font_size)
  local cursor_width = TextMeasurer:calculate_width("|", main_font_size)

  b_w = math.max(b_w, value_width + scaled(20))

  ass:new_event()
  ass:pos(0,0)
  ass:draw_start()
  ass:append(background_style)
  ass:round_rect_cw(cx-b_w/2, cy-b_h/2, cx+b_w/2, cy+b_h/2, scaled(7))
  ass:draw_stop()

  ass:new_event()
  ass:pos(cx-b_w/2 + m, cy+b_h/2 - m)
  ass:append( string.format(txt_fmt, small_font_size, 1) )
  ass:append("[ESC] Cancel")

  ass:new_event()
  ass:pos(cx+b_w/2 - m, cy+b_h/2 - m)
  ass:append( string.format(txt_fmt, small_font_size, 3) )
  ass:append("Accept [ENTER]")

  if multiple_options then
    ass:new_event()
    ass:pos(cx-b_w/2 + m, cy-b_h/2 + m)
    ass:append( string.format(txt_fmt, small_font_size, 7) )
    ass:append("[TAB] Cycle")
  end

  ass:new_event()
  ass:pos(cx, cy-b_h/2 + m + scaled(multiple_options and 15 or 0))
  ass:append( string.format(txt_fmt, main_font_size, 8) )
  ass:append(self.options[self.option_index][2])

  local value = self.current_value
  local cursor = self.cursor
  if self.options[self.option_index][4] == "timestamp" then
    value = value:sub(1, 2) .. ":" .. value:sub(3, 4) .. ":" .. value:sub(5, 6) .. "." .. value:sub(7, 9)
    cursor = cursor + (cursor > 4 and 1 or 0) + (cursor > 6 and 1 or 0) + (cursor > 8 and 1 or 0)
  end

  local safe_text = self:escape_ass(value)

  local text_x, text_y = (cx - value_width/2), (cy + scaled(multiple_options and 7 or 0))
  ass:new_event()
  ass:pos(text_x, text_y)
  ass:append( string.format(txt_fmt, main_font_size, 4) )
  ass:append(safe_text)

  -- Blink the cursor
  local cur_style = (math.floor( (mp.get_time() - self.last_move) * 1.5 ) % 2 == 0) and "{\\alpha&H00&}" or "{\\alpha&HFF&}"

  ass:new_event()
  ass:pos(text_x - (cursor > 1 and cursor_width or 0)/2, text_y)
  ass:append( string.format(txt_fmt, main_font_size, 4) )
  ass:append("{\\alpha&HFF&}" .. self:escape_ass(value:sub(1, value:len() - cursor + 1)) .. cur_style .. "{\\bord1}|" )

  return ass
end

-- -- -- --

local ChoicePicker = {}
ChoicePicker.__index = ChoicePicker

setmetatable(ChoicePicker, {
  __call = function (cls, ...) return cls.new(...) end
})

function ChoicePicker.new()
  local self = setmetatable({}, ChoicePicker)

  self.active = false

  self.choice_index = 1
  self.choices = {} -- { { name = "Visible name", value = "some_value" }, ... }

  self.scale = 1

  local keys = {
    "UP", "DOWN", "PGUP", "PGDWN",
    "ENTER", "ESC"
  }
  local repeatable_keys = Set{"UP", "DOWN"}

  self._keys_bound = false
  self._key_binds = {}

  for i,k in pairs(keys) do
    local listener = function() self:_on_key(k) end
    local do_repeat = repeatable_keys[k]
    local flags = do_repeat and {repeatable=true} or nil

    table.insert(self._key_binds, {k, "_picker_key_" .. k, listener, flags})
  end

  return self
end

function ChoicePicker:shift_selection(offset, no_wrap)
  local n = #self.choices

  if n == 0 then
    return 0
  end

  local target_index = self.choice_index - 1 + offset
  if no_wrap then
    target_index = math.max(0, math.min(n - 1, target_index))
  end

  self.choice_index = (target_index % n) + 1
end


function ChoicePicker:enable_key_bindings()
  if not self._keys_bound then
    for k, v in pairs(self._key_binds)  do
      mp.add_forced_key_binding(unpack(v))
    end
    self._keys_bound = true
  end
end

function ChoicePicker:disable_key_bindings()
  for k, v in pairs(self._key_binds)  do
    mp.remove_key_binding(v[2]) -- remove by name
  end
  self._keys_bound = false
end

function ChoicePicker:start(choices, on_enter, on_cancel)
  self.active = true

  self.choices = choices

  self.choice_index = 1
  -- self:cycle_options() -- Will move index to 1

  self.enter_callback = on_enter
  self.cancel_callback = on_cancel

  self:enable_key_bindings()
end
function ChoicePicker:stop()
  self.active = false

  self:disable_key_bindings()
end

function ChoicePicker:_on_key( key )

  if key == "UP" then
    self:shift_selection(-1)

  elseif key == "DOWN" then
    self:shift_selection(1)

  elseif key == "PGUP" then
    self.choice_index = 1

  elseif key == "PGDWN" then
    self.choice_index = #self.choices

  elseif key == "ESC" then
    self:stop()
    if self.cancel_callback then
      self.cancel_callback()
    end

  elseif key == "ENTER" then
    self:stop()
    if self.enter_callback then
      self.enter_callback(self.choices[self.choice_index].value)
    end

  end
end

function ChoicePicker:get_ass( w, h )
  local ass = assdraw.ass_new()

  -- Center
  local cx = w / 2
  local cy = h / 2
  local choice_count = #self.choices

  local s = function(v) return v * self.scale end

  -- Dialog size
  local b_w = s(220)
  local b_h = s(20 + 20 + (choice_count * 20) + 10)
  local m = s(5) -- Margin

  local small_font_size = s(14)
  local main_font_size = s(18)

  for j, choice in pairs(self.choices) do
    local name_width = TextMeasurer:calculate_width(choice.name, main_font_size)
    b_w = math.max(b_w, name_width + s(20))
  end

  local e_l = cx - b_w/2
  local e_r = cx + b_w/2
  local e_t = cy - b_h/2
  local e_b = cy + b_h/2

  local txt_fmt = "{\\fs%d\\an%d\\bord2}"
  local bgc = 16
  local background_style = string.format("{\\bord0\\1a&H%02X&\\1c&H%02X%02X%02X&}", 96, bgc, bgc, bgc)

  local line_h = s(20)
  local line_h2 = s(22)
  local corner_radius = s(7)

  ass:new_event()
  ass:pos(0,0)
  ass:draw_start()
  ass:append(background_style)
  -- Main BG
  ass:round_rect_cw(e_l, e_t, e_r, e_b, corner_radius)
  -- Options title
  round_rect(ass, e_l + line_h*2, e_t-line_h2, e_r - line_h*2, e_t,  corner_radius, corner_radius, 0, 0)
  ass:draw_stop()

  ass:new_event()
  ass:pos(cx, e_t - line_h2/2)
  ass:append( string.format(txt_fmt, main_font_size, 5) )
  ass:append("Choose")

  ass:new_event()
  ass:pos(e_r - m, e_b - m)
  ass:append( string.format(txt_fmt, small_font_size, 3) )
  ass:append("Choose [ENTER]")

  ass:new_event()
  ass:pos(e_l + m, e_b - m)
  ass:append( string.format(txt_fmt, small_font_size, 1) )
  ass:append("[ESC] Cancel")

  ass:new_event()
  ass:pos(e_l + m, e_t + m)
  ass:append( string.format(txt_fmt, small_font_size, 7) )
  ass:append("[UP]/[DOWN] Select")

  local color_text = function( text, r, g, b )
    return string.format("{\\c&H%02X%02X%02X&}%s{\\c}", b, g, r, text)
  end

  local color_gray = {190, 190, 190}

  local item_height = line_h;
  local text_height = main_font_size;
  local item_margin = (item_height - text_height) / 2;

  local base_y = e_t + m + item_height

  local choice_index = 0

  for j, choice in pairs(self.choices) do
    choice_index = choice_index + 1

    if choice_index == self.choice_index then
      ass:new_event()
      ass:pos(0,0)
      ass:append( string.format("{\\bord0\\1a&H%02X&\\1c&H%02X%02X%02X&}", 128, 250, 250, 250) )
      ass:draw_start()
      ass:rect_cw(e_l, base_y - item_margin, e_r, base_y + item_height + item_margin)
      ass:draw_stop()
    end

    ass:new_event()
    ass:pos(cx, base_y)
    ass:append(string.format(txt_fmt, text_height, 8))
    ass:append(choice.name)

    base_y = base_y + line_h
  end

  return ass
end
--[ FileConcat-E lib/input_tools.lua HASH:7c5b9b73f8d67119a3db9898eea7c260857f4af803a52e8dcc0f0df575683b3b ]--
--[ FileConcat-S src/main.lua HASH:8779eedc9c165c33e43fbf0a05a4e882aaa896bd55cdfc66ffe7f7eb015843f3 ]--
local mp = require 'mp'
local msg = require 'mp.msg'


local function search()
    local search_dialog = NumberInputter()
    local screen_w,screen_h,_ = mp.get_osd_size()

    local function tick_callback()
        local ass=assdraw.ass_new()
        ass:append(search_dialog:get_ass(screen_w,screen_h).text)
        mp.set_osd_ass(screen_w,screen_h,ass.text)
    end
    mp.register_event("tick", tick_callback)

    local function cancel_callback()
        search_dialog:stop()
        mp.set_osd_ass(screen_w,screen_h,"")
        mp.unregister_event(tick_callback)
    end
    local function callback(e,v)
        cancel_callback()
        msg.verbose("searching for: "..v)
        mp.commandv("loadfile", "ytdl://ytsearch50:"..v)

        local function trigger_gallery(prop,count)
            if count > 1 then
                msg.verbose("triggering gallery-view")
                mp.unobserve_property(trigger_gallery)
                mp.commandv("script-message", "gallery-view", "true")
            end
        end
        mp.observe_property("playlist-count", "number", trigger_gallery)
    end

    search_dialog:start({{"search","Search Youtube:",nil,"text"}}, callback, cancel_callback)
end

mp.add_forced_key_binding("/", "youtube-search", search)
--[ FileConcat-E src/main.lua HASH:8779eedc9c165c33e43fbf0a05a4e882aaa896bd55cdfc66ffe7f7eb015843f3 ]--
