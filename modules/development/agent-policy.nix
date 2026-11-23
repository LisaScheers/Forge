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
  policyJson = builtins.toJSON {
    commands =
      map (tokens: {
        command = commandText tokens;
        pattern = commandPattern tokens;
      })
      approvalCommands;
  };

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

  claudeAsk =
    map (tokens: "Bash(${commandText tokens}:*)") approvalCommands
    ++ lib.concatMap (tool: ["mcp__plugin_hm_${tool}" "mcp__${tool}"]) approvalTools;
  claudeDeny = map (path: "Read(${path})") secretReads;
  codexRules = lib.concatMapStrings (tokens: "prefix_rule(pattern = ${builtins.toJSON tokens}, decision = \"prompt\")\n") approvalCommands;
  zedConfirm = map (tokens: {pattern = commandPattern tokens;}) approvalCommands;
  antigravityAsk = map (tokens: "command(${commandText tokens})") approvalCommands;

  policyFile = pkgs: pkgs.writeText "agent-policy.json" policyJson;
  approvalHook = pkgs: "${pkgs.python3}/bin/python3 -I ${./agent-policy/approval_hook.py} ${policyFile pkgs}";
in {
  home.lisa = {pkgs, ...}: {
    programs.claude-code.settings = {
      permissions = {
        ask = claudeAsk;
        deny = claudeDeny;
      };
      # Permission rules see only a command's start; the hook also catches
      # these commands later in a pipeline and in bypass mode.
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = approvalHook pkgs;
            }
          ];
        }
      ];
    };
    programs.codex.rules.agent-policy = codexRules;
  };

  home.workstation.programs.zed-editor.userSettings.agent.tool_permissions = {
    default = "allow";
    tools.terminal.always_confirm = zedConfirm;
  };

  home.lisa-vega.programs.antigravity-cli.settings.permissions.ask = antigravityAsk;

  perSystem = {pkgs, ...}: let
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
        (expect "Codex must prompt before Cognee forget and Clerk tools"
          (servers.cognee.tools.forget.approval_mode == "prompt" && servers.clerk_mcp.default_tools_approval_mode == "prompt"))
        (expect "webmcp must run from the Nix store, not npx" (!(lib.hasInfix "npx" servers.webmcp.command)))
        (expect "Claude permission rules differ from agent-policy.nix"
          (claude.settings.permissions.ask == claudeAsk && claude.settings.permissions.deny == claudeDeny))
        (expect "Claude must run the approval hook before Bash"
          ((builtins.head claude.settings.hooks.PreToolUse).matcher == "Bash"))
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
  in {
    checks.agent-policy = assert lib.assertMsg (failures == []) "Agent configuration no longer matches agent-policy.nix:\n${lib.concatStringsSep "\n" failures}";
      pkgs.runCommand "agent-policy" {
        nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml]))];
        AGENT_POLICY = policyFile pkgs;
      } ''
        cd ${./agent-policy}
        python3 -B -m unittest test_approval_hook
        python3 -B check_skills.py ${./ai-skills/skills} ${./ai-skills/pstack/skills}
        touch "$out"
      '';
  };
}
