require 'rails_helper'

def new_patient_payload(attrs = {})
  payload = Api::V3::PatientPayloadValidator.new(build_patient_payload.deep_merge(attrs))
  payload.validate
  payload
end

describe Api::V3::PatientPayloadValidator, type: :model do
  describe 'Validations' do
    it 'Validates that either age or date of birth is present' do
      expect(new_patient_payload('address' => nil,
                                 'phone_numbers' => nil,
                                 'age' => nil,
                                 'date_of_birth' => 20.years.ago)).to be_valid

      expect(new_patient_payload('address' => nil,
                                 'phone_numbers' => nil,
                                 'age' => rand(18..100),
                                 'age_updated_at' => Time.current,
                                 'date_of_birth' => nil).valid?).to be true

      expect(new_patient_payload('address' => nil,
                                 'phone_numbers' => nil,
                                 'age' => rand(18..100),
                                 'age_updated_at' => nil,
                                 'date_of_birth' => nil).valid?).to be false

      expect(new_patient_payload('address' => nil,
                                 'phone_numbers' => nil,
                                 'age' => nil,
                                 'date_of_birth' => nil).valid?).to be false
    end

    it 'validates patient date_of_birth is less than today' do
      payload = new_patient_payload('date_of_birth' => 3.days.from_now)
      expect(payload.valid?).to be false
      expect(payload.errors[:date_of_birth]).to be_present
    end

    describe 'Required validations' do
      it 'Validates json spec for patient sync request' do
        payload = new_patient_payload('created_at' => nil)
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end
      it 'Validates that full_name is required' do
        payload = new_patient_payload('full_name' => nil)
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end
      it 'Validates that address is required' do
        payload = new_patient_payload('address' => { 'created_at' => nil })
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end
    end

    describe 'Non empty validations' do
      it 'Validates that full_name is not empty' do
        payload = new_patient_payload('full_name' => '')
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end
    end

    describe 'type and format validations' do
      it 'Validates that created_at is of the right type and format' do
        payload = new_patient_payload('created_at' => 'foo')
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end

      it 'Validates that id is of the right type and format' do
        payload = new_patient_payload('id' => 'not-a-uuid')
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end

      it 'Validates that age is of the right type and format' do
        payload = new_patient_payload('age' => 'foo')
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end
    end

    describe 'Enum validations' do
      it 'Validates that gender is present in the prescribed enum' do
        payload = new_patient_payload('gender' => 'foo')
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end

      it 'Validates that status is present in the prescribed enum' do
        payload = new_patient_payload('status' => 'foo')
        expect(payload.valid?).to be false
        expect(payload.errors[:schema]).to be_present
      end
    end

    context 'when schema validations are disabled' do
      before do
        @original_env_var = ENV['ENABLE_SKIP_API_VALIDATION']
        ENV['ENABLE_SKIP_API_VALIDATION'] = 'true'
      end

      after { ENV['ENABLE_SKIP_API_VALIDATION'] = @original_env_var }

      it 'does not validate schema' do
        validator = new_patient_payload

        expect(validator).not_to receive(:validate_schema)

        validator.validate
      end
    end
  end
end
