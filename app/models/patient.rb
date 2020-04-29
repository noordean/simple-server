class Patient < ApplicationRecord
  include ApplicationHelper
  include Mergeable
  include Hashable

  enum reminder_consent: {
    granted: 'granted',
    denied: 'denied'
  }, _prefix: true

  GENDERS = Rails.application.config.country[:supported_genders].freeze
  STATUSES = %w[active dead migrated unresponsive inactive].freeze
  RISK_PRIORITIES = {
    HIGH: 0,
    REGULAR: 1,
    LOW: 2,
    NONE: 3
  }.freeze

  ANONYMIZED_DATA_FIELDS = %w[id created_at registration_date registration_facility_name user_id age gender]

  belongs_to :address, optional: true
  has_many :phone_numbers, class_name: 'PatientPhoneNumber'
  has_many :business_identifiers, class_name: 'PatientBusinessIdentifier'
  has_many :passport_authentications, through: :business_identifiers

  has_many :blood_pressures, inverse_of: :patient
  has_many :blood_sugars
  has_many :prescription_drugs
  has_many :facilities, -> { distinct }, through: :blood_pressures
  has_many :users, -> { distinct }, through: :blood_pressures
  has_many :appointments

  has_one :medical_history

  has_many :encounters
  has_many :observations, through: :encounters

  belongs_to :registration_facility, class_name: "Facility", optional: true
  belongs_to :registration_user, class_name: "User"

  has_many :latest_blood_pressures, -> { order(recorded_at: :desc) }, class_name: 'BloodPressure'
  has_many :latest_blood_sugars, -> { order(recorded_at: :desc) }, class_name: 'BloodSugar'

  has_many :latest_scheduled_appointments,
           -> { where(status: 'scheduled').order(scheduled_date: :desc) },
           class_name: 'Appointment'

  has_many :latest_bp_passports,
           -> { where(identifier_type: 'simple_bp_passport').order(device_created_at: :desc) },
           class_name: 'PatientBusinessIdentifier'

  has_many :current_prescription_drugs, -> { where(is_deleted: false) }, class_name: 'PrescriptionDrug'

  attribute :call_result, :string

  scope :diabetes_only, -> { joins(:medical_history).merge(MedicalHistory.diabetes_yes) }
  scope :hypertension_only, -> { joins(:medical_history).merge(MedicalHistory.hypertension_yes) }

  #
  # Note: This scope expects a join(:blood_pressures) to exist.
  # For eg, Patient.joins(:blood_pressures).follow_ups(:month).
  #
  # It doesn't include the join in this scope to play well with certain parent scopes (eg. Facility).
  # Parent scopes might auto add this join and the final query would end up with unnecessary joins, affecting perf.
  #
  scope :hypertension_follow_ups, -> (period, last: nil) {
    follow_ups_with(:blood_pressures, period, last: last)
      .hypertension_only
  }

  scope :diabetes_follow_ups, -> (period, last: nil) {
    follow_ups_with(:blood_sugars, period, last: last)
      .diabetes_only
  }

  scope :follow_ups, -> (period, last: nil) {
    where(observations: { observable_type: 'BloodPressures' }, medical_history: { hypertension: 'yes' })
      .or(where(observations: { observable_type: 'BloodSugar' }, medical_history: { diabetes: 'yes' }))
      .joins(:medical_history, :observations)
      .where("patients.recorded_at < #{Encounter.date_to_period_sql(period)}")
      .group_by_period(period, 'encounters_patients_join.encountered_on', last: last)
  }

  def self.follow_ups_with(resource_type, period, time_col: 'recorded_at', last: nil)
    resource_name = resource_type.to_s.singularize.camelize.constantize
    group_by_time = "#{resource_type}.#{time_col}"

    where("patients.recorded_at < #{resource_name.date_to_period_sql(period)}")
      .group_by_period(period, group_by_time, last: last)
  end

  private_class_method :follow_ups_with

  enum could_not_contact_reasons: {
    not_responding: 'not_responding',
    moved: 'moved',
    dead: 'dead',
    invalid_phone_number: 'invalid_phone_number',
    public_hospital_transfer: 'public_hospital_transfer',
    moved_to_private: 'moved_to_private',
    other: 'other'
  }

  validate :past_date_of_birth

  validates :device_created_at, presence: true
  validates :device_updated_at, presence: true

  validates_associated :address, if: :address
  validates_associated :phone_numbers, if: :phone_numbers

  def past_date_of_birth
    if date_of_birth.present? && date_of_birth > Date.current
      errors.add(:date_of_birth, "can't be in the future")
    end
  end

  def latest_scheduled_appointment
    latest_scheduled_appointments.first
  end

  def latest_blood_pressure
    latest_blood_pressures.first
  end

  def latest_blood_sugar
    latest_blood_sugars.first
  end

  def latest_phone_number
    phone_numbers.last&.number
  end

  def latest_mobile_number
    phone_numbers.phone_type_mobile.last&.number
  end

  def latest_bp_passport
    latest_bp_passports.first
  end

  def access_tokens
    passport_authentications.map(&:access_token)
  end

  def phone_number?
    latest_phone_number.present?
  end

  def registration_date
    handle_impossible_registration_date(recorded_at)
  end

  def risk_priority
    return RISK_PRIORITIES[:NONE] if latest_scheduled_appointment&.overdue_for_under_a_month?

    if latest_blood_pressure&.critical?
      RISK_PRIORITIES[:HIGH]
    elsif medical_history&.indicates_hypertension_risk? && latest_blood_pressure&.hypertensive?
      RISK_PRIORITIES[:HIGH]
    elsif latest_blood_sugar&.diabetic?
      RISK_PRIORITIES[:HIGH]
    elsif latest_blood_pressure&.hypertensive?
      RISK_PRIORITIES[:REGULAR]
    elsif low_priority?
      RISK_PRIORITIES[:LOW]
    else
      RISK_PRIORITIES[:NONE]
    end
  end

  def high_risk?
    risk_priority == RISK_PRIORITIES[:HIGH]
  end

  def current_age
    if date_of_birth.present?
      Date.current.year - date_of_birth.year
    elsif age.present?
      return 0 if age == 0

      years_since_update = (Time.current - age_updated_at) / 1.year
      (age + years_since_update).floor
    end
  end

  def call_result=(new_call_result)
    if new_call_result == 'contacted'
      self.contacted_by_counsellor = true
    elsif Patient.could_not_contact_reasons.values.include?(new_call_result)
      self.contacted_by_counsellor = false
      self.could_not_contact_reason = new_call_result
    end

    if new_call_result == 'dead'
      self.status = 'dead'
    end

    super(new_call_result)
  end

  def self.not_contacted
    where(contacted_by_counsellor: false)
      .where(could_not_contact_reason: nil)
      .where('device_created_at <= ?', 2.days.ago)
  end

  def anonymized_data
    { id: hash_uuid(id),
      created_at: created_at,
      registration_date: recorded_at,
      registration_facility_name: registration_facility&.name,
      user_id: hash_uuid(registration_user&.id),
      age: age,
      gender: gender
    }
  end

  def discard_data
    address&.discard
    appointments.discard_all
    blood_pressures.discard_all
    blood_sugars.discard_all
    business_identifiers.discard_all
    encounters.discard_all
    medical_history&.discard
    observations.discard_all
    phone_numbers.discard_all
    prescription_drugs.discard_all
    discard
  end

  private

  def low_priority?
    latest_scheduled_appointment&.overdue_for_over_a_year? &&
      latest_blood_pressure&.under_control?
  end
end
