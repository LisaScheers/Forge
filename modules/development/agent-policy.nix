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
  # Matches the command after `cd x &&`, `sudo`, a pipe or a path prefix, but
  # not a longer word such as `deploy-build`. Valid as Python and Rust regex.
  commandPattern = tokens: "(^|[\\s;&|(/])${lib.concatMapStringsSep "\\s+" lib.escapeRegex tokens}($|[\\s;&|)])";
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
    });
  policyStatus = pkgs:
    pkgs.writeShellApplication {
      name = "agent-policy-status";
      text = ''exec ${pkgs.python3}/bin/python3 -I ${./agent-policy/policy_status.py} ${liveExpectations pkgs} "''${1:-$HOME}"'';
    };
in {
  home.lisa = {
    lib,
    pkgs,
    ...
  }: {
    # Mutable settings can drift from Nix between activations; report it at
    # every switch, and on demand with `agent-policy-status`.
    home.packages = [(policyStatus pkgs)];
    home.activation.agentPolicyStatus = lib.hm.dag.entryAfter ["codexMutableSettings" "claudeCodeSettings"] ''
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
        (expect "webmcp must run from the Nix store, not npx" (!(lib.hasInfix "npx" servers.webmcp.command)))
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
    });
    # Home Manager's own merge steps, which write the live files at activation.
    merge = pkgs.writeText "agent-settings-merge.sh" (local.home.activation.codexMutableSettings.data + "\n" + local.home.activation.claudeCodeSettings.data);
  in {
    checks.agent-policy = assert lib.assertMsg (failures == []) "Agent configuration no longer matches agent-policy.nix:\n${lib.concatStringsSep "\n" failures}";
      pkgs.runCommand "agent-policy" {
        nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml])) pkgs.gnused];
        AGENT_POLICY = policyFile pkgs;
      } ''
        cd ${./agent-policy}
        python3 -B -m unittest test_approval_hook test_policy_status
        python3 -B check_skills.py ${./ai-skills/skills} ${./ai-skills/pstack/skills}

        # A home left over from before the policy: full access, no rules, npx.
        home="$TMPDIR/home"
        mkdir -p "$home/.codex" "$home/.claude"
        printf '%s\n' 'approval_policy = "never"' 'sandbox_mode = "danger-full-access"' 'app_owned = "kept"' \
          '[mcp_servers.webmcp]' 'command = "npx"' > "$home/.codex/config.toml"
        echo '{"theme": "dark", "permissions": {"ask": []}}' > "$home/.claude/settings.json"
        ! python3 -B policy_status.py ${localExpectations} "$home" 2>/dev/null
        # Run the real merge against it, then require the policy and the kept keys.
        sed "s#${local.home.homeDirectory}#$home#g" ${merge} > "$TMPDIR/merge.sh"
        bash -c 'errorEcho() { echo "$@" >&2; }; set -eu; source "$1"' merge "$TMPDIR/merge.sh"
        python3 -B policy_status.py ${localExpectations} "$home"
        python3 -B - "$home" <<'PY'
        import json, pathlib, sys, tomllib
        home = pathlib.Path(sys.argv[1])
        codex = tomllib.loads((home / ".codex/config.toml").read_text())
        claude = json.loads((home / ".claude/settings.json").read_text())
        assert codex["app_owned"] == "kept" and claude["theme"] == "dark", "the merge dropped a key the app owns"
        assert "npx" not in codex["mcp_servers"]["webmcp"]["command"]
        assert codex["mcp_servers"]["rea"]["omit_tools_from"] == ["direct"]
        assert codex["otel"]["log_user_prompt"] is False
        assert claude["autoMemoryEnabled"] is False and claude["env"]["ENABLE_TOOL_SEARCH"] == "true"
        PY
        touch "$out"
      '';
  };
}
