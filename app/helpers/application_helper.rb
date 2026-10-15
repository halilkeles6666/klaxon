module ApplicationHelper
  # Consistent, locale-independent timestamp formatting in the app time zone.
  def fmt_time(time)
    return "—" if time.blank?
    time.in_time_zone.strftime("%d.%m.%Y %H:%M")
  end

  def fmt_date(time)
    return "—" if time.blank?
    time.in_time_zone.strftime("%d.%m.%Y")
  end
end
