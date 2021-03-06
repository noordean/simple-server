require 'rails_helper'

RSpec.describe 'BloodSugars sync', type: :request do
  let(:sync_route) { '/api/v4/blood_sugars/sync' }
  let(:request_user) { create(:user) }

  let(:model) { BloodSugar }

  let(:build_payload) { -> { build_blood_sugar_payload(build(:blood_sugar, facility: request_user.facility)) } }
  let(:build_invalid_payload) { -> { build_invalid_blood_sugar_payload } }
  let(:update_payload) { ->(blood_sugar) { updated_blood_sugar_payload blood_sugar } }

  def to_response(blood_sugar)
    Api::V4::BloodSugarTransformer.to_response(blood_sugar)
  end

  include_examples 'v4 API sync requests'
end
