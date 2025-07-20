module Land
  class DeviceResolution < ApplicationRecord
    include TableName

    lookup_by :device_resolution, cache: 1000, find_or_create: true

    has_many :user_agents
    has_many :devices
  end
end
