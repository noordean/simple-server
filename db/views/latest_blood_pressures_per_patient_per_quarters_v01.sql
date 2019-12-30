SELECT DISTINCT ON (patient_id, year, quarter)
    patient_id, facility_id, recorded_at, systolic, diastolic, quarter, year
FROM latest_blood_pressures_per_patient_per_months
ORDER BY patient_id, year, quarter, recorded_at DESC, id;