--[[
  Installer script for CC: Tweaked (and maybe CC?)
  Paste: pastebin run Mt7h3gfz install/uninstall [source] [package]
  Local: lunar install/uninstall [source] [package]
]]

-- The installation location
local apps_dir = '/apps'

-- The location where we'll drop the bin shortcuts
local bin_dir = '/'

----------------------------------------------
-- Helpers
----------------------------------------------

-- Printing and error with formatting
function printf (format, ...) return print(string.format(format, ...)) end
function errorf (format, ...) return error(string.format(format, ...)) end

-- Simple file reader
function file_read (file)
  local handle = fs.open(file, 'r')
  local data = handle.readAll()
  handle.close()
  return data
end

-- Simple file writer
function file_write (file, data)
  local handle = fs.open(file, 'wb')
  if 'table' == type(data) then
    for _, byte in ipairs(data) do
      handle.write(byte)
    end
  else
    handle.write(data)
  end
  handle.close()
end

-- Path handling
function joinpath (p1, p2)
  local result = (p1 .. '/' .. p2):gsub('//+', '/')
  return result -- This is necessary otherwise we'll get extra stuff from the above regex
end

-- Extracts directory path from file path
function dirname (path)
  local pieces = {}
  for piece in path:gmatch('([^/]+)') do
    table.insert(pieces, piece)
  end

  -- Removes last element
  table.remove(pieces, #pieces)

  -- Checks if we need a prefix
  local prefix = ''
  if '/' == path:sub(1, 1) then
    prefix = '/'
  end

  -- Returns final path
  return prefix .. table.concat(pieces, '/')
end

-- Returns data on a shortcut
function shortcut (bin, obj, install_dir)
  local info = {
    name = bin,
    path = obj,
  }
  
  -- Gets path, description, etc
  if 'table' == type(obj) then
    info.path = obj.path
    info.text = obj.text
  end

  -- Gets the shortcut file
  info.bin = joinpath(bin_dir, bin .. '.lua')
  
  -- Gets the destination path
  info.target = joinpath(install_dir, info.path)
  info.target_dir = dirname(info.target)

  -- Done
  return info
end

----------------------------------------------
-- This is our data source setup
----------------------------------------------

-- List of valid sources for package metadata
local pkg_sources = {
  -- Read package from GitHub repo
  github = function (pkg)
    local req, err = http.get(string.format('https://raw.githubusercontent.com/%s/main/ccpkg.json', pkg))

    -- Handles not found
    if not req then
      errorf('Error fetching package "%s" from GitHub: %s', pkg, err)
    end

    -- Parses file
    local data, err = textutils.unserializeJSON(req.readAll())

    -- Handles invalid file
    if not data then
      errorf('Error reading package file: %s', err)
    end

    -- Valid file, returns metadata
    return data
  end,
}

local pkg_installers = {
  github = function (package, destination)
    -- Helper to call GitHub
    local function gh (path, ...)
      return http.get(string.format('https://api.github.com/' .. path, ...), {
        Accept = 'application/vnd.github+json',
      })
    end

    -- Our repo and branch
    local repo = package.source.repo
    local branch = package.source.branch or 'main'

    -- Sanity check
    if not repo then error('Package has no repo set!') end

    -- Gets initial GitHub content
    print('Reading GitHub repository...')
    local req, err = gh('repos/%s/branches/%s', repo, branch)
    if not req then errorf('Failed to fetch GitHub repo: %s', err) end

    -- Reads repo data
    local repo_data = textutils.unserializeJSON(req.readAll())

    -- Loads GitHub file tree
    print('Reading file tree...')
    local req, err = gh('repos/%s/git/trees/%s?recursive=true', repo, repo_data.commit.commit.tree.sha)
    if not req then errorf('Failed to fetch GitHub files: %s', err) end

    -- Reads file data
    local files = textutils.unserializeJSON(req.readAll())

    -- Downloads each of the files
    for _, file in pairs(files.tree) do
      local path = joinpath(destination, file.path)
      if 'tree' == file.type then
        fs.makeDir(path)
      elseif 'blob' == file.type then
        printf('Copy: %s', file.path)
        local req, err = http.get(string.format('https://raw.githubusercontent.com/%s/%s/%s', repo, branch, file.path))
        if not req then errorf('Failed to fetch file: %s', err) end
        file_write(path, req.readAll())
      end
    end
  end,
}

----------------------------------------------
-- This is what actually (un)installs things
----------------------------------------------

function uninstall_package (install_dir)
  -- Reads package
  local install_pkg = install_dir .. '.json'
  local package = textutils.unserializeJSON(file_read(install_pkg))

  -- Removes old binaries
  for bin, bin_data in pairs(package.bin or {}) do
    bin = shortcut(bin, bin_data, install_dir)
    if fs.exists(bin.bin) then
      printf('Unlinking "%s" -> %s', bin.name, bin.target)
      fs.delete(bin.bin)
    end
  end

  -- Removes old directory
  print('Removing files...')
  if fs.exists(install_dir) then
    fs.delete(install_dir)
  end

  -- Removes old metadata
  print('Removing package metadata...')
  fs.delete(install_pkg)

  -- Done
  print('Uninstall successful!')
end

function install_package (package)
  -- Some validation rules
  if not package.id then error('Package ID missing!') end
  if (not package.source) or (not package.source.type) then error('Package source missing!') end

  -- Makes app dir if needed
  if not fs.exists(apps_dir) then
    fs.makeDir(apps_dir)
  elseif not fs.isDir(apps_dir) then
    errorf('Location "%s" already exists, should be a directory.', apps_dir)
  end

  -- Gets our installer ready
  local installer = pkg_installers[package.source.type]
  if not installer then
    errorf('Invalid installer: %s', package.source.type)
  end

  -- Setup our install locations
  local install_dir = joinpath(apps_dir, package.id)
  local install_pkg = install_dir .. '.json'

  -- Checks if there's a version of the package installed
  if fs.exists(install_pkg) then
    print('Found previous version of package installed, performing uninstall...')
    uninstall_package(install_dir)
  end

  -- Puts down new metadata file
  print('Installing package metadata...')
  file_write(install_pkg, textutils.serializeJSON(package))

  -- Installs
  print('Installing new files...')
  fs.makeDir(install_dir)
  installer(package, install_dir)

  -- Creates binary shortcuts
  for bin, bin_data in pairs(package.bin or {}) do
    -- Parses binary
    bin = shortcut(bin, bin_data, install_dir)

    -- Writes the shortcut file
    printf('Linking "%s" -> %s', bin.name, bin.target)
    file_write(bin.bin, string.format('_=shell.dir();shell.setDir("%s");shell.run("%s",...);shell.setDir(_)', bin.target_dir, bin.target))
  end

  -- Shows installed files
  print('Install complete! New commands:')
  for bin, bin_data in pairs(package.bin or {}) do
    bin = shortcut(bin, bin_data, install_dir)
    if (bin.text) then
      printf('- %s : %s', bin.name, bin.text)
    else
      printf('- %s', bin.name)
    end
  end
end

----------------------------------------------
-- Main part of the installer
----------------------------------------------

-- Makes sure HTTP is enabled
if not http then
  error('You must have http enabled in your game/server to use this script.')
end

-- Parses args
local args = {...}
local command = args[1]
local source = args[2]
local source_pkg = args[3]

-- Sanity check
if (not command) or (not source) or (not source_pkg) then
  print('Usage: lunar install/uninstall [source] [package]')
  return 1
end

-- Gets our source loader
local get_package = pkg_sources[source]

-- Checks if source loader is valid
if not get_package then
  printf('Invalid package source: %s', source)
  printf('Valid options:')
  for source, fn in pairs(pkg_sources) do
    printf('- %s', source)
  end
  return 1
end

-- Loads package
local package = get_package(source_pkg)

-- installs package
if 'install' == command then
  install_package(package)
elseif 'uninstall' == command then
  uninstall_package(package)
end