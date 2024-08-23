module Land
  class Visit < ApplicationRecord
    include TableName

    belongs_to :attribution
    belongs_to :cookie
    belongs_to :user_agent
    belongs_to :domain
    belongs_to :referer, optional: true

    lookup_for :owner, class_name: Owner

    has_many :pageviews, dependent: :destroy

    validates :visit_id, presence: true, uniqueness: true

    after_initialize do
      self.id ||= SecureRandom.uuid
    end
  end
end
