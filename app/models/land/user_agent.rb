module Land
  class UserAgent < ApplicationRecord
    include TableName

    self.record_timestamps = false

    lookup_by :user_agent, cache: 50, find_or_create: true

    lookup_for :user_agent_type, class_name: UserAgentType
    lookup_for :device,          class_name: Device
    lookup_for :platform,        class_name: Platform
    lookup_for :browser,         class_name: Browser

    has_many :visits

    belongs_to :browser, optional: true
    belongs_to :device_resolution, optional: true
    belongs_to :browser_color_preference, optional: true

    accepts_nested_attributes_for :browser
    accepts_nested_attributes_for :browser_color_preference
    accepts_nested_attributes_for :device_resolution
  end
end
