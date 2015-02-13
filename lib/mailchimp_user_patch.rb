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
			if !Setting.plugin_redmine_mailchimp[:api_key].nil?
			    mailchimp = Setting.plugin_redmine_mailchimp[:mailchimp]
			    list_id = Setting.plugin_redmine_mailchimp[:list_id]

			    mailchimp.lists.subscribe(list_id, {:email => mail},
			    	{'FNAME' => firstname,
			    	'LNAME' => lastname},
			    	'html',
			    	!!Setting.plugin_redmine_mailchimp[:double_optin],
			    	!!Setting.plugin_redmine_mailchimp[:update_existing],
			    	!!Setting.plugin_redmine_mailchimp[:replace_interests],
			    	!!Setting.plugin_redmine_mailchimp[:send_welcome])
			end
		end

	end
end

User.send(:include, MailchimpUserPatch)
