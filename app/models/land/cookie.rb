module Land
  class Cookie < ApplicationRecord
    include TableName

    lookup_by :cookie_id, cache: 100, find: true

    has_many :ownerships
    has_many :visits

    validates :cookie_id, presence: true, uniqueness: true
  end
end
