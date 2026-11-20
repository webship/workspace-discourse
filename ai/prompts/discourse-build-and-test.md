Build a Discourse forum with its sample data in a sites folder and prove it with its first webship-js feature.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Build a Discourse forum named <name> with its sample data in this sites folder and test it with webship-js
# ~/workspace/<dev|test|sandboxes|demos> · https://<name>.ddev.site · container-based (DDEV by default)
# the builder deletes a project of the same name first: stop if <name> is a forum somebody still needs
# about 1.5 GB of memory at the build's peak, then about 1 GB: check free -g first, build one forum at a time
# nothing on the host: no launcher, rails or rake outside the containers; no public domain, no account anywhere
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-discourse-project.sh <name> --install --add-users --sample-data
   (about five minutes: the launcher's bootstrap of the forum's image, then the accounts and the sample data)
2. bash cmd-tools-discourse-rails.sh <name>
   tell me the version, the address and the accounts it lists
3. bash cmd-tools-testing.sh <name>
   webship-js, the step pack, the users registry and tests/features/site.feature
4. bash cmd-tools-testing.sh <name> --dry-run --path tests/features/site.feature
5. bash cmd-tools-testing.sh <name> --run --path tests/features/site.feature

If a command fails, show the line that failed and stop. Do not retry with other flags.
When the feature is green: the address, the version, how many scenarios and steps passed.
Then ask me whether to keep the forum or remove it with: bash cmd-tools-remove.sh <name>
"""
```
