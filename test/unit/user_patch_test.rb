# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineMailchimp::UserPatchTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses, :custom_fields, :custom_values

  HOOK = :controller_user_created_or_updated

  def setup
    @settings = { 'api_key' => MAILCHIMP_TEST_API_KEY, 'list_id' => 'list1',
                  'double_optin' => true, 'update_existing' => true }
    Setting.plugin_redmine_mailchimp = @settings
    @phone = UserCustomField.find_by!(name: 'Phone number')
  end

  def teardown
    Setting.plugin_redmine_mailchimp = {}
  end

  def build_user(attrs = {})
    User.new({ firstname: 'Jane', lastname: 'Doe', login: 'jane.doe', mail: 'Jane@Example.com',
               language: 'en' }.merge(attrs)).tap { |u| u.password = u.password_confirmation = 'secret123456' }
  end

  test 'plugin is registered and patches User once' do
    assert_equal '3.0.0', Redmine::Plugin.find(:redmine_mailchimp).version
    assert_operator User, :<, RedmineMailchimp::UserPatch
    assert_equal 1, User.ancestors.count(RedmineMailchimp::UserPatch)
  end

  test 'saving an active user subscribes with names and mapped custom fields' do
    Setting.plugin_redmine_mailchimp = @settings.merge('merge_field_0' => 'PHONE', 'user_field_0' => 'Phone number',
                                                       'merge_field_1' => 'GONE', 'user_field_1' => 'No such field',
                                                       'merge_field_2' => '', 'user_field_2' => 'Money')
    user = build_user
    user.custom_field_values = { @phone.id.to_s => '555-1234' }

    RedmineMailchimp::Client.any_instance.expects(:subscribe).once.with(
      'list1', 'Jane@Example.com',
      merge_fields: { 'FNAME' => 'Jane', 'LNAME' => 'Doe', 'PHONE' => '555-1234' },
      double_optin: true, update_existing: true
    )
    assert user.save, user.errors.full_messages.to_sentence
  end

  test 'unchecked options are passed as false' do
    Setting.plugin_redmine_mailchimp = @settings.except('double_optin', 'update_existing')

    RedmineMailchimp::Client.any_instance.expects(:subscribe).once.with(
      'list1', 'Jane@Example.com', has_entries(double_optin: false, update_existing: false)
    )
    assert build_user.save
  end

  test 'nothing is sent without an API key or list' do
    RedmineMailchimp::Client.any_instance.expects(:subscribe).never

    Setting.plugin_redmine_mailchimp = @settings.except('api_key')
    assert build_user.save

    Setting.plugin_redmine_mailchimp = @settings.merge('list_id' => '')
    assert build_user(login: 'jane.two', mail: 'two@example.com').save
  end

  test 'locked users are not subscribed' do
    RedmineMailchimp::Client.any_instance.expects(:subscribe).never
    assert build_user(status: User::STATUS_LOCKED).save
  end

  test 'a failing Mailchimp call does not break saving the user' do
    RedmineMailchimp::Client.any_instance.stubs(:subscribe).raises(RedmineMailchimp::Error, 'boom')
    user = build_user

    assert_nothing_raised { assert user.save }
    assert User.exists?(user.id)
  end

  test 'the user hook fires with the user on each save, even if Mailchimp is not configured' do
    Setting.plugin_redmine_mailchimp = {}
    user = build_user
    Redmine::Hook.expects(:call_hook).with(HOOK, has_entries(user: user, hook_caller: user, project: nil)).twice

    assert user.save
    user.firstname = 'Janet'
    assert user.save
  end

  test 'the user hook fires even if Mailchimp fails' do
    RedmineMailchimp::Client.any_instance.stubs(:subscribe).raises(RedmineMailchimp::Error, 'boom')
    Redmine::Hook.expects(:call_hook).with(HOOK, anything).once

    assert build_user.save
  end

  test 'a failing hook listener does not break saving the user' do
    Redmine::Hook.stubs(:call_hook).with(HOOK, anything).raises('listener failed')
    RedmineMailchimp::Client.any_instance.expects(:subscribe).once

    assert_nothing_raised { assert build_user.save }
  end
end
