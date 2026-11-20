Feature: The forum answers and its accounts work
  As the owner of the forum
  I want the login, each default account, a topic and the refusals to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-discourse-rails.sh --add-users); a scenario logs in by a
  # handle of the users registry in cucumber.js, so no password is written here. It passes on a forum
  # built with --install --add-users, with or without --sample-data.

  @critical
  Scenario: A visitor is offered the login
    Given I am not logged in
    Then I should not be logged in
    When I go to "/login"
    Then I should be on the login page

  Scenario Outline: The <account> account logs in
    When I log in as "<account>" with the login form
    Then I should be logged in as "<account>"

    Examples:
      | account       |
      | administrator |
      | moderator     |
      | member        |
      | newuser       |

  Scenario: A wrong password is refused
    When I log in with the username "member" and the password "Wrong-password-1"
    Then the login should be refused with "Incorrect username, email or password"
    And I should not be logged in

  Scenario: The member reads a topic the moderator writes
    Given there is a topic "A topic for the first run of the suite" in "General" by "moderator"
    And I am a logged in user with the "member" user
    When I open the topic "A topic for the first run of the suite"
    Then post 1 should be by "moderator"

  # The browser logs the refused request (404) of the admin: no error of the forum.
  @js-off
  Scenario: A member may not open the admin
    Given I am a logged in user with the "member" user
    Then I should not be allowed to open "/admin"
