# frozen_string_literal: true

module Land
  module Trackers
    class ApiTracker < Tracker
      attr_reader :pageview

      VISIT_ENDPOINT_REGEX = %r{^/api/v\d+/visit$}
      PAGEVIEW_ENDPOINT_REGEX = %r{^/api/v\d+/tracking/page-view$}

      # before_action Methods ---------------------------------
      def track
        load
        record_visit
      rescue StandardError => e
        # Here we are going to tag the span with the error if Datadog span
        # exists This is called safely to avoid errors in the case that Datadog
        # is not present
        log_error(e)
        Land.config.logger.error "Error recording visit: #{e.message}"
      end

      def load
        last_visit = @last_visit ||= Land::Visit.where(cookie_id: @cookie)
                                                .order(created_at: :desc)
                                                .first

        @cookie_id        = request.params['cookie_id']
        @visit_id         = request.params['visit_id']
        @last_visit_time  = last_visit&.created_at
        @user_agent_hash  = Digest::SHA2.base64digest(raw_user_agent) if raw_user_agent
        @attribution_hash = attribution_hash
        @referer_hash     = Digest::SHA2.base64digest(referer_uri.to_s)

        begin
          Cookie.find_or_create_by(cookie_id: @cookie_id)
        rescue ActiveRecord::RecordNotUnique
          retry
        end
      end

      # Overriding record_visit method as we set the visit id from the API param,
      # so we have to check the Land::Visit does not exist
      def record_visit
        Visit.transaction do
          @visit = Visit.find_or_initialize_by(visit_id: @visit_id) do |visit|
            visit.attribution      = attribution
            visit.cookie_id        = @cookie_id
            visit.referer_id       = referer&.id
            visit.user_agent_id    = user_agent&.id
            visit.ip_address       = remote_ip
            visit.domain_id        = request_domain&.id
            visit.raw_query_string = referer_uri&.query
            visit.click_id         = tracking_params['click_id']
          end

          # Api request race conditions mean that the visit may be created on a call
          # that is not the visit call. Query strings are passed from the front end
          # visit API call. If the visit is created on a different call, the query
          # string will be updated whenever the visit API call is completed.

          # Here we only invoke the visit attribution update if the request is a
          # visit API call
          if controller.request.path =~ VISIT_ENDPOINT_REGEX
            maybe_set_raw_query_string
            maybe_set_unaltered_ingress_url
            maybe_set_visit_attribution
            maybe_set_visit_referer
            maybe_set_user_agent
            maybe_set_click_id
          end

          # When bots click links, we do not get cookies loaded, so no visit call is made
          # This will set attribution if there is no visit call made
          maybe_set_visit_attribution_from_pageview if controller.request.path =~ PAGEVIEW_ENDPOINT_REGEX

          @visit&.save! if @visit&.changed?
        rescue ActiveRecord::RecordNotUnique
          retry
        end

        @visit.visit_id
      end

      def maybe_set_raw_query_string
        return unless referer_uri.present? || @visit.raw_query_string.blank?

        @visit.raw_query_string = referer_uri.query
      end

      def maybe_set_unaltered_ingress_url
        return unless @visit.unaltered_ingress_url.blank? && unaltered_ingress_url.present?

        @visit.unaltered_ingress_url = unaltered_ingress_url
      end

      def maybe_set_visit_attribution
        return unless attribution? || attribution_values_present?

        @visit.attribution = attribution
      end

      def maybe_set_visit_referer
        return unless referer_uri.present? || @visit.referer.present?

        @visit.referer_id = referer.id
      end

      def maybe_set_user_agent
        return unless user_agent && @visit.user_agent.user_agent == Land.config.blank_user_agent_string

        @visit.user_agent_id = user_agent.id
      end

      def maybe_set_click_id
        return unless tracking_params['click_id'].present? && @visit.click_id.blank?

        @visit.click_id = tracking_params['click_id']
      end

      def maybe_set_visit_attribution_from_pageview
        return unless visit_attribution_empty? && page_view_query_string.present?

        params = Rack::Utils.parse_nested_query(page_view_query_string)
        @visit.attribution = Attribution.lookup extract_tracking(params)
      end

      # after_action Methods ---------------------------------
      # This is invoked from Land::Action
      def save
        record_pageview

        events.each do |e|
          e.pageview = pageview
          e.save!
        end
      end

      def record_pageview(method: nil, path: nil)
        current_time = Time.now

        @pageview = Pageview.create do |p|
          p.path                   = path || request.path.to_s
          p.http_method            = method || request.method
          p.mime_type              = request.media_type || request.format.to_s
          p.query_string           = untracked_params.to_query
          p.request_id             = request.uuid
          p.click_id               = tracking_params['click_id']
          p.tiktok_pixel_cookie_id = tracking_params['tiktok_pixel_cookie_id']
          p.http_status            = status || response.status
          p.visit_id               = @visit.id
          p.created_at             = current_time
          p.response_time          = (current_time - @start_time) * 1000
        end
      end

      # Attribution Methods ---------------------------------
      def attribution_values_present?
        @visit.attribution
              .attributes
              .reject { |k, _v| %w[attribution_id created_at].include?(k) }
              .values
              .any?
      end

      def visit_attribution_empty? = !attribution_values_present?

      # Access Methods --------------------------------------------
      def new_visit? = @visit.nil?

      def page_view_query_string
        request && request.params['page_view_query_string']
      end

      def page_view_path
        request && request.params['page_view_path']
      end

      def device_width
        request && request.params.dig('device_resolution', 'width')
      end

      def device_height
        request && request.params.dig('device_resolution', 'height')
      end

      def device_resolution
        return nil unless request && request.params['device_resolution']

        "#{device_width}x#{device_height}"
      end

      def device_orientation
        request && request.params.dig('device_resolution', 'orientation')
      end

      def dark_mode
        request && request.params.dig('color_scheme_preference', 'is_dark_mode')
      end

      def light_mode
        request && request.params.dig('color_scheme_preference', 'is_light_mode')
      end

      def no_preference
        request && request.params.dig('color_scheme_preference', 'is_no_preference')
      end

      def raw_user_agent
        @raw_user_agent ||= request.params['user_agent'] || Land.config.blank_user_agent_string
      end

      def referer_uri
        return @referer_uri if @referer_uri
        return unless unaltered_ingress_url.present?

        @referer_uri ||= Addressable::URI.parse(unaltered_ingress_url.sub(/\Awww\./i, '//\0'))
      end

      def unaltered_ingress_url
        @unaltered_ingress_url ||= request.params['unaltered_ingress_url']
      end

      # Overriding Tracker#user_agent as it is set via params and not header in the API
      def user_agent
        return @user_agent if @user_agent

        user_agent = request.params['user_agent'] ||
                     Land.config.blank_user_agent_string

        @user_agent = UserAgent[user_agent]
        @user_agent.user_agent_type = UserAgentType['user']

        if Land.config.identify_crawlers && defined?(CrawlerDetect)
          crawler_detect = CrawlerDetect.new(user_agent)
          @user_agent.user_agent_type = UserAgentType['crawl'] if crawler_detect.is_crawler?
        end

        browser = ::Browser.new(user_agent)

        update_device_resolution
        update_browser_color_preferences(Browser[browser.name])

        @user_agent.browser = Browser[browser.name]
        @user_agent.device = Device[browser.device.name]
        @user_agent.platform = Platform[browser.platform.name]
        @user_agent.browser_version = browser.version
        @user_agent.device_resolution = DeviceResolution[device_resolution]

        if @user_agent.changed? && !@user_agent.save
          error = @user_agent.errors.full_messages.join(', ')
          log_error(error)
        end

        @user_agent
      end

      def update_device_resolution
        resolution = DeviceResolution[device_resolution]
        return unless resolution.persisted?

        resolution.width = device_width
        resolution.height = device_height
        resolution.orientation = device_orientation
        resolution.save if resolution.changed?
      rescue StandardError => e
        log_error("Error updating device resolution: #{e.message}")
      end

      def update_browser_color_preferences(browser)
        return unless browser

        browser.dark_mode = dark_mode
        browser.light_mode = light_mode
        browser.no_preference = no_preference

        browser.save if browser.changed?
      rescue StandardError => e
        log_error("Error updating browser color preferences: #{e.message}")
      end

      def log_error(error)
        if defined?(Datadog::Tracing) && Datadog::Tracing.respond_to?(:active_span)
          Datadog::Tracing.active_span&.set_error(error)
        end
        Land.config.logger.error "Land::Trackers::ApiTracker Error: #{error}"
      end
    end
  end
end
