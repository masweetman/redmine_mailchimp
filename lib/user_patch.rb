require 'user'

module UserPatch
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
			if !Setting.plugin_redmine_mailchimp[:mailchimp_api_key].empty?
				if @list_id != Setting.plugin_redmine_mailchimp[:mailchimp_list_id] || @api_key != Setting.plugin_redmine_mailchimp[:mailchimp_api_key]
				    @mailchimp = Mailchimp::API.new(Setting.plugin_redmine_mailchimp[:mailchimp_api_key])
				    @api_key = Setting.plugin_redmine_mailchimp[:mailchimp_api_key]
				    @list_id = Setting.plugin_redmine_mailchimp[:mailchimp_list_id]
				end

			    @mailchimp.lists.subscribe(@list_id, {:email => mail},
			    	{'FNAME' => firstname,
			    	'LNAME' => lastname},
			    	'html',
			    	Setting.plugin_redmine_mailchimp[:mailchimp_double_optin],
			    	Setting.plugin_redmine_mailchimp[:mailchimp_update_existing],
			    	Setting.plugin_redmine_mailchimp[:mailchimp_replace_interests],
			    	Setting.plugin_redmine_mailchimp[:mailchimp_send_welcome])
			end
		end

	end
end

User.send(:include, UserPatch)
