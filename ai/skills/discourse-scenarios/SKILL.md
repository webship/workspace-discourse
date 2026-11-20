---
name: discourse-scenarios
description: Write webship-js scenarios for a Discourse forum of the Webship Workspace from phrases that exist — the Discourse step pack's steps by area (the session, the topic lists, a topic and its posts, the composer, mentions and notifications, personal messages, the search, the profile and the preferences, the moderators' actions, the review queue and the admin), the handles of the users registry, the test topics a scenario makes and the steps delete, the traps found on a real forum, and three features that pass on a forum built with the sample data. Use when writing or fixing a scenario for a forum, choosing a step for a forum screen, or turning a manual check of the forum into a feature.
---

# discourse-scenarios

Scenarios for a forum built with the Discourse plugin (`bash cmd-discourse-project.sh <site> --install
--add-users --sample-data`) in a container-based workspace (DDEV by default), tested with webship-js and
`@webship-js/discourse-steps` once `bash cmd-tools-testing.sh <site>` set the project up. Every phrase
below exists in the pack or in webship-js; a scenario names no platform.

## Accounts and test topics

- `Given I am a logged in user with the "member" user`: `administrator` (admin), `moderator`,
  `member` (trust level 2), `newuser` (trust level 0, for the refusals). The forum logs in with the
  username the registry gives. `Given I am not logged in` for a visitor.
- `Given there is a topic "…" in "General" by "moderator"` (or `… with:` and a table of `body` and
  `tags`), `Given there is a message "…" from "moderator" to "member"`, `Given "moderator" replied to the
  topic "…" with "…"`: test content made through the forum's API as that account, deleted after the
  scenario. Every topic, reply, like, bookmark and draft a scenario makes on screen is deleted after it too.
- `Given there is no topic "…"`: for a topic the composer makes in the scenario; what a stopped run left
  is deleted now.
- `Then there should be a topic "…"` (or `no topic`): a check through the forum's search.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I log in as "member" with the login form`, `I log in with the username "…" and the password "…"`, `the login should be refused with "Incorrect username, email or password"`, `I log out`, `I should be logged in as "member"`, `I should not be logged in`, `I should be on the login page` |
| Topic lists | `I am on the "Latest" topic list` (New, Unread, Top, Hot, Categories), `the topic list should be "All latest topics"`, `the topic list should show "…"`, `the topic list should show the topics:`, `the first topic of the list should be "…"`, `the first unpinned topic of the list should be "…"`, `the topic "…" in the list should be in the category "Support"`, `the topic "…" in the list should have the tag "howto"`, `the topic "…" in the list should have 2 replies`, `the topic "…" in the list should be new` (unread, closed, pinned, read), `I open "…" from the list`, `the topic list should be empty` |
| Categories and tags | `I go to the category "Support"`, `I go to the tag "howto"`, `the categories page should list "Support" with the subcategory "Installation"`, `the tags page should list "release-notes" on 2 topics` |
| A topic | `I open the topic "…"`, `I should be reading the topic "…"`, `I read the topic`, `the topic should have 3 posts`, `post 2 should be by "moderator"`, `the last post should read "…"`, `I reply to the topic with "…"`, `I reply to post 2 with "…"`, `I quote post 2 in a reply`, `the last post should quote "moderator"`, `I like post 2`, `I remove my like from post 2`, `post 2 should have 1 like`, `I bookmark post 1`, `I delete the bookmark of post 1`, `post 1 should be bookmarked`, `I flag post 2 as "It's Off-Topic"`, `post 2 should show "You flagged this as off-topic"`, `I set the notifications of the topic to "Tracking"`, `the notifications of the topic should be "Tracking"` |
| Composer | `I open the composer for a new topic`, `I write the title "…" in the composer`, `I choose the category "Support" in the composer`, `I add the tag "howto" in the composer`, `I write "…" in the composer`, `I add "…" to the composer`, `I submit the composer`, `I try to submit the composer`, `the composer should show the error "Title must be at least 15 characters"`, `I show the composer preview`, `the composer preview should show "bold words" in bold`, `I save the draft and close the composer`, `I resume the draft "…"`, `the composer should have the title "…"`, `the composer should show "…"`, `I discard the composer`, `the composer should be closed` |
| Notifications | `I open the notifications menu`, `I open the "Personal messages" tab of the notifications menu`, `the notifications menu should list a "mentioned" notification for "…"`, `the notifications menu should list "moderator …"`, `I open the notification "…"`, `the avatar should show "new message notification"` |
| Messages | `I go to my messages`, `I go to my "Sent" messages`, `my messages should list "…"`, `I open the composer for a new message`, `I add the recipient "moderator" in the composer`, `I send the message "…" to "moderator" with "…"`, `the message should be between "member" and "moderator"`, `I should not be able to start a message` |
| Search | `I search for "backups"`, `the quick search should show "…"`, `I search the full page for "keyboard"`, `the search should find 1 result`, `the search results should show "…"`, `I filter the search by the category "Support"` (tag, author), `the search field should read "backups #support"` |
| Profile | `I open the profile of "member"`, `the profile should show the name "Member Webship"`, `the profile should show "read time"`, `I go to my "Profile" preferences`, `I set the preference "Location" to "…"`, `I save my preferences`, `the preference "Location" should be "…"` |
| Moderation | `I close the topic`, `I open the topic again`, `I pin the topic until "Next month"`, `I pin the topic globally until "Two weeks"`, `I unpin the topic`, `I try to pin the topic without a time`, `the pin dialog should show the error "A date is required to pin this topic."`, `I unlist the topic`, `I list the topic again`, `the topic should be closed` (open, pinned, not pinned, unlisted, listed), `the topic should show the action "Closed"`, `I should not see the topic admin menu` |
| Review queue | `I go to the review queue`, `the review queue should list the flagged post "…"`, `I answer "Keep post" to the flagged post "…"` |
| Admin | `I go to the admin dashboard`, `the admin dashboard should show "Site traffic"`, `I search the site settings for "title"`, `the site settings should list "title"`, `the site setting "title" should be "Webship test forum"`, `I should not be allowed to open "/admin"` |

## A scenario, start to end

A topic closed by the moderator and opened again: the topic is the scenario's own, deleted after it
whatever happens in it.

```gherkin
Feature: Moderation
  Scenario: A topic closed and opened again
    Given there is a topic "A topic the skill closes" in "General" by "member"
    And I am a logged in user with the "moderator" user
    When I open the topic "A topic the skill closes"
    And I close the topic
    Then the topic should be closed
    And the topic should show the action "Closed"
    When I open the topic again
    Then the topic should be open
```

## Traps found on a real forum

- The forum keeps a long poll open at all times (its message bus): the pack's steps wait on the forum's
  own signals (the page loading slider, the answer of each request), and the pack takes the long poll
  and long timers out of webship-js's settle, so `wait for AJAX to finish` works on the forum too.
- The sticky header covers a button near the top of the window: the steps bring a post to the middle
  of the window before they click in it.
- A reply makes a topic unread only for an account that tracks it: read it (`I read the topic`) and set
  its notifications to "Tracking" first.
- The composer is a rich text editor by default; the preview is the Markdown editor's
  (`I show the composer preview` switches, and the account gets the rich text editor back after).
- Staff see unlisted topics in the lists: check an unlisted topic's absence as a member.
- The pinned icon of a topic's title is drawn after a reload; `the topic should be pinned` reads the
  forum's own state.
- On a shared machine the browser on the host can lose a request when another container starts: run
  the suite in the container (`bash cmd-tools-testing.sh <site> --run`).

## Examples

- [`examples/topic.feature`](examples/topic.feature): a reply, a quote and a like on a topic of the scenario.
- [`examples/moderation.feature`](examples/moderation.feature): a topic closed, pinned and opened again.
- [`examples/search.feature`](examples/search.feature): the quick search, the full page and a filter.
- [`examples/composer-and-messages.feature`](examples/composer-and-messages.feature): a topic with a category, a tag and the preview; a message, and a new user who may not send one.

Copy them into `tests/features/` of the project and run them:

```bash
bash cmd-tools-testing.sh <site> --run --path tests/features/topic.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Discourse.** Start with `ch27-testing-spa.md` (a single-page app and its waits),
  `ch07-waiting-dynamic-content.md` (waiting on the app's own signals), `ch10-authentication-authorization.md`
  (logins, sessions, roles and refusals) and `ch20-design-patterns-for-tests.md` (test data a scenario makes and removes).
