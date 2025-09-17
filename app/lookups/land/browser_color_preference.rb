module Land
  class BrowserColorPreference < ApplicationRecord
    include TableName

    validates :dark_mode,
              inclusion: { in: [true, false] },
              uniqueness: {
                scope: %i[light_mode no_preference],
                message: 'combination of dark_mode, light_mode, and no_preference must be unique'
              }

    validates :light_mode,
              inclusion: { in: [true, false] },
              uniqueness: {
                scope: %i[dark_mode no_preference],
                message: 'combination of dark_mode, light_mode, and no_preference must be unique'
              }

    validates :no_preference,
              inclusion: { in: [true, false] },
              uniqueness: { scope: %i[dark_mode light_mode],
                            message: 'combination of dark_mode, light_mode, and no_preference must be unique' }
  end
end
