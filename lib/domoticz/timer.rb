module Domoticz
  class Timer
    attr_accessor :idx
    attr_accessor :data

    def method_missing(method_sym, *arguments, &block)
      hash = Hash[@data.map { |k, v| [k.downcase, v] }]
      key = method_sym.to_s.downcase

      if hash.has_key?(key)
        hash[key]
      else
        super
      end
    end

    def self.new_from_json(json)
      timer = self.new
      timer.data = json
      timer.idx = json["idx"].to_i
      timer
    end

    def active?
      @data['Active'] == 'true'
    end

    EVERYDAY = 0x80
    WEEKDAYS = 0x100
    WEEKENDS = 0x200
    MONDAY = 0x01 | EVERYDAY | WEEKDAYS
    TUESDAY = 0x02 | EVERYDAY | WEEKDAYS
    WEDNESDAY = 0x04 | EVERYDAY | WEEKDAYS
    THURSDAY = 0x08 | EVERYDAY | WEEKDAYS
    FRIDAY = 0x10 | EVERYDAY | WEEKDAYS
    SATURDAY = 0x20 | EVERYDAY | WEEKENDS
    SUNDAY = 0x40 | EVERYDAY | WEEKENDS
    DAYS = [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
    DAY_FLAGS = Hash[ DAYS.zip([SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY]) ]
    def apply_to?(day)
      case(day)
      when Symbol then (DAY_FLAGS[day] & @data['Days']) != 0
      when Date then self.apply_to?(DAYS[day.wday])
      else
        fail "#{day.class}: unsupported type"
      end
    end

    def date_array
      date.split('-').map(&:to_i)
    end
    def time_array
      time.split(':').map(&:to_i)
    end

    BEFORE_SUNRISE = 0
    AFTER_SUNRISE = 1
    ON_TIME = 2
    BEFORE_SUNSET = 3
    AFTER_SUNSET = 4
    FIXED_DATE = 5 
    def next_date(date = DateTime.now)
      local_offset = DateTime.now.offset
      case type
      when BEFORE_SUNRISE, AFTER_SUNRISE
        if ([date.hour, date.min] <=> (t=Domoticz.sunrise_sunset.sunrise_array)) < 0
          DateTime.new(date.year, date.month, date.day, *t, 0, local_offset)
        else
          DateTime.new(date.year, date.month, date.day, *t, 0, local_offset).next_day
        end
      when BEFORE_SUNSET, AFTER_SUNSET
        if ([date.hour, date.min] <=> (t=Domoticz.sunrise_sunset.sunset_array)) < 0
          DateTime.new(date.year, date.month, date.day, *t, 0, local_offset)
        else
          DateTime.new(date.year, date.month, date.day, *t, 0, local_offset).next_day
        end
      when ON_TIME
        c = DateTime.new(date.year, date.month, date.day, *time_array, 0, local_offset)
        c.upto(c.next_day(7)).find{ |d| date < d && self.apply_to?(d) }
      when FIXED_DATE
        c = DateTime.new(*date_array, *time_array, 0, local_offset)
        c if c > date
      end
    end

  end
end
