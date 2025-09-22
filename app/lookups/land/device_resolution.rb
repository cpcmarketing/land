module Land
  class DeviceResolution < ApplicationRecord
    include TableName

    has_many :user_agent

    validates :width, presence: true
    validates :height, presence: true
    validates :orientation, presence: true
  end
end
