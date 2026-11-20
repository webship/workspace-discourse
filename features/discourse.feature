Feature: The Discourse plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Discourse builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Discourse"
     When I go to "/settings/plugin/discourse"
     Then I should see "@webship.co/workspace-discourse"
      And I should see "cmd-discourse-project.sh"
      And I should see "discourse-site-builder"

  Scenario: A sites folder offers the Discourse builder
    Given I am on "/dev"
     Then "option[value='cmd-discourse-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=discourse-"
     Then I should see "discourse-site-builder"
      And I should see "discourse-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=discourse-scenarios"
     Then I should see "discourse-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=discourse-test"
     Then I should see "discourse-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=discourse-"
     Then I should see "discourse-build-and-test"
      And I should see "discourse-scenarios-for-an-area"
