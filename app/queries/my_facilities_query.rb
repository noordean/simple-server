module MyFacilitiesQuery
  def self.visited_patients_with_controlled_bp_by_view
    VisitedPatientsWithControlledBpQuarterly.all
  end

  def self.visited_patients_with_controlled_bp_by_query
    # Scope facilities
    LatestBloodPressuresPerPatientPerQuarter
        .joins('INNER JOIN patients ON patients.id = patient_id')
        .merge(BloodPressure.under_control)
        .where('patients.deleted_at IS NULL')
        .where("date_trunc('quarter', latest_blood_pressures_per_patient_per_quarters.recorded_at) = date_trunc('quarter', patients.recorded_at) + (interval '3 months')")
        .group(:facility_id, :quarter, :year)
        .count
  end
end