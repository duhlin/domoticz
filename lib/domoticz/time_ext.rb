class Time
  SECONDS_IN_DAY = 24 * 3_600
  def next_day(count=1)
    self + SECONDS_IN_DAY*count
  end
  def upto(end_date)
    return enum_for(:upto, end_date) unless block_given?
    d = self
    while (d <= end_date)
      yield d
      d=d.next_day
    end
  end
end
