# One approval policy for every coding agent, rendered into each client's own
# format, and a check that the rendered configuration still matches it.
{
  config,
  lib,
  ...
}: let
  # Commands that change a live system. AGENTS.md requires Lisa's approval for
  # deployments and daily-driver builds, so every client asks before these.
  approvalCommands = [
    ["just" "switch"]
    ["just" "deploy"]
    ["just" "deploy-maintenance"]
    ["just" "nixos-install"]
    ["bash" "scripts/deploy.sh"]
    ["scripts/deploy.sh"]
    ["darwin-rebuild" "switch"]
    ["darwin-rebuild" "activate"]
    ["nixos-rebuild" "switch"]
    ["nixos-rebuild" "boot"]
    ["nixos-rebuild" "test"]
    ["home-manager" "switch"]
    ["deploy"]
    ["nixos-anywhere"]
  ];
  # Matches the command after `cd x &&`, `sudo`, a pipe, a path prefix, a quote
  # (`bash -c "…"`, `eval '…'`) or `$(`, but
  # not a longer word such as `deploy-build`. Valid as Python and Rust regex.
  commandPattern = tokens: "(^|[\\s;&|(/\"'`])${lib.concatMapStringsSep "\\s+" lib.escapeRegex tokens}($|[\\s;&|)\"'`])";
  commandText = lib.concatStringsSep " ";
  # Every pattern the hook and Zed match. Prefix rules cannot express `nix run
  # <flake>#darwin-rebuild -- switch`, so only the hook and Zed see that form.
  livePatterns =
    map (tokens: {
      command = commandText tokens;
      pattern = commandPattern tokens;
    })
    approvalCommands
    ++ [
      {
        command = "nix run … switch";
        pattern = "(^|[\\s;&|(])nix\\s+run\\s+\\S*(nix-darwin|darwin-rebuild|nixos-rebuild|home-manager)\\S*(\\s+--)?\\s+(switch|boot|test|activate)($|[\\s;&|)])";
      }
    ];
  policyJson = builtins.toJSON {commands = livePatterns;};

  # Credentials an agent never needs to read. Claude enforces this list;
  # Codex's sandbox and Zed have no read rules.
  secretReads = [
    "~/.ssh/id_*"
    "~/.config/sops/age/**"
    "~/.codex/auth.json"
    "~/.config/cli-proxy-api-plus/client-api-key"
    "//run/agenix/**"
    "//run/agenix.d/**"
  ];
  # MCP tools that delete memory or change a third-party account. Claude names
  # Home Manager's servers mcp__plugin_hm_<server>, and project ones mcp__<server>.
  approvalTools = ["cognee__forget" "clerk_mcp"];
  # Tools of Lisa's claude.ai connectors that send, publish or delete as her.
  connectorTools = {
    Microsoft_365 = [
      "outlook_send_mail"
      "outlook_send_draft"
      "outlook_forward_mail"
      "outlook_batch_delete_messages"
      "outlook_trash_thread"
      "outlook_delete_event"
      "outlook_set_vacation"
      "teams_send_chat_message"
      "teams_send_channel_message"
      "teams_reply_channel_message"
      "sharepoint_delete_item"
    ];
    Shopify = ["graphql_mutation" "theme_publish" "theme_commit" "publish-digital-product"];
  };

  claudeAsk =
    map (tokens: "Bash(${commandText tokens}:*)") approvalCommands
    ++ lib.concatMap (tool: ["mcp__plugin_hm_${tool}" "mcp__${tool}"]) approvalTools
    ++ lib.concatLists (lib.mapAttrsToList (connector: map (tool: "mcp__claude_ai_${connector}__${tool}")) connectorTools);
  claudeDeny = map (path: "Read(${path})") secretReads;
  codexRules = lib.concatMapStrings (tokens: "prefix_rule(pattern = ${builtins.toJSON tokens}, decision = \"prompt\")\n") approvalCommands;
  zedConfirm = map (rule: {inherit (rule) pattern;}) livePatterns;
  antigravityAsk = map (tokens: "command(${commandText tokens})") approvalCommands;

  policyFile = pkgs: pkgs.writeText "agent-policy.json" policyJson;
  approvalHook = pkgs: client: "${pkgs.python3}/bin/python3 -I ${./agent-policy/approval_hook.py} ${policyFile pkgs} ${client}";
  hookEntry = pkgs: client: matcher: {
    inherit matcher;
    hooks = [
      {
        type = "command";
        command = approvalHook pkgs client;
      }
    ];
  };
  # What the live settings files must contain once activation has merged them.
  liveExpectations = pkgs:
    pkgs.writeText "agent-policy-live.json" (builtins.toJSON {
      codex = {
        sandbox_mode = "workspace-write";
        approval_policy = "on-request";
      };
      claude = {
        permissions = {
          ask = claudeAsk;
          deny = claudeDeny;
        };
        hook = approvalHook pkgs "claude";
      };
      codex_hook = approvalHook pkgs "codex";
      codex_rules = codexRules;
    });
  # Codex keys Nix declared before the retirement manifest existed.
  retiredCodexPaths = [["model_providers" "nook"]];
  # Key paths Nix manages in ~/.codex/config.toml: each top-level key, and each
  # entry of a top-level table, such as one MCP server.
  declaredCodexPaths = settings:
    lib.concatLists (lib.mapAttrsToList (
        key: value:
          if builtins.isAttrs value
          then map (entry: [key entry]) (builtins.attrNames value)
          else [[key]]
      )
      settings);
  retireCommand = pkgs: "${pkgs.python3.withPackages (ps: [ps.tomli-w])}/bin/python3 -I ${./agent-policy/retire_settings.py}";
  policyStatus = pkgs:
    pkgs.writeShellApplication {
      name = "agent-policy-status";
      text = ''exec ${pkgs.python3}/bin/python3 -I ${./agent-policy/policy_status.py} ${liveExpectations pkgs} "''${1:-$HOME}"'';
    };
in {
  home.lisa = {
    config,
    lib,
    pkgs,
    ...
  }: let
    codexSettings = config.programs.codex.settings;
    declared = pkgs.writeText "codex-declared.json" (builtins.toJSON (lib.unique (
      declaredCodexPaths codexSettings
      ++ map (name: ["mcp_servers" name]) (builtins.attrNames config.programs.mcp.servers)
    )));
  in {
    # The merge never removes keys; retire the ones Nix stopped declaring.
    home.activation.codexRetireSettings = lib.hm.dag.entryAfter ["codexMutableSettings"] ''
      run ${retireCommand pkgs} ${config.home.homeDirectory}/.codex/config.toml \
        ${config.xdg.stateHome}/forge-agent-policy/codex-managed.json \
        ${declared} ${pkgs.writeText "codex-retired.json" (builtins.toJSON retiredCodexPaths)}
    '';
    # Mutable settings can drift from Nix between activations; report it at
    # every switch, and on demand with `agent-policy-status`.
    home.packages = [(policyStatus pkgs)];
    home.activation.agentPolicyStatus = lib.hm.dag.entryAfter ["codexRetireSettings" "claudeCodeSettings"] ''
      ${lib.getExe (policyStatus pkgs)} "$HOME" || warnEcho "Live agent settings differ from agent-policy.nix; see the lines above."
    '';
    programs.claude-code.settings = {
      permissions = {
        ask = claudeAsk;
        deny = claudeDeny;
      };
      # Permission rules see only a command's start; the hook also catches
      # these commands later in a pipeline and in bypass mode, and stops
      # subagents from starting subagents.
      hooks.PreToolUse = [
        (hookEntry pkgs "claude" "Bash")
        (hookEntry pkgs "claude" "Agent|Task")
      ];
    };
    programs.codex = {
      rules.agent-policy = codexRules;
      hooks.PreToolUse = [(hookEntry pkgs "codex" "^Bash$")];
    };
  };

  home.workstation.programs.zed-editor.userSettings.agent.tool_permissions = {
    default = "allow";
    tools.terminal.always_confirm = zedConfirm;
  };

  home.lisa-vega.programs.antigravity-cli.settings.permissions.ask = antigravityAsk;

  perSystem = {
    pkgs,
    system,
    ...
  }: let
    homes = lib.genAttrs ["lisa@vega" "lisa@asterion" "lisa@nook"] (name: config.flake.homeConfigurations.${name}.config);
    workstations = ["lisa@vega" "lisa@asterion"];
    nookCodex = config.flake.nixosConfigurations.nook.config.systemd.services.codex.serviceConfig.ExecStart;
    expect = label: condition: lib.optional (!condition) label;
    homeFailures = name: let
      home = homes.${name};
      codex = home.programs.codex;
      claude = home.programs.claude-code;
      servers = codex.settings.mcp_servers;
      prefixed = map (failure: "${name}: ${failure}");
    in
      prefixed (lib.concatLists [
        (expect "Codex must default to workspace-write with on-request approval"
          (codex.settings.sandbox_mode == "workspace-write" && codex.settings.approval_policy == "on-request"))
        (expect "Codex profile `full` must keep the opt-in unsandboxed mode"
          (codex.profiles.full.sandbox_mode == "danger-full-access"))
        (expect "Codex approval rules differ from agent-policy.nix" (codex.rules.agent-policy == codexRules))
        (expect "Codex MCP servers must be exactly clerk_mcp, cognee, rea and webmcp"
          (builtins.attrNames servers == ["clerk_mcp" "cognee" "rea" "webmcp"]))
        (expect "Codex must keep REA's tools out of the initial context and reach them through tool search"
          (servers.rea.omit_tools_from == ["direct"]))
        (expect "Claude must always defer MCP tools to tool search" (claude.settings.env.ENABLE_TOOL_SEARCH == "true"))
        (expect "Telemetry must leave out prompts and responses"
          (claude.settings.env.OTEL_LOG_USER_PROMPTS
            == "0"
            && codex.settings.otel.log_user_prompt == false
            && codex.settings.otel.log_agent_responses == false
            && codex.settings.otel.metrics_exporter == "none"))
        (expect "Codex must prompt before Cognee forget and Clerk tools"
          (servers.cognee.tools.forget.approval_mode == "prompt" && servers.clerk_mcp.default_tools_approval_mode == "prompt"))
        (expect "Every stdio MCP server must run from the Nix store, not a package runner such as npx or uvx"
          (builtins.all (server: (server.command or null) == null || lib.hasPrefix builtins.storeDir server.command)
            (builtins.attrValues servers ++ builtins.attrValues home.programs.mcp.servers)))
        (expect "Claude permission rules differ from agent-policy.nix"
          (claude.settings.permissions.ask == claudeAsk && claude.settings.permissions.deny == claudeDeny))
        (expect "Claude must run the approval hook before Bash and agent launches"
          (map (entry: entry.matcher) claude.settings.hooks.PreToolUse == ["Bash" "Agent|Task"]))
        (expect "Codex must run the approval hook before Bash"
          (map (entry: entry.matcher) codex.hooks.PreToolUse == ["^Bash$"]))
        (expect "Claude's own memory must stay off; Cognee holds memory" (claude.settings.autoMemoryEnabled == false))
        (expect "Claude and Codex must share the same MCP servers"
          (builtins.attrNames home.programs.mcp.servers == ["clerk_mcp" "rea" "webmcp"] && claude.mcpServers ? cognee))
        (expect "Claude must not auto-start project MCP servers" (claude.settings.enableAllProjectMcpServers == false))
        (expect "Claude must have the Cognee server" (claude.mcpServers ? cognee))
        (expect "Codex and Claude must read the same AGENTS.md" (codex.context == claude.context))
        (expect "Shell-wide gateway variables would reroute clients that sign in directly"
          (!(home.home.sessionVariables ? OPENAI_BASE_URL) && !(home.home.sessionVariables ? ANTHROPIC_BASE_URL)))
        (expect "Zed must confirm live-system commands"
          (!(builtins.elem name workstations) || home.programs.zed-editor.userSettings.agent.tool_permissions.tools.terminal.always_confirm == zedConfirm))
      ]);
    vega = homes."lisa@vega".programs.antigravity-cli;

    # The skill and MCP tables in docs/agents.md, rendered from Vega's home.
    vegaHome = homes."lisa@vega";
    claudeServers = builtins.attrNames vegaHome.programs.mcp.servers ++ builtins.attrNames vegaHome.programs.claude-code.mcpServers;
    codexServers = vegaHome.programs.codex.settings.mcp_servers;
    claudeDefers = (vegaHome.programs.claude-code.settings.env.ENABLE_TOOL_SEARCH or "") == "true";
    loading = present: deferred:
      if !present
      then "not installed"
      else if deferred
      then "tool search"
      else "loaded at start";
    approval = server:
      if (server.default_tools_approval_mode or null) == "prompt"
      then "every tool asks"
      else if ((server.tools or {}).forget.approval_mode or null) == "prompt"
      then "`forget` asks"
      else "client default";
    serverRow = name: let
      codexServer = codexServers.${name} or {};
    in "| ${name} | ${loading (builtins.elem name claudeServers) claudeDefers} | ${loading (codexServers ? ${name}) (builtins.elem "direct" (codexServer.omit_tools_from or []))} | ${approval codexServer} |";
    skillCount = client: toString (builtins.length (builtins.attrNames vegaHome.programs.${client}.skills));
    pstackCount = toString (builtins.length (builtins.attrNames (builtins.readDir ./ai-skills/pstack/skills)));
    catalogue = lib.concatStringsSep "\n" ([
        "<!-- catalogue:start: rendered from Nix; checks.agent-policy prints the current version when this differs -->"
        "| Skills on Vega | Claude | Codex | Antigravity | Copilot |"
        "| --- | ---: | ---: | ---: | ---: |"
        "| Installed | ${skillCount "claude-code"} | ${skillCount "codex"} | ${skillCount "antigravity-cli"} | ${skillCount "github-copilot-cli"} |"
        "| Of which pstack, manual only | ${pstackCount} | ${pstackCount} | 0 | 0 |"
        ""
        "| MCP server | Claude | Codex | Approval |"
        "| --- | --- | --- | --- |"
      ]
      ++ map serverRow (lib.unique (lib.sort builtins.lessThan (claudeServers ++ builtins.attrNames codexServers)))
      ++ ["<!-- catalogue:end -->"]);
    catalogueCurrent = lib.hasInfix catalogue (builtins.readFile ../../docs/agents.md);
    failures =
      lib.concatMap homeFailures (builtins.attrNames homes)
      ++ expect "lisa@vega: Antigravity must read AGENTS.md, stay in its workspace and ask before live-system commands"
      (vega.context.GEMINI
        == homes."lisa@vega".programs.codex.context
        && vega.settings.allowNonWorkspaceAccess == false
        && vega.settings.permissions.ask == antigravityAsk)
      ++ expect "nook: the Codex service must use the shared Cognee server"
      (lib.hasInfix "mcp_servers.cognee.url=" nookCodex && lib.hasInfix "mcp_servers.cognee.tools.forget.approval_mode=" nookCodex);
    # The home this system builds, so its generated files exist here.
    local =
      homes.${
        {
          aarch64-darwin = "lisa@vega";
          aarch64-linux = "lisa@asterion";
          x86_64-linux = "lisa@nook";
        }.${
          system
        }
      };
    localExpectations = pkgs.writeText "agent-policy-local.json" (builtins.toJSON {
      codex = {
        sandbox_mode = "workspace-write";
        approval_policy = "on-request";
      };
      claude = {
        permissions = {
          ask = claudeAsk;
          deny = claudeDeny;
        };
        hook = (builtins.head (builtins.head local.programs.claude-code.settings.hooks.PreToolUse).hooks).command;
      };
      codex_hook = (builtins.head (builtins.head local.programs.codex.hooks.PreToolUse).hooks).command;
      codex_rules = codexRules;
    });
    # Home Manager's own merge steps, which write the live files at activation.
    merge = pkgs.writeText "agent-settings-merge.sh" (lib.concatMapStringsSep "\n" (step: local.home.activation.${step}.data) [
      "codexMutableSettings"
      "codexRetireSettings"
      "claudeCodeSettings"
    ]);
  in {
    checks.agent-policy = assert lib.assertMsg (failures == []) "Agent configuration no longer matches agent-policy.nix:\n${lib.concatStringsSep "\n" failures}";
    assert lib.assertMsg catalogueCurrent "docs/agents.md's catalogue differs from Nix; replace it with:\n${catalogue}";
      pkgs.runCommand "agent-policy" {
        nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml ps.tomli-w])) pkgs.gnused];
        AGENT_POLICY = policyFile pkgs;
      } ''
        cd ${./agent-policy}
        python3 -B -m unittest test_approval_hook test_policy_status test_retire_settings
        python3 -B check_skills.py ${./ai-skills/skills} ${./ai-skills/pstack/skills}

        # A home left over from before the policy: full access, no rules, npx.
        home="$TMPDIR/home"
        mkdir -p "$home/.codex" "$home/.claude"
        printf '%s\n' 'approval_policy = "never"' 'sandbox_mode = "danger-full-access"' 'app_owned = "kept"' \
          '[mcp_servers.webmcp]' 'command = "npx"' '[mcp_servers.node_repl]' 'command = "node"' \
          '[model_providers.nook]' 'base_url = "https://gateway"' > "$home/.codex/config.toml"
        echo '{"theme": "dark", "permissions": {"ask": []}}' > "$home/.claude/settings.json"
        ! python3 -B policy_status.py ${localExpectations} "$home" 2>/dev/null
        # Run the real merge against it, then require the policy and the kept keys.
        sed "s#${local.home.homeDirectory}#$home#g" ${merge} > "$TMPDIR/merge.sh"
        bash -c 'errorEcho() { echo "$@" >&2; }; run() { "$@"; }; set -eu; source "$1"' merge "$TMPDIR/merge.sh"
        # Home Manager links these two files rather than merging them.
        mkdir -p "$home/.codex/rules"
        ln -s ${local.home.file.".codex/hooks.json".source} "$home/.codex/hooks.json"
        ln -s ${local.home.file.".codex/rules/agent-policy.rules".source} "$home/.codex/rules/agent-policy.rules"
        python3 -B policy_status.py ${localExpectations} "$home"
        python3 -B - "$home" <<'PY'
        import json, pathlib, sys, tomllib
        home = pathlib.Path(sys.argv[1])
        codex = tomllib.loads((home / ".codex/config.toml").read_text())
        claude = json.loads((home / ".claude/settings.json").read_text())
        assert codex["app_owned"] == "kept" and claude["theme"] == "dark", "the merge dropped a key the app owns"
        assert codex["mcp_servers"]["node_repl"]["command"] == "node", "an app-owned server was retired"
        assert "model_providers" not in codex, "a retired gateway provider survived"
        assert "npx" not in codex["mcp_servers"]["webmcp"]["command"]
        assert codex["mcp_servers"]["rea"]["omit_tools_from"] == ["direct"]
        assert codex["otel"]["log_user_prompt"] is False
        assert claude["autoMemoryEnabled"] is False and claude["env"]["ENABLE_TOOL_SEARCH"] == "true"
        PY
        touch "$out"
      '';
  };
}
