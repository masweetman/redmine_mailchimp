# frozen_string_literal: true

module RedmineMailchimp
  module UserPatch
    extend ActiveSupport::Concern

    included do
      after_save :run_user_created_or_updated_hook
      after_save_commit :subscribe_to_mailchimp
    end

    private

    # Other plugins (e.g. redmine_fraternity_members) listen to this hook, so it must fire
    # on every user save regardless of the Mailchimp configuration or availability.
    def run_user_created_or_updated_hook
      Redmine::Hook.call_hook(:controller_user_created_or_updated, project: nil, hook_caller: self, user: self)
    rescue StandardError => e
      logger&.error "redmine_mailchimp: controller_user_created_or_updated hook failed: #{e.class}: #{e.message}"
    end

    def subscribe_to_mailchimp
      RedmineMailchimp::Sync.new(self).call
    rescue StandardError => e
      logger&.error "redmine_mailchimp: could not sync user ##{id} to Mailchimp: #{e.class}: #{e.message}"
    end
  end
end
