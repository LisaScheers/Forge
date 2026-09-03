# Set up pstack

This Forge module installs pstack declaratively through Home Manager.

## Enable the skills

Enable the AI skills module for the home configuration:

```nix
forge.ai-skills.enable = true;
```

`forge.ai-skills.enablePstackSkills` defaults to `true`. The module discovers each directory under `pstack/skills`, so every installed directory must contain a valid `SKILL.md`.

Evaluate the configuration before activating it. Activation changes the daily-driver environment and should happen only when the user asks.

## Models and reasoning effort

pstack does not require a separate model-selection skill. A subagent inherits the parent model and reasoning effort by default.

When repository configuration needs an override, store the supported model identifier and reasoning effort as separate settings. Do not encode an effort level into a made-up model slug. Keep overrides role-specific and omit them when inheritance is sufficient.

## Run your first task

Pick something real but small, and describe it the way you would describe it to a colleague:

```text
/poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

For a small task, `/poteto-mode` can work directly. For work with dependent steps, it opens a plan and reads the one playbook that matches the current layer. It loads a principle only when that principle changes a concrete decision.

From here you can type normal follow-ups. `/poteto-mode` stays active for the conversation until you opt out.

Next: [Route work through `/poteto-mode`](./02-poteto-mode.md).
