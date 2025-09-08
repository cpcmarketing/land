module Land
  class BrowserColorPreference < ApplicationRecord
    include TableName

    validates :dark_mode, inclusion: { in: [true, false] }, uniqueness: true
    validates :light_mode, inclusion: { in: [true, false] }, uniqueness: true
    validates :no_preference, inclusion: { in: [true, false] }, uniqueness: true
  end
end
