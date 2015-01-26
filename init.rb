#require_dependency 'registration_patch'
#require_dependency 'user_patch'

Redmine::Plugin.register :redmine_mailchimp do
  name 'Redmine Mailchimp Sync'
  author 'Mike Sweetman'
  description 'This plugin allows you to keep your Redmine users synced to Mailchimp!'
  version '0.0.1'
  url 'https://github.com/masweetman/redmine_mailchimp.git'
  author_url 'http://michaelsweetman.com'

  #settings :default => {:mailchimp => ""}, :partial => 'shared/settings'

end
