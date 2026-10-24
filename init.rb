# frozen_string_literal: true

Redmine::Plugin.register :redmine_mailchimp do
  name 'Redmine Mailchimp Sync'
  author 'Mike Sweetman'
  description 'This plugin allows you to keep your Redmine users synced to Mailchimp!'
  version '3.0.0'
  requires_redmine version_or_higher: '7.0.0'
  url 'https://github.com/masweetman/redmine_mailchimp.git'
  author_url 'http://michaelsweetman.com'

  settings default: {
    'double_optin' => true,
    'update_existing' => true
  }, partial: 'settings/mailchimp_settings'
end

User.include(RedmineMailchimp::UserPatch) unless User < RedmineMailchimp::UserPatch
