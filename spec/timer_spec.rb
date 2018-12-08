require "spec_helper"

describe Domoticz::Timer do
  describe '::new_from_json' do
    it 'can create object from a json definition' do
      json = JSON.parse(IO.read('spec/fixtures/timers.json'))
      expect(
        Domoticz::Timer.new_from_json(json['result'].first)
      ).to be_a(Domoticz::Timer)
    end
  end
  subject {
    json = JSON.parse(IO.read('spec/fixtures/timers.json'))
    Domoticz::Timer.new_from_json(json['result'].first)
  }
  describe '#idx' do
    it 'is the timer index' do
      expect(subject.idx).to eq(1)
    end
  end
  describe '#data' do
    it 'is the full setting map' do
      expect(subject.data).to eq({
        "Active"=>"true",
        "Cmd"=>1,
        "Date"=>"",
        "Days"=>27,
        "Hue"=>0,
        "Level"=>100,
        "Randomness"=>false,
        "Time"=>"04:30",
        "Type"=>2,
        "idx"=>"1",
      })
    end
  end
  describe '#apply_to?' do
    context 'when the rule applies to every day' do
      before(:each) { subject.data = {'Days' => Domoticz::Timer::EVERYDAY} }
      it 'returns true for every day' do
        expect( Domoticz::Timer::DAYS.all?{|d| subject.apply_to? d} ).to be true
      end
    end
    context 'when the rule applies to week days' do
      before(:each) { subject.data = {'Days' => Domoticz::Timer::WEEKDAYS} }
      it 'returns true for week days' do
        expect( Domoticz::Timer::DAYS.select{|d| subject.apply_to? d} ).to eq(
          [:monday, :tuesday, :wednesday, :thursday, :friday]
        )
      end
    end
    context 'when the rule applies to week ends' do
      before(:each) { subject.data = {'Days' => Domoticz::Timer::WEEKENDS} }
      it 'returns true for the week ends' do
        expect( Domoticz::Timer::DAYS.select{|d| subject.apply_to? d} ).to eq(
          [:sunday, :saturday]
        )
      end
    end
    FLAGS = {monday: 0x01, tuesday: 0x02, wednesday: 0x04, thursday: 0x08, friday: 0x10, saturday: 0x20, sunday: 0x40}
    FLAGS.each do |day, flag|
      context "when the rule applies to #{day}" do
        before(:each) { subject.data = {'Days' => flag} }
        it "returns true for #{day}" do
          expect( Domoticz::Timer::DAYS.select{|d| subject.apply_to? d} ).to eq([day])
        end
      end
    end
    context 'when the rule applies to several days' do
      let(:selected_days) { FLAGS.to_a.sample(Random.rand(1..7)) }
      before(:each) { subject.data = {'Days' => selected_days.map(&:last).reduce(0){|state, v| state | v}} }
      it 'returns true for these days' do
        expect( Domoticz::Timer::DAYS.select{|d| subject.apply_to? d} ).to match_array(
          selected_days.map(&:first)
        )
      end
    end
    it 'can be applied with a Date object' do
      subject.data = {'Days' => Domoticz::Timer::WEEKENDS}
      expect(subject.apply_to?(Date.new(2016, 02, 26))).to be false #it's friday
      expect(subject.apply_to?(DateTime.new(2016, 02, 27, 10, 45, 0, LOCAL_OFFSET))).to be true #it's saturday


    end
  end
  describe '#date_array' do
    before(:each) { subject.data = {'Date'=> '2016-02-21'} }
    it 'returns an array: [year, month, day]' do
      expect(subject.date_array).to eq([2016, 02, 21])
    end
  end
  describe '#time_array' do
    before(:each) { subject.data = {'Time' => '08:30'} }
    it 'returns an array: [hour, minute]' do
      expect(subject.time_array).to eq([8, 30])
    end
  end
  describe '#next_date' do
    let(:now) { DateTime.new(2016, 02, 22, 8, 30, 0, LOCAL_OFFSET) }
    context 'when the timer is configured with a fixed date' do
      before(:each) { subject.data = {'Type'=> 5} }
      context 'when the fixed date is in the future' do
        before(:each) { 
          subject.data['Date'] = '2050-02-15' 
          subject.data['Time'] = '08:30'
        }
        it 'returns the fixed date' do
          expect(subject.next_date(now)).to eq(DateTime.new(2050, 02, 15, 8, 30, 0, LOCAL_OFFSET))
        end
      end
      context 'when the fixed date is in the past' do
        before(:each) { 
          subject.data['Date'] = '2016-02-22' 
          subject.data['Time'] = '08:29'
        }
        it 'returns nil' do
          expect(subject.next_date(now)).to be_nil
        end
      end
    end
    context 'when the timer is configured with "on time"' do
      before(:each) { 
        subject.data = {
          'Type' => 2,
          'Days' => 0x20, # saturday
          'Time' => '08:45'
        }
      }
      it 'returns the next date' do
        expect(subject.next_date(now)).to eq(
          DateTime.new(2016, 02, 27, 8, 45, 0, LOCAL_OFFSET)
        )
      end
      it 'the next date should be greater than current date' do
        expect(subject.next_date(DateTime.new(2016, 02, 27, 8, 45, 0, LOCAL_OFFSET))).to eq(
          DateTime.new(2016, 02, 27, 8, 45, 0, LOCAL_OFFSET).next_day(7)
        )
      end
    end
    context 'when the timer is configured with sunset/sunrise' do
      let(:sunrise_sunset) {
        Domoticz::SunriseSunset.new.tap{ |s|
          s.data = {
            'Sunrise' => '08:00',
            'Sunset'  => '20:00',
          }
        }
      }
      before(:each) do
        allow(Domoticz).to receive(:sunrise_sunset).and_return(sunrise_sunset)
      end
      context 'when its related to sunrise' do
        before(:each) { subject.data = {'Type' => 0} }
        it 'returns the sunrise on the current day when before the sunrise' do
          expect(subject.next_date(DateTime.new(2016, 02, 22, 7, 59, 0, LOCAL_OFFSET))).to eq(
            DateTime.new(2016, 02, 22, 8, 0, 0, LOCAL_OFFSET)
          )
        end
        it 'returns the sunrize the next day when after the sunrise' do
          expect(subject.next_date(DateTime.new(2016, 02, 22, 8, 0, 0, LOCAL_OFFSET))).to eq(
            DateTime.new(2016, 02, 23, 8, 0, 0, LOCAL_OFFSET)
          )
        end
      end
      context 'when its related to sunset' do
        before(:each) { subject.data = {'Type' => 4} }
        it 'returns the sunset on the current day when before the sunset' do
          expect(subject.next_date(DateTime.new(2016, 02, 22, 19, 59, 0, LOCAL_OFFSET))).to eq(
            DateTime.new(2016, 02, 22, 20, 0, 0, LOCAL_OFFSET)
          )
        end
        it 'returns the sunset on the next day when after the sunset' do
          expect(subject.next_date(DateTime.new(2016, 02, 22, 20, 0, 0, LOCAL_OFFSET))).to eq(
            DateTime.new(2016, 02, 23, 20, 0, 0, LOCAL_OFFSET)
          )
        end
      end


    end
  end
end
