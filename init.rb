require 'mailchimp'
require_dependency 'user_patch'

Redmine::Plugin.register :redmine_mailchimp do
  name 'Redmine Mailchimp Sync'
  author 'Mike Sweetman'
  description 'This plugin allows you to keep your Redmine users synced to Mailchimp!'
  version '0.0.0'
  url 'https://github.com/masweetman/redmine_mailchimp.git'
  author_url 'http://michaelsweetman.com'

  settings :default => {'empty' => true}, :partial => "settings/mailchimp_settings"

end