class OrganizationDistrict < Struct.new(:district_name, :organization)
  def district_slug(district_name)
    district_name.split(" ").select(&:present?).join("-").downcase
  end

  def dashboard_analytics
    query = DistrictAnalyticsQuery.new(district_name)

    [query.follow_up_patients_by_month,
     query.registered_patients_by_month,
     query.total_registered_patients].compact.inject(&:deep_merge)
  end
end
