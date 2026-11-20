Write and run webship-js scenarios for one area of a Discourse forum, from the step pack's own phrases.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write scenarios for the <topic lists|topic|composer|notifications|messages|search|profile|moderation|review queue|admin> area of this forum, and run them
# ~/workspace/<folder>/<site> · https://<site>.ddev.site · container-based (DDEV by default)
# the phrases are in the discourse-scenarios skill; the discourse-tester agent is the one to hand this work over to
# look at the forum first: in the Playwright MCP browser, in a tab of your own, open each screen of the area as the account the scenario uses, once, before writing its scenario
# the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-tools-testing.sh <site>
   (when the project has no cucumber.js yet)
2. write tests/features/<area>.feature from the skill's phrases:
   the accounts by their handles (administrator, moderator, member, newuser), never a password;
   the topics it needs made with Given there is a topic "…" in "…" by "…", which the steps delete again;
   no account created, no platform name in a step
3. bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<area>.feature
4. bash cmd-tools-testing.sh <site> --run --path tests/features/<area>.feature

When it is green: the scenarios and what each one proves. When it is not: the failing step, its
message, and whether the forum or the scenario is wrong.
"""
```
