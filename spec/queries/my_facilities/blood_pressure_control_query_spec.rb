require 'rails_helper'

RSpec.describe MyFacilities::BloodPressureControlQuery do
  include QuarterHelper

  describe 'BP control queries' do
    context 'Quarterly cohorts' do
      let!(:facility) { create(:facility) }
      let!(:user) { create(:user) }

      let!(:current_quarter) { quarter(Time.current) }
      let!(:current_year) { Time.current.year }
      let!(:registration_year_and_quarter) { previous_year_and_quarter(current_year, current_quarter) }
      let!(:registration_quarter) { registration_year_and_quarter.second }
      let!(:registration_quarter_year) { registration_year_and_quarter.first }
      let!(:current_quarter_start) { Time.current.beginning_of_quarter }
      let!(:registration_quarter_start) { quarter_start(*previous_year_and_quarter) }

      let!(:cohort_range) do
        (registration_quarter_start.to_date..registration_quarter_start.end_of_quarter.to_date).to_a
      end

      let!(:current_quarter_range) do
        (current_quarter_start.to_date..Time.current.to_date).to_a
      end

      let!(:patients_with_controlled_bp) do
        (1..2).map do
          create(:patient, recorded_at: cohort_range.sample, registration_facility: facility, registration_user: user)
        end
      end

      let!(:patients_with_uncontrolled_bp) do
        [create(:patient,
                recorded_at: cohort_range.sample,
                registration_facility: facility, registration_user: user),
         create(:patient,
                recorded_at: registration_quarter_start,
                registration_facility: facility,
                registration_user: user),
         create(:patient,
                recorded_at: registration_quarter_start.end_of_quarter,
                registration_facility: facility, registration_user: user)]
      end

      let!(:patients_with_missed_visit) do
        (1..2).map do
          create(:patient, recorded_at: cohort_range.sample, registration_facility: facility, registration_user: user)
        end
      end

      let!(:controlled_blood_pressures) do
        patients_with_controlled_bp.map do |patient|
          create(:blood_pressure,
                 :under_control,
                 facility: facility,
                 patient: patient,
                 recorded_at: current_quarter_range.sample,
                 user: user)
        end
      end

      let!(:uncontrolled_blood_pressures) do
        patients_with_uncontrolled_bp.map do |patient|
          create(:blood_pressure,
                 :hypertensive,
                 facility: facility,
                 patient: patient,
                 recorded_at: current_quarter_range.sample,
                 user: user)
        end
      end

      let!(:query) do

        described_class.new(facilities: Facility.all,
                            cohort_period: { cohort_period: :quarter,
                                             registration_quarter: registration_quarter,
                                             registration_year: registration_quarter_year })
      end

      before do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL TIME ZONE '#{Rails.application.config.country[:time_zone]}'")
          LatestBloodPressuresPerPatientPerMonth.refresh
          LatestBloodPressuresPerPatientPerQuarter.refresh
        end
      end

      describe '#cohort_registrations' do
        specify do
          expect(query.cohort_registrations.count).to eq(7)
        end
      end

      describe '#cohort_controlled_bps' do
        specify do
          expect(query.cohort_controlled_bps.count).to eq(2)
        end
      end

      describe '#cohort_uncontrolled_bps' do
        specify do
          expect(query.cohort_uncontrolled_bps.count).to eq(3)
        end
      end

      describe '#cohort_missed_visits_count' do
        specify do
          expect(query.cohort_missed_visits_count).to eq(2)
        end
      end
    end

    context 'Monthly cohorts' do
      let!(:facility) { create(:facility) }
      let!(:user) { create(:user) }

      let!(:current_month) { Time.current.month }
      let!(:current_year) { Time.current.year }
      let!(:current_month_start) { Time.current.beginning_of_month }

      let!(:registration_month_start) { current_month_start - 2.months }
      let!(:registration_month) { registration_month_start.month }
      let!(:registration_year) { registration_month_start.year }

      let!(:cohort_range) do
        (registration_month_start.to_date..registration_month_start.end_of_month.to_date).to_a
      end

      let!(:bp_recorded_range) do
        ((current_month_start - 1.months).to_date..Time.current.to_date).to_a
      end

      let!(:current_month_range) do
        (current_month_start.to_date..Time.current.to_date).to_a
      end

      let!(:previous_month_range) do
        ((current_month_start - 1.months).to_date..(current_month_start - 1.months).end_of_month.to_date).to_a
      end

      let!(:patients_with_controlled_bp) do
        (1..2).map do
          create(:patient, recorded_at: cohort_range.sample, registration_facility: facility, registration_user: user)
        end
      end

      let!(:patients_with_uncontrolled_bp) do
        [create(:patient,
                recorded_at: registration_month_start,
                registration_facility: facility,
                registration_user: user),
         create(:patient,
                recorded_at: cohort_range.sample,
                registration_facility: facility,
                registration_user: user),
         create(:patient,
                recorded_at: registration_month_start.end_of_month,
                registration_facility: facility, registration_user: user)]
      end

      let!(:patients_with_missed_visit) do
        (1..2).map do
          create(:patient, recorded_at: cohort_range.sample, registration_facility: facility, registration_user: user)
        end
      end

      let!(:controlled_blood_pressures) do
        patients_with_controlled_bp.map do |patient|
          create(:blood_pressure,
                 :under_control,
                 facility: facility,
                 patient: patient,
                 recorded_at: current_month_range.sample,
                 user: user)
          create(:blood_pressure,
                 :under_control,
                 facility: facility,
                 patient: patient,
                 recorded_at: previous_month_range.sample,
                 user: user)
        end
      end

      let!(:uncontrolled_blood_pressures) do
        patients_with_uncontrolled_bp.map do |patient|
          create(:blood_pressure,
                 :hypertensive,
                 facility: facility,
                 patient: patient,
                 recorded_at: bp_recorded_range.sample,
                 user: user)
        end
      end

      let!(:query) do
        described_class.new(facilities: Facility.all,
                            cohort_period: { cohort_period: :month,
                                             registration_month: registration_month,
                                             registration_year: registration_year })
      end

      before do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL TIME ZONE '#{Rails.application.config.country[:time_zone]}'")
          LatestBloodPressuresPerPatientPerMonth.refresh
        end
      end

      describe '#cohort_registrations' do
        specify do
          expect(query.cohort_registrations.count).to eq(7)
        end
      end

      describe '#cohort_controlled_bps' do
        specify do
          expect(query.cohort_controlled_bps.count).to eq(2)
        end
      end

      describe '#cohort_uncontrolled_bps' do
        specify do
          expect(query.cohort_uncontrolled_bps.count).to eq(3)
        end
      end

      describe '#cohort_missed_visits_count' do
        specify do
          expect(query.cohort_missed_visits_count).to eq(2)
        end
      end
    end

    context 'Overall queries' do
      let!(:facility) { create(:facility) }
      let!(:user) { create(:user) }

      let!(:recent_patient) do
        create(:patient, registration_facility: facility, registration_user: user, recorded_at: 1.month.ago)
      end

      let!(:patient_with_recent_bp) do
        create(:patient,
               :hypertension,
               registration_facility: facility,
               registration_user: user,
               recorded_at: 4.months.ago)
      end

      let!(:patient_without_recent_bp) do
        create(:patient,
               :hypertension,
               registration_facility: facility,
               registration_user: user,
               recorded_at: 4.months.ago)
      end

      let!(:patients_with_uncontrolled_bp) do
        create(:patient,
               :hypertension,
               registration_facility: facility,
               registration_user: user,
               recorded_at: 4.months.ago)
      end

      let!(:patients_with_missed_visit) do
        create(:patient,
               :hypertension,
               registration_facility: facility,
               registration_user: user,
               recorded_at: 4.months.ago)
      end

      let!(:bp_for_recent_patient) do
        create(:blood_pressure,
               :under_control,
               patient: recent_patient,
               recorded_at: 1.week.ago,
               facility: facility,
               user: user)
      end

      let!(:bp_for_patient_with_recent_bp) do
        create(:blood_pressure,
               :under_control,
               patient: patient_with_recent_bp,
               recorded_at: 1.week.ago,
               facility: facility,
               user: user)
      end

      let!(:bp_for_patient_without_recent_bp) do
        create(:blood_pressure,
               :under_control,
               patient: patient_without_recent_bp,
               recorded_at: 4.months.ago,
               facility: facility,
               user: user)
      end

      let!(:bp_for_patient_with_uncontrolled_bp) do
        create(:blood_pressure,
               :hypertensive,
               patient: patients_with_uncontrolled_bp,
               recorded_at: 4.months.ago,
               facility: facility,
               user: user)
      end

      let!(:old_patient) do
        create(:patient,
               :hypertension,
               registration_facility: facility,
               registration_user: user,
               recorded_at: 6.months.ago)
      end

      let!(:old_bp) do
        create(:blood_pressure,
               :under_control,
               facility: facility,
               patient: old_patient,
               recorded_at: old_patient.recorded_at,
               user: user)
      end

      before do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL TIME ZONE '#{Rails.application.config.country[:time_zone]}'")
          LatestBloodPressuresPerPatientPerMonth.refresh
          LatestBloodPressuresPerPatient.refresh
        end
      end

      describe '#overall_patients' do
        specify { expect(described_class.new.overall_patients.count).to eq(5) }
      end

      describe '#overall_controlled_bps' do
        specify { expect(described_class.new.overall_controlled_bps.count).to eq(1) }
      end
    end
  end
end
