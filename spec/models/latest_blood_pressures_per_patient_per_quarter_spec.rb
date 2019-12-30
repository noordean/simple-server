require 'rails_helper'

RSpec.describe LatestBloodPressuresPerPatientPerQuarter, type: :model do
  Timecop.travel('1 Oct 2019') do
    let!(:facilities) { create_list(:facility, 2) }
    let!(:months) do
      # 2 quarters
      [1, 2, 3, 4, 5].map { |n| n.months.ago }
    end
    let!(:patients) { create_list(:patient, 2) }

    let!(:blood_pressures) do
      facilities.map do |facility|
        months.map do |month|
          patients.map do |patient|
            create_list(:blood_pressure, 2, facility: facility, recorded_at: month, patient: patient)
          end
        end
      end.flatten
    end

    let!(:query_results) do
      LatestBloodPressuresPerPatientPerMonth.refresh
      LatestBloodPressuresPerPatientPerQuarter.refresh
      LatestBloodPressuresPerPatientPerQuarter.all
    end
  end

  it 'should return a row per patient per quarter' do
    expect(query_results.count).to eq(4)
  end
  it 'should return at least one row per patient' do
    expect(query_results.pluck(:patient_id).uniq).to match_array(patients.map(&:id))
  end
end

