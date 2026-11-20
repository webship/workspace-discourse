Feature: Search
  Scenario: The quick search and the full search page
    Given I am not logged in
    And I am on the "Latest" topic list
    When I search for "backups"
    Then the quick search should show "Where are the nightly backups kept"
    When I search the full page for "laptop"
    Then the search should find 1 result
    When I filter the search by the category "Installation"
    Then the search results should show "How to install the product on a laptop"
