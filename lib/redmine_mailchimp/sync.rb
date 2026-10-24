# frozen_string_literal: true

module RedmineMailchimp
  # Pushes a Redmine user to the configured Mailchimp list.
  class Sync
    def initialize(user, settings = Setting.plugin_redmine_mailchimp)
      @user = user
      @settings = settings || {}
    end

    def configured?
      @settings['api_key'].present? && @settings['list_id'].present?
    end

    def call
      return false unless @user.active? && configured?

      Client.new(@settings['api_key']).subscribe(
        @settings['list_id'],
        @user.mail,
        merge_fields: merge_fields,
        double_optin: option?('double_optin'),
        update_existing: option?('update_existing')
      )
    end

    def merge_fields
      fields = { 'FNAME' => @user.firstname, 'LNAME' => @user.lastname }
      mapped_fields.each do |tag, custom_field|
        fields[tag] = Array(@user.custom_field_value(custom_field)).join(', ')
      end
      fields
    end

    private

    def option?(name)
      @settings[name].present? && @settings[name].to_s != 'false'
    end

    # Settings store the mapping as merge_field_N (Mailchimp tag) / user_field_N (custom field name)
    def mapped_fields
      indexes = @settings.keys.filter_map { |key| key[/\Amerge_field_(\d+)\z/, 1] }
      indexes.filter_map do |index|
        tag = @settings["merge_field_#{index}"]
        custom_field = UserCustomField.find_by(name: @settings["user_field_#{index}"]) if @settings["user_field_#{index}"].present?
        [tag, custom_field] if tag.present? && custom_field
      end
    end
  end
end
