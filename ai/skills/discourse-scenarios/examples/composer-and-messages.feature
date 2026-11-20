Feature: The composer and personal messages
  Scenario: A topic with a category and a tag, and the preview
    Given there is no topic "A topic of the skill's composer example"
    And I am a logged in user with the "member" user
    When I open the composer for a new topic
    And I write the title "A topic of the skill's composer example" in the composer
    And I choose the category "Support" in the composer
    And I add the tag "howto" in the composer
    And I show the composer preview
    And I write "The body of the example, with **bold words** for the preview." in the composer
    Then the composer preview should show "bold words" in bold
    When I submit the composer
    Then I should be reading the topic "A topic of the skill's composer example"

  Scenario: A message to the moderator, and a new user who may not send one
    Given there is no topic "A message of the skill's example"
    And I am a logged in user with the "member" user
    When I send the message "A message of the skill's example" to "moderator" with "A message written by the skill's example."
    Then the message should be between "member" and "moderator"
    Given I am a logged in user with the "newuser" user
    Then I should not be able to start a message
