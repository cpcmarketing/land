
module Land
  class TiktokPixelCookieId < ApplicationRecord
    include TableName

    lookup_by :device, cache: 50, find_or_create: true

    has_many :attributions
  end
end
