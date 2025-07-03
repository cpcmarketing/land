# frozen_string_literal: true

require 'rails_helper'

class ApiTrackerTestController < ActionController::Base
  def call
    render json: { message: 'success' }, status: :ok
  end
end

RSpec.describe 'Land::Trackers::ApiTracker', type: :request do
  before do
    Rails.application.routes.draw do
      get '/api/v1/test', to: 'api_tracker_test#call'
      post '/api/v1/visit', to: 'api_tracker_test#call'
      post '/api/v1/tracking/page-view', to: 'api_tracker_test#call'
    end
  end

  after do
    Rails.application.reload_routes!
  end

  let!(:user_agent) do
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36'
  end

  let(:utm_source)      { 'ig' }
  let(:utm_medium)      { '_11106_Male_Core_Veterans4x5VDAUpdate_Mar0424_TargetCost_20K' }
  let(:utm_medium_id)   { '120206883976350579' }
  let(:utm_campaign)    { 'BillDoctor_ConsolidatedCBO_Core_LowerPayments_NoFlag' }
  let(:utm_campaign_id) { '120203346515640579' }
  let(:utm_content)     do
    '_Static_Veteran_PaycheckToPaycheck_WheelchairVeteranTan4x5_Illustrated_$200K_EnrollByFriday_Ashley'
  end
  let(:utm_content_id) { '120206884079300579' }
  let(:fbclid) do
    'PAAaZn5-5j2fsK-f7fngjG3bcj73pqu4mc6yed7xisPhOidelBkH43nIDRQqY_aem_AWy4nQaSADAesMyYqJ4hh-AySwAQlr5eAd6hfvoBGI3q25heofLIl4xvpAFjsL3IyU5thu52N4iWCEtRNVF6_EpH'
  end

  let(:untracked_query_param) { 'its-untracked' }

  let(:query_string) do
    URI.encode_www_form(
      {
        utm_source:,
        utm_medium:,
        utm_medium_id:,
        utm_campaign:,
        utm_campaign_id:,
        utm_content:,
        utm_content_id:,
        fbclid:,
        untracked_query_param:
      }
    )
  end

  let!(:unaltered_ingress_url) { "https://veterandebtassistance.org/social?#{query_string}" }

  let!(:body) do
    {
      cookie_id:,
      visit_id:,
      referer: unaltered_ingress_url,
      user_agent:,
      unaltered_ingress_url:
    }
  end

  context 'when the request is successful and /api/v1/visit is the first request' do
    let(:cookie_id) { SecureRandom.uuid }
    let(:visit_id) { SecureRandom.uuid }

    before do
      post "/api/v1/visit?#{query_string}", params: body,
                                            as: :json
    end

    it 'creates the expected records' do
      expect(Land::Visit.where(cookie_id:).count).to eq(1)

      visit = Land::Visit.find_by(visit_id:)

      expect(visit.cookie_id).to eq(cookie_id)
      expect(visit.visit_id).to eq(visit_id)
      expect(visit.referer.domain).to eq('veterandebtassistance.org')
      expect(visit.user_agent.user_agent).to eq(user_agent)
      expect(visit.user_agent.device).to eq('Unknown')
      expect(visit.user_agent.platform).to eq('Windows')
      expect(visit.user_agent.browser).to eq('Chrome')
      expect(visit.user_agent.browser_version).to eq('98')

      expect(visit.unaltered_ingress_url).to eq(unaltered_ingress_url)
      expect(visit.raw_query_string).to eq(query_string)
      expect(visit.click_id).to eq(fbclid)
      expect(visit.attribution).to_not be_nil

      expect(visit.attribution.campaign).to eq(utm_campaign)
      expect(visit.attribution.content).to eq(utm_content)
      expect(visit.attribution.medium).to eq(utm_medium)
      expect(visit.attribution.source).to eq('instagram')
      expect(visit.attribution.campaign_identifier).to eq(utm_campaign_id)
      expect(visit.attribution.medium_identifier).to eq(utm_medium_id)
      expect(visit.attribution.content_identifier).to eq(utm_content_id)

      expect(Land::Pageview.count).to eq(1)
      pageview = Land::Pageview.find_by(visit_id:)

      expect(pageview.visit_id).to eq(visit_id)
      expect(pageview.path).to eq('/api/v1/visit')
      expect(pageview.query_string).to eq('untracked_query_param=its-untracked')
      expect(pageview.mime_type).to eq('application/json')
      expect(pageview.http_method).to eq('POST')
      expect(pageview.click_id).to eq(fbclid)
      expect(pageview.http_status).to eq(200)
      expect(pageview.tiktok_pixel_cookie_id).to eq(nil)
    end
  end

  context 'when the request is successful and /api/v1/visit is the second request' do
    let(:cookie_id) { SecureRandom.uuid }
    let(:visit_id) { SecureRandom.uuid }

    before do
    end

    it 'creates the expected records' do
      # first call not visit
      get "/api/v1/test?cookie_id=#{cookie_id}&visit_id=#{visit_id}&location_id=0", params: { cookie_id:, visit_id: },
                                                                                    as: :json

      expect(Land::Visit.where(cookie_id:).count).to eq(1)

      visit = Land::Visit.find_by(visit_id:)

      expect(visit.cookie_id).to eq(cookie_id)
      expect(visit.visit_id).to eq(visit_id)
      expect(visit.referer).to eq(nil)
      expect(visit.user_agent.user_agent).to eq('user agent missing')
      expect(visit.user_agent.device).to eq('Unknown')
      expect(visit.user_agent.platform).to eq('Other')
      expect(visit.user_agent.browser).to eq('Generic Browser')
      expect(visit.user_agent.browser_version).to eq('0')

      expect(visit.unaltered_ingress_url).to eq(nil)
      expect(visit.raw_query_string).to eq(nil)
      expect(visit.click_id).to eq(nil)
      expect(visit.attribution).to_not be_nil

      expect(visit.attribution.campaign).to eq(nil)
      expect(visit.attribution.content).to eq(nil)
      expect(visit.attribution.medium).to eq(nil)
      expect(visit.attribution.source).to eq(nil)
      expect(visit.attribution.campaign_identifier).to eq(nil)
      expect(visit.attribution.medium_identifier).to eq(nil)
      expect(visit.attribution.content_identifier).to eq(nil)

      expect(Land::Pageview.where(visit_id:).count).to eq(1)
      pageview = Land::Pageview.find_by(visit_id:)

      expect(pageview.visit_id).to eq(visit_id)
      expect(pageview.path).to eq('/api/v1/test')
      expect(pageview.raw_query_string.query_string).to eq("cookie_id=#{cookie_id}&location_id=0&visit_id=#{visit_id}")
      expect(pageview.mime_type).to eq('application/json')
      expect(pageview.http_method).to eq('POST')
      expect(pageview.click_id).to eq(nil)
      expect(pageview.http_status).to eq(200)
      expect(pageview.tiktok_pixel_cookie_id).to eq(nil)

      # visit call
      post "/api/v1/visit?#{query_string}", params: body,
                                            as: :json

      expect(Land::Visit.where(cookie_id:).count).to eq(1)

      visit.reload

      expect(visit.cookie_id).to eq(cookie_id)
      expect(visit.visit_id).to eq(visit_id)
      expect(visit.referer.domain).to eq('veterandebtassistance.org')
      expect(visit.user_agent.user_agent).to eq(user_agent)
      expect(visit.user_agent.device).to eq('Unknown')
      expect(visit.user_agent.platform).to eq('Windows')
      expect(visit.user_agent.browser).to eq('Chrome')
      expect(visit.user_agent.browser_version).to eq('98')

      expect(visit.unaltered_ingress_url).to eq(unaltered_ingress_url)
      expect(visit.raw_query_string).to eq(query_string)
      expect(visit.click_id).to eq(fbclid)
      expect(visit.attribution).to_not be_nil

      expect(visit.attribution.campaign).to eq(utm_campaign)
      expect(visit.attribution.content).to eq(utm_content)
      expect(visit.attribution.medium).to eq(utm_medium)
      expect(visit.attribution.source).to eq('instagram')
      expect(visit.attribution.campaign_identifier).to eq(utm_campaign_id)
      expect(visit.attribution.medium_identifier).to eq(utm_medium_id)
      expect(visit.attribution.content_identifier).to eq(utm_content_id)

      expect(Land::Pageview.where(visit_id:).count).to eq(2)
      pageview = Land::Pageview.order(created_at: :desc).first

      expect(pageview.visit_id).to eq(visit_id)
      expect(pageview.path).to eq('/api/v1/visit')
      expect(pageview.query_string).to eq('untracked_query_param=its-untracked')
      expect(pageview.mime_type).to eq('application/json')
      expect(pageview.http_method).to eq('POST')
      expect(pageview.click_id).to eq(fbclid)
      expect(pageview.http_status).to eq(200)
      expect(pageview.tiktok_pixel_cookie_id).to eq(nil)
    end
  end

  context 'when the request is successful and /api/v1/visit is the second request, simulating a race condition' do
    let(:cookie_id) { SecureRandom.uuid }
    let(:visit_id) { SecureRandom.uuid }

    it 'record visit does not throw an error' do
      allow(Land::Visit).to receive(:create)
        .and_raise(ActiveRecord::RecordNotUnique, 'Visit already exists')

      # this is asserting that the `record_visit` call does not throw an error,
      # as this method that is called after the `record_visit` call
      expect_any_instance_of(Land::Trackers::ApiTracker)
        .to receive(:maybe_set_raw_query_string).and_call_original

      # visit call
      post "/api/v1/visit?#{query_string}", params: body,
                                            as: :json
    end

    it 'load does not throw error on cookie race condition' do
      allow(Land::Cookie)
        .to receive_message_chain(:where, :first_or_create)
        .and_raise(ActiveRecord::RecordNotUnique, 'Cookie already exists')
        .and_return([])

      # this is asserting that the `load` call does not throw an error,
      # as this method that is called after the `load` call
      expect_any_instance_of(Land::Trackers::ApiTracker)
        .to receive(:record_visit)
        .and_call_original

      # visit call
      post "/api/v1/visit?#{query_string}", params: body,
                                            as: :json
    end
  end

  context 'pageview arrives first' do
    let(:cookie_id) { SecureRandom.uuid }
    let(:visit_id) { SecureRandom.uuid }

    it 'the attribution is parsed' do
      post '/api/v1/tracking/page-view', params: {
                                           cookie_id:,
                                           visit_id:,
                                           page_view_path: 'http://thedebtfreenurse.com/the-debt-free-nurse',
                                           page_view_query_string: query_string,
                                           page_view_mime_type: 'text/html',
                                           page_view_http_method: 'GET',
                                           page_view_http_status: '200'
                                         },
                                         as: :json

      expect(Land::Visit.where(cookie_id:).count).to eq(1)

      visit = Land::Visit.find_by(visit_id:)

      expect(visit.click_id).to eq(nil)
      expect(visit.raw_query_string).to eq(nil)
      expect(visit.referer).to eq(nil)
      expect(visit.unaltered_ingress_url).to eq(nil)

      expect(visit.cookie_id).to eq(cookie_id)
      expect(visit.visit_id).to eq(visit_id)
      expect(visit.user_agent.user_agent).to eq('user agent missing')
      expect(visit.user_agent.device).to eq('Unknown')
      expect(visit.user_agent.platform).to eq('Other')
      expect(visit.user_agent.browser).to eq('Generic Browser')
      expect(visit.user_agent.browser_version).to eq('0')

      expect(visit.attribution).to_not be_nil
      expect(visit.attribution.campaign).to eq(utm_campaign)
      expect(visit.attribution.content).to eq(utm_content)
      expect(visit.attribution.medium).to eq(utm_medium)
      expect(visit.attribution.source).to eq('instagram')
      expect(visit.attribution.campaign_identifier).to eq(utm_campaign_id)
      expect(visit.attribution.medium_identifier).to eq(utm_medium_id)
      expect(visit.attribution.content_identifier).to eq(utm_content_id)
    end

    context 'and a visit arrives after' do
      before(:each) do
        post '/api/v1/tracking/page-view', params: {
                                             cookie_id:,
                                             visit_id:,
                                             page_view_path: 'http://thedebtfreenurse.com/the-debt-free-nurse',
                                             page_view_query_string: query_string,
                                             page_view_mime_type: 'text/html',
                                             page_view_http_method: 'GET',
                                             page_view_http_status: '200'
                                           },
                                           as: :json
      end

      it 'updates attribution as expected' do
        post "/api/v1/visit?#{query_string}", params: body,
                                              as: :json

        expect(Land::Visit.where(cookie_id:).count).to eq(1)

        visit = Land::Visit.find_by(visit_id:)

        expect(visit.cookie_id).to eq(cookie_id)
        expect(visit.visit_id).to eq(visit_id)
        expect(visit.referer.domain).to eq('veterandebtassistance.org')
        expect(visit.user_agent.user_agent).to eq(user_agent)
        expect(visit.user_agent.device).to eq('Unknown')
        expect(visit.user_agent.platform).to eq('Windows')
        expect(visit.user_agent.browser).to eq('Chrome')
        expect(visit.user_agent.browser_version).to eq('98')

        expect(visit.unaltered_ingress_url).to eq(unaltered_ingress_url)
        expect(visit.raw_query_string).to eq(query_string)
        expect(visit.click_id).to eq(fbclid)
        expect(visit.attribution).to_not be_nil

        expect(visit.attribution.campaign).to eq(utm_campaign)
        expect(visit.attribution.content).to eq(utm_content)
        expect(visit.attribution.medium).to eq(utm_medium)
        expect(visit.attribution.source).to eq('instagram')
        expect(visit.attribution.campaign_identifier).to eq(utm_campaign_id)
        expect(visit.attribution.medium_identifier).to eq(utm_medium_id)
        expect(visit.attribution.content_identifier).to eq(utm_content_id)
      end
    end
  end

  context 'unit tests' do
    let(:cookie_id) { SecureRandom.uuid }
    let(:visit_id) { SecureRandom.uuid }

    describe 'VISIT_ENDPOINT_REGEX' do
      it 'matches the correct endpoint' do
        expect(Land::Trackers::ApiTracker::VISIT_ENDPOINT_REGEX).to be_a(Regexp)
        expect(Land::Trackers::ApiTracker::VISIT_ENDPOINT_REGEX).to match('/api/v1/visit')
        expect(Land::Trackers::ApiTracker::VISIT_ENDPOINT_REGEX).to match('/api/v1121/visit')
        expect(Land::Trackers::ApiTracker::VISIT_ENDPOINT_REGEX).to_not match('/api/v1/visitX')
        expect(Land::Trackers::ApiTracker::VISIT_ENDPOINT_REGEX).to_not match('/apii/v1/visit')
      end
    end

    describe 'PAGEVIEW_ENDPOINT_REGEX' do
      it 'matches the correct endpoint' do
        expect(Land::Trackers::ApiTracker::PAGEVIEW_ENDPOINT_REGEX).to be_a(Regexp)
        expect(Land::Trackers::ApiTracker::PAGEVIEW_ENDPOINT_REGEX).to match('/api/v1/tracking/page-view')
        expect(Land::Trackers::ApiTracker::PAGEVIEW_ENDPOINT_REGEX).to match('/api/v1121/tracking/page-view')
        expect(Land::Trackers::ApiTracker::PAGEVIEW_ENDPOINT_REGEX).to_not match('/api/v1/tracking/page-viewX')
        expect(Land::Trackers::ApiTracker::PAGEVIEW_ENDPOINT_REGEX).to_not match('/apii/v1/tracking/page-view')
      end
    end
  end
end
