local lspconfig = require('lspconfig')
local servers = require('lazy-lsp.servers')

local function escape_shell_arg(arg)
  return "'" .. string.gsub(arg, "'", "'\"'\"'") .. "'"
end

local function escape_shell_args(args)
  local escaped = {}
  for _, arg in ipairs(args) do
    table.insert(escaped, escape_shell_arg(arg))
  end
  return table.concat(escaped, " ")
end

local function build_command(nix_pkgs, cmd, opts)
  if opts.flake_inputs_from then
    local nix_cmd = {"nix", "--extra-experimental-features", "nix-command flakes", "shell", "--inputs-from", opts.flake_inputs_from}
    -- Assuming that the input is called nixpkgs; possibly should be configurable?
    for _, pkg in ipairs(nix_pkgs) do
      table.insert(nix_cmd, "nixpkgs#" .. pkg)
    end
    table.insert(nix_cmd, "--command")
    vim.list_extend(nix_cmd, cmd)
    return nix_cmd
  else
    local nix_cmd = { "nix-shell", "-p" }
    vim.list_extend(nix_cmd, nix_pkgs)
    table.insert(nix_cmd, "--run")
    table.insert(nix_cmd, escape_shell_args(cmd))
  end
end

local function setup(opts)
  opts = opts or {}
  local excluded_servers = opts.excluded_servers or {}
  local default_config = opts.default_config or {}
  local configs = opts.configs or {}

  for lsp, nix_pkg in pairs(servers) do
    if lspconfig[lsp] and not vim.tbl_contains(excluded_servers, lsp) then
      local cmd = (configs[lsp] and configs[lsp].cmd) or
          (type(nix_pkg) == "table" and nix_pkg.cmd) or
          lspconfig[lsp].document_config.default_config.cmd
      if nix_pkg ~= "" and cmd then
        local config = configs[lsp] or default_config
        local nix_pkgs = type(nix_pkg) == "string" and { nix_pkg } or nix_pkg.pkgs
        local nix_cmd = build_command(nix_pkgs, cmd, opts)
        config = vim.tbl_extend("keep", { cmd = nix_cmd }, config)
        lspconfig[lsp].setup(config)
      elseif configs[lsp] then
        lspconfig[lsp].setup(configs[lsp])
      end
    end
  end
end

return {
  setup = setup
}
