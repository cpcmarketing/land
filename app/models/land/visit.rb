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

    before_save do
      tracker_class = caller.find{ |l| l.include?("Tracker") }&.split(' ')&.last&.split('#')&.first
      # Attempt to add metadata to the active Datadog span if it exists.
      Datadog::Tracing.active_span&.set_tag('visit_save', tracker_class:) if defined?(Datadog::Tracing) && Datadog::Tracing.respond_to?(:active_span)
    rescue StandardError => e
      # Rescue everything to avoid breaking the save.
      nil
    end

    after_initialize do
      self.id ||= SecureRandom.uuid
    end
  end
end
