# frozen_string_literal: true

module Land
  module Trackers
    class ApiTracker < Tracker
      attr_reader :pageview

      def track
        load
        record_visit

        # Api request race conditions mean that the visit may be created on a call
        # that is not the visit call. Query strings are passed from the front end
        # visit API call. If the visit is created on a different call, the query
        # string will be updated whenever the visit API call is completed.
        maybe_set_raw_query_string
        maybe_set_unaltered_ingress_url
        maybe_set_visit_attribution
        maybe_set_visit_referer

        @visit.save if @visit.changed?
      rescue StandardError => e
        Land.config.logger.error "Error recording visit: #{e.message}"
      end

      # Overriding record_visit method as we set the visit id from the API param,
      # so we have to check the Land::Visit does not exist
      #
      def record_visit
        return @visit_id if visit

        @visit = Visit.create do |visit|
          visit.id = @visit_id
          visit.attribution   = attribution
          visit.cookie_id     = @cookie_id
          visit.referer_id    = referer&.id
          visit.user_agent_id = user_agent.id
          visit.ip_address    = remote_ip
          visit.domain_id     = request_domain&.id
          visit.raw_query_string = unescaped_query_string
        end

        @visit_id
      end

      def load
        # create cookie prior to validating
        @cookie_id = cookie_id = request.params['cookie_id']
        Cookie.create(cookie_id:) unless Cookie.where(cookie_id:).first

        @visit_id         = request.params['visit_id']
        @last_visit_time  = nil
        @user_agent_hash  = Digest::SHA2.base64digest(raw_user_agent)
        @attribution_hash = attribution_hash
        @referer_hash     = Digest::SHA2.base64digest(referer_uri.to_s)
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

      # Overriding user agent as it is set via params and not header in the API
      def user_agent
        return @user_agent if @user_agent

        user_agent = request.params['user_agent']
        user_agent = Land.config.blank_user_agent_string if user_agent.blank?

        @user_agent = UserAgent[user_agent]
      end

      def raw_user_agent
        request.params['user_agent'] || Land.config.blank_user_agent_string
      end

      # Overriding referer URI to pull from passed params in the API
      def referer_uri
        return unless request.params['referer'].present?

        @referer_uri ||= Addressable::URI.parse(request.params['referer'].sub(/\Awww\./i, '//\0'))
      end

      def maybe_set_visit_attribution
        return unless attribution? || attribution_values_present?(visit)

        @visit.attribution = attribution
      end

      def maybe_set_raw_query_string
        return unless request.query_string.present?

        @visit.raw_query_string = unescaped_query_string
      end

      def maybe_set_visit_referer
        return unless referer_uri.present? || @visit.referer.present?

        @visit.referer = referer
      end

      def maybe_set_unaltered_ingress_url
        return unless @visit.unaltered_ingress_url.blank? && request.params['unaltered_ingress_url'].present?

        @visit.unaltered_ingress_url = request.params['unaltered_ingress_url']
      end

      def attribution_values_present?(visit)
        visit.attribution
             .attributes
             .reject { |k, _v| %w[attribution_id created_at].include?(k) }
             .values
             .any?
      end

      def unescaped_query_string
        CGI.unescape(request.query_string)
      end

      def visit
        @visit ||= Land::Visit.where(visit_id: @visit_id).first
      end

      def new_visit?
        @visit.nil?
      end
    end
  end
end
