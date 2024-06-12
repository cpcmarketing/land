# frozen_string_literal: true

require "digest/sha2"
require "uri"
require "addressable/uri"

module Land
  class Tracker
    # About ValueTrack parameters
    # https://support.google.com/google-ads/answer/2375447?hl=en&ref_topic=6031980
    #
    # Set up tracking with ValueTrack parameters
    # https://support.google.com/google-ads/answer/6305348?hl=en
    #
    # iOS Campaign Tracker
    # https://developers.google.com/analytics/devguides/collection/ios/v3/campaigns#url-builder

    # @todo Cake: SUB ID => s1, s2, s3, s4, s5?
    # https://www.affluent.io/blog/affiliate-sub-campaign-sid-tracking-guide/
    #
    # https://strackr.com/subid
    TRACKING_PARAMS = {
      'ad_group'               => %w[ad_group adgroup adset_name ovadgrpid ysmadgrpid],
      'ad_type'                => %w[ad_type adtype],
      'affiliate'              => %w[affiliate aff affid],
      'app'                    => %w[aid],
      'bid_match_type'         => %w[bidmatchtype bid_match_type bmt],
      'brand'                  => %w[brand brand_name],
      'campaign'               => %w[campaign campaign_name utm_campaign ovcampgid ysmcampgid cn],
      'campaign_identifier'    => %w[campaign_identifier campaignidentifier campaignid campaign_id cid utm_campaign_id],
      'click_id'               => %w[click_id clickid dclid fbclid gclid gclsrc msclkid zanpid ttclid],
      'content'                => %w[content ad_name utm_content cc],
      'content_identifier'     => %w[content_identifier contentidentifier contentid content_id cntid utm_content_id],
      'creative'               => %w[creative adid ovadid],
      'device_type'            => %w[device_type devicetype device],
      'experiment'             => %w[experiment aceid],
      'keyword'                => %w[keyword kw utm_term ovkey ysmkey],
      'match_type'             => %w[match_type matchtype match ovmtc ysmmtc],
      'medium'                 => %w[medium utm_medium cm],
      'medium_identifier'      => %w[medium_identifier mediumidentifier mediumid medium_id mid utm_medium_id],
      'network'                => %w[network anid],
      'placement'              => %w[placement],
      'position'               => %w[position adposition ad_position],
      'search_term'            => %w[search_term searchterm q querystring ovraw ysmraw],
      'source'                 => %w[source utm_source cs],
      'subsource'              => %w[subsource subid sid effi_id customid afftrack pubref argsite fobs epi ws u1],
      'target'                 => %w[target],
      'tiktok_pixel_cookie_id' => %w[ttp]
    }.freeze

    TRACKING_KEYS    = TRACKING_PARAMS.values.flatten.freeze
    ATTRIBUTION_KEYS = TRACKING_PARAMS.except('click_id', 'tiktok_pixel_cookie_id').keys

    TRACKING_PARAMS_TRANSFORM = {
      'ad_type'        => { 'pe'  => 'product_extensions',
                            'pla' => 'product_listing' },

      'bid_match_type' => { 'bb'  => 'bidded broad',
                            'bc'  => 'bidded content',
                            'be'  => 'bidded exact',
                            'bp'  => 'bidded phrase' },

      'device_type'    => { 'c'   => 'computer',
                            'm'   => 'mobile',
                            't'   => 'tablet' },

      'match_type'     => { 'b'   => 'broad',
                            'c'   => 'content',
                            'e'   => 'exact',
                            'p'   => 'phrase',
                            'std' => 'standard',
                            'adv' => 'advanced',
                            'cnt' => 'content' },

      'network'        => { 'g'   => 'google_search',
                            's'   => 'search_partner',
                            'd'   => 'display_network' },

      'source'         => { 'fb'  => 'facebook',
                            'ig'  => 'instagram',
                            'msg' => 'messenger',
                            'an'  => 'audience network' }
    }.freeze

    TRACKED_PARAMS = TRACKING_PARAMS.values.flatten.freeze

    UUID_REGEX       = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\Z/
    UUID_REGEX_V4    = /\A\h{8}-\h{4}-4\h{3}-[89aAbB]\h{3}-\h{12}\Z/

    # Compact the session by shortening names
    KEYS = {
      visit_id:         'vid',
      visit_time:       'vt',
      user_agent_hash:  'uh',
      attribution_hash: 'ah',
      referer_hash:     'rh'
    }.freeze

    attr_accessor :status

    attr_reader :controller, :events, :visit

    delegate :request, :response, :session, to: :controller
    delegate :headers, :path, :query_parameters, :referer, :remote_ip, to: :request

    class << self
      def for(controller)
        type = Land::UserAgent[controller.request.user_agent].try(:user_agent_type)
        type = 'noop' unless Land.config.enabled
        type = 'user' if type.nil?

        # override
        type = 'user' if controller.request.query_parameters.with_indifferent_access.slice(*TRACKING_KEYS).any?

        # match on versioned APIs, which serve the frontend
        type = 'api' if controller.request.path =~ %r{^/api/v}

        "Land::Trackers::#{type.classify}Tracker".constantize.new(controller)
      end
    end

    def initialize(controller)
      # Allow subclasses to super from initialize
      raise NotImplementedError, 'You must subclass Land::Tracker' if self.class == Tracker

      @controller = controller
      @events     = []
      @start_time = Time.now
      @status     = nil
    end

    def queue_event(type, meta = {})
      return unless tracking?

      Event.new(visit_id: @visit_id, event_type: type, meta: meta, request_id: request.uuid).tap do |event|
        @events << event
      end
    end

    def track
      fail NotImplementedError, "You must subclass Land::Tracker" if self.class == Tracker
    end

    protected

    def cookies
      request.cookie_jar
    end

    def cookie
      validate_cookie
      @cookie_id ||= Cookie.create.id
      set_cookie
    end

    def validate_cookie
      return unless @cookie_id
      return if @cookie_id =~ UUID_REGEX_V4 && Cookie[@cookie_id]

      # Invalid cookie
      @cookie_id = nil
      @visit_id  = nil
    end

    def set_cookie
      cookies.permanent[:land] = cookie_defaults.merge(value: @cookie_id)
    end

    def cookie_defaults
      { domain: :all, secure: Land.config.secure_cookie, httponly: true }
    end

    def referer
      return @referer if @referer
      return unless referer_uri

      params      = Rack::Utils.parse_query referer_uri.query
      attribution = Attribution.lookup params.slice(*ATTRIBUTION_KEYS)
      query       = params.except(*ATTRIBUTION_KEYS)

      begin
        @referer = Referer.where(domain_id:       Domain[referer_uri.host.to_s],
                                 path_id:         Path[referer_path],
                                 query_string_id: QueryString[query.to_query],
                                 attribution_id:  attribution.id).first_or_create
      rescue ActiveRecord::RecordNotUnique
        retry
      end
    end

    def referer_changed?
      external_referer? && referer_hash != @referer_hash
    end

    def referer_path
      referer_uri.path.present? ? referer_uri.path : '/'
    end

    def referer_uri
      @referer_uri ||= Addressable::URI.parse(request.referer.sub(/\Awww\./i, '//\0')) if request.referer.present?
    end

    def attribution
      @attribution ||= Attribution.lookup attribution_params
    end

    def attribution_changed?
      attribution? && attribution_hash != @attribution_hash
    end

    def attribution_hash
      Attribution.digest attribution_params
    end

    def user_agent
      return @user_agent if @user_agent

      user_agent = request.user_agent
      user_agent = Land.config.blank_user_agent_string if user_agent.blank?

      @user_agent = UserAgent[user_agent]
    end

    def user_agent_hash
      Digest::SHA2.base64digest user_agent.user_agent
    end

    def user_agent_changed?
      user_agent_hash != @user_agent_hash
    end

    def referer_hash
      Digest::SHA2.base64digest request.referer
    end

    def attribution?
      attribution_params.any?
    end

    def record_visit
      create_visit if new_visit?
    end

    def create_visit
      @visit = Visit.new
      visit.attribution   = attribution
      visit.cookie_id     = @cookie_id
      visit.referer_id    = referer&.id
      visit.user_agent_id = user_agent.id
      visit.ip_address    = remote_ip
      visit.domain_id     = request_domain&.id
      visit.raw_query_string = request.query_string
      visit.save!

      @visit_id = @visit.id
    end

    def request_domain
      Domain[request.host]
    end

    def new_visit?
      Rails.logger.debug "New visit reasons: #{Land.config.new_visit_reasons}"

      @visit_id.nil? || Land.config.new_visit_reasons.map{ |reason| send(reason.to_sym) }.any?
    end

    def external_referer?
      referer_uri && referer_uri.host != request.host
    end

    def extract_tracking(params)
      hash = {}

      TRACKING_PARAMS.each do |key, names|
        param = names.find { |name| params.key?(name) }
        next unless param
        hash[key] = params[param]
      end

      TRACKING_PARAMS_TRANSFORM.each do |key, transform|
        next unless hash.key? key
        hash[key] = transform[hash[key]] if transform.key? hash[key]
      end

      hash
    end

    def attribution_params
      @attribution_params ||= tracking_params.with_indifferent_access.slice(*ATTRIBUTION_KEYS)
    end

    def query_params
      @query_params ||= request.query_parameters.with_indifferent_access
    end

    def tracking?
      !!@visit_id
    end

    def tracking_params
      @tracking_params ||= extract_tracking(query_params)
    end

    def untracked_params
      query_params.except(*TRACKED_PARAMS)
    end

    def visit_stale?
      return false unless @last_visit_time

      Rails.logger.debug "Last visit time: #{@last_visit_time}"
      Time.current - @last_visit_time > Land.config.visit_timeout
    end
  end
end
