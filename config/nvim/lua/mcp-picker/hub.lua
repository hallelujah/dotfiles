local M = {}

local function fetch_json(url, method, body)
  local cmd = { "curl", "-fsS" }
  if method == "POST" then
    vim.list_extend(cmd, { "-X", "POST", "-H", "content-type: application/json", "-d", body })
  end
  vim.list_extend(cmd, { url })
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    return nil, result.stderr ~= "" and result.stderr or "curl failed (code " .. result.code .. ")"
  end
  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok then
    return nil, "JSON parse error"
  end
  return data, nil
end

local function build_server_items(server_name, caps, categories)
  local want = {}
  for _, c in ipairs(categories) do
    want[c] = true
  end

  local items = {}

  if want["tools"] then
    for _, tool in ipairs(caps.tools or {}) do
      items[#items + 1] = {
        text = "[" .. server_name .. "][tool] " .. tool.name,
        kind = "tool",
        server = server_name,
        cap_name = tool.name,
        description = tool.description or "(no description)",
        preview = {
          text = "**Tool:** `" .. tool.name .. "`\n\n" .. (tool.description or "(no description)"),
          ft = "markdown",
        },
      }
    end
  end

  if want["prompts"] then
    for _, prompt in ipairs(caps.prompts or {}) do
      items[#items + 1] = {
        text = "[" .. server_name .. "][prompt] " .. prompt.name,
        kind = "prompt",
        server = server_name,
        cap_name = prompt.name,
        arguments = prompt.arguments or {},
        description = prompt.description or "(no description)",
        preview = {
          text = "**Prompt:** `" .. prompt.name .. "`\n\n" .. (prompt.description or "(no description)"),
          ft = "markdown",
        },
      }
    end
  end

  if want["resourceTemplates"] then
    for _, tmpl in ipairs(caps.resourceTemplates or {}) do
      items[#items + 1] = {
        text = "[" .. server_name .. "][resource] " .. tmpl.name,
        kind = "resourceTemplate",
        server = server_name,
        cap_name = tmpl.name,
        uri_template = tmpl.uriTemplate or "",
        description = tmpl.description or "(no description)",
        preview = {
          text = "**Resource Template:** `" .. tmpl.name .. "`"
            .. "\n\nURI: `" .. (tmpl.uriTemplate or "") .. "`"
            .. "\n\n" .. (tmpl.description or "(no description)"),
          ft = "markdown",
        },
      }
    end
  end

  return items
end

function M.fetch_items(hub_url, categories)
  local data, err = fetch_json(hub_url .. "/api/servers")
  if err then
    return nil, err
  end

  local items = {}
  local disconnected = {}
  for _, server in ipairs(data.servers or {}) do
    if server.status ~= "connected" then
      disconnected[#disconnected + 1] = server.name
    else
      vim.list_extend(items, build_server_items(server.name, server.capabilities or {}, categories))
    end
  end

  return items, nil, disconnected
end

function M.fetch_prompt_content(hub_url, server, prompt_name, arguments)
  local body = vim.json.encode({
    server_name = server,
    prompt = prompt_name,
    arguments = arguments,
  })
  local data, err = fetch_json(hub_url .. "/api/servers/prompts", "POST", body)
  if err then
    return nil, err
  end
  return (data.result or {}).messages or {}, nil
end

function M.health(hub_url)
  local data, err = fetch_json(hub_url .. "/api/health")
  if err then
    vim.notify("mcp-picker health: hub unreachable — " .. err, vim.log.levels.ERROR)
    return
  end

  local servers_data, servers_err = fetch_json(hub_url .. "/api/servers")
  if servers_err then
    vim.notify("mcp-picker health: status=" .. (data.status or "?") .. ", servers unreachable", vim.log.levels.WARN)
    return
  end

  local lines = { "mcp-picker health — hub " .. (data.status or "?") }
  for _, s in ipairs(servers_data.servers or {}) do
    local caps = s.capabilities or {}
    lines[#lines + 1] = string.format(
      "  %s [%s]  tools:%d  prompts:%d  resources:%d",
      s.name, s.status,
      #(caps.tools or {}), #(caps.prompts or {}), #(caps.resourceTemplates or {})
    )
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
