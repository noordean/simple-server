METHODS_TO_INSTRUMENT = [
  [Api::V3::PatientTransformer.singleton_class, :from_nested_request],
  [Api::V3::PatientTransformer.singleton_class, :to_nested_response],

  [Api::V3::BloodPressureTransformer.singleton_class, :from_request],
  [Api::V3::BloodPressureTransformer.singleton_class, :to_response],

  [Api::V3::PatientsController, :current_facility_records],
  [Api::V3::PatientsController, :other_facility_records],

  [Api::V3::PatientsController, :merge_if_valid],
  [Api::V3::BloodPressuresController, :merge_if_valid],
  [Api::V3::AppointmentsController, :merge_if_valid],
  [Api::V3::PrescriptionDrugsController, :merge_if_valid],
  [Api::V3::MedicalHistoriesController, :merge_if_valid],

  [Api::V3::BloodPressuresController, :current_facility_records],
  [Api::V3::BloodPressuresController, :other_facility_records],

  [Api::V3::BloodPressurePayloadValidator, :invalid?],
  [Api::V3::AppointmentPayloadValidator, :invalid?],
  [Api::V3::PrescriptionDrugPayloadValidator, :invalid?],

  # Debugging production issues with large payloads
  [Api::V3::SyncController, :__sync_from_user__],
  [Api::V3::SyncController, :capture_errors],
  [AuditLog.singleton_class, :merge_log],
  [AuditLog.singleton_class, :write_audit_log],
  [Api::V3::PatientPayloadValidator, :invalid?],
  [Address, :merge],
  [Patient, :merge],
  [MergePatientService, :merge_phone_numbers],
  [MergePatientService, :merge_business_identifiers],
  [MergePatientService, :attributes_with_metadata],
  [Patient.singleton_class, :compute_merge_status],
  [Patient.singleton_class, :merge],
  [Patient.singleton_class, :existing_record],
  [Patient.singleton_class, :discarded_record],
  [Patient.singleton_class, :invalid_record],
  [Patient.singleton_class, :create_new_record],
  [Patient.singleton_class, :update_existing_record],
  [Patient.singleton_class, :return_old_record],

  [MergePatientService, :merge],
  [BloodPressure.singleton_class, :merge],
  [Appointment.singleton_class, :merge],
  [PrescriptionDrug.singleton_class, :merge]
]

METHODS_TO_INSTRUMENT.each do |class_method|
  cls = class_method[0]
  method = class_method[1]

  cls.class_eval do
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer method
  end
end
