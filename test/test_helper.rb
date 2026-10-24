# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

# Built at runtime so no literal key-shaped string is committed (it trips secret scanners)
MAILCHIMP_TEST_API_KEY = "#{'0' * 32}-us12"
