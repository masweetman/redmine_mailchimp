# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class MailchimpSettingsTest < Redmine::ControllerTest
  tests SettingsController
  fixtures :users, :email_addresses, :roles, :custom_fields, :custom_values

  def setup
    @request.session[:user_id] = 1
    @settings = { 'api_key' => MAILCHIMP_TEST_API_KEY, 'double_optin' => true, 'update_existing' => true }
  end

  def teardown
    Setting.plugin_redmine_mailchimp = {}
  end

  test 'plugin is listed with its version' do
    get :plugin, params: { id: 'redmine_mailchimp' }
    assert_response :success
  end

  test 'settings page renders without an API key and makes no API calls' do
    Setting.plugin_redmine_mailchimp = { 'double_optin' => true }
    RedmineMailchimp::Client.any_instance.expects(:lists).never

    get :plugin, params: { id: 'redmine_mailchimp' }

    assert_response :success
    assert_select 'input#settings_api_key'
    assert_select 'select#settings_list_id', 0
    assert_select 'input#settings_double_optin[checked=checked]'
    assert_select 'input#settings_update_existing:not([checked])'
  end

  test 'settings page shows lists and merge field mapping rows' do
    Setting.plugin_redmine_mailchimp = @settings.merge('list_id' => 'l2', 'merge_field_0' => 'PHONE',
                                                       'user_field_0' => 'Phone number')
    RedmineMailchimp::Client.any_instance.stubs(:lists).returns([{ 'id' => 'l1', 'name' => 'One' },
                                                                 { 'id' => 'l2', 'name' => 'Two' }])
    RedmineMailchimp::Client.any_instance.stubs(:merge_field_tags).with('l2').returns(%w[EMAIL FNAME LNAME PHONE])

    get :plugin, params: { id: 'redmine_mailchimp' }

    assert_response :success
    assert_select 'select#settings_list_id option[selected=selected][value=l2]', text: 'Two'
    assert_select 'select#settings_merge_field_0 option[selected=selected]', text: 'PHONE'
    assert_select 'select#settings_user_field_0 option[selected=selected]', text: 'Phone number'
    assert_select 'select#settings_merge_field_1', 0
  end

  test 'API errors are shown on the page' do
    Setting.plugin_redmine_mailchimp = @settings
    RedmineMailchimp::Client.any_instance.stubs(:lists).raises(RedmineMailchimp::Error, 'Mailchimp API error 401: API Key Invalid')

    get :plugin, params: { id: 'redmine_mailchimp' }

    assert_response :success
    assert_select 'div.flash.error', text: /API Key Invalid/
    assert_select 'input#settings_api_key[value=?]', @settings['api_key']
  end

  test 'settings can be saved' do
    post :plugin, params: { id: 'redmine_mailchimp',
                            settings: { api_key: @settings['api_key'], list_id: 'l1', double_optin: 'true',
                                        merge_field_0: 'PHONE', user_field_0: 'Phone number' } }

    assert_redirected_to '/settings/plugin/redmine_mailchimp'
    saved = Setting.plugin_redmine_mailchimp
    assert_equal 'l1', saved['list_id']
    assert_equal 'PHONE', saved['merge_field_0']
    assert_nil saved['update_existing']
  end
end
