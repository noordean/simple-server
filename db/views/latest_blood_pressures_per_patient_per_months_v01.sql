SELECT DISTINCT ON (patient_id, year, month)
    id, patient_id, facility_id, recorded_at, systolic, diastolic,
    EXTRACT(MONTH FROM blood_pressures.recorded_at) AS month,
    EXTRACT(QUARTER FROM blood_pressures.recorded_at) AS quarter,
    EXTRACT(YEAR FROM blood_pressures.recorded_at) AS year
FROM blood_pressures
ORDER BY patient_id, year, month, recorded_at DESC, id;