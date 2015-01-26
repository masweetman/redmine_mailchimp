require 'user'

module UserPatch
	def self.included(base)
		base.send(:include, InstanceMethods)

		base.class_eval do
			unloadable
			belongs_to :deliverable

			alias_method_chain :update, :mailchimp_subscribe
		end
	end

	module InstanceMethods

		def update_with_mailchimp_subscribe
			update_without_mailchimp_subscribe
			if self.active?
				self.subscribe
			end
		end

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
			    	false,
			    	true,
			    	true,
			    	false)
			end
		end

	end
end

User.send(:include, UserPatch)
