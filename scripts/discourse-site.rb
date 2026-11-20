# frozen_string_literal: true
#
# The test site of the step pack: run with the forum's own Rails, in its
# container (`rails runner -`, the script on the standard input). The build
# script of the step pack and the Webship Workspace's builder both run it.
#
# Verbs (DISCOURSE_SITE_VERBS, in order):
#   settings  the settings of a test site (see SETTINGS below)
#   owner     the owner of $discourse_site_accounts (the admin rake admin:create
#             made): its username, name and password, active and admin
#   accounts  the accounts of $discourse_site_accounts: made, or given back their
#             email, name, password, role and trust level
#   cancel    the accounts of $discourse_site_accounts deleted (never the owner)
#   list      the accounts, one per line
#   seed      the sample content: categories, tags, topics, replies, a message
#
# The accounts travel as base64 of a JSON object on the first line of the
# input ($discourse_site_accounts), never on a command line.

require "base64"
require "json"

VERBS = ENV.fetch("DISCOURSE_SITE_VERBS", "").split
DATA =
  begin
    JSON.parse(Base64.decode64($discourse_site_accounts.to_s))
  rescue StandardError
    {}
  end
ACCOUNTS = DATA.fetch("accounts", [])

def say(message)
  puts "  #{message}"
end

# The settings of a test site. The forum keeps every limit a person meets; it
# drops the ones one test run meets because it comes from one address and posts
# many times in a few minutes, and the screens that sit over a first visit.
SETTINGS = {
  title: "Webship test forum",
  site_description: "The forum a webship-js test suite runs against.",
  contact_email: "administrator@example.com",
  notification_email: "noreply@example.com",
  # No setup wizard over the admin's first page, https links behind the router.
  wizard_enabled: false,
  force_https: true,
  # No tips over the pages of a first visit.
  enable_user_tips: false,
  # The accounts share one password of 12 characters (the default asks 15 of an admin).
  min_admin_password_length: 10,
  tagging_enabled: true,
  # One test run: one address, many logins, posts and actions in a few minutes.
  unique_posts_mins: 0,
  rate_limit_create_topic: 0,
  rate_limit_create_post: 0,
  rate_limit_new_user_create_post: 0,
  max_logins_per_ip_per_hour: 1000,
  max_logins_per_ip_per_minute: 1000,
  max_topics_per_day: 1000,
  max_personal_messages_per_day: 1000,
  max_likes_per_day: 1000,
  max_bookmarks_per_day: 1000,
  max_flags_per_day: 1000,
  max_edits_per_day: 1000,
  max_post_deletions_per_minute: 1000,
  max_post_deletions_per_day: 1000,
  tl1_max_topics_in_first_day: 1000,
  tl1_max_replies_in_first_day: 1000,
}.freeze

def set_setting(name, value)
  unless SiteSetting.respond_to?("#{name}=")
    say("no setting #{name} in this release: left as it is")
    return
  end
  SiteSetting.public_send("#{name}=", value) if SiteSetting.public_send(name) != value
rescue StandardError => e
  say("#{name}: #{e.message}")
end

def settings!
  SETTINGS.each { |name, value| set_setting(name, value) }
  say("the settings of a test site")
end

def owner
  User.find_by_email(DATA.dig("owner", "email").to_s) || User.where(admin: true).where("id > 0").order(:id).first
end

def account!(spec)
  user = User.find_by_email(spec["email"]) || User.find_by_username(spec["username"])
  created = user.nil?
  user ||= User.new
  user.username = spec["username"] if user.username != spec["username"]
  user.email = spec["email"] if user.email != spec["email"]
  user.name = spec["name"]
  user.password = spec["password"]
  user.active = true
  user.approved = true
  user.approved_at ||= Time.zone.now
  user.save!
  user.email_tokens.update_all(confirmed: true)

  case spec["role"]
  when "admin"
    user.grant_admin! unless user.admin
    user.revoke_moderation! if user.moderator
  when "moderator"
    user.revoke_admin! if user.admin
    user.grant_moderation! unless user.moderator
  else
    user.revoke_admin! if user.admin
    user.revoke_moderation! if user.moderator
  end

  # The editor of the composer the forum gives a new account (an earlier run may have switched it).
  if user.user_option && UserOption.column_names.include?("composition_mode")
    default_mode = UserOption.column_defaults["composition_mode"]
    user.user_option.update!(composition_mode: default_mode) if user.user_option.composition_mode != default_mode
  end

  level = spec["trust_level"].to_i
  user.update!(manual_locked_trust_level: level)
  user.change_trust_level!(level) if user.trust_level != level
  user.update!(suspended_at: nil, suspended_till: nil, silenced_till: nil) if user.suspended? || user.silenced?
  say("#{created ? "made" : "kept"} #{user.username} <#{user.email}>: #{spec["role"]}, trust level #{user.reload.trust_level}")
  user
end

def accounts!
  ACCOUNTS.each { |spec| account!(spec) }
end

def owner!
  spec = DATA["owner"] || {}
  user = User.find_by_email(spec["email"].to_s)
  return say("no owner #{spec["email"]}: make it with rake admin:create first") unless user
  user.username = spec["username"] if spec["username"].present? && user.username != spec["username"]
  user.name = spec["name"] if spec["name"].present?
  user.password = spec["password"] if spec["password"].present?
  user.active = true
  user.approved = true
  user.save!
  user.email_tokens.update_all(confirmed: true)
  user.grant_admin! unless user.admin
  say("owner #{user.username} <#{user.email}>: admin")
end

def cancel!
  by = owner
  ACCOUNTS.each do |spec|
    next if spec["email"] == DATA.dig("owner", "email") && spec["handle"] == "owner"
    user = User.find_by_email(spec["email"]) || User.find_by_username(spec["username"])
    next say("no account #{spec["username"]}") unless user
    next say("#{user.username} is the owner: kept") if by && user.id == by.id && DATA.dig("owner", "handle") == "owner"
    user.revoke_admin! if user.admin
    user.revoke_moderation! if user.moderator
    UserDestroyer.new(Discourse.system_user).destroy(user, delete_posts: true, context: "Webship test site")
    say("deleted #{spec["username"]}")
  end
end

def list!
  ACCOUNTS.each do |spec|
    user = User.find_by_email(spec["email"]) || User.find_by_username(spec["username"])
    if user
      role = user.admin ? "admin" : (user.moderator ? "moderator" : "member")
      say("#{user.username} <#{user.email}> #{role}, trust level #{user.trust_level}#{user.active ? "" : ", not active"}")
    else
      say("#{spec["username"]}: missing")
    end
  end
end

# ---------------------------------------------------------------------------
# The sample content
# ---------------------------------------------------------------------------

CATEGORIES = [
  { name: "Announcements", color: "0088CC", description: "News about the test forum and its releases." },
  { name: "Support", color: "25AAE2", description: "Questions about installing and running the product." },
  { name: "Installation", parent: "Support", color: "9EB83B", description: "Getting the product running on a new machine." },
  { name: "Off-topic", color: "92278F", description: "Anything that does not fit another category." },
].freeze

TAGS = %w[howto question release-notes backups].freeze

TOPICS = [
  {
    title: "How this test forum is organised",
    category: "Announcements", by: "administrator", tags: %w[release-notes],
    raw: "This forum is where the test suite reads, writes and moderates. Every topic here is sample content made by the build of the site.",
    replies: [],
  },
  {
    title: "How to install the product on a laptop",
    category: "Installation", by: "member", tags: %w[howto],
    raw: "I want to try the product on my laptop before the server is ready. Which steps do I need, and how much memory does it take?",
    replies: [
      { by: "moderator", raw: "Start with the container tool, then run the installer. Four gigabytes of memory is enough for a laptop." },
      { by: "administrator", raw: "The installation guide in the documentation has every step, with the commands to copy." },
    ],
    likes: { 0 => %w[moderator administrator newuser], 1 => %w[member] },
  },
  {
    title: "Where are the nightly backups kept",
    category: "Support", by: "member", tags: %w[question backups],
    raw: "The nightly backups run at two in the morning. Where does the server keep the files, and for how many days?",
    replies: [
      { by: "moderator", raw: "They are kept in the backups folder of the shared volume for seven days, then removed." },
    ],
  },
  {
    title: "Release notes for the spring update",
    category: "Announcements", by: "moderator", tags: %w[release-notes],
    raw: "The spring update brings a faster search, a new editor toolbar and many small fixes. Read the full list below.",
    replies: [],
  },
  {
    title: "Favourite keyboard shortcuts of the team",
    category: "Off-topic", by: "member", tags: [],
    raw: "Which keyboard shortcuts do you use every day? Mine is the one that jumps to the next unread topic.",
    replies: [
      { by: "moderator", raw: "The question mark opens the list of every shortcut the forum knows." },
      { by: "administrator", raw: "I use the shortcut that opens the reply composer without the mouse." },
      { by: "member", raw: "Thanks, I did not know the question mark trick. That list is very handy." },
    ],
  },
  {
    title: "The old server is retired this month",
    category: "General", by: "moderator", tags: [],
    raw: "The old server is switched off at the end of the month. This topic is closed: ask in Support instead.",
    replies: [],
    closed: true,
  },
  {
    title: "Ideas for the next community meetup",
    category: "General", by: "moderator", tags: [],
    raw: "Let us collect ideas for the next community meetup: the place, the date and the talks people want to hear.",
    replies: [
      { by: "member", raw: "A short talk about the new search would be great, with time for questions after it." },
    ],
  },
].freeze

MESSAGES = [
  {
    title: "Your account on the test forum",
    by: "administrator", to: %w[member],
    raw: "Welcome to the test forum. This personal message is sample content made by the build of the site.",
  },
].freeze

def user_named(username)
  User.find_by_username(username) || raise("no account #{username}: run the accounts verb first")
end

def category_named(name, parent = nil)
  scope = Category.where("lower(name) = ?", name.downcase)
  scope = scope.where(parent_category_id: parent.id) if parent
  scope.first
end

def seed_categories!
  admin = owner
  CATEGORIES.each do |spec|
    parent = spec[:parent] && category_named(spec[:parent])
    category = category_named(spec[:name], parent)
    unless category
      category = Category.new(name: spec[:name], user: admin, color: spec[:color], text_color: "FFFFFF")
      category.parent_category_id = parent.id if parent
      category.save!
      say("category #{spec[:name]}")
    end
    if category.topic && category.topic.first_post && category.description.to_s.exclude?(spec[:description])
      category.topic.first_post.revise(admin, { raw: spec[:description] }, skip_validations: true, bypass_bump: true)
    end
  end
end

def seed_tags!
  TAGS.each { |name| Tag.find_or_create_by!(name: name) }
end

def find_topic(title, archetype = Archetype.default)
  Topic.where(archetype: archetype).where("lower(title) = ?", title.downcase).first
end

def seed_topics!
  TOPICS.each do |spec|
    topic = find_topic(spec[:title])
    if topic.nil?
      category = category_named(spec[:category]) || raise("no category #{spec[:category]}")
      post = PostCreator.create!(user_named(spec[:by]), title: spec[:title], raw: spec[:raw], category: category.id, tags: spec[:tags], skip_validations: true)
      topic = post.topic
      spec[:replies].each do |reply|
        PostCreator.create!(user_named(reply[:by]), topic_id: topic.id, raw: reply[:raw], skip_validations: true)
      end
      say("topic #{spec[:title]} (#{spec[:replies].size} replies)")
    end
    (spec[:likes] || {}).each do |index, usernames|
      post = topic.posts.where(post_number: index + 1).first
      next unless post
      usernames.each do |username|
        liker = user_named(username)
        next if PostAction.exists?(post_id: post.id, user_id: liker.id, post_action_type_id: PostActionType.types[:like])
        PostActionCreator.like(liker, post)
      end
    end
    if spec[:closed] && !topic.closed
      topic.update_status("closed", true, Discourse.system_user)
    end
  end
end

def seed_messages!
  MESSAGES.each do |spec|
    next if find_topic(spec[:title], Archetype.private_message)
    PostCreator.create!(user_named(spec[:by]), title: spec[:title], raw: spec[:raw], archetype: Archetype.private_message, target_usernames: spec[:to].join(","), skip_validations: true)
    say("message #{spec[:title]}")
  end
end

def seed!
  seed_categories!
  seed_tags!
  seed_topics!
  seed_messages!
  TopTopic.refresh!
  say("the sample content")
end

VERBS.each do |verb|
  case verb
  when "settings" then settings!
  when "owner" then owner!
  when "accounts" then accounts!
  when "cancel" then cancel!
  when "list" then list!
  when "seed" then seed!
  else
    warn "Unknown verb #{verb}: settings, owner, accounts, cancel, list, seed"
    exit 1
  end
end
