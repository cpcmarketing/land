module Land
  class BrowserColorPreference < ApplicationRecord
    include TableName

    validates :dark_mode, presence: true, uniqueness: true
    validates :light_mode, presence: true, uniqueness: true
    validates :no_preference, presence: true, uniqueness: true
  end
end