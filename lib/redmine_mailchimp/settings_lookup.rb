# frozen_string_literal: true

module RedmineMailchimp
  # Loads the Mailchimp data needed by the settings page, capturing API errors for display.
  class SettingsLookup
    STANDARD_TAGS = %w[EMAIL FNAME LNAME].freeze

    attr_reader :error

    def initialize(settings)
      @settings = settings || {}
    end

    def api_key?
      @settings['api_key'].present?
    end

    # [[name, id], ...]
    def lists
      @lists ||= fetch { client.lists.map { |list| [list['name'], list['id']] } } || []
    end

    # Merge field tags of the selected list that can be mapped to Redmine user fields
    def merge_field_tags
      return [] unless api_key? && @settings['list_id'].present? && @error.nil?

      @merge_field_tags ||= fetch { client.merge_field_tags(@settings['list_id']) - STANDARD_TAGS } || []
    end

    def user_field_names
      UserCustomField.order(:name).pluck(:name).uniq
    end

    private

    def client
      Client.new(@settings['api_key'])
    end

    def fetch
      yield
    rescue Error => e
      @error = e.message
      nil
    end
  end
end
