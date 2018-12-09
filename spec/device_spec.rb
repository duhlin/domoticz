require "spec_helper"

describe Domoticz::Device do
  it "gets all available devices" do
    stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "switches.json")

    devices = Domoticz::Device.all
    expect(devices.count).to eq 2

    expect(devices.first.name).to eq "Switch 1"
    expect(devices.first.dimmer?).to be_truthy
    expect(devices.first.idx).to eq 1
    expect(devices.first.type).to eq "Lighting 1"
    expect(devices.first.subtype).to eq "X10"
  end

  it "gets a specific device" do
    stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "switches.json")

    device = Domoticz::Device.find_by_id(1)
    expect(device).to be_a Domoticz::Device

    expect(device.name).to eq "Switch 1"
    expect(device.dimmer?).to be_truthy
    expect(device.idx).to eq 1
    expect(device.type).to eq "Lighting 1"
    expect(device.subtype).to eq "X10"
  end

  it "turns on a switch" do
    stub_server_with_fixture(params: "type=command&param=switchlight&idx=8&switchcmd=On", fixture: "switch_turn_on.json", required: true)

    switch = Domoticz::Device.new
    switch.idx = "8"
    switch.on!
  end

  it "turns off a switch" do
    stub_server_with_fixture(params: "type=command&param=switchlight&idx=8&switchcmd=Off", fixture: "switch_turn_off.json", required: true)

    switch = Domoticz::Device.new
    switch.idx = "8"
    switch.off!
  end

  it "toggles a switch" do
    stub_server_with_fixture(params: "type=command&param=switchlight&idx=8&switchcmd=Toggle", fixture: "switch_toggle.json", required: true)

    switch = Domoticz::Device.new
    switch.idx = "8"
    switch.toggle!
  end

  it "tells us how old this data point is" do
    # "LastUpdate": "2015-12-13 14:02:47",
    stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "temperature_device.json")

    Timecop.freeze(2015, 12, 13, 14, 2, 51)

    device = Domoticz::Device.find_by_id(47)
    expect(device.seconds_since_update).to eq 4
  end

  it "gets the raw json data" do
    stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "temperature_device.json")

    switches = Domoticz::Device.all
    expect(switches.first.data).to eq ({
      "AddjMulti" => 1.0,
      "AddjMulti2" => 1.0,
      "AddjValue" => 0.0,
      "AddjValue2" => 0.0,
      "BatteryLevel" => 100,
      "CustomImage" => 0,
      "Data" => "20.6 C, 45 %",
      "Description" => "",
      "DewPoint" => "8.25",
      "Favorite" => 1,
      "HardwareID" => 3,
      "HardwareName" => "razberry",
      "HardwareType" => "OpenZWave USB",
      "HardwareTypeVal" => 21,
      "HaveTimeout" => false,
      "Humidity" => 45,
      "HumidityStatus" => "Comfortable",
      "ID" => "0601",
      "LastUpdate" => "2015-12-13 14:02:47",
      "Name" => "Woonkamer",
      "Notifications" => "false",
      "PlanID" => "5",
      "PlanIDs" => [5],
      "Protected" => false,
      "ShowNotifications" => true,
      "SignalLevel" => "-",
      "SubType" => "WTGR800",
      "Temp" => 20.6,
      "Timers" => "false",
      "Type" => "Temp + Humidity",
      "TypeImg" => "temperature",
      "Unit" => 0,
      "Used" => 1,
      "XOffset" => "185",
      "YOffset" => "592",
      "idx" => "47"
    })
  end

  describe '#timers' do
    context 'when the device has timers' do
      it 'returns associated timers' do
        stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "switches.json")
        stub_server_with_fixture(params: "type=timers&idx=1", fixture: "timers.json")

        switch = Domoticz::Device.find_by_id(1)
        expect(switch.timers).to be_kind_of(Array)
        switch.timers.each { |t| expect(t).to be_a(Domoticz::Timer) }
      end
    end

    context 'when the device has no timers' do
      it 'returns []' do
        stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "switches.json")
        switch = Domoticz::Device.find_by_id(2)
        expect(switch.timers).to eq([])
      end
    end
  end

  describe '#schedules' do
    context 'when the device has schedules' do
      it 'returns the associated schedules' do
        stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "devices.json")
        stub_server_with_fixture(params: "type=schedules", fixture: "schedules.json")

        device = Domoticz::Device.find_by_id(65)
        expect(device.schedules).to be_kind_of(Array)
        device.schedules.each { |t| expect(t).to be_a(Domoticz::Schedule) }
      end
    end

    context 'when the device has no schedules' do
      it 'returns []' do
        stub_server_with_fixture(params: "type=devices&filter=all&used=true", fixture: "devices.json")
        stub_server_with_fixture(params: "type=schedules", fixture: "schedules.json")
        
        switch = Domoticz::Device.find_by_id(2)
        expect(switch.schedules).to eq([])
      end
    end
  end

  def create_timer(idx, date)
    Domoticz::Timer.new.tap do |t| 
      t.data = {
        'Idx' => idx,
        'Type' => Domoticz::Timer::FIXED_DATE, 
        'Date' => "#{date.year}-#{date.month}-#{date.day}",
        'Time' => "#{date.hour}:#{date.min}",
      }
    end
  end
  let(:timer_dates) {[
    Time.new(2016, 2, 23, 8, 0),
    Time.new(2016, 2, 23, 9, 0),
    Time.new(2016, 2, 23, 8, 0),
    Time.new(2016, 2, 23, 7, 0),
    Time.new(2016, 2, 23, 10, 0),
  ]}
  let(:timers) { timer_dates.each_with_index.map{|d, i| create_timer(i, d)} }

  describe '#next_timers' do
    it 'returns TimerDate objects' do
      allow(subject).to receive(:timers).and_return(timers)
      expect(
        subject.next_timers(Time.new(2016, 2, 23, 7, 30)).all?{|e| e.is_a? Domoticz::Device::TimerDate}
      ).to be true
    end
    it 'returns the list of the next timers' do
      allow(subject).to receive(:timers).and_return(timers)
      expect(
        subject.next_timers(Time.new(2016, 2, 23, 7, 30)).map(&:timer)
      ).to eq(
        [timers[0], timers[2]]
      )

      # can be called twice
      expect(
        subject.next_timers(Time.new(2016, 2, 23, 7, 30)).map(&:timer)
      ).to eq(
        [timers[0], timers[2]]
      )


      # list can be empty
      expect(
        subject.next_timers(Time.new(2016, 2, 23, 10, 1))
      ).to be_empty
    end
  end
  describe '#enum_next_timers' do
    let(:now) { Time.new(2016, 2, 23, 0, 0) }
    it 'returns an enumerator on the next timers' do
      allow(subject).to receive(:timers).and_return(timers)
      expect( subject.enum_next_timers(now)).to be_a Enumerator

      expect( subject.enum_next_timers(now).first(3).map(&:date) ).to eq(
        timer_dates.sort.first(3)
      )
    end
    it 'supports infinite loop: case where there is a recurrent timer' do
      allow(subject).to receive(:timers).and_return([
        Domoticz::Timer.new.tap do |t|
          t.data = {
            'Type' => Domoticz::Timer::ON_TIME,
            'Time' => '12:00',
            'Days' => Domoticz::Timer::EVERYDAY,
          }
        end
      ])
      first = Time.new(now.year, now.month, now.day, 12, 0)
      expect(
        subject.enum_next_timers(now).map(&:date).first(3)
      ).to eq(first.upto(first.next_day(2)).to_a)
    end
  end

  describe '#lightlog' do
    subject { Domoticz::Device.new.tap{|s| s.idx = '1'} }
    it 'returns the lightlog' do
      stub_server_with_fixture(params: "type=lightlog&idx=1", fixture: "lightlog.json")

      lightlog = subject.lightlog
      expect(lightlog.size).to eq(378)
      expect(lightlog.first.date).to eq('2017-01-02 08:31:00')
      expect(lightlog.first.data).to eq('On')
      expect(lightlog.first.status).to eq('On')
      expect(lightlog.first.level).to eq(0)
      expect(lightlog.first.max_dim_level).to eq(100)
    end
  end

  describe '#templog' do
    subject { Domoticz::Device.new.tap{|s| s.idx = '1'} }
    it 'returns the temperature history for days' do
      stub_server_with_fixture(params: "type=graph&sensor=temp&idx=1&range=day", fixture: "templog_day.json")

      templog = subject.templog(:day)
      expect(templog.size).to eq(2017)
      expect(templog.first).to be_a(Domoticz::Device::TempRecord)
      expect(templog.first.date).to eq("2016-12-26 21:25")
      expect(templog.first.temperature).to eq(20.6)
      expect(templog.first.humidity).to eq(42)
      expect(templog.first.temp_min).to be_nil
      expect(templog.first.temp_max).to be_nil
      end
    
    it 'returns the temperature history for months' do
      stub_server_with_fixture(params: "type=graph&sensor=temp&idx=1&range=month", fixture: "templog_month.json")

      templog = subject.templog(:month)
      expect(templog.size).to eq(32)
      expect(templog.first).to be_a(Domoticz::Device::TempRecord)
      expect(templog.first.date).to eq("2016-12-02")
      expect(templog.first.temperature).to eq(18.95)
      expect(templog.first.humidity).to eq(42)
      expect(templog.first.temp_min).to eq(16.7)
      expect(templog.first.temp_max).to eq(20.6)
    end
    
    it 'returns the temperature history for years' do
      stub_server_with_fixture(params: "type=graph&sensor=temp&idx=1&range=year", fixture: "templog_year.json")

      templog = subject.templog(:year)
      expect(templog.size).to eq(358)
      expect(templog.first).to be_a(Domoticz::Device::TempRecord)
      expect(templog.first.date).to eq("2016-01-07")
      expect(templog.first.temperature).to eq(17.77)
      expect(templog.first.humidity).to eq(46)
      expect(templog.first.temp_min).to eq(17.3)
      expect(templog.first.temp_max).to eq(20.0)
    end
    
  end

end
