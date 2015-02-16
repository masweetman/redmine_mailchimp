require 'user'

module MailchimpUserPatch
	def self.included(base)
		base.send(:include, InstanceMethods)

		base.class_eval do
			unloadable
			belongs_to :deliverable

			alias_method_chain :create, :mailchimp_subscribe
			alias_method_chain :update, :mailchimp_subscribe
			#alias_method_chain :destroy, :mailchimp_unsubscribe
		end
	end

	module InstanceMethods

		def create_with_mailchimp_subscribe
			create_without_mailchimp_subscribe
			if self.active?
				self.subscribe
			end
		end


		def update_with_mailchimp_subscribe
			update_without_mailchimp_subscribe
			if self.active?
				self.subscribe
			end
		end

		#def destroy_with_mailchimp_unsubscribe
		#	self.unsubscribe
		#	destroy_without_mailchimp_unsubscribe
		#end

		def subscribe
			begin
				if !Setting.plugin_redmine_mailchimp[:api_key].nil?
				    mailchimp = Setting.plugin_redmine_mailchimp[:mailchimp]
				    list_id = Setting.plugin_redmine_mailchimp[:list_id]
				    count = Setting.plugin_redmine_mailchimp[:merge_fields_count].to_i
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
				    	!!Setting.plugin_redmine_mailchimp[:double_optin],
				    	!!Setting.plugin_redmine_mailchimp[:update_existing],
				    	!!Setting.plugin_redmine_mailchimp[:replace_interests],
				    	!!Setting.plugin_redmine_mailchimp[:send_welcome])
				end
			rescue Exception => e
				logger.error e.message
			end
		end

	end
end

User.send(:include, MailchimpUserPatch)
