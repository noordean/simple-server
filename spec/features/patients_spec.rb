require 'rails_helper'

RSpec.feature 'Adherence follow-ups', type: :feature do
  let(:facility_group) { create(:facility_group) }
  let!(:counsellor) { create(:admin, role: 'counsellor') }
  let!(:permissions) do
    create(:user_permission,
           user: counsellor,
           permission_slug: :view_adherence_follow_up_list,
           resource: facility_group)
  end

  describe 'index' do
    before { sign_in(counsellor.email_authentication) }

    it 'shows Overdue tab' do
      visit root_path

      expect(page).to have_content('Adherence follow-ups')
    end

    describe 'Adherence follow-ups tab' do
      let!(:authorized_facility_group) { facility_group }

      let!(:facility_1) { create(:facility, facility_group: authorized_facility_group) }

      let!(:patient_to_followup_in_facility_1) do
        create(:patient, full_name: 'patient_1', registration_facility: facility_1, device_created_at: 10.days.ago)
      end

      let!(:patient_to_not_followup_in_facility_1) do
        create(:patient, full_name: 'patient_2', registration_facility: facility_1, device_created_at: 1.day.ago)
      end

      let!(:facility_2) { create(:facility, facility_group: authorized_facility_group) }

      let!(:patient_to_followup_in_facility_2) do
        create(:patient, registration_facility: facility_2, device_created_at: 5.days.ago)
      end

      let!(:unauthorized_facility_group) { create(:facility_group) }

      let!(:unauthorized_facility) { create(:facility, facility_group: unauthorized_facility_group) }

      let!(:patient_to_followup_in_unauthorized_facility) do
        create(:patient, full_name: 'patient_3', registration_facility: unauthorized_facility, device_created_at: 3.days.ago)
      end

      before do
        visit patients_path
      end

      it 'shows all patients to followup' do
        expect(page).to have_content(patient_to_followup_in_facility_1.full_name)
        expect(page).to have_content(patient_to_followup_in_facility_2.full_name)
      end

      it 'does not show patients registered less than 2 days ago' do
        expect(page).not_to have_content(patient_to_not_followup_in_facility_1.full_name)
      end

      it 'does not show patients registered more than 2 days ago in unauthorized facilities' do
        expect(page).not_to have_content(patient_to_followup_in_unauthorized_facility.full_name)
      end

      it 'shows patients ordered by how long back they registered' do
        first_item = find(:css, '.card:nth-of-type(1)')
        second_item = find(:css, '.card:nth-of-type(2)')

        expect(first_item).to have_content(patient_to_followup_in_facility_1.full_name)
        expect(second_item).to have_content(patient_to_followup_in_facility_2.full_name)
      end

      it 'sets a call_result, and removes patient from the 48 hour list' do
        within('.card:first-of-type') do
          find(:option, 'Dead').click
        end

        page.reset!
        visit patients_path
        expect(page).not_to have_content(patient_to_followup_in_facility_1.full_name)
      end
    end
  end
end
