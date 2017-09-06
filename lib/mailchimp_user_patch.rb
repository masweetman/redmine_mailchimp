require 'users_controller'

module MailchimpUserPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable

      after_save :subscribe

    end
  end

  module InstanceMethods

    def subscribe
      begin
        if self.active?
          if !Setting.plugin_redmine_mailchimp["api_key"].nil?
            mailchimp = Mailchimp::API.new(Setting.plugin_redmine_mailchimp["api_key"])
            list_id = Setting.plugin_redmine_mailchimp["list_id"]
            count = 0
            Setting.plugin_redmine_mailchimp.keys.map { |k| count += 1 if k.include? "merge_field" }
            merge_fields = Hash.new
            merge_fields["FNAME"] = firstname
            merge_fields["LNAME"] = lastname
            i = 0
            while i < count
              user_field_name = Setting.plugin_redmine_mailchimp["user_field_" + i.to_s]
              user_field_value = self.custom_field_value(CustomField.find_by_name(user_field_name).id)
              merge_fields[Setting.plugin_redmine_mailchimp["merge_field_" + i.to_s]] = user_field_value
              i += 1
            end

            mailchimp.lists.subscribe(list_id, {:email => mail},
              merge_fields,
              'html',
              !!Setting.plugin_redmine_mailchimp["double_optin"],
              !!Setting.plugin_redmine_mailchimp["update_existing"],
              !!Setting.plugin_redmine_mailchimp["replace_interests"],
              !!Setting.plugin_redmine_mailchimp["send_welcome"])
          end
        end
        successful_update(self)
      rescue Exception => e
        logger.error e.message
      end
    end

    def successful_update(user)
      call_hook(:controller_user_created_or_updated, {:user => user })
    end

  end
end

User.send(:include, MailchimpUserPatch)
User.send(:include, Redmine::Hook::Helper)
