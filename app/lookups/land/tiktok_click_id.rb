module Land
  class TiktokClickId < ApplicationRecord
    include TableName

    lookup_by :device, cache: 50, find_or_create: true

    has_many :attributions
  end
end
