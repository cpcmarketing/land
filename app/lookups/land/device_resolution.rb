module Land
  class DeviceResolution < ApplicationRecord
    include TableName

    validates :width, presence: true
    validates :height, presence: true
    validates :orientation, presence: true
  end
end
