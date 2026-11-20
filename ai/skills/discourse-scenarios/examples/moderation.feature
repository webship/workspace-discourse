Feature: Moderation
  Scenario: The moderator closes, pins and opens a topic
    Given there is a topic "A topic the skill's example moderates" in "General" by "member"
    And I am a logged in user with the "moderator" user
    When I open the topic "A topic the skill's example moderates"
    And I close the topic
    Then the topic should be closed
    And the topic should show the action "Closed"
    When I pin the topic until "Next month"
    Then the topic should be pinned
    When I unpin the topic
    And I open the topic again
    Then the topic should be open
