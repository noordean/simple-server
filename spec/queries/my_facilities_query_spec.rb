require 'rails_helper'
require 'benchmark'

RSpec.describe MyFacilitiesQuery do
  # Pick a start_month, end_month => t months
  # Create n facilities
  # Create m patients, m/n patients per facility, m/t per month
  # Create k blood pressures, k/m bps per patient, k/t per month
  # Create a user with permission to 100 facilities


  let!(:no_of_facilities) { 5 }
  let!(:no_of_months) { 15 }
  let!(:start_month) { Date.parse('1 Jan 2018') }
  let!(:end_month) { start_month + no_of_months.months }
  let!(:facilities) { create_list(:facility, no_of_facilities) }
  let!(:months) do
    (start_month..end_month).select { |d| d.day == 1 }
  end

  let!(:patients) do
    facilities.map do |facility|
      months.map do |month|
        create(:patient, registration_facility: facility, recorded_at: month)
      end
    end.flatten
  end

  let!(:blood_pressures) do
    patients.map do |patient|
      (Date.parse(patient.recorded_at.to_s)..end_month).select { |d| d.day == 1 }.map do |month|
        create(:blood_pressure, patient: patient, facility: patient.registration_facility, recorded_at: month + 10.days)
      end
    end
  end

  it 'compares the time taken for the two function calls' do

    # a. Time taken for latest_bps_per_month refresh
    # b. Time taken for latest_bps_per_quarter refresh
    # c. Time taken for visited_with_controlled_bp refresh

    LatestBloodPressuresPerPatientPerMonth.refresh
    sleep(10)
    LatestBloodPressuresPerPatientPerQuarter.refresh
    sleep(10)
    VisitedPatientsWithControlledBpQuarterly.refresh
    sleep(10)

    p VisitedPatientsWithControlledBpQuarterly.all

    # d. Time taken for .visited_patients_with_controlled_bp_by_view
    # e. Time taken for .visited_patients_with_controlled_bp_by_query
    # f. Time taken for .visited_patients_with_controlled_bp_by_query after scoping the facilities by user
    # Compare d, e
    # Compare d, f

    p Benchmark.measure { MyFacilitiesQuery.visited_patients_with_controlled_bp_by_query }
    p Benchmark.measure { MyFacilitiesQuery.visited_patients_with_controlled_bp_by_view }
  end
end