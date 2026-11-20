Feature: A topic
  Scenario: The member replies, quotes and likes
    Given there is a topic "A topic of the skill's example" in "General" by "moderator"
    And I am a logged in user with the "member" user
    When I open the topic "A topic of the skill's example"
    And I reply to the topic with "A reply of the skill's example, written by the suite."
    Then the topic should have 2 posts
    And the last post should be by "member"
    When I quote post 1 in a reply
    And I add "A quotation of the skill's example." to the composer
    And I submit the composer
    Then the last post should quote "moderator"
    When I like post 1
    Then post 1 should have 1 like
