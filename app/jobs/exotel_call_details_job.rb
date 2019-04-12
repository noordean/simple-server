class ExotelCallDetailsJob < ApplicationJob
  queue_as :default
  self.queue_adapter = :sidekiq

  DEFAULT_RETRY_TIMES = 5
  DEFAULT_RETRY_SECONDS = 10.minutes.seconds.to_i

  retry_on ExotelAPIService::HTTPError,
           wait: Config.get_int('EXOTEL_CALL_DETAILS_JOB_RETRY_SECONDS', DEFAULT_RETRY_SECONDS),
           attempts: Config.get_int('EXOTEL_CALL_DETAILS_JOB_RETRY_TIMES', DEFAULT_RETRY_TIMES)

  def perform(call_id, user_id, callee_phone_number, call_status)
    call_details = ExotelAPIService.new(ENV['EXOTEL_SID'],
                                        ENV['EXOTEL_TOKEN']).call_details(call_id)

    CallLog.create!(call_log_params(call_details[:Call],
                                    user_id,
                                    callee_phone_number,
                                    call_status)) if call_details.present?
  end

  def call_log_params(call_details, user_id, callee_phone_number, call_status)
    parse_call_details(call_details)
      .merge(participant_details(user_id, callee_phone_number))
      .merge(result: call_status)
  end

  def participant_details(user_id, callee_phone_number)
    { user_id: user_id,
      callee_phone_number: callee_phone_number }
  end

  def parse_call_details(call_details)
    { session_id: call_details[:Sid],
      end_time: call_details[:EndTime],
      start_time: call_details[:StartTime],
      duration: call_details[:Duration] }
  end
end