require 'mailchimp'
require_dependency 'mailchimp_user_patch'

Redmine::Plugin.register :redmine_mailchimp do
  name 'Redmine Mailchimp Sync'
  author 'Mike Sweetman'
  description 'This plugin allows you to keep your Redmine users synced to Mailchimp!'
  version '0.0.1'
  url 'https://github.com/masweetman/redmine_mailchimp.git'
  author_url 'http://michaelsweetman.com'

  settings :default => {
      'double_optin' => true,
      'update_existing' => true,
      'replace_interests' => true,
      'send_welcome' => true,
      'merge_field_0' => 'EMAIL',
      'user_field_0' => 'mail',
      'merge_field_1' => 'FIRST',
      'user_field_1' => 'firstname',
      'merge_field_2' => 'LAST',
      'user_field_2' => 'lastname'
    }, :partial => "settings/mailchimp_settings"

end