# frozen_string_literal: true

module RedmineMailchimp
  class Error < StandardError
    attr_reader :status, :title

    def initialize(message = nil, status: nil, title: nil)
      super(message)
      @status = status
      @title = title
    end
  end
end
