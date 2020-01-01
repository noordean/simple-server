SELECT blood_pressures.facility_id,
       quarter,
       year,
       COUNT(*) AS count
FROM latest_blood_pressures_per_patient_per_quarters AS blood_pressures
INNER JOIN patients ON patients.id = blood_pressures.patient_id
WHERE patients.deleted_at IS NULL AND
      (blood_pressures.systolic < 140 AND blood_pressures.diastolic < 90) AND
      (date_trunc('quarter', blood_pressures.recorded_at) = date_trunc('quarter', patients.recorded_at) + (interval '3 months'))
GROUP BY blood_pressures.facility_id, quarter, year
ORDER BY year, quarter;