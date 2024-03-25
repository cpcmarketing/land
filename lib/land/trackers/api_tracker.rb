# frozen_string_literal: true

module Land
  module Trackers
    class ApiTracker < Tracker
      attr_reader :pageview

      def track
        load
        cookie
        record_visit
      end

      # Overriding record_visit method as we set the visit id from the API param,
      # so we have to check the Land::Visit does not exist
      def record_visit
        @visit = Visit.new
        visit.id = @visit_id
        visit.attribution   = attribution
        visit.cookie_id     = @cookie_id
        visit.referer_id    = referer&.id
        visit.user_agent_id = user_agent.id
        visit.ip_address    = remote_ip
        visit.domain_id     = request_domain&.id
        visit.raw_query_string = request.query_string
        visit.save

        @visit_id
      end

      def load
        @cookie_id = request.params['cookie_id']

        # Create a new cookie if it is not present, if it doesn't save then it already
        # exists. If the format is invalid Land::Tracker will validate
        Cookie.find_or_create_by(cookie_id: @cookie_id)

        @visit_id         = request.params['visit_id']
        @last_visit_time  = nil
        @user_agent_hash  = request.params['user_agent']
        @attribution_hash = attribution_hash
        @referer_hash     = request.params['referer']
      end

      # visit_id is an optional keyword param, when this is called from
      # the application it is used in directly the visit_id does not exist
      def record_pageview(method: nil, path: nil)
        current_time = Time.now

        @pageview = Pageview.create do |p|
          p.path = path || request.path.to_s
          p.http_method                 = method || request.method
          p.mime_type                   = request.media_type || request.format.to_s
          p.query_string                = untracked_params.to_query
          p.request_id                  = request.uuid
          p.click_id                    = tracking_params['click_id']
          p.tiktok_pixel_cookie_id      = tracking_params['tiktok_pixel_cookie_id']
          p.http_status                 = status || response.status
          p.visit_id                    = @visit_id
          p.created_at                  = current_time
          p.response_time               = (current_time - @start_time) * 1000
        end
      end

      def save
        record_pageview

        events.each do |e|
          e.pageview = pageview
          e.save!
        end
      end

      def identify(identifier)
        visit = @visit || Visit.find(@visit_id)

        owner = Owner[identifier]

        visit.owner = owner
        visit.save!

        begin
          Ownership.where(cookie_id: @cookie_id, owner_id: owner).first_or_create
        rescue ActiveRecord::RecordNotUnique
          retry
        end
      end
    end
  end
end
