module Land
  class UserAgent < ApplicationRecord
    include TableName

    self.record_timestamps = false

    lookup_by :user_agent, cache: 50, find_or_create: true

    lookup_for :user_agent_type,   class_name: UserAgentType
    lookup_for :device,            class_name: Device
    lookup_for :platform,          class_name: Platform
    lookup_for :browser,           class_name: Browser
    lookup_for :device_resolution, class_name: DeviceResolution

    has_many :visits
  end
end
